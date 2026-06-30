import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var appNapActivityToken: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "com.medicaixa.app/app_nap", binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, result) in
        guard let self = self else { return }
        if call.method == "start" {
          if self.appNapActivityToken == nil {
            self.appNapActivityToken = ProcessInfo.processInfo.beginActivity(
              options: [.userInitiated, .latencyCritical, .idleSystemSleepDisabled],
              reason: "MediCaixa active alarm playing sound"
            )
          }
          result(nil)
        } else if call.method == "stop" {
          if let token = self.appNapActivityToken {
            ProcessInfo.processInfo.endActivity(token)
            self.appNapActivityToken = nil
          }
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
