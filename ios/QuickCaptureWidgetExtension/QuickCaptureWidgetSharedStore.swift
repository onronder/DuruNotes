import Foundation

struct QuickCaptureWidgetSharedStore {
  static let appGroupIdentifier = "group.com.fittechs.durunotes"
  private static let payloadKey = "quick_capture_widget_payload"
  private static var hasLoggedMissingSuite = false

  private static func resolveDefaults() -> UserDefaults? {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      ),
      FileManager.default.fileExists(atPath: containerURL.path)
    else {
      #if DEBUG
      if !hasLoggedMissingSuite {
        NSLog("[QuickCaptureWidgetSharedStore] App Group container missing: \(appGroupIdentifier)")
        hasLoggedMissingSuite = true
      }
      #endif
      return nil
    }
    return UserDefaults(suiteName: appGroupIdentifier)
  }

  func readPayload() -> [String: Any]? {
    guard
      let defaults = Self.resolveDefaults(),
      let jsonString = defaults.string(forKey: Self.payloadKey),
      let data = jsonString.data(using: .utf8)
    else {
      return nil
    }

    guard
      let object = try? JSONSerialization.jsonObject(with: data, options: []),
      let dictionary = object as? [String: Any]
    else {
      return nil
    }

    return dictionary
  }
}
