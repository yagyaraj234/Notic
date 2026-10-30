import AppKit
import NoticCore
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

    var dragsPill = true
    var stackDragFrame: CGRect = .zero
    var onStackPress: (() -> Void)?
    var onStackDrag: ((CGPoint, Bool) -> Void)?
    var onStackRelease: (() -> Void)?
    var onPillClick: (() -> Void)?
    private var pressPoint: CGPoint?
    private var pressEvent: NSEvent?
    private var movedStack = false
    var isTrackingStack: Bool { pressPoint != nil }

    override func sendEvent(_ event: NSEvent) {
        let point = convertPoint(toScreen: event.locationInWindow)
        if event.type == .leftMouseDown, event.modifierFlags.intersection([.control, .option]).isEmpty,
           (dragsPill ? interactiveFrame : stackDragFrame).contains(point) {
            pressPoint = point
            pressEvent = event
            movedStack = false
            onStackPress?()
            return
        }
        if let start = pressPoint {
            if event.type == .leftMouseDragged {
                if hypot(point.x - start.x, point.y - start.y) >= 8 { movedStack = true }
                if movedStack { onStackDrag?(NSEvent.mouseLocation, false) }
                return
            }
            if event.type == .leftMouseUp {
                let moved = movedStack
                if moved { onStackDrag?(NSEvent.mouseLocation, true) }
                else if dragsPill { onPillClick?() }
                else if let pressEvent {
                    super.sendEvent(pressEvent)
                    super.sendEvent(event)
                }
                pressPoint = nil
                pressEvent = nil
                // A drop has already rested the deck; re-reading the pointer
                // would fan it again from under the landed stack.
                if !moved { onStackRelease?() }
                return
            }
            if event.type == .mouseEntered || event.type == .mouseExited { return }
        }
        super.sendEvent(event)
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
        guard (window as? EdgePanel)?.isTrackingStack != true else { return }
        super.mouseEntered(with: event)
        // Ignore queued entries from the larger tracking area after collapse.
        guard interactiveRect.contains(convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)) else { return }
        onEntered()
    }

    override func mouseExited(with event: NSEvent) {
        guard (window as? EdgePanel)?.isTrackingStack != true else { return }
        super.mouseExited(with: event)
        // Moving the panel can queue exits from its old tracking area.
        guard !interactiveRect.contains(convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)) else { return }
        onExited()
    }
}

