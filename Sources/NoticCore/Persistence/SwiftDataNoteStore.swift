import Foundation
import SwiftData

/// SwiftData row backing a `Note`. Kept private to the persistence layer; the
/// rest of the module only sees `Note` values.
@Model
nonisolated final class NoteRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var colorRaw: String
    var sortOrder: Int
    var editorWidth: Double
    var editorHeight: Double
    var editorOriginX: Double?
    var editorOriginY: Double?
    var createdAt: Date
    var modifiedAt: Date
    var lifecycleRaw: String
    var deletionDeadline: Date?
    var restoreToRaw: String?

    init(_ note: Note) {
        id = note.id
        createdAt = note.createdAt
        title = ""
        body = ""
        colorRaw = ""
        sortOrder = 0
        editorWidth = 0
        editorHeight = 0
        editorOriginX = nil
        editorOriginY = nil
        modifiedAt = note.modifiedAt
        lifecycleRaw = ""
        apply(note)
    }

    func apply(_ note: Note) {
        title = note.title
        body = note.body
        colorRaw = note.color.rawValue
        sortOrder = note.sortOrder
        editorWidth = note.editorSize.width
        editorHeight = note.editorSize.height
        if let origin = note.editorOrigin {
            editorOriginX = origin.x
            editorOriginY = origin.y
        } else {
            editorOriginX = nil
            editorOriginY = nil
        }
        modifiedAt = note.modifiedAt
        switch note.lifecycle {
        case .active:
            lifecycleRaw = "active"
            deletionDeadline = nil
            restoreToRaw = nil
        case .archived:
            lifecycleRaw = "archived"
            deletionDeadline = nil
            restoreToRaw = nil
        case let .pendingDeletion(deadline, restoreTo):
            lifecycleRaw = "pendingDeletion"
            deletionDeadline = deadline
            restoreToRaw = restoreTo.rawValue
        }
    }

    var note: Note {
        let lifecycle: NoteLifecycle
        switch lifecycleRaw {
        case "archived":
            lifecycle = .archived
        case "pendingDeletion":
            lifecycle = .pendingDeletion(
                deadline: deletionDeadline ?? .distantPast,
                restoreTo: restoreToRaw.flatMap(NoteLifecycle.RetainedState.init(rawValue:)) ?? .active
            )
        default:
            lifecycle = .active
        }
        return Note(
            id: id,
            title: title,
            body: body,
            color: NoteColor(rawValue: colorRaw) ?? .yellow,
            sortOrder: sortOrder,
            editorSize: CGSize(width: editorWidth, height: editorHeight),
            editorOrigin: {
                if let x = editorOriginX, let y = editorOriginY { return CGPoint(x: x, y: y) }
                return nil
            }(),
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            lifecycle: lifecycle
        )
    }
}

/// The production note store: one local SwiftData store, no CloudKit.
public final class SwiftDataNoteStore: NoteStore {
    private let container: ModelContainer
    private let context: ModelContext

    public init(url: URL) throws {
        let configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        container = try ModelContainer(for: NoteRecord.self, configurations: configuration)
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func fetchAll() throws -> [Note] {
        try context.fetch(FetchDescriptor<NoteRecord>()).map(\.note)
    }

    public func upsert(_ notes: [Note]) throws {
        guard !notes.isEmpty else { return }
        let ids = Set(notes.map(\.id))
        let existing = try context.fetch(FetchDescriptor<NoteRecord>(predicate: #Predicate { ids.contains($0.id) }))
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for note in notes {
            if let record = byID[note.id] {
                record.apply(note)
            } else {
                context.insert(NoteRecord(note))
            }
        }
        try commit()
    }

    public func delete(_ ids: Set<Note.ID>) throws {
        guard !ids.isEmpty else { return }
        let doomed = try context.fetch(FetchDescriptor<NoteRecord>(predicate: #Predicate { ids.contains($0.id) }))
        for record in doomed {
            context.delete(record)
        }
        try commit()
    }

    private func commit() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

/// Settings persisted as a small JSON document beside the note store.
public final class JSONSettingsStore: SettingsStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> NoticSettings? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(NoticSettings.self, from: Data(contentsOf: url))
    }

    public func save(_ settings: NoticSettings) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
