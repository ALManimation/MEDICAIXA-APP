# Adversarial Challenge Report — Settings C++ API Integration Robustness

## Challenge Summary

**Overall risk assessment**: MEDIUM

While the Settings C++ API client has robust exception safety (due to `try/catch` and `AsyncValue.guard` blocks), we discovered a **critical type mismatch bug** in the production implementation of `restartDevice` and `resetDevicePartitions`. Both methods register an error handler using `.catchError((_) => null)` on a `Future<Response<dynamic>>`. In Dart, the error handler callback of `Future.catchError` must return a value matching the future's type (or a future of that type). Returning `null` throws an `ArgumentError` at runtime, completely breaking the recovery paths.

Other integrations—such as JSON parsing, timeout configurations, and sequential request queueing via `RequestLock`—are highly robust and function exactly as designed.

---

## Challenges & Vulnerabilities Found

### [High] Challenge 1: Invalid `Future.catchError` signature causes runtime `ArgumentError` on `/restart` failure
- **Assumption challenged**: Assumed that `.catchError((_) => null)` on a `Future<Response>` is a safe way to ignore connection errors when triggering a reboot.
- **Attack scenario**: When `settingsRepo.restartDevice()` is invoked and the request fails (e.g. peer resets connection, network timeout), Dart's async runtime throws:
  `Invalid argument(s) (onError): The error handler of Future.catchError must return a value of the future's type`
- **Blast radius**: This error causes a crash in the async loop or propagates out of the caller, causing unexpected failures instead of cleanly ignoring the connection reset.
- **Vulnerability confirmed**: Confirmed in unit testing (`restartDevice triggers a runtime error due to incorrect catchError usage (production bug)`).
- **Mitigation**: Update the `catchError` callback signature to return a compatible type or use standard `try/catch` blocks:
  ```dart
  Future<void> restartDevice() async {
    try {
      await _dioClient.post('/restart');
    } catch (_) {
      // Cleanly ignore connection errors on restart
    }
  }
  ```

### [High] Challenge 2: Broken standalone redirection after partition resets when `/restart` fails
- **Assumption challenged**: Assumed that `DeviceResetNotifier.resetDevicePartitions` would always transition the app to standalone mode on Wi-Fi/factory resets even if the ESP32 disconnects.
- **Attack scenario**: In `resetDevicePartitions` (line 361 of `settings_repository.dart`), the app posts to `/restart` and registers `.catchError((_) => null)`. When the network connection fails or gets reset (which is expected because the ESP32 is rebooting/wiping Wi-Fi), the same `ArgumentError` is thrown.
- **Blast radius**: The exception aborts the remaining execution of the block inside `AsyncValue.guard`. Consequently, the 8-second delay and the redirection to standalone mode (`useStandalone()`) are skipped. The app state remains stuck as "connected" to a device that is no longer accessible.
- **Vulnerability confirmed**: Confirmed in unit testing (`DeviceResetNotifier.resetDevicePartitions triggers runtime error when /restart fails during reset`).
- **Mitigation**: Wrap the reboot request in a try/catch block to ensure that the recovery and redirect logic is never skipped.

### [Medium] Challenge 3: Malformed JSON types during `/settings` sync
- **Assumption challenged**: Assumed that fields like `speaker_volume` and `brightness` would always be integers in the JSON response from ESP32.
- **Attack scenario**: If the ESP32 responds with a String (e.g., `'high'` or `'true'`), casting `map['speaker_volume'] as num?` throws a `TypeError`.
- **Blast radius**: This exception is caught by the outer `try/catch` block in `syncSettings()`. The app does not crash, but the database update is skipped entirely.
- **Mitigation**: Use a safer parser (e.g. parsing helper that parses values defensively) to extract numbers from JSON.

---

## Stress Test & Robustness Results

- **Network Failures (GET `/server_time`, POST `/test_sound`)** → Throws descriptive network/connection exceptions rather than generic failures. → **PASS**
- **Slow Connections & Timeout Triggers** → Correctly respects `AppConstants.requestTimeoutMs` (5000ms) and throws timeout exceptions on `/server_time` and `/backup`. → **PASS**
- **Malformed JSON Response Formats** → `fetchDeviceTime` throws `TypeError` on string responses or invalid type casts; `syncSettings` handles invalid/non-numeric values gracefully without crash. → **PASS**
- **Sequential Request Queueing (FIFO Lock)** → Verified that `RequestLock` correctly serializes incoming async tasks in a strict FIFO order. Sequential calls to `DioClient.get` and `DioClient.post` are serialized to avoid ESP32 memory overload. → **PASS**
- **Wi-Fi Repository Robustness** → Network failures, timeouts, and malformed inputs (rssi type cast errors) are successfully handled. → **PASS**
- **Backup/Restore Robustness** → Verified that `executeBackupRestore` correctly maps the restored file count and throws `TypeError` on invalid payload signatures. → **PASS**

---

## Unchallenged Areas

- **Actual ESP32 memory leaks under load** — Although request serialization was verified via unit tests, actual hardware behavior under concurrent pressure can only be observed on real hardware.
