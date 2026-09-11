import Foundation
import Testing
import NoticCore

@Suite("Edge layout")
struct EdgeLayoutTests {
    @Test func `all stack edges anchor on offset displays and keep editors inside`() {
        let screen = CGRect(x: -1440, y: 80, width: 1440, height: 875)
        for edge in ScreenEdge.allCases {
            let layout = EdgeLayout(visibleFrame: screen, edge: edge)
            let pill = layout.pillFrame(noteCount: 4)
            let deck = layout.deckMetrics(noteCount: 4, hasOverflow: false, footerRows: 2)
            #expect(screen.contains(pill))
            #expect(screen.contains(deck.frame))
            switch edge {
            case .right:
                #expect(deck.frame.maxX == screen.maxX)
                #expect(pill.maxX == screen.maxX)
            case .left:
                #expect(deck.frame.minX == screen.minX)
                #expect(pill.minX == screen.minX)
            case .bottom:
                #expect(deck.frame.minY == screen.minY)
                #expect(pill.minY == screen.minY)
                #expect(deck.frame.midX == screen.midX)
                #expect(deck.frame.width > deck.frame.height)
            }
            for index in 0..<4 {
                let editor = layout.editorFrame(size: CGSize(width: 580, height: 420), tabIndex: index, deck: deck)
                #expect(screen.contains(editor))
                if edge == .left { #expect(editor.minX == deck.frame.maxX + EdgeLayout.screenMargin) }
                if edge == .bottom { #expect(editor.minY == deck.frame.maxY + EdgeLayout.screenMargin) }
                #expect(!editor.intersects(deck.frame))
            }
        }
    }

    @Test func `dragging selects all edges and clamps pill and deck together`() {
        let screen = CGRect(x: -1440, y: 80, width: 1440, height: 875)
        let initial = EdgeLayout(visibleFrame: screen)
        for (point, edge) in [
            (CGPoint(x: -1, y: 800), ScreenEdge.right),
            (CGPoint(x: -1439, y: 300), .left),
            (CGPoint(x: -600, y: 81), .bottom)
        ] {
            let docked = initial.docking(at: point)
            #expect(docked.edge == edge)
        }
        for edge in ScreenEdge.allCases {
            for position in [0.0, 0.2, 0.8, 1.0] {
                let moved = EdgeLayout(visibleFrame: screen, edge: edge, position: position)
                let deck = moved.deckFrame(noteCount: 8, hasOverflow: true, footerRows: 2)
                let pill = moved.pillFrame(noteCount: 8, hasOverflow: true, footerRows: 2)
                #expect(screen.contains(deck))
                #expect(screen.contains(pill))
                #expect(edge == .bottom ? pill.midX == deck.midX : pill.midY == deck.midY)
            }
        }
        let high = EdgeLayout(visibleFrame: screen, position: 0.8).deckFrame(noteCount: 3, hasOverflow: false)
        let low = EdgeLayout(visibleFrame: screen, position: 0.2).deckFrame(noteCount: 3, hasOverflow: false)
        #expect(high.midY > low.midY)
    }

    // A 1440x900 display with a 25pt menu bar, in AppKit coordinates.
    let layout = EdgeLayout(visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))

    @Test func `the pill hugs the right edge and is vertically centred`() {
        let pill = layout.pillFrame(noteCount: 4)

        #expect(pill.maxX == 1440)
        #expect(pill.midY == 437.5)
        #expect(pill.width == 1440 * 0.025)
        #expect(pill.height < 875)
    }

    @Test func `hover activation is confined to the outer two and a half percent`() {
        for width: CGFloat in [1280, 1440, 2560] {
            let screen = CGRect(x: -width, y: 80, width: width, height: 900)
            for edge in ScreenEdge.allCases {
                let pill = EdgeLayout(visibleFrame: screen, edge: edge).pillFrame(noteCount: 3)
                func point(depth: CGFloat) -> CGPoint {
                    switch edge {
                    case .right: CGPoint(x: screen.maxX - width * depth, y: pill.midY)
                    case .left: CGPoint(x: screen.minX + width * depth, y: pill.midY)
                    case .bottom: CGPoint(x: pill.midX, y: screen.minY + screen.height * depth)
                    }
                }
                #expect(pill.contains(point(depth: 0.02)))
                #expect(!pill.contains(point(depth: 0.03)))
                #expect(!pill.contains(point(depth: 0.08)))
            }
        }
    }

    @Test func `the pill grows one dash per note and never disappears`() {
        let empty = layout.pillFrame(noteCount: 0)
        let one = layout.pillFrame(noteCount: 1)
        let four = layout.pillFrame(noteCount: 4)

        #expect(empty.height == one.height)
        #expect(four.height - one.height == 3 * (EdgeLayout.pillDashHeight + EdgeLayout.pillDashSpacing))
    }

    @Test func `the fanned deck stays inside the visible frame`() {
        let deck = layout.deckFrame(noteCount: 8, hasOverflow: true)

        #expect(deck.maxX == 1440)
        #expect(deck.minY >= 0)
        #expect(deck.maxY <= 875)
        #expect(deck.height > layout.deckFrame(noteCount: 1, hasOverflow: false).height)
    }

    @Test func `tabs shingle at the preferred step when there is room`() {
        let metrics = layout.deckMetrics(noteCount: 4, hasOverflow: false)

        #expect(metrics.tileCount == 4)
        #expect(metrics.tabStep == EdgeLayout.preferredTabStep)
        // Four shingled tabs: three steps plus one full tab.
        #expect(metrics.tabsHeight == 3 * EdgeLayout.preferredTabStep + EdgeLayout.tabHeight)
    }

    @Test func `tabs overlap more tightly on a short display`() {
        let short = EdgeLayout(visibleFrame: CGRect(x: 0, y: 0, width: 1280, height: 400))

        let metrics = short.deckMetrics(noteCount: 8, hasOverflow: true)

        #expect(metrics.tileCount == 9)
        #expect(metrics.tabStep < EdgeLayout.preferredTabStep)
        #expect(metrics.tabStep >= EdgeLayout.minimumTabStep)
        #expect(metrics.frame.minY >= 0)
        #expect(metrics.frame.maxY <= 400)
    }

    @Test func `the editor opens level with its tab at its stored size`() {
        let metrics = layout.deckMetrics(noteCount: 3, hasOverflow: false)

        let editor = layout.editorFrame(size: CGSize(width: 580, height: 420), tabIndex: 1, deck: metrics)

        #expect(editor.size == CGSize(width: 580, height: 420))
        #expect(editor.maxX == metrics.frame.minX - EdgeLayout.screenMargin)
        // Its top edge lines up with the top of the second tab.
        #expect(editor.maxY == metrics.tabTop(at: 1))
        #expect(editor.minY >= 0)
    }

    @Test func `a live tab offset lines the editor up the same way a slot does`() {
        let metrics = layout.deckMetrics(noteCount: 3, hasOverflow: false)
        let size = CGSize(width: 580, height: 420)

        let slotted = layout.editorFrame(size: size, tabIndex: 1, deck: metrics)
        let dragged = layout.editorFrame(size: size, tabOffsetY: metrics.tabStep, deck: metrics)
        #expect(slotted == dragged)

        let between = layout.editorFrame(size: size, tabOffsetY: metrics.tabStep + 20, deck: metrics)
        #expect(between.maxY == metrics.frame.maxY - EdgeLayout.deckPadding - (metrics.tabStep + 20))
    }

    @Test func `an editor the user dragged stays where it was put, as long as that is on screen`() {
        let placed = layout.editorFrame(size: CGSize(width: 580, height: 420), placedAt: CGPoint(x: 200, y: 150))
        #expect(placed == CGRect(x: 200, y: 150, width: 580, height: 420))

        let offscreen = layout.editorFrame(size: CGSize(width: 580, height: 420), placedAt: CGPoint(x: -300, y: 2000))
        #expect(offscreen.size == CGSize(width: 580, height: 420))
        #expect(offscreen.minX == EdgeLayout.screenMargin)
        #expect(offscreen.maxY == 875 - EdgeLayout.screenMargin)
    }

    @Test func `a restored editor larger than the display is clamped into the visible frame`() {
        let small = EdgeLayout(visibleFrame: CGRect(x: 100, y: 50, width: 800, height: 500))
        let metrics = small.deckMetrics(noteCount: 2, hasOverflow: false)

        let editor = small.editorFrame(size: CGSize(width: 1200, height: 900), tabIndex: 1, deck: metrics)

        #expect(editor.minX >= 100)
        #expect(editor.maxX <= 900)
        #expect(editor.minY >= 50)
        #expect(editor.maxY <= 550)
    }

    @Test func `an off-screen frame is moved back inside the visible frame`() {
        let frame = CGRect(x: 2000, y: -300, width: 580, height: 420)

        let clamped = layout.clamped(frame)

        #expect(clamped.size == frame.size)
        #expect(clamped.maxX <= 1440)
        #expect(clamped.minY >= 0)
    }
}
