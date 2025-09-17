import Foundation

// MARK: - QuickNote Model
struct QuickNote: Codable {
    let id: String
    let content: String
    let type: NoteType
    let createdAt: Date
    let syncStatus: SyncStatus
    
    enum NoteType: String, Codable {
        case text = "text"
        case voice = "voice"
        case photo = "photo"
        case task = "task"
    }
    
    enum SyncStatus: String, Codable {
        case pending = "pending"
        case synced = "synced"
        case failed = "failed"
    }
    
    init(content: String, type: NoteType) {
        self.id = UUID().uuidString
        self.content = content
        self.type = type
        self.createdAt = Date()
        self.syncStatus = .pending
    }
}