/// Shown only while the stack is dragged: a spider web on every edge the deck
/// can dock to, grey, with the one it will land on turned the accent colour and tied by a
/// thread of silk to the stack, drawn as one card under the pointer.
/// Click-through, so the drag is never interrupted.
final class DropZonePanel: NSPanel {
    private let hosting = NSHostingView(rootView: DropZoneView(target: .right, pointer: .zero, card: nil, seed: 0))
    /// Respun for every drag, so no two webs look alike.
    private var seed = 0.0

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        hosting.sizingOptions = []
        contentView = hosting
    }

    /// Covers `visibleFrame` beneath `panel`, highlighting `target` and
    /// threading it to `pointer`, in screen coordinates.
    func show(_ target: ScreenEdge, over visibleFrame: CGRect, pointer: CGPoint, card: DragCard, below panel: NSWindow) {
        if !isVisible { seed = .random(in: 0..<1000) }
        flights += 1
        let local = CGPoint(x: pointer.x - visibleFrame.minX, y: visibleFrame.maxY - pointer.y)
        hosting.rootView = DropZoneView(target: target, pointer: local, card: card, seed: seed)
        if frame != visibleFrame { setFrame(visibleFrame, display: true) }
        collectionBehavior = panel.collectionBehavior
        // No fade in: the card stands in for the stack the moment it hides.
        // Also cancels a fade out still running from the last drop.
        if alphaValue < 1 { fade(to: 1, duration: 0) }
        if !isVisible { order(.below, relativeTo: panel.windowNumber) }
    }

    /// Ends the drag: the card flies into the stack at `dock` (screen
    /// coordinates) while the webs fade, then `completion` brings the stack
    /// back so it never shows twice. Reduced motion skips the flight.
    func dismiss(landingAt dock: CGPoint, then completion: @escaping () -> Void) {
        let view = hosting.rootView
        guard isVisible, view.card != nil, !Motion.systemReducesMotion else {
            hosting.rootView = DropZoneView(target: view.target, pointer: view.pointer, card: nil, seed: view.seed)
            completion()
            fade(to: 0) { [weak self] in
                // A new drag may have started while this one faded out.
                if self?.alphaValue == 0 { self?.orderOut(nil) }
            }
            return
        }
        let local = CGPoint(x: dock.x - frame.minX, y: frame.maxY - dock.y)
        hosting.rootView = DropZoneView(target: view.target, pointer: view.pointer, card: view.card, seed: view.seed, landing: local)
        let flight = flights
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.landDuration) { [weak self] in
            // A new drag that began mid-flight owns the panel now.
            guard let self, self.flights == flight else { return }
            self.orderOut(nil)
            completion()
        }
    }

    /// Bumped by every `show`, so a landing that was interrupted never finishes.
    private var flights = 0

    private func fade(to alpha: CGFloat, duration: TimeInterval = Motion.scaled(0.16), then completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Motion.systemReducesMotion ? 0 : duration
            context.timingFunction = Motion.panelExit
            animator().alphaValue = alpha
        }, completionHandler: completion)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct DropZoneView: View {
    let target: ScreenEdge
    /// Where the stack is held, in the view's own top-left coordinates.
    let pointer: CGPoint
    let card: DragCard?
    let seed: Double
    /// Where the card is flying to on release; `nil` while it is held.
    var landing: CGPoint?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(ScreenEdge.allCases, id: \.self) { edge in
                let active = edge == target
                ZStack {
                    let web = Web(edge: edge, seed: seed + Double(ScreenEdge.allCases.firstIndex(of: edge)!) * 17)
                    web.stroke(Color.gray.opacity(0.4), lineWidth: 0.75)
                    web.stroke(Color.accentColor, lineWidth: 1.2)
                        .opacity(active ? 1 : 0)
                }
                .scaleEffect(active ? 1.02 : 1, anchor: Self.anchor(edge))
                // Only the webs ease; the card and thread track the pointer 1:1.
                .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: Motion.scaled(0.16)), value: target)
            }
            .opacity(landing == nil ? 1 : 0)
            if let card {
                if landing == nil {
                    GeometryReader { proxy in
                        Silk(from: Web.hub(of: target, in: CGRect(origin: .zero, size: proxy.size)), to: pointer)
                            .stroke(Color.accentColor.opacity(0.7), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    }
                }
                DragCardView(card: card)
                    .scaleEffect(landing == nil ? 1 : 0.5)
                    .opacity(landing == nil ? 1 : 0)
                    .position(landing ?? pointer)
            }
        }
        // Eases only the release; a drag resuming mid-flight snaps back under the pointer.
        .animation(landing == nil ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: Motion.landDuration), value: landing)
        .accessibilityHidden(true)
    }

    private static func anchor(_ edge: ScreenEdge) -> UnitPoint {
        switch edge {
        case .left: .leading
        case .right: .trailing
        case .bottom: .bottom
        }
    }
}

