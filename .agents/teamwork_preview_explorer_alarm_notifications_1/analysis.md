# Android Native Alarm and Sound Integration Analysis

This analysis outlines the native Android requirements for implementing a highly reliable, reboot-resilient, and lock-screen-capable alarm notification system for the MediCaixa application. It includes required configuration edits for `AndroidManifest.xml`, Kotlin level updates for `MainActivity`, Dart/Flutter runtime permission recommendations, and details the Android design section for `docs/integration_plan.md`.

---

## 1. Android Permission Analysis

To achieve a full-screen alarm experience that rings reliably on schedule and survives device restarts, the following permissions must be configured:

### A. `android.permission.USE_FULL_SCREEN_INTENT`
- **Why it is required**: Android 10 (API 29) introduced background activity launch restrictions. Apps cannot launch an activity directly from the background. To show the alarm response screen (`AlarmActiveScreen`) over the lock screen or as a heads-up banner when the device is in use, we must trigger a high-priority notification with a `fullScreenIntent`. This permission authorizes the use of full-screen intents.
- **Android 14 (API 34) Updates**: On Android 14+, this is a special app access permission. For apps targeting API 34+, Google Play restricts it to apps whose core function fits specific categories (e.g., dialer, alarms). Since MediCaixa is a critical health reminder/alarm app, it fits the criteria.

### B. `android.permission.SCHEDULE_EXACT_ALARM`
- **Why it is required**: To schedule alarms at exact times (e.g., 08:00:00), the app must invoke Android's `AlarmManager` with exact scheduling API methods (`setExact()`, `setExactAndAllowWhileIdle()`, or `setAlarmClock()`). This permission enables scheduling exact alarms.
- **Android 14 (API 34) Updates**: This permission is no longer granted by default to newly installed apps on Android 14+. The app must check at runtime if it is allowed, and if not, redirect the user to the system settings page to grant it.

### C. `android.permission.USE_EXACT_ALARM`
- **Why it is required**: Added in Android 13 (API 33). It is a normal permission (automatically granted at install time) that allows scheduling exact alarms.
- **Google Play Policy Caution**: Google Play Store restricts the use of `USE_EXACT_ALARM` strictly to apps where the core user-facing functionality is an alarm clock, timer, or calendar. If a medication app declares this, it faces a high risk of rejection unless it goes through a manual declaration. 
- **Recommendation**: Declare both `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` in the manifest for maximum coverage, but for Play Store releases, it is safer to only use `SCHEDULE_EXACT_ALARM` and request manual user consent at runtime to avoid store policy rejection.

### D. `android.permission.WAKE_LOCK`
- **Why it is required**: When the alarm fires, the CPU must stay awake to initialize the Flutter engine, play the sound file, and render the initial UI. Declaring `WAKE_LOCK` allows the notification service or broadcast receiver to use a power manager wake lock to prevent the device from going back to sleep prematurely.

### E. `android.permission.RECEIVE_BOOT_COMPLETED`
- **Why it is required**: The operating system wipes all active `AlarmManager` schedules upon reboot. The app must receive the boot completed broadcast, read the SQLite database (Drift), and reschedule all active alarms.
- **How it's handled**: The `flutter_local_notifications` plugin has a built-in receiver (`ScheduledNotificationBootReceiver`) that automatically reschedules zoned notifications on boot. However, this receiver must be declared in the manifest, and the `RECEIVE_BOOT_COMPLETED` permission must be requested.

### F. `android.permission.POST_NOTIFICATIONS`
- **Why it is required**: Required starting from Android 13 (API 33) to post notifications. Must be requested at runtime.

---

## 2. File to Modify: `android/app/src/main/AndroidManifest.xml`

Below is the exact diff proposed to update the Android manifest file.

```xml
<<<<
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:label="medicaixa_app"
        android:name="${applicationName}"
        android:icon="@mipmap/launcher_icon">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
====
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Network & Local Connection Permissions -->
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Alarm & Sound Background Permissions -->
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.USE_EXACT_ALARM" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <application
        android:label="medicaixa_app"
        android:name="${applicationName}"
        android:icon="@mipmap/launcher_icon">
        
        <!-- Broadcast Receiver for Reboot Resiliency (flutter_local_notifications) -->
        <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize"
            android:showWhenLocked="true"
            android:turnScreenOn="true">
>>>>
```

---

## 3. Kotlin Modification (`MainActivity.kt`)

To guarantee the screen turns on and the main activity displays over the keyguard (lock screen) programmatically when a full-screen intent is launched, the `MainActivity.kt` file should be updated.

**Path**: `android/app/src/main/kotlin/com/medicaixa/medicaixa_app/MainActivity.kt`

