//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Onur Önder on 28.08.2025.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    let appGroupID = "group.com.fittechs.durunotes" // Match entitlements

    override func isContentValid() -> Bool {
        // Basic validation - ensure we have some content
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = extensionContext?.inputItems.first?.attachments?.isEmpty == false
        
        return !text.isEmpty || hasAttachments
    }

    override func didSelectPost() {
        guard let context = extensionContext else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }

        var itemsToSave: [[String: Any]] = []

        // Save the typed text (if any)
        let text = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let title = String(text.prefix(100)) // Use first 100 chars as title
            itemsToSave.append([
                "type": "text",
                "title": title,
                "content": text,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])
        }

        // Process attachments
        let dispatchGroup = DispatchGroup()

        for item in context.inputItems {
            guard let inputItem = item as? NSExtensionItem,
                  let attachments = inputItem.attachments else { continue }

            for provider in attachments {
                // Handle images
                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (data, error) in
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
                
                // Handle text/URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                        defer { dispatchGroup.leave() }
                        
                        if let sharedText = data as? String, !sharedText.isEmpty {
                            let title = String(sharedText.prefix(100))
                            itemsToSave.append([
                                "type": "text",
                                "title": title,
                                "content": sharedText,
                                "timestamp": ISO8601DateFormatter().string(from: Date())
                            ])
                        }
                    }
                }
                
                // Handle URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    dispatchGroup.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { (data, error) in
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

    // MARK: - Private Methods

    private func saveImageFromURL(_ url: URL, to items: inout [[String: Any]]) {
        do {
            let imageData = try Data(contentsOf: url)
            let fileName = UUID().uuidString + ".jpg"
            
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
                let imagesDir = containerURL.appendingPathComponent("shared_images")
                try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
                
                let fileURL = imagesDir.appendingPathComponent(fileName)
                try imageData.write(to: fileURL)
                
                items.append([
                    "type": "image",
                    "title": "Shared Image",
                    "imagePath": fileURL.path,
                    "imageSize": imageData.count,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
            }
        } catch {
            print("Error saving image from URL: \(error)")
        }
    }
    
    private func saveImage(_ image: UIImage, to items: inout [[String: Any]]) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = UUID().uuidString + ".jpg"
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let imagesDir = containerURL.appendingPathComponent("shared_images")
            try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
            
            let fileURL = imagesDir.appendingPathComponent(fileName)
            
            do {
                try imageData.write(to: fileURL)
                items.append([
                    "type": "image",
                    "title": "Shared Image",
                    "imagePath": fileURL.path,
                    "imageSize": imageData.count,
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ])
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }

    private func persistSharedItems(_ items: [[String: Any]]) {
        guard !items.isEmpty else { return }
        
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            let fileURL = containerURL.appendingPathComponent("shared_items.json")
            
            // Read existing items
            var existingItems: [[String: Any]] = []
            if let existingData = try? Data(contentsOf: fileURL),
               let existing = try? JSONSerialization.jsonObject(with: existingData, options: []) as? [[String: Any]] {
                existingItems = existing
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
}
