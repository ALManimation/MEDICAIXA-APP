# Explorer 2 Context: iOS & macOS Native Alarm Integration
- Target: ios/Runner/Info.plist, ios/Runner/Runner.entitlements, macos/Runner/DebugProfile.entitlements, macos/Runner/Release.entitlements, macos/Runner/Info.plist
- Permissions: Critical Alerts, Background Modes (audio, fetch), local network/notification entitlements on macOS.
- OS constraints: Requesting Critical Alerts entitlement, AVAudioSession configuration for background playback, Time-Sensitive notifications on macOS.
