import AppKit
import NoticCore
import SwiftUI

/// View state for the library window, kept outside the view so menu commands
/// can switch filters before the window appears.
@Observable
final class LibraryModel {
    var query = ""
    var filter: LibraryFilter = .all
    /// Notes ticked for a bulk action.
    var selection: Set<Note.ID> = []
    /// The note shown in the detail pane and moved with the arrow keys.
    var focused: Note.ID?
}

/// The single searchable window containing every note: a list on the left,
/// the chosen note in full on the right.
struct LibraryView: View {
    let workspace: NoticWorkspace
    @Bindable var model: LibraryModel
    let openNote: (Note.ID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let notes = workspace.libraryNotes(matching: model.query, filter: model.filter)
        HStack(spacing: 0) {
            listPane(notes)
                .frame(minWidth: 380, maxWidth: .infinity)
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
            detailPane(notes)
                .frame(width: 400)
                .background(NotePalette.paneBackground)
        }
        .background(NotePalette.windowBackground)
        .frame(minWidth: 800, minHeight: 480)
        .onChange(of: notes.map(\.id)) { _, ids in
            model.selection = model.selection.intersection(ids)
            if let focused = model.focused, !ids.contains(focused) {
                model.focused = nil
            }
            if model.focused == nil {
                model.focused = ids.first
            }
        }
        .onAppear {
            if model.focused == nil { model.focused = notes.first?.id }
        }
    }

    // MARK: List pane

