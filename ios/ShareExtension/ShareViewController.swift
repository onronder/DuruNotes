import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Share Extension View Controller
/// Handles content shared from other apps (Safari, Notes, Photos, etc.)
class ShareViewController: SLComposeServiceViewController {
  private let store = ShareExtensionSharedStore()
  private var sharedItems: [[String: Any]] = []

  override func isContentValid() -> Bool {
    // Always valid - we'll handle validation during processing
    return true
  }

  override func didSelectPost() {
    // Process shared content
    processSharedContent { [weak self] in
      guard let self = self else { return }

      // Write to app group container
      do {
        try self.store.writeSharedItems(self.sharedItems)
        print("[ShareExtension] ✅ Successfully saved \(self.sharedItems.count) items")

        // CRITICAL FIX: Force UserDefaults to sync to disk before terminating
        // This prevents "Error Code=18" termination failures that cause black screen hang
        if let defaults = self.store.defaults {
          let syncSuccess = defaults.synchronize()
          if syncSuccess {
            print("[ShareExtension] ✅ UserDefaults synced successfully")
          } else {
            print("[ShareExtension] ⚠️ UserDefaults sync returned false (may still succeed)")
          }
        }

        // PRODUCTION FIX: Add small delay to ensure filesystem operations complete
        // iOS extensions need time for App Group writes to finalize before termination
        // Without this delay, iOS may terminate the extension before data is persisted,
        // causing a 1-2 second hang and Error Code 18
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          // CRITICAL FIX: Use proper completion handler (not nil)
          // Nil completion handler causes iOS extension termination to hang
          self?.extensionContext?.completeRequest(returningItems: []) { _ in
            print("[ShareExtension] ✅ Extension completed successfully")
          }
        }
      } catch {
        print("[ShareExtension] ❌ Failed to save shared items: \(error)")
        let alert = UIAlertController(
          title: "Error",
          message: "Failed to share content. Please try again.",
          preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
          // Also use proper completion handler in error case
          self.extensionContext?.completeRequest(returningItems: []) { _ in
            print("[ShareExtension] ⚠️ Extension completed with error")
          }
        })
        self.present(alert, animated: true)
      }
    }
  }

  override func configurationItems() -> [Any]! {
    // Return an empty array to hide the configuration sheet
    return []
  }

  // MARK: - Content Processing

  private func processSharedContent(completion: @escaping () -> Void) {
    guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      completion()
      return
    }

    let group = DispatchGroup()

    for item in inputItems {
      guard let attachments = item.attachments else { continue }

      for attachment in attachments {
        // Process text
        if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          group.enter()
          processText(attachment: attachment) {
            group.leave()
          }
        }
        // Process URLs
        else if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          group.enter()
          processURL(attachment: attachment) {
            group.leave()
          }
        }
        // Process images
        else if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          group.enter()
          processImage(attachment: attachment) {
            group.leave()
          }
        }
      }
    }

    group.notify(queue: .main) {
      completion()
    }
  }

  private func processText(attachment: NSItemProvider, completion: @escaping () -> Void) {
    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, error in
      defer { completion() }

      guard let self = self else { return }

      if let error = error {
        print("[ShareExtension] ❌ Failed to load text: \(error)")
        return
      }

      if let text = data as? String {
        let title = self.generateTitleFromText(text)
        let item: [String: Any] = [
          "type": "text",
          "title": title,
          "content": text,
          "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        self.sharedItems.append(item)
        print("[ShareExtension] ✅ Processed text: \(title)")
      }
    }
  }

  private func processURL(attachment: NSItemProvider, completion: @escaping () -> Void) {
    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, error in
      defer { completion() }

      guard let self = self else { return }

      if let error = error {
        print("[ShareExtension] ❌ Failed to load URL: \(error)")
        return
      }

      if let url = data as? URL {
        let title = url.host ?? "Shared Link"
        let item: [String: Any] = [
          "type": "url",
          "title": title,
          "url": url.absoluteString,
          "content": self.contentText ?? url.absoluteString,
          "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        self.sharedItems.append(item)
        print("[ShareExtension] ✅ Processed URL: \(url.absoluteString)")
      }
    }
  }

  private func processImage(attachment: NSItemProvider, completion: @escaping () -> Void) {
    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
      defer { completion() }

      guard let self = self else { return }

      if let error = error {
        print("[ShareExtension] ❌ Failed to load image: \(error)")
        return
      }

      var imageData: Data?
      var filename = "shared_image_\(Int(Date().timeIntervalSince1970)).jpg"

      if let url = data as? URL {
        // Image from file URL
        imageData = try? Data(contentsOf: url)
        filename = url.lastPathComponent
      } else if let image = data as? UIImage {
        // Direct UIImage
        imageData = image.jpegData(compressionQuality: 0.8)
      }

      if let imageData = imageData {
        // Save image to temporary shared container location
        if let tempImageURL = self.saveImageToSharedContainer(imageData, filename: filename) {
          let item: [String: Any] = [
            "type": "image",
            "title": "Shared Image",
            "imagePath": tempImageURL.path,
            "imageSize": imageData.count,
            "timestamp": ISO8601DateFormatter().string(from: Date())
          ]
          self.sharedItems.append(item)
          print("[ShareExtension] ✅ Processed image: \(filename) (\(imageData.count) bytes)")
        }
      }
    }
  }

  // MARK: - Helper Methods

  // Note: Changed to internal for unit testing
  internal func saveImageToSharedContainer(_ imageData: Data, filename: String) -> URL? {
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: ShareExtensionSharedStore.appGroupIdentifier
    ) else {
      print("[ShareExtension] ❌ Failed to access app group container")
      return nil
    }

    let imagesDirectory = containerURL.appendingPathComponent("SharedImages", isDirectory: true)

    // Create directory if needed
    try? FileManager.default.createDirectory(
      at: imagesDirectory,
      withIntermediateDirectories: true,
      attributes: nil
    )

    let fileURL = imagesDirectory.appendingPathComponent(filename)

    do {
      try imageData.write(to: fileURL)
      print("[ShareExtension] ✅ Saved image to: \(fileURL.path)")
      return fileURL
    } catch {
      print("[ShareExtension] ❌ Failed to save image: \(error)")
      return nil
    }
  }

  // Note: Changed to internal for unit testing
  internal func generateTitleFromText(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return "Shared Note"
    }

    // Use first line or first 50 characters
    let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
    if firstLine.count <= 50 {
      return firstLine
    }

    let endIndex = firstLine.index(firstLine.startIndex, offsetBy: 47)
    return String(firstLine[..<endIndex]) + "..."
  }
}
