import Foundation
import Observation

/// The single shared note collection every display presents. All user-level
/// commands enter here and all observable state is published from here.
@Observable
public final class NoticWorkspace {
    private let store: any NoteStore
    private let settingsStore: any SettingsStore
    private let scheduler: any NoticScheduler

    /// Every known note, including those pending deletion, keyed by identifier.
    private var notes: [Note.ID: Note] = [:]

    public private(set) var settings: NoticSettings

    /// Whether everything the user has done has reached the store.
    public private(set) var saveState: SaveState = .saved

    /// Notes changed in memory that have not yet been written.
    private var dirtyIDs: Set<Note.ID> = []
    /// Notes whose deletion window expired and must be removed from the store.
    private var doomedIDs: Set<Note.ID> = []
    /// Whether `settings` has changed since it was last written.
    private var settingsDirty = false

    private var autosaveWork: (any ScheduledWork)?
    private var retryWork: (any ScheduledWork)?
    private var deletionWork: [Note.ID: any ScheduledWork] = [:]

    /// Opens a workspace on an explicit persistence boundary.
    public init(store: any NoteStore, settingsStore: any SettingsStore, scheduler: any NoticScheduler) throws {
        self.store = store
        self.settingsStore = settingsStore
        self.scheduler = scheduler
        self.settings = try settingsStore.load() ?? NoticSettings()
        for note in try store.fetchAll() {
            notes[note.id] = note
        }
        reconcilePendingDeletions()
    }

