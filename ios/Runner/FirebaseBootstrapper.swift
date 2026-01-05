import FirebaseCore
import Foundation

enum FirebaseBootstrapState {
  case configured
  case alreadyConfigured
  case missingPlist
}

struct FirebaseBootstrapper {
  func configureIfNeeded(using bundle: Bundle = .main) -> FirebaseBootstrapState {
    if FirebaseApp.app() != nil {
      return .alreadyConfigured
    }

    if let options = FirebaseOptions.defaultOptions() {
      FirebaseApp.configure(options: options)
      return .configured
    }

    guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
      return .missingPlist
    }

    FirebaseApp.configure()
    return .configured
  }
}

extension FirebaseBootstrapState {
  var isReady: Bool {
    switch self {
    case .configured, .alreadyConfigured:
      return true
    case .missingPlist:
      return false
    }
  }
}
