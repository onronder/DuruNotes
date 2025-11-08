import Foundation

/// Shared storage for items shared from other apps via Share Extension
/// Uses App Group container to communicate between extension and main app
/// This is the main app's copy - must stay in sync with ShareExtension/ShareExtensionSharedStore.swift
final class ShareExtensionSharedStore {
  static let appGroupIdentifier = "group.com.fittechs.durunotes"
  private static let sharedItemsKey = "share_extension_shared_items"

  // Internal access needed for explicit synchronization in ShareViewController
  // This allows ShareViewController to call defaults.synchronize() before termination
  let defaults = UserDefaults(suiteName: appGroupIdentifier)

  enum StoreError: Error {
    case missingSuite
    case invalidPayload
    case encodingFailed
  }

  /// Write shared items to App Group UserDefaults
  /// - Parameter items: Array of shared item dictionaries
  /// - Throws: StoreError if writing fails
  func writeSharedItems(_ items: [[String: Any]]) throws {
    guard let defaults else { throw StoreError.missingSuite }

    guard JSONSerialization.isValidJSONObject(items) else {
      throw StoreError.invalidPayload
    }

    let data = try JSONSerialization.data(withJSONObject: items)

    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw StoreError.encodingFailed
    }

    defaults.set(jsonString, forKey: Self.sharedItemsKey)
  }

  /// Read shared items from App Group UserDefaults
  /// - Returns: Array of shared item dictionaries, or nil if no items
  func readSharedItems() -> [[String: Any]]? {
    guard
      let defaults = defaults,
      let jsonString = defaults.string(forKey: Self.sharedItemsKey),
      let data = jsonString.data(using: .utf8)
    else {
      return nil
    }

    return try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
  }

  /// Clear shared items from App Group UserDefaults
  func clearSharedItems() {
    defaults?.removeObject(forKey: Self.sharedItemsKey)
  }
}
