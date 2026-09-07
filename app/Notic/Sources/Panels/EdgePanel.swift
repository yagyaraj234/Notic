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

    /// The panel is never key, so the first click must reach the cards directly.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onEntered()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onExited()
    }
}
