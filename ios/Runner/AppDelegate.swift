import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let quickCaptureChannelName = "com.fittechs.durunotes/quick_capture_widget"
  private let shareExtensionChannelName = "com.fittechs.durunotes/share_extension"
  private let firebaseBootstrapper = FirebaseBootstrapper()
  private lazy var quickCaptureStore = QuickCaptureSharedStore()
  private lazy var shareExtensionStore = ShareExtensionSharedStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let firebaseState = firebaseBootstrapper.configureIfNeeded()
    switch firebaseState {
    case .configured:
      print("✅ Firebase configured successfully")
    case .alreadyConfigured:
      print("ℹ️ Firebase already configured — skipping duplicate configure() call")
    case .missingPlist:
      print("❌ GoogleService-Info.plist not found - Firebase disabled")
    }

    if firebaseState.isReady {
      UNUserNotificationCenter.current().delegate = self

      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )

      application.registerForRemoteNotifications()
      Messaging.messaging().delegate = self
    } else {
      print("⚠️ Push notifications disabled - Firebase not configured")
    }

    GeneratedPluginRegistrant.register(with: self)

    attachMethodChannels()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle APNs token registration
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass device token to Firebase only if Firebase is configured
    if FirebaseApp.app() != nil {
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }

  // MARK: - Deep Link Handling
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    print("📱 [DeepLink] Received URL: \(url.absoluteString)")

    guard url.scheme == "durunotes" else {
      print("❌ [DeepLink] Invalid scheme: \(url.scheme ?? "nil")")
      return false
    }

    guard let controller = resolveFlutterViewController() else {
      print("❌ [DeepLink] FlutterViewController not available")
      return false
    }

    let deepLinkChannel = FlutterMethodChannel(
      name: "com.fittechs.durunotes/deep_links",
      binaryMessenger: controller.binaryMessenger
    )

    deepLinkChannel.invokeMethod("handleDeepLink", arguments: url.absoluteString)
    print("✅ [DeepLink] Forwarded to Flutter: \(url.absoluteString)")

    return true
  }

  private func attachMethodChannels() {
    guard let controller = resolveFlutterViewController() else {
      NSLog("[Bootstrap] Unable to locate FlutterViewController for method channel registration")
      return
    }

    configureQuickCaptureChannel(controller)
    configureShareExtensionChannel(controller)
  }

  private func resolveFlutterViewController() -> FlutterViewController? {
    if let flutterViewController = locateFlutterViewController(from: window?.rootViewController) {
      return flutterViewController
    }

    let keyWindowRootController = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController

    return locateFlutterViewController(from: keyWindowRootController)
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
        print("[ShareExtension] ✅ Retrieved \(items.count) shared items from App Group")
        result(items)
      } else {
        print("[ShareExtension] ℹ️ No shared items found in App Group")
        result([])
      }
    case "clearSharedItems":
      shareExtensionStore.clearSharedItems()
      print("[ShareExtension] ✅ Cleared shared items from App Group")
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(fcmToken ?? "nil")")
  }
}
