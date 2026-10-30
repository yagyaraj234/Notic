import AppKit
import NoticCore
import SwiftUI

/// Presents the pill, deck, and at most one editor on a single display, driven
/// entirely by the workspace's published state for that display.
final class DisplayCoordinator {
    let display: DisplayID
    private let workspace: NoticWorkspace
    private let commands: AppCommands
    /// Shared with the deck view so tabs shingle with the panel's step.
    private let geometry: DisplayGeometry
    private var layout: EdgeLayout { geometry.layout }

    private let edgePanel: EdgePanel
    private var editorPanel: EditorPanel?
    private let dropZones = DropZonePanel()
    private var observation: ObservationToken?
    private var tabDragObservation: ObservationToken?
    private var focusesNextEditor = false

    init(display: DisplayID, screen: NSScreen, workspace: NoticWorkspace, commands: AppCommands) {
        self.display = display
        self.workspace = workspace
        self.commands = commands
        self.geometry = DisplayGeometry(layout: EdgeLayout(visibleFrame: screen.visibleFrame, edge: workspace.settings.stackPosition, position: workspace.settings.stackOffset))

        edgePanel = EdgePanel(
            content: EdgeSurfaceView(workspace: workspace, display: display, geometry: geometry, commands: commands),
            onPointerEntered: { workspace.pointerEntered(display) },
            onPointerExited: { workspace.pointerExited(display) }
        )
        edgePanel.onStackPress = { [weak self] in
            guard let self else { return }
            if self.workspace.deckState(on: display) == .dormant {
                self.workspace.pointerExited(display)
            } else {
                self.workspace.pointerEntered(display)
            }
        }
        edgePanel.onStackDrag = { [weak self] point, ended in
            guard let self else { return }
            let docked = self.layout.docking(at: point)
            guard ended else {
                // Tabs only make sense against an edge, so while it moves the
                // stack is one whole card under the pointer. Hidden, not
                // ordered out: the panel is still tracking the drag.
                self.edgePanel.alphaValue = 0
                self.dropZones.show(docked.edge, over: self.layout.visibleFrame, pointer: point,
                                    card: self.dragCard, below: self.edgePanel)
                return
            }
            self.geometry.layout = docked
            self.refreshFrames(animated: false)
            // A dropped stack rests closed; the card lands on the pill, not the fanned deck.
            self.workspace.restDeck(on: display)
            let dock = self.current.map {
                self.layout.pillFrame(noteCount: $0.deckCount, hasOverflow: $0.hasOverflow, footerRows: $0.footerRows)
            } ?? self.edgePanel.interactiveFrame
            self.dropZones.dismiss(landingAt: CGPoint(x: dock.midX, y: dock.midY)) { [weak self] in
                self?.edgePanel.alphaValue = 1
            }
            self.workspace.updateSettings {
                $0.stackPosition = docked.edge
                $0.stackOffset = docked.position
            }
        }
        edgePanel.onStackRelease = { [weak self] in
            guard let self else { return }
            if self.edgePanel.interactiveFrame.contains(NSEvent.mouseLocation) {
                self.workspace.pointerEntered(display)
            } else {
                self.workspace.pointerExited(display)
            }
        }
        edgePanel.onPillClick = { workspace.revealDeck(on: display) }
        let deck = layout.deckMetrics(noteCount: workspace.deckNotes.count, hasOverflow: workspace.overflowCount > 0)
        edgePanel.setFrame(deck.frame, display: false)
        edgePanel.interactiveFrame = layout.pillFrame(noteCount: workspace.deckNotes.count)
        edgePanel.orderFrontRegardless()

        // Deliberately excludes note text so typing does not re-run layout.
        observation = ObservationToken.track({ [workspace] in
            let state = workspace.deckState(on: display)
            let deck = workspace.deckNotes
            let openNote = state.openNoteID.flatMap(workspace.note)
            var footerRows = workspace.pendingDeletions.isEmpty ? 0 : 1
            if case .failed = workspace.saveState { footerRows += 1 }
            return Snapshot(
                state: state,
                deckCount: deck.count,
                hasOverflow: workspace.overflowCount > 0,
                footerRows: footerRows,
                isHidden: workspace.isHidden,
                openNoteID: openNote?.id,
                openTabIndex: openNote.flatMap { note in deck.firstIndex { $0.id == note.id } } ?? 0,
                openEditorSize: openNote?.editorSize,
                settings: workspace.settings
            )
        }) { [weak self] snapshot in
            // Typing changes the note body, which this read observes, but the
            // snapshot itself is unchanged. Re-applying would pin the editor
            // back to its tab.
            guard self?.current != snapshot else { return }
            self?.apply(snapshot)
        }

        tabDragObservation = ObservationToken.track({ [geometry] in
            geometry.tabDrag
        }) { [weak self] drag in
            guard let self, let current = self.current else { return }
            if let drag, drag.id == current.openNoteID {
                self.refreshFrames(animated: false)
            } else if drag == nil {
                self.refreshFrames(animated: true)
            }
        }
    }

