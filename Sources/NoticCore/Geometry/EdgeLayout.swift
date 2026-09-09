import CoreGraphics
import Foundation

/// The screen edge Notic docks to.
public nonisolated enum ScreenEdge: String, Codable, CaseIterable, Sendable {
    case right
    case left
    case bottom
}

/// Frame arithmetic for one display, in AppKit (bottom-left origin) coordinates.
///
/// The deck has three shapes. Dormant, it is a thin stripe holding one dash
/// per note. Fanned, the notes shingle down the edge as colour tabs that
/// overlap like roof tiles, with an add button beneath. Open, one note slides
/// out level with its own tab.
public nonisolated struct EdgeLayout: Sendable {
    public let visibleFrame: CGRect
    public let edge: ScreenEdge

    // Pill
    /// Width of the drawn stripe.
    public static let pillWidth: CGFloat = 12
    /// Width reserved for the pill's button and artwork.
    public static let pillHitWidth: CGFloat = 16
    public static let pillDashHeight: CGFloat = 22
    public static let pillDashSpacing: CGFloat = 6
    public static let pillPadding: CGFloat = 7

    // Fanned deck
    /// Visible width of a tab. Tabs run off the screen edge, so only their
    /// left portion (label and perforation) is seen.
    public static let tabWidth: CGFloat = 64
    public static let tabHeight: CGFloat = 128
    /// Vertical distance between the tops of neighbouring tabs when there is room.
    public static let preferredTabStep: CGFloat = 72
    /// Tightest the shingle is allowed to get on a short display.
    public static let minimumTabStep: CGFloat = 30
    public static let addButtonSize: CGFloat = 36
    public static let addButtonGap: CGFloat = 14
    /// Room for the first-run prompt when the deck has no tabs.
    public static let emptyPromptHeight: CGFloat = 44
    /// Padding inside the panel; also leaves room for tab shadows.
    public static let deckPadding: CGFloat = 16
    /// Width of the panel that hosts the fanned deck (tabs plus shadow room).
    public static let deckWidth: CGFloat = tabWidth + 40
    public static let screenMargin: CGFloat = 8

    public init(visibleFrame: CGRect, edge: ScreenEdge = .right) {
        self.visibleFrame = visibleFrame
        self.edge = edge
    }

    public var activationDepth: CGFloat {
        (edge == .bottom ? visibleFrame.height : visibleFrame.width) * 0.025
    }

    /// The dormant pill's pointer target, hugging the edge and vertically
    /// centred. An empty deck still shows a single placeholder dash.
    public func pillFrame(noteCount: Int) -> CGRect {
        let hitDepth = activationDepth
        let dashes = CGFloat(max(1, noteCount))
        let height = Self.pillPadding * 2
            + dashes * Self.pillDashHeight
            + (dashes - 1) * Self.pillDashSpacing
        if edge == .bottom {
            return CGRect(x: visibleFrame.midX - height / 2, y: visibleFrame.minY,
                          width: height, height: hitDepth)
        }
        return CGRect(
            x: edge == .left ? visibleFrame.minX : visibleFrame.maxX - hitDepth,
            y: visibleFrame.midY - height / 2,
            width: hitDepth,
            height: height
        )
    }

    /// Resolved geometry of a fanned deck: the panel frame and the shingle
    /// step the tabs are laid out with.
    public struct DeckMetrics: Sendable, Equatable {
        public let frame: CGRect
        public let tileCount: Int
        public let tabStep: CGFloat

        /// Height of the shingled tab stack.
        public var tabsHeight: CGFloat {
            guard tileCount > 0 else { return 0 }
            return CGFloat(tileCount - 1) * tabStep + EdgeLayout.tabHeight
        }

        /// AppKit y-coordinate of the top edge of the tab at `index`.
        public func tabTop(at index: Int) -> CGFloat {
            frame.maxY - EdgeLayout.deckPadding - CGFloat(index) * tabStep
        }
    }

    /// Height of one status row (Undo, save warning) shown under the add button.
    public static let footerRowHeight: CGFloat = 32

    /// Lays out the fanned deck for the given number of visible cards,
    /// vertically centred and kept inside the visible frame. When the
    /// preferred shingle does not fit, tabs overlap more tightly.
    /// `footerRows` counts transient status rows beneath the add button.
    public func deckMetrics(noteCount: Int, hasOverflow: Bool, footerRows: Int = 0) -> DeckMetrics {
        let tiles = noteCount + (hasOverflow ? 1 : 0)
        let available = (edge == .bottom ? visibleFrame.width : visibleFrame.height) - Self.screenMargin * 2
        let fixed = Self.deckPadding * 2 + Self.addButtonGap + Self.addButtonSize
            + CGFloat(footerRows) * Self.footerRowHeight

        let step: CGFloat
        let tabsHeight: CGFloat
        if tiles == 0 {
            step = Self.preferredTabStep
            tabsHeight = Self.emptyPromptHeight
        } else {
            let room = available - fixed - Self.tabHeight
            let fitted = tiles > 1 ? room / CGFloat(tiles - 1) : Self.preferredTabStep
            step = min(Self.preferredTabStep, max(Self.minimumTabStep, fitted))
            tabsHeight = CGFloat(tiles - 1) * step + Self.tabHeight
        }

        let height = min(fixed + tabsHeight, available)
        var frame = CGRect(
            x: visibleFrame.maxX - Self.deckWidth,
            y: visibleFrame.midY - height / 2,
            width: Self.deckWidth,
            height: height
        )
        // The deck keeps hugging the edge; only its vertical position is clamped.
        frame.origin.y = clamped(frame).origin.y
        if edge == .left {
            frame.origin.x = visibleFrame.minX
        } else if edge == .bottom {
            frame = CGRect(x: visibleFrame.midX - height / 2, y: visibleFrame.minY,
                           width: height, height: Self.deckWidth)
        }
        return DeckMetrics(frame: frame, tileCount: tiles, tabStep: step)
    }

    /// The fanned deck's panel frame.
    public func deckFrame(noteCount: Int, hasOverflow: Bool, footerRows: Int = 0) -> CGRect {
        deckMetrics(noteCount: noteCount, hasOverflow: hasOverflow, footerRows: footerRows).frame
    }

    /// Where an expanded editor of `size` sits: pulled out of the deck level
    /// with its own tab, flush to the edge, shrunk and shifted as needed to
    /// stay on screen.
    public func editorFrame(size: CGSize, tabIndex: Int, deck: DeckMetrics) -> CGRect {
        editorFrame(size: size, tabOffsetY: CGFloat(max(0, tabIndex)) * deck.tabStep, deck: deck)
    }

    /// Same as `editorFrame(size:tabIndex:deck:)`, but the tab's top is
    /// `tabOffsetY` points below the top of the stack — used while a tab is
    /// dragged so a docked editor can stay level with it.
    public func editorFrame(size: CGSize, tabOffsetY: CGFloat, deck: DeckMetrics) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        let fitted = CGSize(
            width: min(size.width, max(bounds.width, EditorSizing.minimumSize.width)),
            height: min(size.height, max(bounds.height, EditorSizing.minimumSize.height))
        )
        let top = deck.frame.maxY - Self.deckPadding - tabOffsetY
        let frame = CGRect(
            x: edge == .bottom ? deck.frame.maxX - Self.deckPadding - tabOffsetY - fitted.width
                : edge == .left ? bounds.minX : bounds.maxX - fitted.width,
            y: edge == .bottom ? bounds.minY : top - fitted.height,
            width: fitted.width,
            height: fitted.height
        )
        return clamped(frame)
    }

    /// Where an editor the user dragged sits: at `origin` with `size`, shrunk
    /// to the display if needed and shifted back on screen if the display
    /// changed underneath it.
    public func editorFrame(size: CGSize, placedAt origin: CGPoint) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        let fitted = CGSize(
            width: min(size.width, max(bounds.width, EditorSizing.minimumSize.width)),
            height: min(size.height, max(bounds.height, EditorSizing.minimumSize.height))
        )
        return clamped(CGRect(origin: origin, size: fitted))
    }

    /// Shifts `frame` so it lies within the visible frame (inset by the screen
    /// margin) without changing its size.
    public func clamped(_ frame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: Self.screenMargin, dy: Self.screenMargin)
        var result = frame
        if result.maxX > bounds.maxX { result.origin.x = bounds.maxX - result.width }
        if result.minX < bounds.minX { result.origin.x = bounds.minX }
        if result.maxY > bounds.maxY { result.origin.y = bounds.maxY - result.height }
        if result.minY < bounds.minY { result.origin.y = bounds.minY }
        return result
    }
}
