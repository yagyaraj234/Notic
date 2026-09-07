import Foundation
import Testing
import NoticCore

@Suite("Edge layout")
struct EdgeLayoutTests {
    // A 1440x900 display with a 25pt menu bar, in AppKit coordinates.
    let layout = EdgeLayout(visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))

    @Test func `the pill hugs the right edge and is vertically centred`() {
        let pill = layout.pillFrame(noteCount: 4)

        #expect(pill.maxX == 1440)
        #expect(pill.midY == 437.5)
        #expect(pill.width < 20)
        #expect(pill.height < 875)
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
        #expect(editor.maxX == 1440 - EdgeLayout.screenMargin)
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