    /// Re-clamps everything after a resolution or arrangement change.
    func screenDidChange(_ screen: NSScreen) {
        geometry.layout = EdgeLayout(visibleFrame: screen.visibleFrame, edge: workspace.settings.stackPosition, position: workspace.settings.stackOffset)
        refreshFrames(animated: false)
    }

    /// Activates the editor for the display's open note. Because the workspace
    /// publishes state asynchronously, the panel may not exist yet; in that
    /// case focus is applied as soon as it is created.
    func focusEditor() {
        if let editorPanel {
            editorPanel.activateAndFocus()
        } else {
            focusesNextEditor = true
        }
    }

    func tearDown() {
        observation = nil
        tabDragObservation = nil
        editorPanel?.orderOut(nil)
        editorPanel = nil
        for panel in retiring { panel.orderOut(nil) }
        retiring.removeAll()
        dropZones.orderOut(nil)
        edgePanel.orderOut(nil)
    }

    // MARK: State application

    private struct Snapshot: Equatable {
        var state: DeckState
        var deckCount: Int
        var hasOverflow: Bool
        var footerRows: Int
        var isHidden: Bool
        var openNoteID: Note.ID?
        var openTabIndex: Int
        var openEditorSize: CGSize?
        var settings: NoticSettings
    }

    private var current: Snapshot?

    private func apply(_ snapshot: Snapshot) {
        let previousSettings = current?.settings
        current = snapshot
        if previousSettings?.stackPosition != snapshot.settings.stackPosition || previousSettings?.stackOffset != snapshot.settings.stackOffset {
            geometry.layout = EdgeLayout(visibleFrame: layout.visibleFrame, edge: snapshot.settings.stackPosition, position: snapshot.settings.stackOffset)
        }

        if snapshot.isHidden {
            edgePanel.orderOut(nil)
            editorPanel?.orderOut(nil)
            return
        }

        var presentedEditor: EditorPanel?
        // Read before the panels change: is the pointer on the deck or editor?
        var slide = edgeSlide
        if let id = snapshot.openNoteID {
            if editorPanel?.noteID != id {
                // One note replacing another in the same spot swaps at once:
                // two editors sliding past each other read as a double exposure.
                if editorPanel != nil { slide = nil }
                retire(editorPanel, slidingTo: slide)
                let panel = makeEditorPanel(for: id)
                editorPanel = panel
                presentedEditor = panel
            }
        } else if let editorPanel {
            retire(editorPanel, slidingTo: slide)
            self.editorPanel = nil
        }

        applyWindowBehaviour(snapshot.settings)
        refreshFrames()
        edgePanel.orderFrontRegardless()

        if let presentedEditor {
            presentedEditor.present(at: editorTarget(for: snapshot) ?? presentedEditor.frame, slidingFrom: slide)
        } else {
            editorPanel?.orderFrontRegardless()
        }

        if focusesNextEditor, let editorPanel {
            focusesNextEditor = false
            editorPanel.activateAndFocus()
        }
    }

