import AppKit
import NoticCore
import SwiftUI

/// The expanded plain-text editor for one note: a header with the title
/// and save state, the body, and a footer with colours and lifecycle actions.
struct EditorView: View {
    let workspace: NoticWorkspace
    let noteID: Note.ID
    let display: DisplayID
    let commands: AppCommands

    private enum Field: Hashable {
        case title
        case body
    }

    @FocusState private var focus: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let note = workspace.note(noteID) {
            content(for: note)
        } else {
            Color.clear
        }
    }

    private func content(for note: Note) -> some View {
        let swatch = NotePalette.swatch(for: note.color, paper: workspace.settings.paperStyle)
        let fontChoice = workspace.settings.fontChoice
        return VStack(alignment: .leading, spacing: 0) {
            header(for: note)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(WindowDragHandle())

            Rectangle()
                .fill(swatch.foreground.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 6)

            NoteBodyEditor(
                text: workspace.note(noteID)?.body ?? note.body,
                font: FontRegistry.nsFont(fontChoice, size: 21),
                ink: NSColor(swatch.foreground),
                onChange: { workspace.updateBody(of: noteID, to: $0) }
            )
            .padding(.horizontal, 4)
            .padding(.top, 4)

            footer(for: note, swatch: swatch)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 6)
        }
        .foregroundStyle(swatch.foreground)
        .tint(swatch.foreground)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(swatch.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EdgeHighlight(), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(swatch.border.opacity(0.6), lineWidth: 0.5)
        )
        .animation(Motion.recolor(reduceMotion: reduceMotion), value: note.color)
        .onAppear {
            if note.title.isEmpty && note.body.isEmpty {
                focus = .title
            } else {
                DispatchQueue.main.async { NoteBodyEditorBridge.focusKeyEditor() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(note.title.isEmpty ? "Untitled" : note.title) editor")
        .accessibilityHint("Drag the title bar to move the note. Double-click it to return the note to its tab.")
    }

    private func header(for note: Note) -> some View {
        let swatch = NotePalette.swatch(for: note.color, paper: workspace.settings.paperStyle)
        return HStack(spacing: 10) {
            HStack(spacing: 6) {
                WindowDot(restColor: swatch.foreground.opacity(0.22), hoverColor: Color(red: 1, green: 0.38, blue: 0.35), label: "Close note", hint: "Closes the editor. The note stays in the deck.") {
                    workspace.closeEditor(on: display)
                }
                .keyboardShortcut("w", modifiers: .command)
                .accessibilityIdentifier("notic.closeEditor")
                WindowDot(restColor: swatch.foreground.opacity(0.22), hoverColor: Color(red: 1, green: 0.74, blue: 0.2), label: "Mark complete", hint: "Moves the note out of the deck into the archive") {
                    workspace.archive([noteID])
                }
            }

            TextField("Untitled note", text: titleBinding(note))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
                .focused($focus, equals: .title)
                .accessibilityLabel("Title")
                .accessibilityIdentifier("notic.editor.title")

            if let progress = TaskMarkup.progress(in: note.body) {
                Text("\(progress.done)/\(progress.total)")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.5)
                    .accessibilityLabel("\(progress.done) of \(progress.total) to-dos done")
            }

            Spacer(minLength: 8)

            ChromeButton(
                workspace.settings.showsAboveAllApps ? "Unpin notes" : "Pin notes",
                systemImage: workspace.settings.showsAboveAllApps ? "pin.fill" : "pin",
                on: swatch
            ) {
                workspace.updateSettings { $0.showsAboveAllApps.toggle() }
            }
            .help(workspace.settings.showsAboveAllApps ? "Stop showing notes above all apps" : "Show notes above all apps")
            .accessibilityValue(workspace.settings.showsAboveAllApps ? "Pinned" : "Not pinned")
            .accessibilityIdentifier("notic.editor.pin")

            if case .failed = workspace.saveState {
                SaveStateLabel(state: workspace.saveState, compact: false)
            }
        }
    }

    private func footer(for note: Note, swatch: NotePalette.Swatch) -> some View {
        return HStack(spacing: 7) {
            ForEach(NoteColor.allCases, id: \.self) { color in
                ColorSwatchButton(color: color, isSelected: color == note.color, ink: swatch.foreground) {
                    workspace.setColor(of: noteID, to: color)
                }
            }
            ChromeButton("Add to-do", systemImage: "checklist", on: swatch) {
                NoteBodyEditorBridge.insertTaskInKeyEditor()
            }
            .help("Add a to-do. Type [] and a space, or press ⇧⌘T.")
            .accessibilityHint("Inserts a checkbox on this line, or a new to-do after the current one.")
            .accessibilityIdentifier("notic.editor.addTask")

            Spacer(minLength: 8)

            ChromeButton("Delete", systemImage: "trash", tint: swatch.destructive, on: swatch) {
                workspace.delete([noteID])
            }
            .accessibilityHint("Deletes the note. Undo is available for ten seconds.")
            .accessibilityIdentifier("notic.editor.delete")
        }
    }

    private func titleBinding(_ note: Note) -> Binding<String> {
        Binding(
            get: { workspace.note(noteID)?.title ?? note.title },
            set: { workspace.updateTitle(of: noteID, to: $0) }
        )
    }

}

/// A small circular control in the editor header that colours on hover.
private struct WindowDot: View {
    let restColor: Color
    let hoverColor: Color
    let label: String
    let hint: String
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(hovering ? hoverColor : restColor)
                .frame(width: 9, height: 9)
                .frame(width: 16, height: 16)
                .contentShape(Circle())
        }
        .buttonStyle(PressFeedbackStyle(scale: 0.85))
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }
}

/// The compact rounded button used in the editor footer.
struct ChromeButton: View {
    let title: String
    let systemImage: String
    var tint: Color?
    let swatch: NotePalette.Swatch
    let action: () -> Void

    init(_ title: String, systemImage: String, tint: Color? = nil, on swatch: NotePalette.Swatch, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.swatch = swatch
        self.action = action
    }

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint ?? swatch.foreground.opacity(0.85))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(swatch.foreground.opacity(hovering ? 0.14 : 0.08))
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.pressFeedback)
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
    }
}

struct ColorSwatchButton: View {
    let color: NoteColor
    let isSelected: Bool
    /// The ink of the surface the swatch sits on, for the selection ring.
    var ink: Color = .primary
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let swatch = NotePalette.swatch(for: color)
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(swatch.paper)
                .frame(width: 16, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                )
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(ink.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
                )
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .animation(Motion.hover(reduceMotion: reduceMotion), value: isSelected)
        }
        .buttonStyle(PressFeedbackStyle(scale: 0.9))
        .accessibilityLabel(NotePalette.name(for: color))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("notic.color.\(color.rawValue)")
    }
}

/// Reports persistence status without interrupting writing.
struct SaveStateLabel: View {
    let state: SaveState
    var compact = false

    var body: some View {
        switch state {
        case .saved, .unsaved:
            EmptyView()
        case let .failed(message):
            Group {
                if compact {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                        .padding(6)
                        .background(Circle().fill(.regularMaterial))
                } else {
                    Label("Couldn't save — retrying", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .help(message)
            .accessibilityLabel("Couldn't save, retrying. \(message)")
            .accessibilityIdentifier("notic.saveState.failed")
        }
    }
}