/// A half spider web spun out from the middle of one screen edge: wide along
/// the edge, shallow into the screen, and uneven, differently for every seed.
private nonisolated struct Web: Shape {
    let edge: ScreenEdge
    let seed: Double

    /// The web's centre: the middle of its edge.
    static func hub(of edge: ScreenEdge, in rect: CGRect) -> CGPoint {
        switch edge {
        case .left: CGPoint(x: rect.minX, y: rect.midY)
        case .right: CGPoint(x: rect.maxX, y: rect.midY)
        case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
        }
    }

    /// A repeatable 0..<1 value for `i` under this seed.
    private func random(_ i: Double) -> Double {
        let x = sin(seed * 12.9898 + i * 78.233) * 43758.5453
        return x - x.rounded(.down)
    }

    func path(in rect: CGRect) -> Path {
        let hub = Self.hub(of: edge, in: rect)
        let start: Double = switch edge {
        case .left: -.pi / 2
        case .right: .pi / 2
        case .bottom: .pi
        }
        let spokes = 8 + Int(random(1) * 5)
        let rings = 5 + Int(random(2) * 3)
        let along = (edge == .bottom ? rect.width : rect.height) * (0.1 + 0.05 * random(3))
        let depth = min(120, along * (0.45 + 0.15 * random(4)))
        let (rx, ry) = edge == .bottom ? (along, depth) : (depth, along)
        // Each spoke gets its own angle and reach, so it reads as spun, not drawn.
        let angles = (0..<spokes).map { i in
            start + .pi * (0.1 + 0.8 * (Double(i) + 0.7 * (random(Double(10 + i)) - 0.5)) / Double(spokes - 1))
        }
        let reach = (0..<spokes).map { 0.8 + 0.35 * random(Double(40 + $0)) }
        func point(_ spoke: Int, _ r: Double) -> CGPoint {
            let i = min(max(spoke, 0), spokes - 1)
            let a = min(max(angles[i], start), start + .pi)
            return CGPoint(x: hub.x + cos(a) * r * rx, y: hub.y + sin(a) * r * ry)
        }

        var path = Path()
        for spoke in 0..<spokes {
            path.move(to: hub)
            path.addLine(to: point(spoke, reach[spoke] * 1.1))
        }
        for ring in 1...rings {
            let base = Double(ring) / Double(rings)
            let r = { (spoke: Int) in min(reach[spoke], base * (0.88 + 0.24 * random(Double(100 + ring * 20 + spoke)))) }
            path.move(to: point(0, r(0)))
            for spoke in 1..<spokes {
                let a = point(spoke - 1, r(spoke - 1)), b = point(spoke, r(spoke))
                // Now and then a thread has snapped.
                guard random(Double(300 + ring * 20 + spoke)) > 0.06 else { path.move(to: b); continue }
                // Threads sag toward the hub.
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let sag = 0.08 + 0.15 * random(Double(500 + ring * 20 + spoke))
                path.addQuadCurve(to: b, control: CGPoint(x: mid.x + (hub.x - mid.x) * sag, y: mid.y + (hub.y - mid.y) * sag))
            }
        }
        return path
    }
}

/// A single thread from the web to the stack, sagging under its own weight.
private nonisolated struct Silk: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        let sag = min(80, hypot(to.x - from.x, to.y - from.y) * 0.2)
        var path = Path()
        path.move(to: from)
        path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 + sag))
        return path
    }
}

/// What the dragged stack shows: its front note.
struct DragCard {
    let title: String
    let swatch: NotePalette.Swatch
    let count: Int
}

private struct DragCardView: View {
    let card: DragCard

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text(card.title.isEmpty ? "UNTITLED" : card.title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(1.6)
                .lineLimit(4)
                .foregroundStyle(card.swatch.foreground.opacity(0.62))
            Spacer(minLength: 0)
            if card.count > 1 {
                Text("\(card.count) notes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(card.swatch.foreground.opacity(0.5))
            }
        }
        .padding(12)
        .frame(width: 120, height: 120, alignment: .topLeading)
        .background(shape.fill(card.swatch.background).shadow(color: .black.opacity(0.2), radius: 12, y: 6))
        .overlay(shape.strokeBorder(card.swatch.border.opacity(0.5), lineWidth: 0.5))
        .rotationEffect(.degrees(-3))
    }
}
