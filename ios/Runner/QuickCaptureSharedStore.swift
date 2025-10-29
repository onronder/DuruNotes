import Foundation
final class QuickCaptureSharedStore {
  static let appGroupIdentifier = "group.com.fittechs.durunotes"
  static let widgetKind = "QuickCaptureWidget"
  private static let payloadKey = "quick_capture_widget_payload"

  private let defaults = UserDefaults(suiteName: appGroupIdentifier)

  enum StoreError: Error {
    case missingSuite
    case invalidPayload
    case encodingFailed
  }

  func writePayload(_ payload: [String: Any], userId: String) throws {
    guard let defaults else { throw StoreError.missingSuite }

    var payloadWithUser = payload
    payloadWithUser["userId"] = payloadWithUser["userId"] ?? userId

    guard JSONSerialization.isValidJSONObject(payloadWithUser) else {
      throw StoreError.invalidPayload
    }

    let data = try JSONSerialization.data(withJSONObject: payloadWithUser)

    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw StoreError.encodingFailed
    }

    defaults.set(jsonString, forKey: Self.payloadKey)
  }

  func clear() {
    defaults?.removeObject(forKey: Self.payloadKey)
  }

  func readPayload() -> [String: Any]? {
    guard
      let defaults = defaults,
      let jsonString = defaults.string(forKey: Self.payloadKey),
      let data = jsonString.data(using: .utf8)
    else {
      return nil
    }

    return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }
}
