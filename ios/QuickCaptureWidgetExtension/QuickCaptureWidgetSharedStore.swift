import Foundation

struct QuickCaptureWidgetSharedStore {
  static let appGroupIdentifier = "group.com.fittechs.durunotes"
  private static let payloadKey = "quick_capture_widget_payload"

  func readPayload() -> [String: Any]? {
    guard
      let defaults = UserDefaults(suiteName: Self.appGroupIdentifier),
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
