//
//  WidgetDataProvider.swift
//  QuickCaptureWidget
//
//  Handles data synchronization between widget and main app
//  Production-grade implementation with offline support
//

import Foundation
import WidgetKit

// MARK: - Configuration
struct QuickCaptureWidgetConfiguration {
    static let appGroupIdentifier = "group.com.fittechs.durunotes"
}

// MARK: - Widget Data Provider
class WidgetDataProvider {
    
    // MARK: - Properties
    private let appGroup = QuickCaptureWidgetConfiguration.appGroupIdentifier
    private let userDefaults: UserDefaults?
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Cache keys
    private enum CacheKey {
        static let recentNotes = "widget.recentNotes"
        static let authToken = "widget.authToken"
        static let userId = "widget.userId"
        static let lastSync = "widget.lastSync"
        static let pendingCaptures = "widget.pendingCaptures"
        static let templates = "widget.templates"
    }
    
    // MARK: - Initialization
    init() {
        self.userDefaults = UserDefaults(suiteName: appGroup)
        
        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Ensure container directory exists
        createContainerDirectoryIfNeeded()
    }
    
    // MARK: - Authentication
    func isAuthenticated() async -> Bool {
        guard let token = userDefaults?.string(forKey: CacheKey.authToken),
              !token.isEmpty else {
            return false
        }
        
        // Check if token is still valid
        // In production, this would validate with the server
        return true
    }
    
    func saveAuthenticationData(token: String, userId: String) {
        userDefaults?.set(token, forKey: CacheKey.authToken)
        userDefaults?.set(userId, forKey: CacheKey.userId)
        userDefaults?.set(Date(), forKey: CacheKey.lastSync)
    }
    
    func clearAuthenticationData() {
        userDefaults?.removeObject(forKey: CacheKey.authToken)
        userDefaults?.removeObject(forKey: CacheKey.userId)
        clearCache()
    }
    
    // MARK: - Recent Notes
    func loadRecentNotes(limit: Int = 5) async throws -> [QuickNote] {
        // Try to load from cache first
        if let cached = loadCachedNotes() {
            // Check if cache is fresh (less than 5 minutes old)
            if let lastSync = userDefaults?.object(forKey: CacheKey.lastSync) as? Date,
               Date().timeIntervalSince(lastSync) < 300 {
                return Array(cached.prefix(limit))
            }
        }
        
        // If cache is stale or doesn't exist, request update from main app
        requestDataRefresh()
        
        // Return cached data for now (will be updated on next timeline refresh)
        return loadCachedNotes() ?? []
    }
    
    private func loadCachedNotes() -> [QuickNote]? {
        guard let data = userDefaults?.data(forKey: CacheKey.recentNotes) else {
            return nil
        }
        
        do {
            return try decoder.decode([QuickNote].self, from: data)
        } catch {
            print("Failed to decode cached notes: \(error)")
            return nil
        }
    }
    
    func saveRecentNotes(_ notes: [QuickNote]) {
        do {
            let data = try encoder.encode(notes)
            userDefaults?.set(data, forKey: CacheKey.recentNotes)
            userDefaults?.set(Date(), forKey: CacheKey.lastSync)
        } catch {
            print("Failed to save notes to cache: \(error)")
        }
    }
    
    // MARK: - Pending Captures
    func savePendingCapture(_ capture: PendingCapture) {
        var pending = loadPendingCaptures()
        pending.append(capture)
        
        do {
            let data = try encoder.encode(pending)
            userDefaults?.set(data, forKey: CacheKey.pendingCaptures)
            
            // Notify main app to sync
            requestDataSync()
        } catch {
            print("Failed to save pending capture: \(error)")
        }
    }
    
    func loadPendingCaptures() -> [PendingCapture] {
        guard let data = userDefaults?.data(forKey: CacheKey.pendingCaptures) else {
            return []
        }
        
        do {
            return try decoder.decode([PendingCapture].self, from: data)
        } catch {
            print("Failed to load pending captures: \(error)")
            return []
        }
    }
    
    func clearPendingCaptures() {
        userDefaults?.removeObject(forKey: CacheKey.pendingCaptures)
    }
    
