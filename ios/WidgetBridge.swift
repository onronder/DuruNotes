import Foundation
import WidgetKit

@objc class WidgetBridge: NSObject {
    
    // App Group identifier - must match the one in widget
    static let appGroupIdentifier = "group.com.fittechs.durunotes"
    
    // Refresh all widgets
    @objc static func refreshWidgets() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // Save data for widget to access
    @objc static func saveDataForWidget(data: [String: Any]) {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        
        // Save the data
        for (key, value) in data {
            userDefaults.set(value, forKey: key)
        }
        
        // Trigger widget refresh
        refreshWidgets()
    }
    
    // Read data from widget
    @objc static func readDataFromWidget(key: String) -> Any? {
        guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return nil }
        return userDefaults.object(forKey: key)
    }
}
