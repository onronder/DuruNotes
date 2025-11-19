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
    NSLog("🔵 [AppDelegate] iOS 18.6 MANUAL WINDOW FIX - didFinishLaunchingWithOptions STARTED")

    // Call super first - this sets up the Flutter engine and registers plugins internally
    NSLog("🔵 [AppDelegate] Calling super.application()")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    NSLog("🔵 [AppDelegate] super.application() returned \(result)")

    // iOS 18.6 FIX: Check if window was created, if not create it manually
    if window == nil {
      NSLog("🔵 [AppDelegate] Window is nil after super.application(), creating manually for iOS 18.6...")

      // Create window and FlutterViewController
      // FlutterViewController() without engine param uses the shared engine from FlutterAppDelegate
      window = UIWindow(frame: UIScreen.main.bounds)
      let flutterViewController = FlutterViewController()
      window?.rootViewController = flutterViewController
      window?.makeKeyAndVisible()

      NSLog("✅ [AppDelegate] Window manually created: exists=\(window != nil), isKey=\(window?.isKeyWindow ?? false)")
      NSLog("✅ [AppDelegate] FlutterViewController set as rootViewController")
    } else {
      NSLog("✅ [AppDelegate] Window already exists from super.application()")
    }

    // Register plugins AFTER window is created
    NSLog("🔵 [AppDelegate] Registering plugins...")
    GeneratedPluginRegistrant.register(with: self)
    NSLog("✅ [AppDelegate] Plugins registered")

    // BLACK SCREEN FIX: Setup diagnostics channel
    setupWindowDiagnosticsChannel()

    NSLog("🔵 [AppDelegate] didFinishLaunchingWithOptions COMPLETED")
    NSLog("🔵 [AppDelegate] Final window state: exists=\(window != nil), isKey=\(window?.isKeyWindow ?? false)")

    return result
  }

  // BLACK SCREEN FIX: Setup method channel for window diagnostics
  private func setupWindowDiagnosticsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ [Diagnostics] Cannot setup channel - no FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.fittechs.durunotes/window_diagnostics",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "getWindowState" {
        result(self?.getWindowStateDictionary() ?? [:])
      } else if call.method == "logPlatformState" {
        guard let args = call.arguments as? [String: Any],
              let context = args["context"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing context", details: nil))
          return
        }
        self?.logPlatformStateToConsole(context: context)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ [Diagnostics] Window diagnostics channel registered")
  }

  // BLACK SCREEN FIX: Log platform state at specific execution points
  private func logPlatformStateToConsole(context: String) {
    NSLog("📊 [PlatformState] ========== \(context) ==========")
    NSLog("📊 [MainThread] Is main thread: \(Thread.isMainThread)")

    // Window state
    if let window = self.window {
      NSLog("📊 [Window] exists=true, isKey=\(window.isKeyWindow), hidden=\(window.isHidden), alpha=\(window.alpha)")

      // Root ViewController
      if let rootVC = window.rootViewController {
        NSLog("📊 [RootVC] type=\(String(describing: type(of: rootVC)))")
        NSLog("📊 [RootVC] view.alpha=\(rootVC.view.alpha), hidden=\(rootVC.view.isHidden)")

        // Presented ViewController (modals)
        if let presentedVC = rootVC.presentedViewController {
          NSLog("📊 [PresentedVC] type=\(String(describing: type(of: presentedVC)))")
          NSLog("📊 [PresentedVC] isBeingDismissed=\(presentedVC.isBeingDismissed)")
          NSLog("📊 [PresentedVC] view.alpha=\(presentedVC.view.alpha)")
        } else {
          NSLog("📊 [PresentedVC] none")
        }

        // Check if FlutterViewController
        if rootVC is FlutterViewController {
          NSLog("📊 [FlutterVC] Confirmed as FlutterViewController")
        } else {
          NSLog("📊 [FlutterVC] ⚠️ NOT FlutterViewController!")
        }
      } else {
        NSLog("📊 [RootVC] ❌ DOES NOT EXIST")
      }
    } else {
      NSLog("📊 [Window] ❌ DOES NOT EXIST")
    }

    // All windows count
    let allWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    NSLog("📊 [AllWindows] count=\(allWindows.count)")

    NSLog("📊 [PlatformState] ========================================")
  }

  // BLACK SCREEN FIX: Get window state as dictionary
  private func getWindowStateDictionary() -> [String: Any] {
    var state: [String: Any] = [:]

    if let window = self.window {
      state["window_exists"] = true
      state["is_key_window"] = window.isKeyWindow
      state["is_hidden"] = window.isHidden
      state["alpha"] = window.alpha
      state["frame_width"] = window.frame.width
      state["frame_height"] = window.frame.height
      state["background_color"] = window.backgroundColor?.description ?? "nil"

      if let rootVC = window.rootViewController {
        state["root_vc_type"] = String(describing: type(of: rootVC))
        state["root_vc_view_alpha"] = rootVC.view.alpha
        state["root_vc_view_hidden"] = rootVC.view.isHidden
        state["root_vc_view_frame_width"] = rootVC.view.frame.width
        state["root_vc_view_frame_height"] = rootVC.view.frame.height

        if let flutterVC = rootVC as? FlutterViewController {
          state["is_flutter_vc"] = true
          state["flutter_subviews_count"] = flutterVC.view.subviews.count

          var subviewsInfo: [[String: Any]] = []
          for (index, subview) in flutterVC.view.subviews.enumerated() {
            subviewsInfo.append([
              "index": index,
              "type": String(describing: type(of: subview)),
              "alpha": subview.alpha,
              "hidden": subview.isHidden,
              "width": subview.frame.width,
              "height": subview.frame.height
            ])
          }
          state["flutter_subviews"] = subviewsInfo
        } else {
          state["is_flutter_vc"] = false
        }
      } else {
        state["root_vc_exists"] = false
      }
    } else {
      state["window_exists"] = false
    }

    return state
  }

  // BLACK SCREEN FIX: Log detailed window and view state
  private func logWindowState() {
    NSLog("🪟 [Window Diagnostics] ========== START ==========")

    // Check window
    if let window = self.window {
      NSLog("🪟 [Window] EXISTS")
      NSLog("🪟 [Window] isKeyWindow: \(window.isKeyWindow)")
      NSLog("🪟 [Window] isHidden: \(window.isHidden)")
      NSLog("🪟 [Window] alpha: \(window.alpha)")
      NSLog("🪟 [Window] frame: \(window.frame)")
      NSLog("🪟 [Window] bounds: \(window.bounds)")
      NSLog("🪟 [Window] backgroundColor: \(String(describing: window.backgroundColor))")

      // Check rootViewController
      if let rootVC = window.rootViewController {
        NSLog("🪟 [RootViewController] EXISTS: \(type(of: rootVC))")
        NSLog("🪟 [RootViewController] view.alpha: \(rootVC.view.alpha)")
        NSLog("🪟 [RootViewController] view.isHidden: \(rootVC.view.isHidden)")
        NSLog("🪟 [RootViewController] view.frame: \(rootVC.view.frame)")
        NSLog("🪟 [RootViewController] view.backgroundColor: \(String(describing: rootVC.view.backgroundColor))")

        // Check if it's FlutterViewController
        if let flutterVC = rootVC as? FlutterViewController {
          NSLog("🪟 [FlutterVC] CONFIRMED as FlutterViewController")
          NSLog("🪟 [FlutterVC] view.subviews.count: \(flutterVC.view.subviews.count)")

          for (index, subview) in flutterVC.view.subviews.enumerated() {
            NSLog("🪟 [FlutterVC] Subview[\(index)]: \(type(of: subview)) alpha:\(subview.alpha) hidden:\(subview.isHidden) frame:\(subview.frame)")
          }
        } else {
          NSLog("❌ [FlutterVC] NOT a FlutterViewController! Type: \(type(of: rootVC))")
        }
      } else {
        NSLog("❌ [RootViewController] DOES NOT EXIST")
      }
    } else {
      NSLog("❌ [Window] DOES NOT EXIST")
    }

    // Check all windows in connected scenes
    let allWindows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }

    NSLog("🪟 [AllWindows] Total count: \(allWindows.count)")
    for (index, window) in allWindows.enumerated() {
      NSLog("🪟 [AllWindows[\(index)]] isKey:\(window.isKeyWindow) hidden:\(window.isHidden) alpha:\(window.alpha)")
    }

    NSLog("🪟 [Window Diagnostics] ========== END ==========")
  }

  // BLACK SCREEN FIX: Track app lifecycle
  override func applicationDidBecomeActive(_ application: UIApplication) {
    NSLog("🔵 [AppDelegate] applicationDidBecomeActive - app became active")
    logWindowState()
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    NSLog("🔵 [AppDelegate] applicationWillResignActive - app will resign active")
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
