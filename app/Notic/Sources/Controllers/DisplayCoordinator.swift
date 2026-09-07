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
    private var observation: ObservationToken?
    private var tabDragObservation: ObservationToken?
    private var focusesNextEditor = false

    init(display: DisplayID, screen: NSScreen, workspace: NoticWorkspace, commands: AppCommands) {
        self.display = display
        self.workspace = workspace
        self.commands = commands
        self.geometry = DisplayGeometry(layout: EdgeLayout(visibleFrame: screen.visibleFrame))

        edgePanel = EdgePanel(
            content: EdgeSurfaceView(workspace: workspace, display: display, geometry: geometry, commands: commands),
            onPointerEntered: { workspace.pointerEntered(display) },
            onPointerExited: { workspace.pointerExited(display) }
        )
        edgePanel.setFrame(layout.pillFrame(noteCount: workspace.deckNotes.count), display: false)
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
                editorOrigin: openNote?.editorOrigin,
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
        geometry.layout = EdgeLayout(visibleFrame: screen.visibleFrame)
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
        pendingShrink?.cancel()
        editorPanel?.orderOut(nil)
        editorPanel = nil
        for panel in retiring { panel.orderOut(nil) }
        retiring.removeAll()
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
        var editorOrigin: CGPoint?
        var settings: NoticSettings
    }

    private var current: Snapshot?

    private func apply(_ snapshot: Snapshot) {
        current = snapshot

        if snapshot.isHidden {
            edgePanel.orderOut(nil)
            editorPanel?.orderOut(nil)
            return
        }

        var presentedEditor: EditorPanel?
        if let id = snapshot.openNoteID {
            if editorPanel?.noteID != id {
                retire(editorPanel)
                let panel = makeEditorPanel(for: id)
                editorPanel = panel
                presentedEditor = panel
            }
        } else if let editorPanel {
            retire(editorPanel)
            self.editorPanel = nil
        }

        applyWindowBehaviour(snapshot.settings)
        refreshFrames()
        edgePanel.orderFrontRegardless()

        if let presentedEditor {
            // Slide out of the tab rather than popping into place.
            presentedEditor.present(at: editorTarget(for: snapshot) ?? presentedEditor.frame)
        } else {
            editorPanel?.orderFrontRegardless()
        }

        if focusesNextEditor, let editorPanel {
            focusesNextEditor = false
            editorPanel.activateAndFocus()
        }
    }

    /// Editors leave the way they arrived, then release their panel.
    private func retire(_ panel: EditorPanel?) {
        guard let panel else { return }
        retiring.insert(panel)
        panel.dismiss { [weak self] in
            self?.retiring.remove(panel)
        }
    }

    private var retiring: Set<EditorPanel> = []

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
                if self.placedOrigins[id] != nil, let panel = self.editorPanel, panel.noteID == id {
                    self.placedOrigins[id] = panel.frame.origin
                }
                self.current?.openEditorSize = size
                self.refreshFrames(animated: false)
            },
            onMove: { [weak self] origin in
                guard let self else { return }
                self.placedOrigins[id] = origin
                self.workspace.setEditorOrigin(of: id, to: origin)
                if origin == nil {
                    self.current?.editorOrigin = nil
                    if let editorPanel = self.editorPanel, let current = self.current,
                       let target = self.editorTarget(for: current) {
                        // Double-click: glide back to the tab instead of jumping.
                        self.glideEditor(editorPanel, to: target)
                    }
                } else {
                    self.current?.editorOrigin = origin
                }
            },
            onClose: { [weak self] in
                guard let self else { return }
                self.workspace.closeEditor(on: self.display)
            }
        )
    }

    private var pendingShrink: DispatchWorkItem?

    /// Same curve as return-to-tab: the editor is already on screen and
    /// moving to a new place, not appearing.
    private func glideEditor(_ panel: EditorPanel, to target: CGRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.systemReducesMotion ? 0 : 0.22
            context.timingFunction = Motion.panelEnter
            panel.animator().setFrame(target, display: true)
        }
    }

    private func refreshFrames(animated: Bool = true) {
        guard let current else { return }
        let deck = layout.deckMetrics(noteCount: current.deckCount, hasOverflow: current.hasOverflow, footerRows: current.footerRows)
        let edgeFrame = current.state == .dormant ? layout.pillFrame(noteCount: current.deckCount) : deck.frame

        pendingShrink?.cancel()
        pendingShrink = nil
        if edgePanel.frame != edgeFrame {
            if current.state == .dormant, edgePanel.frame.height > edgeFrame.height {
                // Let the tabs slide back to the edge before the panel closes
                // around the pill; shrinking first would cut them off mid-flight.
                let work = DispatchWorkItem { [weak self] in
                    guard let self, self.current?.state == .dormant else { return }
                    self.edgePanel.setFrame(edgeFrame, display: true)
                }
                pendingShrink = work
                DispatchQueue.main.asyncAfter(deadline: .now() + Motion.deckDuration, execute: work)
            } else {
                edgePanel.setFrame(edgeFrame, display: true)
            }
        }

        if let editorPanel, !editorPanel.inLiveResize, !editorPanel.isPresenting, !editorPanel.isBeingDragged,
           let target = editorTarget(for: current), editorPanel.frame != target {
            let followsDrag = current.editorOrigin == nil
                && current.openNoteID.flatMap { placedOrigins[$0] } == nil
                && geometry.tabDrag?.id == current.openNoteID
            if followsDrag || !animated || !editorPanel.isVisible {
                editorPanel.setFrame(target, display: true)
            } else {
                glideEditor(editorPanel, to: target)
            }
        }
    }

    /// Where the user last dragged each note's editor on this display. A note
    /// without an entry opens level with its tab; one with an entry reopens
    /// where it was left for as long as Notic runs.
    private var placedOrigins: [Note.ID: CGPoint] = [:]

    private func editorTarget(for snapshot: Snapshot) -> CGRect? {
        guard let size = snapshot.openEditorSize, let id = snapshot.openNoteID else { return nil }
        if let origin = snapshot.editorOrigin ?? placedOrigins[id] {
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
