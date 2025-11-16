import Flutter
import UIKit
// TEMPORARILY COMMENTED OUT FOR DEBUGGING:
// import FirebaseCore
// import FirebaseMessaging
// import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // TEMPORARILY COMMENTED OUT FOR DEBUGGING:
  // private let quickCaptureChannelName = "com.fittechs.durunotes/quick_capture_widget"
  // private let shareExtensionChannelName = "com.fittechs.durunotes/share_extension"
  // private let firebaseBootstrapper = FirebaseBootstrapper()
  // private lazy var quickCaptureStore = QuickCaptureSharedStore()
  // private lazy var shareExtensionStore = ShareExtensionSharedStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSLog("🔵 [AppDelegate] MINIMAL VERSION - didFinishLaunchingWithOptions STARTED")

    // PHASE 1 TEST: Only register plugins, nothing else
    NSLog("🔵 [AppDelegate] About to register plugins...")
    GeneratedPluginRegistrant.register(with: self)
    NSLog("🔵 [AppDelegate] Plugin registration complete")

    NSLog("🔵 [AppDelegate] Calling super.application()")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    NSLog("🔵 [AppDelegate] didFinishLaunchingWithOptions COMPLETED, returning \(result)")
    return result
  }

  // ALL OTHER METHODS COMMENTED OUT FOR PHASE 1 TEST
  /*
  // Handle APNs token registration
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    NSLog("🔵 [AppDelegate] didRegisterForRemoteNotificationsWithDeviceToken CALLED")
    // Pass device token to Firebase only if Firebase is configured
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    NSLog("🔵 [AppDelegate] didRegisterForRemoteNotificationsWithDeviceToken COMPLETED")
  }

  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    NSLog("🔵 [AppDelegate] didFailToRegisterForRemoteNotificationsWithError CALLED")
    NSLog("❌ [AppDelegate] Failed to register for remote notifications: \(error)")
    NSLog("🔵 [AppDelegate] didFailToRegisterForRemoteNotificationsWithError COMPLETED")
  }

  // MARK: - Deep Link Handling
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    NSLog("📱 [DeepLink] Received URL: \(url.absoluteString)")

    guard url.scheme == "durunotes" else {
      NSLog("❌ [DeepLink] Invalid scheme: \(url.scheme ?? "nil")")
      return false
    }

    guard let controller = resolveFlutterViewController() else {
      NSLog("❌ [DeepLink] FlutterViewController not available")
      return false
    }

    let deepLinkChannel = FlutterMethodChannel(
      name: "com.fittechs.durunotes/deep_links",
      binaryMessenger: controller.binaryMessenger
    )

    deepLinkChannel.invokeMethod("handleDeepLink", arguments: url.absoluteString)
    NSLog("✅ [DeepLink] Forwarded to Flutter: \(url.absoluteString)")

    return true
  }

  private func attachMethodChannels() {
    NSLog("🔵 [AppDelegate] attachMethodChannels STARTED")
    NSLog("🔵 [AppDelegate] About to resolve FlutterViewController...")
    guard let controller = resolveFlutterViewController() else {
      NSLog("❌ [AppDelegate] Unable to locate FlutterViewController for method channel registration")
      return
    }
    NSLog("✅ [AppDelegate] FlutterViewController resolved successfully")

    NSLog("🔵 [AppDelegate] Configuring QuickCaptureChannel...")
    configureQuickCaptureChannel(controller)
    NSLog("✅ [AppDelegate] QuickCaptureChannel configured")

    NSLog("🔵 [AppDelegate] Configuring ShareExtensionChannel...")
    configureShareExtensionChannel(controller)
    NSLog("✅ [AppDelegate] ShareExtensionChannel configured")
    NSLog("🔵 [AppDelegate] attachMethodChannels COMPLETED")
  }

  private func resolveFlutterViewController() -> FlutterViewController? {
    NSLog("🔵 [AppDelegate] resolveFlutterViewController STARTED")
    NSLog("🔵 [AppDelegate] Trying window?.rootViewController...")
    if let flutterViewController = locateFlutterViewController(from: window?.rootViewController) {
      NSLog("✅ [AppDelegate] Found FlutterViewController from window.rootViewController")
      return flutterViewController
    }

    NSLog("🔵 [AppDelegate] window.rootViewController didn't work, trying keyWindow...")
    let keyWindowRootController = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController

    let result = locateFlutterViewController(from: keyWindowRootController)
    if result != nil {
      NSLog("✅ [AppDelegate] Found FlutterViewController from keyWindow")
    } else {
      NSLog("❌ [AppDelegate] FlutterViewController NOT FOUND anywhere!")
    }
    return result
  }

  private func locateFlutterViewController(from controller: UIViewController?) -> FlutterViewController? {
    if let flutterViewController = controller as? FlutterViewController {
      return flutterViewController
    }

    if let navigationController = controller as? UINavigationController {
      for child in navigationController.viewControllers {
        if let flutterViewController = locateFlutterViewController(from: child) {
          return flutterViewController
        }
      }
    }

    if let tabController = controller as? UITabBarController {
      for child in tabController.viewControllers ?? [] {
        if let flutterViewController = locateFlutterViewController(from: child) {
          return flutterViewController
        }
      }
    }

    if let presentedController = controller?.presentedViewController {
      return locateFlutterViewController(from: presentedController)
    }

    return nil
  }

  private func configureQuickCaptureChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: quickCaptureChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "quick_capture_disposed", message: "AppDelegate deallocated", details: nil))
        return
      }

      self.handleQuickCapture(methodCall: call, result: result)
    }
  }

  private func handleQuickCapture(methodCall call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "syncWidgetCache":
      guard
        let arguments = call.arguments as? [String: Any],
        let userId = arguments["userId"] as? String,
        let payload = arguments["payload"] as? [String: Any]
      else {
        result(
          FlutterError(
            code: "quick_capture_invalid_args",
            message: "Expected map with userId and payload",
            details: nil
          )
        )
        return
      }

      do {
        try quickCaptureStore.writePayload(payload, userId: userId)
        DispatchQueue.main.async {
          WidgetCenter.shared.reloadTimelines(ofKind: QuickCaptureSharedStore.widgetKind)
        }
        result(nil)
      } catch {
        result(
          FlutterError(
            code: "quick_capture_write_failed",
            message: "Failed to persist widget payload",
            details: error.localizedDescription
          )
        )
      }
    case "clearWidgetCache":
      quickCaptureStore.clear()
      DispatchQueue.main.async {
        WidgetCenter.shared.reloadTimelines(ofKind: QuickCaptureSharedStore.widgetKind)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func configureShareExtensionChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: shareExtensionChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "share_extension_disposed", message: "AppDelegate deallocated", details: nil))
        return
      }

      self.handleShareExtension(methodCall: call, result: result)
    }
  }

  private func handleShareExtension(methodCall call: FlutterMethodCall, result: FlutterResult) {
    switch call.method {
    case "getSharedItems":
      if let items = shareExtensionStore.readSharedItems() {
        NSLog("✅ [ShareExtension] Retrieved \(items.count) shared items from App Group")
        result(items)
      } else {
        NSLog("ℹ️ [ShareExtension] No shared items found in App Group")
        result([])
      }
    case "clearSharedItems":
      shareExtensionStore.clearSharedItems()
      NSLog("✅ [ShareExtension] Cleared shared items from App Group")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  */
}

// MARK: - MessagingDelegate
// TEMPORARILY COMMENTED OUT FOR DEBUGGING:
/*
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    NSLog("🔵 [Firebase] Registration token: \(fcmToken ?? "nil")")
  }
}
*/
