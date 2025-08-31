//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Onur Önder on 28.08.2025.
//

import UIKit
import Social
import MobileCoreServices  // For iOS 13+ compatibility

class ShareViewController: SLComposeServiceViewController {

    let appGroupID = "group.com.fittechs.durunotes" // Match entitlements

    override func isContentValid() -> Bool {
        // Basic validation: accept if we have text or attachments
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return true }
        
        // Properly cast to NSExtensionItem before accessing attachments
        if let firstItem = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = firstItem.attachments,
           !attachments.isEmpty {
            return true
        }
        return false
    }

    override func didSelectPost() {
        guard let context = extensionContext else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        var itemsToSave: [[String: Any]] = []

        // Save the typed text (if any)
        let trimmed = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let title = String(trimmed.prefix(50)) // Use first 50 chars as title
            itemsToSave.append([
                "type": "text",
                "title": title,
                "content": trimmed,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }

        // Process attachments
        let dispatchGroup = DispatchGroup()

        for input in context.inputItems {
            // Properly cast to NSExtensionItem
            guard let item = input as? NSExtensionItem,
                  let attachments = item.attachments else { continue }

            for provider in attachments {
                // Handle images (using MobileCoreServices for iOS 13+ compatibility)
                if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (data, error) in
                        defer { dispatchGroup.leave() }
                        
                        if let error = error {
                            print("Error loading image: \(error)")
                            return
                        }
                        
                        if let url = data as? URL {
                            self.saveImageFromURL(url, to: &itemsToSave)
                        } else if let image = data as? UIImage {
                            self.saveImage(image, to: &itemsToSave)
                        }
                    }
                }
                
                // Handle URLs (using MobileCoreServices for iOS 13+ compatibility)
                if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (data, error) in
                        defer { dispatchGroup.leave() }
                        
                        if let url = data as? URL {
                            let urlText = url.absoluteString
                            itemsToSave.append([
                                "type": "url",
                                "title": url.host ?? "Shared Link",
                                "content": urlText,
                                "url": urlText,
                                "timestamp": ISO8601DateFormatter().string(from: Date())
                            ])
                        }
                    }
                }
                
                // Handle plain text (using MobileCoreServices for iOS 13+ compatibility)
                if provider.hasItemConformingToTypeIdentifier(kUTTypePlainText as String) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: kUTTypePlainText as String, options: nil) { (data, error) in
                        defer { dispatchGroup.leave() }
                        
                        if let sharedText = data as? String, !sharedText.isEmpty {
                            let title = String(sharedText.prefix(50))
                            itemsToSave.append([
                                "type": "text",
                                "title": title,
                                "content": sharedText,
                                "timestamp": ISO8601DateFormatter().string(from: Date())
                            ])
                        }
                    }
                }
            }
        }

        // After all items are processed, persist them
        dispatchGroup.notify(queue: .main) {
            self.persistSharedItems(itemsToSave)
            context.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        // No additional configuration needed for Phase 1
        return []
    }

    // MARK: - Private Helper Methods

    private func saveImageFromURL(_ url: URL, to items: inout [[String: Any]]) {
        self.saveAttachment(data: try! Data(contentsOf: url), extension: "jpg", into: &items)
    }
    
    private func saveImage(_ image: UIImage, to items: inout [[String: Any]]) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        self.saveAttachment(data: imageData, extension: "jpg", into: &items)
    }

    private func saveAttachment(data: Data, extension ext: String, into items: inout [[String: Any]]) {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let imagesDir = containerURL.appendingPathComponent("shared_images")
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
            
            let filename = UUID().uuidString + "." + ext
            let fileURL = imagesDir.appendingPathComponent(filename)
            
            do {
                try data.write(to: fileURL)
                items.append([
                    "type": "image",
                    "title": "Shared Image",
                    "imagePath": fileURL.path,
                    "imageSize": data.count,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
            } catch {
                print("Error saving attachment: \(error)")
            }
        }
    }

    private func persistSharedItems(_ items: [[String: Any]]) {
        guard !items.isEmpty else { return }
        
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Error: Could not access app group container")
            return
        }
        
        let fileURL = containerURL.appendingPathComponent("shared_items.json")
        
        // Read existing items
        var existingItems: [[String: Any]] = []
        if let existingData = try? Data(contentsOf: fileURL),
           let decoded = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
            existingItems = decoded
        }
        
        // Append new items
        existingItems.append(contentsOf: items)
        
        // Save back to file
        do {
            let data = try JSONSerialization.data(withJSONObject: existingItems, options: .prettyPrinted)
            try data.write(to: fileURL)
            print("Successfully saved \(items.count) shared items")
        } catch {
            print("Error saving shared items: \(error)")
        }
    }
}
