import AppKit
import SwiftUI

/// The borderless, non-activating panel that hosts the pill and fanned deck.
/// It never becomes key, so hovering and clicking cards cannot steal focus.
final class EdgePanel: NSPanel {
    init(content: some View, onPointerEntered: @escaping () -> Void, onPointerExited: @escaping () -> Void) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // The pill and deck always float: a utility the user cannot reach is
        // useless. The "Show above all apps" preference governs editors only.
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        setAccessibilityIdentifier("notic.edgePanel")

        let hosting = HoverTrackingHostingView(rootView: AnyView(content), onEntered: onPointerEntered, onExited: onPointerExited)
        hosting.sizingOptions = []
        contentView = hosting
    }

    /// The part of the screen the panel answers the pointer over: the dock's
    /// stripe while the deck rests, the whole deck once it is fanned. The
    /// panel itself is always the size of the fanned deck — resizing it as the
    /// deck fans raced the deck's own animation and clipped it mid-flight — so
    /// this is what keeps the rest of the panel out of the pointer's way.
    var interactiveFrame: CGRect = .zero {
        didSet {
            guard interactiveFrame != oldValue else { return }
            applyInteractiveFrame()
        }
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        // The rect is held in screen coordinates, so moving the panel moves it.
        applyInteractiveFrame()
    }

    private func applyInteractiveFrame() {
        guard !interactiveFrame.isEmpty, let hosting = contentView as? HoverTrackingHostingView else { return }
        hosting.interactiveRect = hosting.convert(convertFromScreen(interactiveFrame), from: nil)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosts SwiftUI content and reports pointer entry/exit even while Notic is
/// not the active application. Non-generic on purpose: the Swift 6.3 optimizer
/// crashes inlining the deinit of a generic `NSHostingView` subclass.
final class HoverTrackingHostingView: NSHostingView<AnyView> {
    private let onEntered: () -> Void
    private let onExited: () -> Void
    private var trackingArea: NSTrackingArea?

    init(rootView: AnyView, onEntered: @escaping () -> Void, onExited: @escaping () -> Void) {
        self.onEntered = onEntered
        self.onExited = onExited
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init(rootView: AnyView) {
        fatalError("Use init(rootView:onEntered:onExited:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    /// The panel is bigger than what it draws, so only this rect is Notic's.
    /// Everything else has to fall through to whatever is behind it.
    var interactiveRect: CGRect = .zero {
        didSet {
            guard interactiveRect != oldValue else { return }
            updateTrackingAreas()
        }
    }

    /// The panel is never key, so the first click must reach the cards directly.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    /// Points outside the interactive rect belong to the desktop, not to Notic.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveRect.contains(convert(point, from: superview)) else { return nil }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        // Not `.inVisibleRect`: the panel is the size of the fanned deck even
        // while the deck rests, and resting on the desktop 80pt from the edge
        // must not count as resting on the dock.
        let area = NSTrackingArea(
            rect: interactiveRect,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        // Ignore queued entries from the larger tracking area after collapse.
        guard interactiveRect.contains(convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)) else { return }
        onEntered()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onExited()
    }
}
