import NoticCore
import SwiftUI

/// Observable holder for one display's geometry so the deck can lay tabs out
/// with the same shingle step the coordinator sizes the panel with.
@Observable
final class DisplayGeometry {
    var layout: EdgeLayout
    /// Live drag of a tab; `nil` when none is being dragged. The coordinator
    /// reads this so a docked editor can stay level with its tab.
    var tabDrag: TabDrag?

    struct TabDrag: Equatable {
        var id: Note.ID
        /// Distance from the top of the tab stack to the top of the dragged tab.
        var offsetY: CGFloat
    }

    init(layout: EdgeLayout) {
        self.layout = layout
    }
}

/// The fanned deck: colour tabs shingled down the screen edge, the "+N more"
/// tab, and the add button beneath them.
struct DeckView: View {
    let workspace: NoticWorkspace
    let display: DisplayID
    let geometry: DisplayGeometry
    let commands: AppCommands

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A tab being dragged to a new place in the order. The tab follows the
    /// pointer 1:1 from where it was grabbed; the others reflow around it.
    private struct Drag {
        let id: Note.ID
        let startIndex: Int
        var translation: CGFloat = 0
    }

    @State private var drag: Drag?

    var body: some View {
        let notes = workspace.deckNotes
        let openID = workspace.deckState(on: display).openNoteID
        let metrics = geometry.layout.deckMetrics(
            noteCount: notes.count,
            hasOverflow: workspace.overflowCount > 0,
            footerRows: footerRows
        )
        VStack(alignment: .trailing, spacing: 0) {
            if metrics.tileCount == 0 {
                emptyPrompt
                    .frame(height: EdgeLayout.emptyPromptHeight)
            } else {
                ZStack(alignment: .topTrailing) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        let dragging = drag?.id == note.id
                        NoteTabView(
                            title: note.title,
                            swatch: NotePalette.swatch(for: note.color, paper: workspace.settings.paperStyle),
                            colorName: NotePalette.name(for: note.color),
                            preview: preview(of: note),
                            visibleLength: visibleLength(at: index, metrics: metrics),
                            tilt: workspace.settings.tiltsTabs ? NoteTabView.lean(for: note.id, at: index) : 0,
                            isOpen: openID == note.id,
                            isLifted: dragging
                        ) {
                            workspace.openNote(note.id, on: display)
                        }
                        .highPriorityGesture(reorderGesture(for: note.id, index: index, notes: notes, metrics: metrics))
                        .secondaryClickMenu { commands.dockMenu(note.id) }
                        .offset(y: tabOffset(index: index, dragging: dragging, metrics: metrics))
                        .zIndex(dragging ? 100 : Double(index))
                        .accessibilityIdentifier("notic.card.\(index)")
                    }
                    if workspace.overflowCount > 0 {
                        OverflowTab(count: workspace.overflowCount, action: commands.showLibrary)
                            .offset(y: CGFloat(notes.count) * metrics.tabStep)
                            .zIndex(Double(notes.count))
                    }
                }
                .frame(width: EdgeLayout.tabWidth, height: metrics.tabsHeight, alignment: .topTrailing)
                .animation(Motion.settle(reduceMotion: reduceMotion), value: notes.map(\.id))
            }

            addButton
                .padding(.top, EdgeLayout.addButtonGap)
                .padding(.trailing, 10)