    /// Opens a workspace whose SwiftData store and settings live in `directory`.
    public convenience init(directory: URL, scheduler: any NoticScheduler = SystemScheduler()) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(
            store: SwiftDataNoteStore(url: directory.appending(path: "Notes.store")),
            settingsStore: JSONSettingsStore(url: directory.appending(path: "Settings.json")),
            scheduler: scheduler
        )
    }

    // MARK: Published collections

    /// Notes shown in the edge deck, in manual order.
    public var activeNotes: [Note] {
        notes.values.filter { $0.lifecycle == .active }.sorted(by: deckOrder)
    }

    /// Retained notes excluded from the deck, most recently modified first.
    public var archivedNotes: [Note] {
        notes.values.filter { $0.lifecycle == .archived }.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    /// Notes inside their ten-second Undo window, soonest deadline first.
    public var pendingDeletions: [Note] {
        notes.values
            .filter(\.lifecycle.isPendingDeletion)
            .sorted { deadline(of: $0) < deadline(of: $1) }
    }

    /// The active notes that fit in the edge deck.
    public var deckNotes: [Note] {
        Array(activeNotes.prefix(Self.deckCapacity))
    }

    /// How many active notes are hidden behind the "+N more" tile.
    public var overflowCount: Int {
        max(0, activeNotes.count - Self.deckCapacity)
    }

    /// The maximum number of notes the deck fans out.
    public static let deckCapacity = 8

    /// Looks up a single note by identifier.
    public func note(_ id: Note.ID) -> Note? {
        notes[id]
    }

    /// Notes for the library window: filtered by lifecycle, matched against
    /// title and body, most recently modified first.
    public func libraryNotes(matching query: String, filter: LibraryFilter) -> [Note] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.values
            .filter { filter.includes($0.lifecycle) }
            .filter { needle.isEmpty || $0.title.localizedStandardContains(needle) || $0.body.localizedStandardContains(needle) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    // MARK: Settings

    /// Whether to show the "Create your first note" prompt in the deck.
    public var showsFirstNotePrompt: Bool {
        !settings.hasCreatedFirstNote
    }

    /// Applies and immediately persists a settings change.
    public func updateSettings(_ change: (inout NoticSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        settingsDirty = true
        persist()
    }

    // MARK: Creating and editing

    /// Creates a timestamped note at the front of the active deck.
    @discardableResult
    public func createNote() -> Note.ID {
        let now = scheduler.now
        let titleFormatter = DateFormatter()
        titleFormatter.locale = Locale(identifier: "en_IN")
        titleFormatter.dateFormat = "d MMM yyyy · h:mm a"
        let title = titleFormatter.string(from: now)
        let note = Note(title: title, sortOrder: nextFrontOrder(), createdAt: now, modifiedAt: now)
        notes[note.id] = note
        dirtyIDs.insert(note.id)
        persist()
        updateSettings { $0.hasCreatedFirstNote = true }
        return note.id
    }

    public func updateTitle(of id: Note.ID, to title: String) {
        edit(id) { $0.title = title }
    }

    public func updateBody(of id: Note.ID, to body: String) {
        edit(id) { $0.body = body }
    }

    /// Changes a note's colour. Saved immediately.
    public func setColor(of id: Note.ID, to color: NoteColor) {
        guard var note = notes[id], note.color != color else { return }
        note.color = color
        note.modifiedAt = scheduler.now
        notes[id] = note
        dirtyIDs.insert(id)
        persist()
    }

    /// Records where the user dragged the editor. `nil` docks it to its tab
    /// again. Does not bump `modifiedAt` — moving a note is not an edit.
    public func setEditorOrigin(of id: Note.ID, to origin: CGPoint?) {
        guard var note = notes[id], note.editorOrigin != origin else { return }
        note.editorOrigin = origin
        notes[id] = note
        dirtyIDs.insert(id)
        saveState = .unsaved
        scheduleAutosave()
    }

    /// Records the editor size the user resized to, clamped to `EditorSizing`.
    /// Goes through the autosave debounce because live resizing fires rapidly.
    public func setEditorSize(of id: Note.ID, to size: CGSize) {
        let clamped = EditorSizing.clamped(size)
        guard var note = notes[id], note.editorSize != clamped else { return }
        note.editorSize = clamped
        notes[id] = note
        dirtyIDs.insert(id)
        saveState = .unsaved
        scheduleAutosave()
    }

    /// Moves an active note to `index` within the deck order and persists the
    /// whole order atomically.
    public func moveActiveNote(_ id: Note.ID, toIndex index: Int) {
        var order = activeNotes.map(\.id)
        guard let from = order.firstIndex(of: id) else { return }
        order.remove(at: from)
        order.insert(id, at: min(max(index, 0), order.count))
        for (position, noteID) in order.enumerated() where notes[noteID]?.sortOrder != position {
            notes[noteID]?.sortOrder = position
            dirtyIDs.insert(noteID)
        }
        persist()
    }

    /// Writes any debounced edits now. Called when an editor closes or the
    /// application is about to terminate.
    public func flushPendingChanges() {
        autosaveWork?.cancel()
        autosaveWork = nil
        guard !dirtyIDs.isEmpty || !doomedIDs.isEmpty || settingsDirty else { return }
        persist()
    }

    // MARK: Lifecycle

    /// Moves active notes out of the deck into the archive.
    public func archive(_ ids: some Sequence<Note.ID>) {
        transition(ids, from: .active, to: .archived)
    }

    /// Returns archived notes to the front of the deck.
    public func restore(_ ids: some Sequence<Note.ID>) {
        transition(ids, from: .archived, to: .active)
    }

    /// Starts the ten-second deletion window for each note.
    public func delete(_ ids: some Sequence<Note.ID>) {
        let deadline = scheduler.now.addingTimeInterval(NoticTiming.deletionGrace)
        var changed = false
        for id in ids {
            guard var note = notes[id], let restoreTo = note.lifecycle.retainedState else { continue }
            note.lifecycle = .pendingDeletion(deadline: deadline, restoreTo: restoreTo)
            notes[id] = note
            dirtyIDs.insert(id)
            scheduleFinalisation(of: id, at: deadline)
            closeEditors(showing: id)
            changed = true
        }
        if changed { persist() }
    }

    /// Cancels pending deletions, returning each note to where it came from.
    public func undoDelete(_ ids: some Sequence<Note.ID>) {
        var changed = false
        for id in ids {
            guard var note = notes[id], case let .pendingDeletion(_, restoreTo) = note.lifecycle else { continue }
            deletionWork[id]?.cancel()
            deletionWork[id] = nil
            // The note keeps its previous sort order, so it reappears where it was.
            note.lifecycle = restoreTo == .active ? .active : .archived
            notes[id] = note
            dirtyIDs.insert(id)
            changed = true
        }
        if changed {
            persist()
            releaseDecksHeldForUndo()
        }
    }

    private func transition(_ ids: some Sequence<Note.ID>, from: NoteLifecycle, to: NoteLifecycle) {
        var changed = false
        for id in ids {
            guard var note = notes[id], note.lifecycle == from else { continue }
            note.lifecycle = to
            note.modifiedAt = scheduler.now
            if to == .active { note.sortOrder = nextFrontOrder() }
            notes[id] = note
            dirtyIDs.insert(id)
            if to != .active { closeEditors(showing: id) }
            changed = true
        }
        if changed { persist() }
    }

    private func scheduleFinalisation(of id: Note.ID, at deadline: Date) {
        deletionWork[id]?.cancel()
        let delay = max(0, deadline.timeIntervalSince(scheduler.now))
        deletionWork[id] = scheduler.schedule(after: delay) { [weak self] in
            self?.finaliseDeletion(of: id)
        }
    }

    private func finaliseDeletion(of id: Note.ID) {
        deletionWork[id] = nil
        guard let note = notes[id], note.lifecycle.isPendingDeletion else { return }
        notes[id] = nil
        dirtyIDs.remove(id)
        doomedIDs.insert(id)
        persist()
        releaseDecksHeldForUndo()
    }

    /// Runs at launch: finalises deletions that expired while Notic was not
    /// running and resumes timers for the rest.
    private func reconcilePendingDeletions() {
        let now = scheduler.now
        for note in pendingDeletions {
            let deadline = deadline(of: note)
            if deadline <= now {
                notes[note.id] = nil
                doomedIDs.insert(note.id)
            } else {
                scheduleFinalisation(of: note.id, at: deadline)
            }
        }
        if !doomedIDs.isEmpty { persist() }
    }

    // MARK: Display presentation

    private var displays: [DisplayID: DisplayPresentation] = [:]

    /// Whether the user has asked for every Notic surface to be hidden.
    public private(set) var isHidden = false

    /// Displays that currently present a pill, in stable order.
    public var attachedDisplays: [DisplayID] {
        displays.keys.sorted()
    }

    public func deckState(on display: DisplayID) -> DeckState {
        displays[display]?.state ?? .dormant
    }

    /// Starts presenting a pill on a newly connected display.
    public func attachDisplay(_ display: DisplayID) {
        guard displays[display] == nil else { return }
        displays[display] = DisplayPresentation()
    }

    /// Stops presenting on a display. Any open editor closes and its pending
    /// content is written; the note itself is untouched.
    public func detachDisplay(_ display: DisplayID) {
        guard var presentation = displays.removeValue(forKey: display) else { return }
        presentation.cancelTimers()
        if presentation.state.openNoteID != nil {
            flushPendingChanges()
        }
    }

    /// The pointer moved onto this display's pill or deck.
    public func pointerEntered(_ display: DisplayID) {
        guard var presentation = displays[display] else { return }
        presentation.pointerInside = true
        presentation.collapseWork?.cancel()
        presentation.collapseWork = nil
        if presentation.state == .dormant, presentation.expandWork == nil {
            presentation.expandWork = scheduler.schedule(after: NoticTiming.hoverExpandDelay) { [weak self] in
                self?.fanDeck(on: display)
            }
        }
        displays[display] = presentation
    }

    /// The pointer left this display's pill and deck.
    public func pointerExited(_ display: DisplayID) {
        guard var presentation = displays[display] else { return }
        presentation.pointerInside = false
        presentation.expandWork?.cancel()
        presentation.expandWork = nil
        if presentation.state == .fanned {
            scheduleCollapse(&presentation, on: display)
        }
        displays[display] = presentation
    }

    private func scheduleCollapse(_ presentation: inout DisplayPresentation, on display: DisplayID) {
        presentation.collapseWork?.cancel()
        presentation.collapseWork = scheduler.schedule(after: NoticTiming.collapseGrace) { [weak self] in
            self?.collapseDeck(on: display)
        }
    }

    /// Fans the deck immediately, for an explicit click or assistive activation
    /// of the pill. The deck then stays open until the pointer leaves it.
    public func revealDeck(on display: DisplayID) {
        guard var presentation = displays[display], presentation.state == .dormant else { return }
        presentation.cancelTimers()
        presentation.pointerInside = true
        presentation.state = .fanned
        displays[display] = presentation
    }

    /// Expands a note's editor beside the deck, replacing any note already
    /// open on that display.
    public func openNote(_ id: Note.ID, on display: DisplayID) {
        guard var presentation = displays[display], notes[id]?.lifecycle == .active else { return }
        if let current = presentation.state.openNoteID, current != id {
            flushPendingChanges()
        }
        presentation.cancelTimers()
        presentation.state = .noteOpen(id)
        displays[display] = presentation
    }

    /// Collapses the expanded editor on a display. Pending edits are written;
    /// the note's lifecycle never changes. The deck stays fanned and then
    /// collapses through the normal grace period if the pointer is elsewhere.
    public func closeEditor(on display: DisplayID) {
        guard var presentation = displays[display], presentation.state.openNoteID != nil else { return }
        flushPendingChanges()
        presentation.state = .fanned
        if !presentation.pointerInside {
            scheduleCollapse(&presentation, on: display)
        }
        displays[display] = presentation
    }

    /// Hides or restores every Notic surface without touching notes.
    public func toggleHidden() {
        isHidden.toggle()
    }

    private func fanDeck(on display: DisplayID) {
        guard var presentation = displays[display] else { return }
        presentation.expandWork = nil
        guard presentation.state == .dormant, presentation.pointerInside else {
            displays[display] = presentation
            return
        }
        presentation.state = .fanned
        displays[display] = presentation
    }

    /// Collapses a fanned deck unless the pointer is inside it or a deletion is
    /// still undoable — the deck is where the Undo control lives.
    private func collapseDeck(on display: DisplayID) {
        guard var presentation = displays[display] else { return }
        presentation.collapseWork = nil
        guard presentation.state == .fanned, !presentation.pointerInside, pendingDeletions.isEmpty else {
            displays[display] = presentation
            return
        }
        presentation.state = .dormant
        displays[display] = presentation
    }

    /// Once no deletion is pending, decks that were held open for Undo collapse
    /// through the normal grace period.
    private func releaseDecksHeldForUndo() {
        guard pendingDeletions.isEmpty else { return }
        for display in displays.keys {
            guard var presentation = displays[display], presentation.state == .fanned, !presentation.pointerInside else { continue }
            scheduleCollapse(&presentation, on: display)
            displays[display] = presentation
        }
    }

    /// Closes editors showing a note that just left the active deck.
    private func closeEditors(showing id: Note.ID) {
        for display in displays.keys where displays[display]?.state.openNoteID == id {
            closeEditor(on: display)
        }
    }

    // MARK: Autosave

    /// Applies a text-style edit that goes through the autosave debounce.
    private func edit(_ id: Note.ID, _ change: (inout Note) -> Void) {
        guard var note = notes[id] else { return }
        change(&note)
        note.modifiedAt = scheduler.now
        notes[id] = note
        dirtyIDs.insert(id)
        saveState = .unsaved
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        autosaveWork?.cancel()
        autosaveWork = scheduler.schedule(after: NoticTiming.autosaveDebounce) { [weak self] in
            guard let self else { return }
            self.autosaveWork = nil
            self.persist()
        }
    }

    // MARK: Persistence

    /// Writes every dirty note, removes every doomed note, and saves changed
    /// settings. On failure the in-memory state is kept, the failure is
    /// published, and a retry is scheduled.
    private func persist() {
        retryWork?.cancel()
        retryWork = nil
        do {
            try store.upsert(dirtyIDs.compactMap { notes[$0] })
            dirtyIDs.removeAll()
            try store.delete(doomedIDs)
            doomedIDs.removeAll()
            if settingsDirty {
                try settingsStore.save(settings)
                settingsDirty = false
            }
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
            retryWork = scheduler.schedule(after: NoticTiming.saveRetryInterval) { [weak self] in
                guard let self else { return }
                self.retryWork = nil
                self.persist()
            }
        }
    }

    // MARK: Helpers

    private func nextFrontOrder() -> Int {
        (activeNotes.first?.sortOrder ?? 0) - 1
    }

    private func deadline(of note: Note) -> Date {
        if case let .pendingDeletion(deadline, _) = note.lifecycle { return deadline }
        return .distantFuture
    }

    private func deckOrder(_ lhs: Note, _ rhs: Note) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt > rhs.createdAt
    }
}