### Proposed Code:
```kotlin
package com.medicaixa.medicaixa_app

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Ensure screen turns on and bypasses lock screen when full screen intent activity launches
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}
```

---

## 4. Dart / Flutter Runtime Permission and Launch Strategy

### A. Runtime Notification Permission Check (Android 13+)
Using `flutter_local_notifications`:
```dart
Future<void> requestNotificationPermissions() async {
  if (Platform.isAndroid) {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    // Requests POST_NOTIFICATIONS permission on Android 13+
    final bool? granted = await androidPlugin?.requestNotificationsPermission();
    debugPrint('Notification permission granted: $granted');
  }
}
```

### B. Exact Alarm Permission Check and Request (Android 14+)
Before scheduling an exact alarm, check if the permission is enabled. If not, request it, which redirects the user to the system's "Alarms & Reminders" settings screen.
```dart
Future<bool> checkAndRequestExactAlarms() async {
  if (!Platform.isAndroid) return true;

  final androidPlugin = _notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin == null) return false;

  // Check if we are permitted to schedule exact alarms
  final bool? isGranted = await androidPlugin.areExactAlarmsPermissionGranted();
  
  if (isGranted == false) {
    debugPrint('Exact alarms permission is not granted. Requesting...');
    // Redirects user to Settings -> Special App Access -> Alarms & Reminders
    final bool? requested = await androidPlugin.requestExactAlarmsPermission();
    return requested ?? false;
  }

  return true;
}
```

### C. Boot-start and App Initialization Launch Detection
When the phone boots or when the user taps on a notification, the Flutter engine needs to know why the app launched to display the correct route.
```dart
Future<void> handleAppLaunchFromNotification() async {
  final NotificationAppLaunchDetails? launchDetails =
      await _notificationsPlugin.getNotificationAppLaunchDetails();

  if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
    final NotificationResponse? response = launchDetails.notificationResponse;
    if (response != null && response.payload != null) {
      debugPrint('App launched via notification. Payload: ${response.payload}');
      // Route to AlarmActiveScreen or perform action based on payload
    }
  }
}
```

---

## 5. Engineering Plan Design: Android Section (`docs/integration_plan.md`)

This section contains the finalized layout and details designed specifically for the Android portion of the project's overall `docs/integration_plan.md`.

```markdown
## Android Platform Integration

### 1. Architectural Strategy
On Android, MediCaixa uses a combination of Android's system `AlarmManager` and `NotificationManager` APIs (interfaced via `flutter_local_notifications`) to schedule precise reminders. 
When an alarm is triggered:
1. `AlarmManager` fires a broadcast intent.
2. The `ScheduledNotificationReceiver` handles the intent, acquires a `WakeLock`, and sends a high-importance notification.
3. Because the notification is configured with `fullScreenIntent`, the OS immediately launches the app's `MainActivity` on top of the lock screen (using the window attributes configured in the manifest and Kotlin).

### 2. Permissions Declared in `AndroidManifest.xml`
- `android.permission.USE_FULL_SCREEN_INTENT`: Authorizes high-priority full-screen notifications.
- `android.permission.SCHEDULE_EXACT_ALARM`: Enables exact timing constraints for medication intervals on Android 12+.
- `android.permission.USE_EXACT_ALARM`: Automatically grants exact scheduling on Android 13+ (for standalone/sideloaded testing, keep monitored due to Play Store restrictions).
- `android.permission.WAKE_LOCK`: Prevents CPU suspension during alarm sound playback.
- `android.permission.RECEIVE_BOOT_COMPLETED`: Reschedules all alarms on device reboot.
- `android.permission.POST_NOTIFICATIONS`: Requests permission to display notifications (Android 13+).
- `android.permission.FOREGROUND_SERVICE`: Supports prolonged alarm operations in the background.

### 3. Reboot Resiliency
A reboot clears the OS alarm list. Rescheduling is managed by registering `com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver`.
On `BOOT_COMPLETED`, the receiver loads scheduled notifications from the plugin's internal database and re-registers them in `AlarmManager`.

### 4. Lock Screen Interface and Window Settings
The app's main activity is configured in `AndroidManifest.xml` with:
- `android:showWhenLocked="true"`
- `android:turnScreenOn="true"`

Programmatic enforcement in `MainActivity.kt`:
```kotlin
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
    setShowWhenLocked(true)
    setTurnScreenOn(true)
} else {
    window.addFlags(
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
    )
}
```

### 5. Custom Sounds
Custom alarm sound files (e.g., `med_alarm.mp3`) must be stored in `android/app/src/main/res/raw/med_alarm.mp3`. They are referenced in `AndroidNotificationDetails` as a `RawResourceAndroidNotificationSound('med_alarm')` without the `.mp3` extension.
```
