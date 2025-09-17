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
    
    // Register Widget Bridge for Quick Capture Widget
    // TODO: Uncomment when WidgetBridge.swift is added to Xcode project
    // if let controller = window?.rootViewController as? FlutterViewController {
    //   WidgetBridge.register(with: controller)
    // }
    
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
  
  // MARK: - Deep Link Handling for Widget
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    // Handle widget deep links
    // TODO: Uncomment when WidgetBridge.swift is added to Xcode project
    // if WidgetBridge.handleAppLaunch(with: url) {
    //   return true
    // }
    
    // Handle other deep links
    return super.application(app, open: url, options: options)
  }
  
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Handle universal links from widget
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL,
       url.scheme == "durunotes" {
      // TODO: Uncomment when WidgetBridge.swift is added to Xcode project
      // return WidgetBridge.handleAppLaunch(with: url)
      return false
    }
    
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
  
  // MARK: - Widget Lifecycle
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    // Update widget data when app goes to background
    NotificationCenter.default.post(name: Notification.Name("UpdateWidgetData"), object: nil)
  }
  
  override func applicationWillTerminate(_ application: UIApplication) {
    super.applicationWillTerminate(application)
    // Clear sensitive widget data on app termination if needed
    // WidgetBridge.clearWidgetData() // Uncomment if you want to clear data on termination
  }
}
