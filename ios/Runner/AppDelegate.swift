import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let quickCaptureChannelName = "com.fittechs.durunotes/quick_capture_widget"
  private lazy var quickCaptureStore = QuickCaptureSharedStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase with safety checks
    var firebaseConfigured = false
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
      print("✅ Firebase config file found at: \(path)")
      FirebaseApp.configure()
      print("✅ Firebase configured successfully")
      firebaseConfigured = true
    } else {
      print("❌ GoogleService-Info.plist not found - Firebase disabled")
      // Continue without Firebase to prevent app crash
    }

    // Only setup Firebase-dependent features if Firebase is configured
    if firebaseConfigured {
      // Register for remote notifications
      UNUserNotificationCenter.current().delegate = self

      // Request notification permissions
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )

      application.registerForRemoteNotifications()

      // Set messaging delegate
      Messaging.messaging().delegate = self
    } else {
      print("⚠️ Push notifications disabled - Firebase not configured")
    }
    
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      configureQuickCaptureChannel(controller)
    } else {
      NSLog("[QuickCapture] Unable to locate FlutterViewController for method channel registration")
    }

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

    // Forward to Flutter via method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let deepLinkChannel = FlutterMethodChannel(
        name: "com.fittechs.durunotes/deep_links",
        binaryMessenger: controller.binaryMessenger
      )

      deepLinkChannel.invokeMethod("handleDeepLink", arguments: url.absoluteString)
      print("✅ [DeepLink] Forwarded to Flutter: \(url.absoluteString)")
    } else {
      print("❌ [DeepLink] FlutterViewController not available")
    }

    return true
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
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(fcmToken ?? "nil")")
  }
}