            if !workspace.pendingDeletions.isEmpty {
                UndoChip(workspace: workspace)
                    .frame(height: EdgeLayout.footerRowHeight)
                    .padding(.trailing, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
            if case .failed = workspace.saveState {
                SaveStateLabel(state: workspace.saveState, compact: true)
                    .frame(height: EdgeLayout.footerRowHeight)
                    .padding(.trailing, 12)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, EdgeLayout.deckPadding)
        .frame(width: EdgeLayout.deckWidth, alignment: .topTrailing)
        .animation(Motion.settle(reduceMotion: reduceMotion), value: footerRows)
        .secondaryClickMenu(behind: true) { commands.dockMenu(nil) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notic deck")
        .accessibilityIdentifier("notic.deck")
    }

    private var footerRows: Int {
        var rows = workspace.pendingDeletions.isEmpty ? 0 : 1
        if case .failed = workspace.saveState { rows += 1 }
        return rows
    }

    /// How much of the tab at `index` is uncovered by the tab below it.
    private func visibleLength(at index: Int, metrics: EdgeLayout.DeckMetrics) -> CGFloat {
        index == metrics.tileCount - 1 ? EdgeLayout.tabHeight : metrics.tabStep
    }

    private func preview(of note: Note) -> String {
        let first = TaskMarkup.preview(note.body).split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return first
    }

    // MARK: Reordering

    /// The dragged tab sits where the pointer put it, resisting past the ends
    /// of the deck; every other tab sits in its slot.
    private func tabOffset(index: Int, dragging: Bool, metrics: EdgeLayout.DeckMetrics) -> CGFloat {
        guard dragging, let drag else { return CGFloat(index) * metrics.tabStep }
        let raw = CGFloat(drag.startIndex) * metrics.tabStep + drag.translation
        let last = CGFloat(max(0, workspace.deckNotes.count - 1)) * metrics.tabStep
        if raw < 0 {
            return Motion.rubberband(raw, dimension: EdgeLayout.tabHeight)
        }
        if raw > last {
            return last + Motion.rubberband(raw - last, dimension: EdgeLayout.tabHeight)
        }
        return raw
    }

    private func reorderGesture(for id: Note.ID, index: Int, notes: [Note], metrics: EdgeLayout.DeckMetrics) -> some Gesture {
        // Global space: the tab itself moves with the pointer, so its local
        // space would drift under the gesture and halve the translation.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if drag == nil {
                    drag = Drag(id: id, startIndex: index)
                }
                drag?.translation = value.translation.height
                // Reflow the others as the dragged tab crosses slot midpoints.
                let raw = CGFloat(drag?.startIndex ?? index) * metrics.tabStep + value.translation.height
                settle(id, near: raw, notes: notes, metrics: metrics)
                geometry.tabDrag = DisplayGeometry.TabDrag(
                    id: id,
                    offsetY: tabOffset(index: index, dragging: true, metrics: metrics)
                )
            }
            .onEnded { value in
                defer { geometry.tabDrag = nil }
                guard let current = drag else { return }
                // Land where the throw is going, not where the pointer let go.
                // Slots are discrete and close together, so use the snappier
                // deceleration: a brisk flick carries about one slot.
                let raw = CGFloat(current.startIndex) * metrics.tabStep + value.translation.height
                let projected = raw + Motion.project(velocity: value.velocity.height, decelerationRate: 0.99)
                let target = settle(id, near: projected, notes: workspace.deckNotes, metrics: metrics)
                let remaining = CGFloat(target) * metrics.tabStep - tabOffset(index: index, dragging: true, metrics: metrics)
                let relativeVelocity = abs(remaining) > 0.5 ? Double(value.velocity.height / remaining) : 0
                withAnimation(Motion.handoff(relativeVelocity: relativeVelocity, reduceMotion: reduceMotion)) {
                    drag = nil
                }
            }
    }

    /// Moves `id` to the slot nearest `y` and returns that slot.
    @discardableResult
    private func settle(_ id: Note.ID, near y: CGFloat, notes: [Note], metrics: EdgeLayout.DeckMetrics) -> Int {
        let slot = min(max(Int((y / metrics.tabStep).rounded()), 0), max(0, notes.count - 1))
        if let currentIndex = notes.firstIndex(where: { $0.id == id }), currentIndex != slot {
            withAnimation(Motion.settle(reduceMotion: reduceMotion)) {
                workspace.moveActiveNote(id, toIndex: slot)
            }
        }
        return slot
    }

    // MARK: Chrome

    private var emptyPrompt: some View {
        Text(workspace.showsFirstNotePrompt ? "Create your first note" : "No active notes")
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(NotePalette.chipBackground))
            .accessibilityIdentifier(workspace.showsFirstNotePrompt ? "notic.firstNotePrompt" : "notic.emptyDeck")
    }

    private var addButton: some View {
        Button {
            commands.newNote(display)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.7))
                .frame(width: EdgeLayout.addButtonSize, height: EdgeLayout.addButtonSize)
                .background(
                    Circle()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 1)
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.pressFeedback)
        .accessibilityLabel("New Note")
        .accessibilityIdentifier("notic.newNote")
    }
}

/// The shape of a tab: rounded on the side facing the desktop, square where
/// it runs off the screen edge.
struct TabShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 14, bottomLeadingRadius: 14,
            bottomTrailingRadius: 0, topTrailingRadius: 0,
            style: .continuous
        )
        .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> TabShape {
        TabShape(inset: inset + amount)
    }
}

/// A faint bright line along the top edge, the light catching the paper.
struct EdgeHighlight: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        LinearGradient(
            colors: [.white.opacity(environment.colorScheme == .dark ? 0.16 : 0.55), .white.opacity(0)],
            startPoint: .top, endPoint: .center
        )
    }
}

/// The vertical label and perforation that identify a tab.
struct TabLabel: View {
    let title: String
    let swatch: NotePalette.Swatch
    /// Length along the edge available for the label before it is cut off.
    let visibleLength: CGFloat

    var body: some View {
        let labelLength = max(24, visibleLength - 22)
        HStack(alignment: .top, spacing: 0) {
            Text((title.isEmpty ? "Untitled" : title).uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.6)
                .lineLimit(1)
                .fixedSize()
                .frame(width: labelLength, alignment: .leading)
                .mask(
                    // Long titles run under the next tab, so fade the cut end.
                    LinearGradient(
                        stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 14, height: labelLength)
                .padding(.top, 11)
                .padding(.leading, 14)
                .foregroundStyle(swatch.foreground.opacity(0.62))
            Perforation()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(swatch.foreground.opacity(0.28))
                .frame(width: 1)
                .padding(.vertical, 10)
                .padding(.leading, 16)
        }
        .accessibilityHidden(true)
    }

    private struct Perforation: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }
}

