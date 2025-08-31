import UIKit
import Flutter
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // Register all Flutter plugins for the main isolate.
    GeneratedPluginRegistrant.register(with: self)
    
    // TODO: Register custom share extension plugin when Xcode project is updated
    // ShareExtensionPlugin.register(with: self.registrar(forPlugin: "ShareExtensionPlugin")!)

    // Show notifications while app is in foreground (iOS 10+)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // ---- Background isolate plugin registration (e.g. flutter_local_notifications) ----
    // Some plugins spin up a background Flutter engine. For those engines to find
    // your plugins, we pass a registrar block that calls GeneratedPluginRegistrant.
    if let pluginClass = NSClassFromString("FlutterLocalNotificationsPlugin") as? NSObject.Type {

      // Block that registers all plugins on a given registry.
      let registrarBlock: (@convention(block) (FlutterPluginRegistry) -> Void) = { registry in
        GeneratedPluginRegistrant.register(with: registry)
      }

      // Support both the new and legacy selector names.
      let newSelector = NSSelectorFromString("setRegisterPlugins:")
      let oldSelector = NSSelectorFromString("setPluginRegistrantCallback:")

      if pluginClass.responds(to: newSelector) {
        _ = pluginClass.perform(newSelector, with: registrarBlock)
      } else if pluginClass.responds(to: oldSelector) {
        _ = pluginClass.perform(oldSelector, with: registrarBlock)
      }
    }
    // -------------------------------------------------------------------------------

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