    /// Hide the previous editor before presenting its replacement.
    private func retire(_ panel: EditorPanel?, slidingTo offset: CGVector?) {
        guard let panel else { return }
        retiring.insert(panel)
        panel.dismiss(slidingTo: offset) { [weak self] in
            self?.retiring.remove(panel)
        }
    }

    private var retiring: Set<EditorPanel> = []

    /// How far an editor slides toward the deck's edge when it opens from, or
    /// closes into, its tab with the pointer; `nil` for keyboard commands,
    /// which stay instant. The state change arrives a turn after the event,
    /// so a click that just landed on the deck or the editor stands in for
    /// the cause. Global hotkeys arrive as Carbon events, never as a click.
    private var edgeSlide: CGVector? {
        let pointer = NSEvent.mouseLocation
        guard let event = NSApp.currentEvent,
              [.leftMouseDown, .leftMouseUp].contains(event.type),
              ProcessInfo.processInfo.systemUptime - event.timestamp < 0.5,
              edgePanel.frame.contains(pointer) || editorPanel?.frame.contains(pointer) == true
        else { return nil }
        if Motion.systemReducesMotion { return .zero }
        switch layout.edge {
        case .right: return CGVector(dx: 16, dy: 0)
        case .left: return CGVector(dx: -16, dy: 0)
        case .bottom: return CGVector(dx: 0, dy: -16)
        }
    }

    private func makeEditorPanel(for id: Note.ID) -> EditorPanel {
        EditorPanel(
            noteID: id,
            content: EditorView(workspace: workspace, noteID: id, display: display, commands: commands),
            onResize: { [weak self] size in
                self?.workspace.setEditorSize(of: id, to: size)
            },
            onLiveResizeEnded: { [weak self] in
                // Re-anchor using the size the user just chose: beside the deck,
                // or wherever they dragged the note, which resizing may have shifted.
                guard let self, let size = self.workspace.note(id)?.editorSize else { return }
                if self.current?.settings.editorOrigin != nil, let panel = self.editorPanel, panel.noteID == id {
                    self.workspace.setEditorOrigin(panel.frame.origin)
                    self.current?.settings.editorOrigin = panel.frame.origin
                }
                self.current?.openEditorSize = size
                self.refreshFrames(animated: false)
            },
            onMove: { [weak self] origin in
                guard let self else { return }
                self.workspace.setEditorOrigin(origin)
                // Keep the snapshot in step so the settings change does not re-apply mid-drag.
                self.current?.settings.editorOrigin = origin
                if origin == nil {
                    if let editorPanel = self.editorPanel, let current = self.current,
                       let target = self.editorTarget(for: current) {
                        // Double-click: glide back to the tab instead of jumping.
                        self.glideEditor(editorPanel, to: target)
                    }
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.workspace.closeEditor(on: self.display)
            }
        )
    }

    /// Same curve as return-to-tab: the editor is already on screen and
    /// moving to a new place, not appearing.
    private func glideEditor(_ panel: EditorPanel, to target: CGRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.systemReducesMotion ? 0 : Motion.scaled(0.22)
            context.timingFunction = Motion.panelEnter
            panel.animator().setFrame(target, display: true)
        }
    }

