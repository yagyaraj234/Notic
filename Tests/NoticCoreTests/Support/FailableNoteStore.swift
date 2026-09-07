import Foundation
import NoticCore

struct SimulatedFailure: LocalizedError {
    var errorDescription: String? { "Disk unavailable" }
}

/// Wraps the real stores so a test can make the persistence boundary fail on demand.
final class FailableNoteStore: NoteStore, SettingsStore {
    private let notes: any NoteStore
    private let settings: any SettingsStore
    var shouldFail = false

    init(notes: any NoteStore, settings: any SettingsStore) {
        self.notes = notes
        self.settings = settings
    }

    func fetchAll() throws -> [Note] {
        try notes.fetchAll()
    }

    func upsert(_ notes: [Note]) throws {
        if shouldFail { throw SimulatedFailure() }
        try self.notes.upsert(notes)
    }

    func delete(_ ids: Set<Note.ID>) throws {
        if shouldFail { throw SimulatedFailure() }
        try notes.delete(ids)
    }

    func load() throws -> NoticSettings? {
        try settings.load()
    }

    func save(_ settings: NoticSettings) throws {
        if shouldFail { throw SimulatedFailure() }
        try self.settings.save(settings)
    }
}

extension WorkspaceFixture {
    /// Opens a workspace whose persistence boundary can be made to fail.
    /// - Parameter failingSettings: start with the store already failing.
    func launchWithFailableStore(failingSettings: Bool = false) throws -> (NoticWorkspace, FailableNoteStore) {
        let store = FailableNoteStore(
            notes: try SwiftDataNoteStore(url: directory.appending(path: "Notes.store")),
            settings: JSONSettingsStore(url: directory.appending(path: "Settings.json"))
        )
        store.shouldFail = failingSettings
        let workspace = try NoticWorkspace(store: store, settingsStore: store, scheduler: scheduler)
        return (workspace, store)
    }
}
