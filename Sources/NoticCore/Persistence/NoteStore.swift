import Foundation

/// Persistence boundary for notes. The workspace never reports "Saved" until a
/// call through this boundary returns without throwing.
public protocol NoteStore: AnyObject {
    func fetchAll() throws -> [Note]
    /// Inserts or updates every note in a single atomic write.
    func upsert(_ notes: [Note]) throws
    func delete(_ ids: Set<Note.ID>) throws
}

/// Persistence boundary for user settings.
public protocol SettingsStore: AnyObject {
    func load() throws -> NoticSettings?
    func save(_ settings: NoticSettings) throws
}