    private func listPane(_ notes: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(model.filter == .archived ? "Archive" : "All Notes")
                .font(.system(size: 13, weight: .semibold))
                .padding(.top, 44)
                .padding(.horizontal, 20)

            searchField(count: notes.count)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            filterChips
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ZStack {
                if notes.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(notes) { note in
                                    LibraryRow(
                                        note: note,
                                        fontChoice: workspace.settings.fontChoice,
                                        paperStyle: workspace.settings.paperStyle,
                                        isChecked: model.selection.contains(note.id),
                                        isFocused: model.focused == note.id,
                                        toggleChecked: { toggle(note.id) }
                                    )
                                    .id(note.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        if note.lifecycle == .active { openNote(note.id) }
                                    }
                                    .simultaneousGesture(TapGesture().onEnded { model.focused = note.id })
                                    .contextMenu { rowMenu(for: note) }
                                    .transition(.opacity)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .focusable()
                        .focusEffectDisabled()
                        .onMoveCommand { direction in
                            moveFocus(direction, in: notes)
                            if let focused = model.focused {
                                proxy.scrollTo(focused, anchor: nil)
                            }
                        }
                        .onKeyPress(.space) {
                            if let focused = model.focused { toggle(focused) }
                            return .handled
                        }
                    }
                    .accessibilityIdentifier("notic.library.list")
                    .id(model.filter)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(Motion.hover(reduceMotion: reduceMotion), value: model.filter)
            .animation(Motion.hover(reduceMotion: reduceMotion), value: notes.isEmpty)

            if !workspace.pendingDeletions.isEmpty {
                PendingDeletionBanner(workspace: workspace)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
        }
        .animation(Motion.settle(reduceMotion: reduceMotion), value: workspace.pendingDeletions.isEmpty)
    }

    private func searchField(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search all notes", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .accessibilityLabel("Search notes")
                .accessibilityIdentifier("notic.library.search")
            Text("\(count) \(count == 1 ? "note" : "notes")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    private var filterChips: some View {
        HStack(spacing: 4) {
            FilterChip(title: "All", isSelected: model.filter == .all) { model.filter = .all }
            FilterChip(title: "Active", isSelected: model.filter == .active) { model.filter = .active }
            FilterChip(title: "Archived", isSelected: model.filter == .archived) { model.filter = .archived }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter")
        .accessibilityIdentifier("notic.library.filter")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text(emptyTitle)
                .font(.system(size: 15, weight: .semibold))
            Text(emptyDetail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("notic.library.empty")
    }

    private var emptyTitle: String {
        if !model.query.trimmingCharacters(in: .whitespaces).isEmpty { return "No matches" }
        switch model.filter {
        case .archived: return "Nothing archived"
        case .active: return "No active notes"
        case .all: return "No notes yet"
        }
    }

    private var emptyDetail: String {
        if !model.query.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Nothing matches “\(model.query)”."
        }
        switch model.filter {
        case .archived: return "Archived notes stay here until you restore or delete them."
        case .active: return "Press ⌥⌘N or use the deck's + button to create one."
        case .all: return "Create your first note with ⌥⌘N."
        }
    }

    private func moveFocus(_ direction: MoveCommandDirection, in notes: [Note]) {
        guard !notes.isEmpty else { return }
        let index = notes.firstIndex { $0.id == model.focused } ?? -1
        switch direction {
        case .up: model.focused = notes[max(0, index - 1)].id
        case .down: model.focused = notes[min(notes.count - 1, index + 1)].id
        default: break
        }
    }

    private func toggle(_ id: Note.ID) {
        if model.selection.contains(id) {
            model.selection.remove(id)
        } else {
            model.selection.insert(id)
        }
    }

    // MARK: Detail pane

    /// The notes an action applies to: the ticked set, or else the focused note.
    private func targets(in visible: [Note]) -> [Note] {
        let ticked = visible.filter { model.selection.contains($0.id) }
        if !ticked.isEmpty { return ticked }
        return visible.filter { $0.id == model.focused }
    }

    @ViewBuilder
    private func detailPane(_ notes: [Note]) -> some View {
        let targets = targets(in: notes)
        let focusedNote = notes.first { $0.id == model.focused } ?? targets.first
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(targets: targets, focused: focusedNote)
                .padding(.top, 44)
            if let focusedNote {
                NoteDetailCard(note: focusedNote, fontChoice: workspace.settings.fontChoice, paperStyle: workspace.settings.paperStyle)
            } else {
                Spacer()
                Text(notes.isEmpty ? "" : "Select a note to read it here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func detailHeader(targets: [Note], focused: Note?) -> some View {
        let canArchive = targets.contains { $0.lifecycle == .active }
        let canRestore = targets.contains { $0.lifecycle == .archived }
        let openable = focused.flatMap { $0.lifecycle == .active ? $0 : nil }
        return HStack(spacing: 8) {
            if let focused {
                Circle()
                    .fill(NotePalette.swatch(for: focused.color, paper: workspace.settings.paperStyle).paper)
                    .frame(width: 8, height: 8)
                Text(statusText(for: focused, count: targets.count))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            PaneButton("Open") {
                if let openable { openNote(openable.id) }
            }
            .disabled(openable == nil || targets.count > 1)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint("Opens the selected active note beside the deck")
            .accessibilityIdentifier("notic.library.open")
            if canRestore, !canArchive {
                PaneButton("Restore") {
                    withAnimation(Motion.hover(reduceMotion: reduceMotion)) {
                        workspace.restore(targets.filter { $0.lifecycle == .archived }.map(\.id))
                    }
                }
                .accessibilityIdentifier("notic.library.restore")
            } else {
                PaneButton("Mark complete") {
                    withAnimation(Motion.hover(reduceMotion: reduceMotion)) {
                        workspace.archive(targets.filter { $0.lifecycle == .active }.map(\.id))
                    }
                }
                .disabled(!canArchive)
                .accessibilityIdentifier("notic.library.archive")
            }
            PaneButton("Delete", tint: NotePalette.destructive) {
                workspace.delete(targets.map(\.id))
                model.selection = []
            }
            .disabled(targets.isEmpty)
            .keyboardShortcut(.delete, modifiers: .command)
            .accessibilityIdentifier("notic.library.delete")
        }
    }

    private func statusText(for note: Note, count: Int) -> String {
        if count > 1 { return "\(count) SELECTED" }
        switch note.lifecycle {
        case .active: return "ACTIVE · IN THE DECK"
        case .archived: return "ARCHIVED"
        case .pendingDeletion: return "DELETING · UNDO AVAILABLE"
        }
    }

    @ViewBuilder
    private func rowMenu(for note: Note) -> some View {
        if note.lifecycle == .active {
            Button("Open") { openNote(note.id) }
            Button("Mark complete") {
                withAnimation(Motion.hover(reduceMotion: reduceMotion)) {
                    workspace.archive([note.id])
                }
            }
        } else {
            Button("Restore") {
                withAnimation(Motion.hover(reduceMotion: reduceMotion)) {
                    workspace.restore([note.id])
                }
            }
        }
        Button("Delete", role: .destructive) { workspace.delete([note.id]) }
    }
}

/// One line in the library list.
struct LibraryRow: View {
    let note: Note
    let fontChoice: NoticSettings.FontChoice
    let paperStyle: NoticSettings.PaperStyle
    let isChecked: Bool
    let isFocused: Bool
    let toggleChecked: () -> Void

    var body: some View {
        let swatch = NotePalette.swatch(for: note.color, paper: paperStyle)
        HStack(spacing: 12) {
            Button(action: toggleChecked) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isChecked ? 0 : 0.25), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isChecked ? Color.accentColor : Color.primary.opacity(0.04))
                    )
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressFeedback)
            .accessibilityLabel(isChecked ? "Deselect" : "Select")
            .accessibilityAddTraits(isChecked ? .isSelected : [])

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(swatch.paper)
                .frame(width: 3, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(note.title.isEmpty ? "Untitled note" : note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(note.body.isEmpty ? "No text" : TaskMarkup.preview(note.body).replacingOccurrences(of: "\n", with: " "))
                    .font(FontRegistry.font(fontChoice, size: 14, relativeTo: .callout))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(note.lifecycle == .archived ? "ARCHIVED" : "ACTIVE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.07)))
            Text(CompactAge.string(from: note.modifiedAt))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isFocused ? 0.06 : 0))
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isFocused ? .isSelected : [])
        .accessibilityLabel("\(note.title.isEmpty ? "Untitled" : note.title), \(NotePalette.name(for: note.color)), \(note.lifecycle == .archived ? "archived" : "active")")
        .accessibilityValue(note.body)
    }
}

/// The selected note shown in full on the right of the library.
struct NoteDetailCard: View {
    let note: Note
    let fontChoice: NoticSettings.FontChoice
    let paperStyle: NoticSettings.PaperStyle

    var body: some View {
        let swatch = NotePalette.swatch(for: note.color, paper: paperStyle)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(note.title.isEmpty ? "Untitled note" : note.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("edited \(note.modifiedAt.formatted(.dateTime.day().month(.abbreviated)))")
                    .font(.system(size: 11))
                    .opacity(0.6)
            }
            ScrollView {
                Text(TaskMarkup.preview(note.body).isEmpty ? note.body : TaskMarkup.preview(note.body))
                    .font(FontRegistry.font(fontChoice, size: 17, relativeTo: .body))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            Rectangle()
                .fill(swatch.foreground.opacity(0.12))
                .frame(height: 1)
            Text("Created \(note.createdAt.formatted(.dateTime.day().month(.abbreviated).year())) · Updated \(note.modifiedAt.formatted(.relative(presentation: .named)))")
                .font(.system(size: 11))
                .opacity(0.6)
        }
        .padding(16)
        .foregroundStyle(swatch.foreground)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(swatch.background))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(swatch.border.opacity(0.5), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.title.isEmpty ? "Untitled" : note.title)")
        .accessibilityValue(note.body)
    }
}

/// One of the All / Active / Archived filters.
private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(isSelected ? 0.09 : 0)))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.pressFeedback)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Compact neutral button used in the detail pane header.
struct PaneButton: View {
    let title: String
    var tint: Color?
    let action: () -> Void