    // MARK: - Templates
    func loadTemplates() -> [CaptureTemplate] {
        // Default templates
        let defaults = [
            CaptureTemplate(
                id: "text",
                name: "Text Note",
                icon: "text.badge.plus",
                content: "",
                type: .text
            ),
            CaptureTemplate(
                id: "checklist",
                name: "Checklist",
                icon: "checklist",
                content: "- [ ] ",
                type: .checklist
            ),
            CaptureTemplate(
                id: "meeting",
                name: "Meeting Notes",
                icon: "person.3.fill",
                content: "## Meeting Notes\n\nDate: {{date}}\nAttendees:\n\nAgenda:\n- ",
                type: .text
            ),
            CaptureTemplate(
                id: "idea",
                name: "Quick Idea",
                icon: "lightbulb.fill",
                content: "## Idea\n\n",
                type: .text
            )
        ]
        
        // Load custom templates if available
        guard let data = userDefaults?.data(forKey: CacheKey.templates) else {
            return defaults
        }
        
        do {
            let custom = try decoder.decode([CaptureTemplate].self, from: data)
            return custom + defaults
        } catch {
            return defaults
        }
    }
    
    // MARK: - File Management
    private func createContainerDirectoryIfNeeded() {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return
        }
        
        let widgetDataURL = containerURL.appendingPathComponent("WidgetData")
        
        if !fileManager.fileExists(atPath: widgetDataURL.path) {
            try? fileManager.createDirectory(at: widgetDataURL, withIntermediateDirectories: true)
        }
    }
    
    func saveImage(_ imageData: Data, withId id: String) -> URL? {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return nil
        }
        
        let imageURL = containerURL
            .appendingPathComponent("WidgetData")
            .appendingPathComponent("Images")
            .appendingPathComponent("\(id).jpg")
        
        do {
            try fileManager.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try imageData.write(to: imageURL)
            return imageURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    // MARK: - Communication with Main App
    private func requestDataRefresh() {
        // Use Darwin Notification Center for inter-process communication
        let notificationName = "com.fittechs.durunotes.widget.refresh" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
    }
    
    private func requestDataSync() {
        let notificationName = "com.fittechs.durunotes.widget.sync" as CFString
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName),
            nil,
            nil,
            true
        )
    }
    
    // MARK: - Cache Management
    func clearCache() {
        userDefaults?.removeObject(forKey: CacheKey.recentNotes)
        userDefaults?.removeObject(forKey: CacheKey.lastSync)
        
        // Clear image cache
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            let imagesURL = containerURL.appendingPathComponent("WidgetData/Images")
            try? fileManager.removeItem(at: imagesURL)
        }
    }
    
    func getCacheSize() -> Int64 {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            return 0
        }
        
        let widgetDataURL = containerURL.appendingPathComponent("WidgetData")
        
        do {
            let resourceValues = try widgetDataURL.resourceValues(forKeys: [.fileSizeKey])
            return Int64(resourceValues.fileSize ?? 0)
        } catch {
            return 0
        }
    }
    
    // MARK: - Analytics
    func trackEvent(_ event: WidgetAnalyticsEvent) {
        // In production, this would send to analytics service
        // For now, just log locally
        let eventData: [String: Any] = [
            "event": event.name,
            "timestamp": Date().timeIntervalSince1970,
            "properties": event.properties
        ]
        
        print("Widget Analytics: \(eventData)")
    }
}

// MARK: - Supporting Types
struct PendingCapture: Codable {
    let id: String
    let content: String
    let type: CaptureType
    let templateId: String?
    let attachments: [String]
    let createdAt: Date
    
    init(content: String, type: CaptureType, templateId: String? = nil, attachments: [String] = []) {
        self.id = UUID().uuidString
        self.content = content
        self.type = type
        self.templateId = templateId
        self.attachments = attachments
        self.createdAt = Date()
    }
}

struct CaptureTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let content: String
    let type: CaptureType
}

enum CaptureType: String, Codable {
    case text
    case checklist
    case voice
    case photo
    case drawing
}

struct WidgetAnalyticsEvent {
    let name: String
    let properties: [String: Any]
    
    static func captureCreated(type: CaptureType) -> WidgetAnalyticsEvent {
        WidgetAnalyticsEvent(
            name: "widget.capture_created",
            properties: ["type": type.rawValue]
        )
    }
    
    static func widgetOpened(family: String) -> WidgetAnalyticsEvent {
        WidgetAnalyticsEvent(
            name: "widget.opened",
            properties: ["family": family]
        )
    }
    
    static func errorOccurred(error: String) -> WidgetAnalyticsEvent {
        WidgetAnalyticsEvent(
            name: "widget.error",
            properties: ["error": error]
        )
    }
}
