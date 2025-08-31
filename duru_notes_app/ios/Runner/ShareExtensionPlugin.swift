//
//  ShareExtensionPlugin.swift
//  Runner
//
//  Created for Duru Notes Share Extension integration
//

import Flutter
import UIKit
import Foundation

public class ShareExtensionPlugin: NSObject, FlutterPlugin {
    
    static let appGroupID = "group.com.fittechs.durunotes"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.fittechs.durunotes/share_extension", binaryMessenger: registrar.messenger())
        let instance = ShareExtensionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSharedItems":
            getSharedItems(result: result)
        case "clearSharedItems":
            clearSharedItems(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getSharedItems(result: @escaping FlutterResult) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareExtensionPlugin.appGroupID) else {
            result(FlutterError(code: "NO_APP_GROUP", message: "Could not access app group container", details: nil))
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("shared_items.json")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                let jsonString = String(data: data, encoding: .utf8) ?? "[]"
                result(jsonString)
            } else {
                result("[]")
            }
        } catch {
            result(FlutterError(code: "READ_ERROR", message: "Failed to read shared items", details: error.localizedDescription))
        }
    }
    
    private func clearSharedItems(result: @escaping FlutterResult) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareExtensionPlugin.appGroupID) else {
            result(FlutterError(code: "NO_APP_GROUP", message: "Could not access app group container", details: nil))
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("shared_items.json")
        
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            
            // Also clean up shared images directory
            let imagesDir = containerURL.appendingPathComponent("shared_images")
            if FileManager.default.fileExists(atPath: imagesDir.path) {
                try FileManager.default.removeItem(at: imagesDir)
            }
            
            result(true)
        } catch {
            result(FlutterError(code: "CLEAR_ERROR", message: "Failed to clear shared items", details: error.localizedDescription))
        }
    }
}
