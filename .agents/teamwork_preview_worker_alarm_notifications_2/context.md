# Worker Alarm Notifications Refinement Context
- Target: Refine code implementations based on feedback from Reviewer 1, Challenger 1, and Challenger 2.
- Items to fix:
  - iOS Swift Runner (`ios/Runner/AppDelegate.swift`): remove macOS protocols, add `GeneratedPluginRegistrant.register(with: self)`.
  - Android MainActivity (`MainActivity.kt`): set FLAG_KEEP_SCREEN_ON programmatically.
  - Zoned scheduling DST shifts (`NotificationService.dart`): calculate next day timezone-safely without absolute 24h duration additions.
  - Android Custom Sound names (`NotificationService.dart`): strip extensions.
  - Zoned scheduling ID collisions (`NotificationService.dart`): ensure robust calculations.
  - Error handling: try-catch in scheduled loop, try-catch in active screen vibration, try-catch in local sound player fallback.