    init(_ title: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.action = action
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(tint ?? .primary)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(hovering && isEnabled ? 0.12 : 0.07)))
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.pressFeedback)
        .opacity(isEnabled ? 1 : 0.4)
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
    }
}

/// "23m", "1h", "3d" style ages for the list.
enum CompactAge {
    static func string(from date: Date, now: Date = .now) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86400: return "\(Int(seconds / 3600))h"
        case ..<(86400 * 7): return "\(Int(seconds / 86400))d"
        default: return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

/// Owns the one library window.
final class LibraryWindowController: NSWindowController {
    private let workspace: NoticWorkspace
    private let commands: AppCommands
    private let model = LibraryModel()

    init(workspace: NoticWorkspace, commands: AppCommands) {
        self.workspace = workspace
        self.commands = commands
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "All Notes"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("NoticLibrary")
        window.setAccessibilityIdentifier("notic.library")
        super.init(window: window)
        window.contentView = NSHostingView(rootView: LibraryView(workspace: workspace, model: model) { [weak self] id in
            self?.open(id)
        })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    func show(filter: LibraryFilter) {
        model.filter = filter
        window?.title = filter == .archived ? "Archive" : "All Notes"
        presentActivating()
    }

    /// Opens an active note on the display showing the library.
    private func open(_ id: Note.ID) {
        guard let display = window?.screen?.noticDisplayID ?? NSScreen.main?.noticDisplayID else { return }
        workspace.openNote(id, on: display)
    }
}

extension NSWindowController {
    /// Brings Notic forward and shows the window, centring it on first use.
    func presentActivating() {
        if window?.isVisible != true {
            window?.center()
        }
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