    private func refreshFrames(animated: Bool = true) {
        guard let current else { return }
        let deck = layout.deckMetrics(noteCount: current.deckCount, hasOverflow: current.hasOverflow, footerRows: current.footerRows)
        // The panel is the fanned deck's size whether or not the deck is
        // fanned. Growing it as the deck fanned raced the deck's own
        // animation — the slide began in a panel still only as wide as the
        // dock and was clipped to a sliver for its first frames — and
        // shrinking it afterwards had to be deferred to avoid cutting the
        // tabs off mid-flight. Only `interactiveFrame` changes with the state.
        //
        // A window snaps its frame to whole points, so the deck's half-point
        // centring never compares equal. Without the tolerance every state
        // change re-set the frame to the place it was already in.
        if !edgePanel.frame.equalTo(deck.frame, within: 1) {
            edgePanel.setFrame(deck.frame, display: true)
        }
        edgePanel.dragsPill = current.state == .dormant
        // Leave the add button and footer controls on their normal click path.
        let controls = EdgeLayout.deckPadding + EdgeLayout.addButtonSize
            + EdgeLayout.addButtonGap + CGFloat(current.footerRows) * layout.footerRowLength
        if layout.edge == .bottom {
            edgePanel.stackDragFrame = CGRect(x: deck.frame.minX + controls, y: deck.frame.minY,
                                              width: deck.frame.width - controls, height: deck.frame.height)
        } else {
            edgePanel.stackDragFrame = CGRect(x: deck.frame.minX, y: deck.frame.minY + controls,
                                              width: deck.frame.width, height: deck.frame.height - controls)
        }
        edgePanel.interactiveFrame = current.state == .dormant
            ? layout.pillFrame(noteCount: current.deckCount, hasOverflow: current.hasOverflow, footerRows: current.footerRows)
            : deck.frame

        if let editorPanel, !editorPanel.inLiveResize, !editorPanel.isBeingDragged,
           let target = editorTarget(for: current), editorPanel.frame != target {
            let followsDrag = current.settings.editorOrigin == nil
                && geometry.tabDrag?.id == current.openNoteID
            if followsDrag || !animated || !editorPanel.isVisible {
                editorPanel.setFrame(target, display: true)
            } else {
                glideEditor(editorPanel, to: target)
            }
        }
    }

    /// The front note, standing in for the whole stack while it is dragged.
    private var dragCard: DragCard {
        let notes = workspace.deckNotes
        let paper = workspace.settings.paperStyle
        guard let front = notes.first else {
            return DragCard(title: "No notes", swatch: NotePalette.swatch(for: .yellow, paper: paper), count: 0)
        }
        return DragCard(title: DeckView.tabTitle(of: front), swatch: NotePalette.swatch(for: .yellow, paper: paper), count: notes.count)
    }

    private func editorTarget(for snapshot: Snapshot) -> CGRect? {
        guard let size = snapshot.openEditorSize, let id = snapshot.openNoteID else { return nil }
        if let origin = snapshot.settings.editorOrigin {
            return layout.editorFrame(size: size, placedAt: origin)
        }
        let deck = layout.deckMetrics(noteCount: snapshot.deckCount, hasOverflow: snapshot.hasOverflow, footerRows: snapshot.footerRows)
        if let drag = geometry.tabDrag, drag.id == id {
            return layout.editorFrame(size: size, tabOffsetY: drag.offsetY, deck: deck)
        }
        return layout.editorFrame(size: size, tabIndex: snapshot.openTabIndex, deck: deck)
    }

    private func applyWindowBehaviour(_ settings: NoticSettings) {
        var behaviour: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if settings.visibleOverFullScreenApps {
            behaviour.insert(.fullScreenAuxiliary)
        }
        edgePanel.collectionBehavior = behaviour
        editorPanel?.collectionBehavior = behaviour
        editorPanel?.level = settings.showsAboveAllApps ? .floating : .normal
    }
}

private extension CGRect {
    /// Whether two frames name the same place, allowing for a window having
    /// snapped its own frame to whole points.
    func equalTo(_ other: CGRect, within tolerance: CGFloat) -> Bool {
        abs(minX - other.minX) < tolerance && abs(minY - other.minY) < tolerance
            && abs(width - other.width) < tolerance && abs(height - other.height) < tolerance
    }
}