/// One shingled tab in the fanned deck.
struct NoteTabView: View {
    let title: String
    let swatch: NotePalette.Swatch
    let colorName: String
    let preview: String
    let visibleLength: CGFloat
    /// Lean in degrees; positive tips the visible edge downward.
    var tilt: Double = 0
    let isOpen: Bool
    var isLifted = false
    let action: () -> Void

    /// Tabs run this far past the screen edge so a leaning tab never shows a
    /// sliver of desktop at its square corners.
    static let overhang: CGFloat = 8

    /// A stable lean for a note: alternating direction down the deck, with a
    /// magnitude between 1.2° and 2.4° drawn from the note's identity, so the
    /// same note always leans the same way and neighbours differ.
    static func lean(for id: Note.ID, at index: Int) -> Double {
        let magnitude = 1.2 + Double(id.uuid.0 % 100) / 100 * 1.2
        return index.isMultiple(of: 2) ? -magnitude : magnitude
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            TabLabel(title: title, swatch: swatch, visibleLength: visibleLength)
                .frame(width: EdgeLayout.tabWidth + Self.overhang, height: EdgeLayout.tabHeight, alignment: .topLeading)
                .background(
                    TabShape()
                        .fill(swatch.background)
                        .shadow(color: .black.opacity(isLifted ? 0.32 : 0.22), radius: isLifted ? 12 : 6, x: isLifted ? -6 : -2, y: isLifted ? 8 : 3)
                )
                .overlay(TabShape().strokeBorder(EdgeHighlight(), lineWidth: 1))
                .overlay(TabShape().strokeBorder(swatch.border.opacity(0.5), lineWidth: 0.5))
                .contentShape(TabShape())
        }
        .buttonStyle(PressFeedbackStyle(scale: 0.98))
        // Lean about the edge the tab hangs from; a lifted or open tab sits straight.
        .rotationEffect(.degrees(isLifted || isOpen ? 0 : tilt), anchor: .trailing)
        .offset(x: Self.overhang)
        // Hint toward the pull-out: the tab eases off the edge under the pointer.
        .offset(x: hovering && !isOpen && !isLifted && !reduceMotion ? -6 : 0)
        .scaleEffect(isLifted && !reduceMotion ? 1.04 : 1, anchor: .trailing)
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .animation(Motion.settle(reduceMotion: reduceMotion), value: isLifted)
        .animation(Motion.settle(reduceMotion: reduceMotion), value: isOpen)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(title.isEmpty ? "Untitled" : title), \(colorName) note")
        .accessibilityValue(preview)
        .accessibilityHint(isOpen ? "Open" : "Opens the note level with its tab")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }
}

/// The tab shown when more than eight notes are active.
struct OverflowTab: View {
    let count: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let swatch = NotePalette.Swatch(
            background: Color(nsColor: .windowBackgroundColor),
            foreground: .primary,
            border: .primary.opacity(0.2),
            accent: .primary,
            paper: .gray,
            destructive: NotePalette.destructive
        )
        Button(action: action) {
            TabLabel(title: "+\(count) more", swatch: swatch, visibleLength: EdgeLayout.tabHeight)
                .frame(width: EdgeLayout.tabWidth + NoteTabView.overhang, height: EdgeLayout.tabHeight, alignment: .topLeading)
                .background(
                    TabShape()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.22), radius: 6, x: -2, y: 3)
                )
                .overlay(TabShape().strokeBorder(EdgeHighlight(), lineWidth: 1))
                .overlay(TabShape().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                .contentShape(TabShape())
        }
        .buttonStyle(PressFeedbackStyle(scale: 0.98))
        .offset(x: NoteTabView.overhang)
        .offset(x: hovering && !reduceMotion ? -6 : 0)
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(count) more notes")
        .accessibilityHint("Opens the note library")
        .accessibilityIdentifier("notic.overflow")
    }
}

/// Small "Undo" control shown under the deck while a deletion can be undone.
struct UndoChip: View {
    let workspace: NoticWorkspace

    var body: some View {
        let pending = workspace.pendingDeletions
        Button {
            workspace.undoDelete(pending.map(\.id))
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
                .font(.system(size: 11, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(.regularMaterial).shadow(color: .black.opacity(0.14), radius: 3, y: 1))
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.pressFeedback)
        .help(pending.count == 1 ? "Note deleted" : "\(pending.count) notes deleted")
        .accessibilityLabel(pending.count == 1 ? "Undo delete note" : "Undo delete \(pending.count) notes")
        .accessibilityIdentifier("notic.undoDelete")
    }
}

/// Non-blocking "deleted · Undo" strip used where there is horizontal room.
struct PendingDeletionBanner: View {
    let workspace: NoticWorkspace

    var body: some View {
        let pending = workspace.pendingDeletions
        HStack {
            Text(pending.count == 1 ? "Note deleted" : "\(pending.count) notes deleted")
                .font(.callout)
            Spacer()
            Button("Undo") {
                workspace.undoDelete(pending.map(\.id))
            }
            .buttonStyle(.pressFeedback)
            .accessibilityIdentifier("notic.undoDelete")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.thinMaterial))
        .accessibilityElement(children: .combine)
    }
}
