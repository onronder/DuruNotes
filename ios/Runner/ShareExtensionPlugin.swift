//
//  ShareExtensionPlugin.swift
//  Runner
//
//  Created for Duru Notes Share Extension integration
//

import Flutter
import UIKit

public class ShareExtensionPlugin: NSObject, FlutterPlugin {
    private let appGroupID = "group.com.fittechs.durunotes"
    private let sharedFileName = "shared_items.json"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.fittechs.durunotes/share_extension",
            binaryMessenger: registrar.messenger()
        )
        let instance = ShareExtensionPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getSharedItems":
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let fileURL = containerURL.appendingPathComponent(sharedFileName)
                if let data = try? Data(contentsOf: fileURL),
                   let jsonString = String(data: data, encoding: .utf8) {
                    result(jsonString)  // return the JSON string to Dart
                    return
                }
            }
            result("[]")  // no items
            
        case "clearSharedItems":
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let fileURL = containerURL.appendingPathComponent(sharedFileName)
                try? FileManager.default.removeItem(at: fileURL)
                
                // Also clean up shared images directory
                let imagesDir = containerURL.appendingPathComponent("shared_images")
                try? FileManager.default.removeItem(at: imagesDir)
            }
            result(nil)  // acknowledge success
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
