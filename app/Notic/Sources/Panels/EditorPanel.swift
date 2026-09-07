import AppKit
import NoticCore
import SwiftUI

/// A resizable, non-activating panel for one expanded note. Hovering does
/// nothing; an explicit click activates Notic so typing can begin.
final class EditorPanel: NSPanel, NSWindowDelegate {
    let noteID: Note.ID
    private let onResize: (CGSize) -> Void
    private let onLiveResizeEnded: () -> Void
    /// The user dragged the note somewhere; `nil` means they asked for it to
    /// go back beside its tab.
    private let onMove: (CGPoint?) -> Void
    private let onClose: () -> Void

    init(
        noteID: Note.ID,
        content: some View,
        onResize: @escaping (CGSize) -> Void,
        onLiveResizeEnded: @escaping () -> Void,
        onMove: @escaping (CGPoint?) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.noteID = noteID
        self.onResize = onResize
        self.onLiveResizeEnded = onLiveResizeEnded
        self.onMove = onMove
        self.onClose = onClose
        super.init(
            contentRect: CGRect(origin: .zero, size: EditorSizing.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .normal
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        minSize = EditorSizing.minimumSize
        maxSize = EditorSizing.maximumSize
        delegate = self
        setAccessibilityIdentifier("notic.editorPanel")

        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        contentView = hosting
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Brings Notic forward and makes this panel key so the editor gets focus.
    func activateAndFocus() {
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    // MARK: Moving

    /// True while the user is dragging the note; layout must leave it alone.
    private(set) var isBeingDragged = false

    func userDragBegan() {
        isBeingDragged = true
    }

    /// Every step is reported, not just the last one, so that if a state
    /// change relays out mid-drag the note is already known to be placed
    /// here and is not snapped back under the pointer.
    func userDragMoved(to origin: CGPoint) {
        guard let screen = screen ?? NSScreen.main else {
            setFrameOrigin(origin)
            onMove(origin)
            return
        }
        // Keep at least a grip's worth of the note on screen.
        let bounds = screen.visibleFrame
        var clamped = origin
        clamped.x = min(max(clamped.x, bounds.minX - frame.width + 60), bounds.maxX - 60)
        clamped.y = min(max(clamped.y, bounds.minY - frame.height + 44), bounds.maxY - frame.height)
        setFrameOrigin(clamped)
        onMove(clamped)
    }

    func userDragEnded() {
        isBeingDragged = false
        onMove(frame.origin)
    }

    /// Sends the note back beside its tab.
    func returnToTab() {
        onMove(nil)
    }

    // MARK: Presentation

    /// How far the note travels from the edge as it slides out of its tab.
    private static let travel: CGFloat = 28

    private(set) var isPresenting = false

    /// Slides the note out of the edge to `frame`, fading in as it travels.
    /// Under Reduce Motion it fades in place.
    func present(at frame: CGRect) {
        let reduceMotion = Motion.systemReducesMotion
        var start = frame
        if !reduceMotion { start.origin.x += Self.travel }
        alphaValue = 0
        setFrame(start, display: false)
        orderFrontRegardless()
        isPresenting = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.15 : 0.26
            context.timingFunction = Motion.panelEnter
            animator().alphaValue = 1
            if !reduceMotion { animator().setFrame(frame, display: true) }
        }, completionHandler: { [weak self] in
            self?.isPresenting = false
        })
    }

    /// Returns the note to the edge it came from, then hides the panel.
    func dismiss(completion: @escaping () -> Void) {
        let reduceMotion = Motion.systemReducesMotion
        var end = frame
        end.origin.x += Self.travel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = reduceMotion ? 0.12 : 0.2
            context.timingFunction = Motion.panelExit
            animator().alphaValue = 0
            if !reduceMotion { animator().setFrame(end, display: true) }
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.alphaValue = 1
            completion()
        })
    }

    /// An explicit click anywhere in the editor is the one interaction that
    /// activates Notic. Hovering never reaches this path.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !NSApp.isActive {
            NSApp.activate()
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        onClose()
    }

    override func performClose(_ sender: Any?) {
        onClose()
    }

    /// Only a user-driven resize is recorded as the note's preferred size.
    /// Programmatic clamping to a smaller display must not overwrite it.
    func windowDidResize(_ notification: Notification) {
        guard inLiveResize else { return }
        onResize(frame.size)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        onLiveResizeEnded()
    }
}
