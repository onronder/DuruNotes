import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
// import WidgetKit // Enable when WidgetKit is needed

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Phase 2.2: Quick Capture & Share Extension method channels
  private let quickCaptureChannelName = "com.fittechs.durunotes/quick_capture_widget"
  private let shareExtensionChannelName = "com.fittechs.durunotes/share_extension"
  private let firebaseBootstrapper = FirebaseBootstrapper()
  private lazy var quickCaptureStore = QuickCaptureSharedStore()
  private lazy var shareExtensionStore = ShareExtensionSharedStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    NSLog("🔵 [AppDelegate] iOS 18.6 MANUAL WINDOW FIX - didFinishLaunchingWithOptions STARTED")
    NSLog("🔵 [AppDelegate] Calling super.application()")
    #endif

    // Call super first - this sets up the Flutter engine and registers plugins internally
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    #if DEBUG
    NSLog("🔵 [AppDelegate] super.application() returned \(result)")
    #endif

    // iOS 18.6 FIX: Check if window was created, if not create it manually
    if window == nil {
      #if DEBUG
      NSLog("🔵 [AppDelegate] Window is nil after super.application(), creating manually for iOS 18.6...")
      #endif

      // Create window and FlutterViewController
      // FlutterViewController() without engine param uses the shared engine from FlutterAppDelegate
      window = UIWindow(frame: UIScreen.main.bounds)
      let flutterViewController = FlutterViewController()
      window?.rootViewController = flutterViewController
      window?.makeKeyAndVisible()

      #if DEBUG
      NSLog("✅ [AppDelegate] Window manually created: exists=\(window != nil), isKey=\(window?.isKeyWindow ?? false)")
      NSLog("✅ [AppDelegate] FlutterViewController set as rootViewController")
      #endif
    } else {
      #if DEBUG
      NSLog("✅ [AppDelegate] Window already exists from super.application()")
      #endif
    }

    // Register plugins AFTER window is created
    #if DEBUG
    NSLog("🔵 [AppDelegate] Registering plugins...")
    #endif
    GeneratedPluginRegistrant.register(with: self)
    #if DEBUG
    NSLog("✅ [AppDelegate] Plugins registered")
    #endif

    // Setup diagnostics channel (iOS 18.6 debugging support)
    setupWindowDiagnosticsChannel()

    // Phase 2.2: Attach Quick Capture and Share Extension method channels
    #if DEBUG
    NSLog("🔵 [AppDelegate] Attaching Phase 2.2 method channels...")
    #endif
    attachMethodChannels()
    #if DEBUG
    NSLog("✅ [AppDelegate] Phase 2.2 method channels attached")
    NSLog("🔵 [AppDelegate] didFinishLaunchingWithOptions COMPLETED")
    NSLog("🔵 [AppDelegate] Final window state: exists=\(window != nil), isKey=\(window?.isKeyWindow ?? false)")
    #endif

    return result
  }

  // MARK: - Phase 2.2 Method Channels

  private func attachMethodChannels() {
    #if DEBUG
    NSLog("🔵 [AppDelegate] attachMethodChannels STARTED")
    NSLog("🔵 [AppDelegate] About to resolve FlutterViewController...")
    #endif
    guard let controller = resolveFlutterViewController() else {
      #if DEBUG
      NSLog("❌ [AppDelegate] Unable to locate FlutterViewController for method channel registration")
      #endif
      return
    }
    #if DEBUG
    NSLog("✅ [AppDelegate] FlutterViewController resolved successfully")
    NSLog("🔵 [AppDelegate] Configuring QuickCaptureChannel...")
    #endif
    configureQuickCaptureChannel(controller)
    #if DEBUG
    NSLog("✅ [AppDelegate] QuickCaptureChannel configured")
    NSLog("🔵 [AppDelegate] Configuring ShareExtensionChannel...")
    #endif
    configureShareExtensionChannel(controller)
    #if DEBUG
    NSLog("✅ [AppDelegate] ShareExtensionChannel configured")
    NSLog("🔵 [AppDelegate] attachMethodChannels COMPLETED")
    #endif
  }

  private func resolveFlutterViewController() -> FlutterViewController? {
    #if DEBUG
    NSLog("🔵 [AppDelegate] resolveFlutterViewController STARTED")
    NSLog("🔵 [AppDelegate] Trying window?.rootViewController...")
    #endif

    // First try: direct window.rootViewController
    if let flutterViewController = locateFlutterViewController(from: window?.rootViewController) {
      #if DEBUG
      NSLog("✅ [AppDelegate] Found FlutterViewController from window.rootViewController")
      #endif
      return flutterViewController
    }

    // Second try: keyWindow from connected scenes
    #if DEBUG
    NSLog("🔵 [AppDelegate] window.rootViewController didn't work, trying keyWindow...")
    #endif
    let keyWindowRootController = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: { $0.isKeyWindow })?
      .rootViewController

    let result = locateFlutterViewController(from: keyWindowRootController)
    #if DEBUG
    if result != nil {
      NSLog("✅ [AppDelegate] Found FlutterViewController from keyWindow")
    } else {
      NSLog("❌ [AppDelegate] FlutterViewController NOT FOUND anywhere!")
    }
    #endif
    return result
  }

  private func locateFlutterViewController(from controller: UIViewController?) -> FlutterViewController? {
    // Direct match
    if let flutterViewController = controller as? FlutterViewController {
      return flutterViewController
    }

    // Search in navigation controller
    if let navigationController = controller as? UINavigationController {
      for child in navigationController.viewControllers {
        if let flutterViewController = locateFlutterViewController(from: child) {
          return flutterViewController
        }
      }
    }

    // Search in tab bar controller
    if let tabController = controller as? UITabBarController {
      for child in tabController.viewControllers ?? [] {
        if let flutterViewController = locateFlutterViewController(from: child) {
          return flutterViewController
        }
      }
    }

    // Search in presented controller (modals)
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
        // Note: WidgetKit commented out - uncomment when WidgetKit is enabled
        // DispatchQueue.main.async {
        //   WidgetCenter.shared.reloadTimelines(ofKind: QuickCaptureSharedStore.widgetKind)
        // }
        #if DEBUG
        NSLog("✅ [QuickCapture] Widget cache synced for user \(userId)")
        #endif
        result(nil)
      } catch {
        #if DEBUG
        NSLog("❌ [QuickCapture] Failed to write payload: \(error.localizedDescription)")
        #endif
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
      // Note: WidgetKit commented out - uncomment when WidgetKit is enabled
      // DispatchQueue.main.async {
      //   WidgetCenter.shared.reloadTimelines(ofKind: QuickCaptureSharedStore.widgetKind)
      // }
      #if DEBUG
      NSLog("✅ [QuickCapture] Widget cache cleared")
      #endif
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
        #if DEBUG
        NSLog("✅ [ShareExtension] Retrieved \(items.count) shared items from App Group")
        #endif
        result(items)
      } else {
        #if DEBUG
        NSLog("ℹ️ [ShareExtension] No shared items found in App Group")
        #endif
        result([])
      }

    case "clearSharedItems":
      shareExtensionStore.clearSharedItems()
      #if DEBUG
      NSLog("✅ [ShareExtension] Cleared shared items from App Group")
      #endif
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Deep Link Handling

  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    #if DEBUG
    NSLog("📱 [DeepLink] Received URL: \(url.absoluteString)")
    #endif

    guard url.scheme == "durunotes" else {
      #if DEBUG
      NSLog("❌ [DeepLink] Invalid scheme: \(url.scheme ?? "nil")")
      #endif
      return false
    }

    guard let controller = resolveFlutterViewController() else {
      #if DEBUG
      NSLog("❌ [DeepLink] FlutterViewController not available")
      #endif
      return false
    }

    let deepLinkChannel = FlutterMethodChannel(
      name: "com.fittechs.durunotes/deep_links",
      binaryMessenger: controller.binaryMessenger
    )

    deepLinkChannel.invokeMethod("handleDeepLink", arguments: url.absoluteString)
    #if DEBUG
    NSLog("✅ [DeepLink] Forwarded to Flutter: \(url.absoluteString)")
    #endif

    return true
  }

  // MARK: - iOS 18.6 Diagnostics (Debugging Support)

  private func setupWindowDiagnosticsChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      #if DEBUG
      NSLog("❌ [Diagnostics] Cannot setup channel - no FlutterViewController")
      #endif
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

    #if DEBUG
    NSLog("✅ [Diagnostics] Window diagnostics channel registered")
    #endif
  }

  private func logPlatformStateToConsole(context: String) {
    #if DEBUG
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
    #endif
  }

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

  private func logWindowState() {
    #if DEBUG
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
    #endif
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    #if DEBUG
    NSLog("🔵 [AppDelegate] applicationDidBecomeActive - app became active")
    logWindowState()
    #endif
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    #if DEBUG
    NSLog("🔵 [AppDelegate] applicationWillResignActive - app will resign active")
    #endif
  }
}
