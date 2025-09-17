//
//  WidgetBridge.swift
//  Runner
//
//  Bridge between Flutter app and iOS Widget
//  Handles data synchronization and method channel communication
//

import Foundation
import Flutter
import WidgetKit

@objc class WidgetBridge: NSObject {
    
    // MARK: - Properties
    private static let channelName = "com.fittechs.durunotes/quick_capture"
    private static let appGroupIdentifier = "group.com.fittechs.durunotes"
    
    private var channel: FlutterMethodChannel?
    private let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    @objc static func register(with controller: FlutterViewController) {
        let instance = WidgetBridge()
        instance.setupChannel(with: controller)
        instance.setupNotificationObservers()
    }
    
    private func setupChannel(with controller: FlutterViewController) {
        channel = FlutterMethodChannel(
            name: WidgetBridge.channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call, result: result)
        }
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Method Channel Handler
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateWidgetData":
            updateWidgetData(call.arguments as? [String: Any] ?? [:], result: result)
            
        case "refreshWidget":
            refreshWidget(result: result)
            
        case "getAuthStatus":
            getAuthStatus(result: result)
            
        case "savePendingCapture":
            savePendingCapture(call.arguments as? [String: Any] ?? [:], result: result)
            
        case "getPendingCaptures":
            getPendingCaptures(result: result)
            
        case "clearPendingCaptures":
            clearPendingCaptures(result: result)
            
        case "handleDeepLink":
            handleDeepLink(call.arguments as? String ?? "", result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Widget Data Management
    private func updateWidgetData(_ data: [String: Any], result: @escaping FlutterResult) {
        do {
            // Update recent notes
            if let notesData = data["recentNotes"] as? [[String: Any]] {
                let notesJson = try JSONSerialization.data(withJSONObject: notesData)
                userDefaults?.set(notesJson, forKey: "widget.recentNotes")
            }
            
            // Update auth token
            if let token = data["authToken"] as? String {
                userDefaults?.set(token, forKey: "widget.authToken")
            }
            
            // Update user ID
            if let userId = data["userId"] as? String {
                userDefaults?.set(userId, forKey: "widget.userId")
            }
            
            // Update last sync time
            userDefaults?.set(Date(), forKey: "widget.lastSync")
            
            // Reload widget timelines
            WidgetCenter.shared.reloadAllTimelines()
            
            result(true)
        } catch {
            result(FlutterError(
                code: "UPDATE_ERROR",
                message: "Failed to update widget data",
                details: error.localizedDescription
            ))
        }
    }
    
    private func refreshWidget(result: @escaping FlutterResult) {
        WidgetCenter.shared.reloadAllTimelines()
        result(true)
    }
    
    // MARK: - Authentication
    private func getAuthStatus(result: @escaping FlutterResult) {
        let isAuthenticated = userDefaults?.string(forKey: "widget.authToken") != nil
        let userId = userDefaults?.string(forKey: "widget.userId")
        
        result([
            "isAuthenticated": isAuthenticated,
            "userId": userId as Any
        ])
    }
    
    // MARK: - Pending Captures
    private func savePendingCapture(_ data: [String: Any], result: @escaping FlutterResult) {
        do {
            var pending = getPendingCapturesArray()
            
            // Add new capture
            var capture = data
            capture["id"] = UUID().uuidString
            capture["createdAt"] = Date().timeIntervalSince1970
            pending.append(capture)
            
            // Save to user defaults
            let jsonData = try JSONSerialization.data(withJSONObject: pending)
            userDefaults?.set(jsonData, forKey: "widget.pendingCaptures")
            
            result(capture["id"])
        } catch {
            result(FlutterError(
                code: "SAVE_ERROR",
                message: "Failed to save pending capture",
                details: error.localizedDescription
            ))
        }
    }
    
    private func getPendingCaptures(result: @escaping FlutterResult) {
        result(getPendingCapturesArray())
    }
    
    private func getPendingCapturesArray() -> [[String: Any]] {
        guard let data = userDefaults?.data(forKey: "widget.pendingCaptures"),
              let captures = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return captures
    }
    
    private func clearPendingCaptures(result: @escaping FlutterResult) {
        userDefaults?.removeObject(forKey: "widget.pendingCaptures")
        result(true)
    }
    
    // MARK: - Deep Linking
    private func handleDeepLink(_ url: String, result: @escaping FlutterResult) {
        // Parse the deep link URL
        guard let urlComponents = URLComponents(string: url) else {
            result(FlutterError(
                code: "INVALID_URL",
                message: "Invalid deep link URL",
                details: nil
            ))
            return
        }
        
        let path = urlComponents.path
        let queryItems = urlComponents.queryItems ?? []
        
        // Extract parameters
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value
        }
        
        // Send to Flutter
        channel?.invokeMethod("handleDeepLink", arguments: [
            "path": path,
            "params": params
        ])
        
        result(true)
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        // Listen for widget refresh requests
        let refreshNotificationName = "com.fittechs.durunotes.widget.refresh" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let bridge = Unmanaged<WidgetBridge>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    bridge.handleWidgetRefreshRequest()
                }
            },
            refreshNotificationName,
            nil,
            .deliverImmediately
        )
        
        // Listen for widget sync requests
        let syncNotificationName = "com.fittechs.durunotes.widget.sync" as CFString
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let bridge = Unmanaged<WidgetBridge>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    bridge.handleWidgetSyncRequest()
                }
            },
            syncNotificationName,
            nil,
            .deliverImmediately
        )
    }
    
    private func handleWidgetRefreshRequest() {
        // Request fresh data from Flutter
        channel?.invokeMethod("requestDataRefresh", arguments: nil) { [weak self] result in
            if let data = result as? [String: Any] {
                self?.updateWidgetData(data) { _ in }
            }
        }
    }
    
    private func handleWidgetSyncRequest() {
        // Sync pending captures with Flutter
        let pendingCaptures = getPendingCapturesArray()
        
        if !pendingCaptures.isEmpty {
            channel?.invokeMethod("syncPendingCaptures", arguments: pendingCaptures) { [weak self] result in
                if result as? Bool == true {
                    self?.clearPendingCaptures { _ in }
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    @objc static func handleAppLaunch(with url: URL) -> Bool {
        // Handle widget deep links
        if url.scheme == "durunotes" && url.host == "quick-capture" {
            // Process the quick capture request
            NotificationCenter.default.post(
                name: Notification.Name("QuickCaptureRequested"),
                object: nil,
                userInfo: ["url": url]
            )
            return true
        }
        return false
    }
    
    @objc static func clearWidgetData() {
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        userDefaults?.removeObject(forKey: "widget.recentNotes")
        userDefaults?.removeObject(forKey: "widget.authToken")
        userDefaults?.removeObject(forKey: "widget.userId")
        userDefaults?.removeObject(forKey: "widget.lastSync")
        userDefaults?.removeObject(forKey: "widget.pendingCaptures")
        
        WidgetCenter.shared.reloadAllTimelines()
    }
}
