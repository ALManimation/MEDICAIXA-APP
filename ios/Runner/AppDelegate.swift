import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Trigger swizzling of UNUserNotificationCenter
    _ = UNUserNotificationCenter.swizzleAdd
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

extension UNUserNotificationCenter {
    static let swizzleAdd: Void = {
        let originalSelector = #selector(add(_:withCompletionHandler:))
        let swizzledSelector = #selector(swizzled_add(_:withCompletionHandler:))
        
        guard let originalMethod = class_getInstanceMethod(UNUserNotificationCenter.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UNUserNotificationCenter.self, swizzledSelector) else {
            return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()
    
    @objc func swizzled_add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        let content = request.content
        if #available(iOS 15.0, *), content.interruptionLevel == .critical {
            var sound: UNNotificationSound = .defaultCritical
            if let soundRef = content.sound {
                let selector = NSSelectorFromString("soundFileName")
                if soundRef.responds(to: selector),
                   let fileName = soundRef.value(forKey: "soundFileName") as? String,
                   !fileName.isEmpty && fileName != "default" {
                    sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName(rawValue: fileName), withAudioVolume: 1.0)
                }
            }
            
            if let mutableContent = content.mutableCopy() as? UNMutableNotificationContent {
                mutableContent.sound = sound
                let newRequest = UNNotificationRequest(identifier: request.identifier, content: mutableContent, trigger: request.trigger)
                swizzled_add(newRequest, withCompletionHandler: completionHandler)
                return
            }
        }
        
        swizzled_add(request, withCompletionHandler: completionHandler)
    }
}
