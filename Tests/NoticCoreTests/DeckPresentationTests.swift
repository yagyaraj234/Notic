import Foundation
import Testing
import NoticCore

@Suite("Per-display deck presentation")
struct DeckPresentationTests {
    let main = DisplayID(rawValue: 1)
    let side = DisplayID(rawValue: 2)

    @Test func `an attached display starts dormant and fans out after the open delay of sustained hover`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()

        workspace.attachDisplay(main)
        #expect(workspace.attachedDisplays == [main])
        #expect(workspace.deckState(on: main) == .dormant)

        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: NoticTiming.hoverExpandDelay - 0.001)
        #expect(workspace.deckState(on: main) == .dormant)

        fixture.scheduler.advance(by: 0.001)
        #expect(workspace.deckState(on: main) == .fanned)
    }

    @Test func `clicking or activating the pill fans the deck without waiting`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)

        workspace.revealDeck(on: main)

        #expect(workspace.deckState(on: main) == .fanned)
        fixture.scheduler.advance(by: 1)
        #expect(workspace.deckState(on: main) == .fanned)
    }

    @Test func `a pointer that passes through before 120ms does not fan the deck`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)

        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: 0.05)
        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 1)

        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `the deck collapses 350ms after the pointer leaves unless it comes back`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: NoticTiming.hoverExpandDelay)

        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 0.349)
        #expect(workspace.deckState(on: main) == .fanned)

        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: 1)
        #expect(workspace.deckState(on: main) == .fanned)

        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 0.35)
        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `opening a note expands it and opening another replaces it on the same display`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let first = workspace.createNote()
        let second = workspace.createNote()

        workspace.openNote(first, on: main)
        #expect(workspace.deckState(on: main) == .noteOpen(first))

        workspace.updateBody(of: first, to: "typed before switching")
        workspace.openNote(second, on: main)

        #expect(workspace.deckState(on: main) == .noteOpen(second))
        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().note(first)?.body == "typed before switching")
    }

    @Test func `the pointer leaving does not collapse an open note`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let id = workspace.createNote()
        workspace.openNote(id, on: main)

        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 5)

        #expect(workspace.deckState(on: main) == .noteOpen(id))
    }

    @Test func `closing an editor flushes edits and never changes the note's lifecycle`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let id = workspace.createNote()
        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: NoticTiming.hoverExpandDelay)
        workspace.openNote(id, on: main)
        workspace.updateBody(of: id, to: "closing soon")

        workspace.closeEditor(on: main)

        #expect(workspace.deckState(on: main) == .fanned)
        #expect(workspace.saveState == .saved)
        #expect(workspace.note(id)?.lifecycle == .active)
        #expect(workspace.activeNotes.map(\.id) == [id])

        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 0.35)
        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `displays are independent but share one collection of notes`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        workspace.attachDisplay(side)
        let id = workspace.createNote()

        workspace.openNote(id, on: main)

        #expect(workspace.deckState(on: main) == .noteOpen(id))
        #expect(workspace.deckState(on: side) == .dormant)
        #expect(workspace.deckNotes.map(\.id) == [id])
    }

    @Test func `removing a display with an open note closes it safely and keeps the note`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        workspace.attachDisplay(side)
        let id = workspace.createNote()
        workspace.openNote(id, on: side)
        workspace.updateBody(of: id, to: "unplugged mid-sentence")

        workspace.detachDisplay(side)

        #expect(workspace.attachedDisplays == [main])
        #expect(workspace.deckState(on: side) == .dormant)
        #expect(workspace.saveState == .saved)
        #expect(workspace.note(id)?.lifecycle == .active)
        #expect(try fixture.launch().note(id)?.body == "unplugged mid-sentence")
    }

    @Test func `archiving an open note closes its editor and the deck collapses normally`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let archived = workspace.createNote()
        workspace.openNote(archived, on: main)

        workspace.archive([archived])

        #expect(workspace.deckState(on: main) == .fanned)
        fixture.scheduler.advance(by: 0.35)
        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `deleting an open note keeps the deck fanned so Undo stays reachable`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let deleted = workspace.createNote()
        workspace.createNote()
        workspace.openNote(deleted, on: main)

        workspace.delete([deleted])

        #expect(workspace.deckState(on: main) == .fanned)
        fixture.scheduler.advance(by: 5)
        #expect(workspace.deckState(on: main) == .fanned)

        workspace.undoDelete([deleted])
        fixture.scheduler.advance(by: 0.35)
        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `the deck collapses once a pending deletion is finalised`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let deleted = workspace.createNote()
        workspace.openNote(deleted, on: main)

        workspace.delete([deleted])
        fixture.scheduler.advance(by: 10)

        #expect(workspace.note(deleted) == nil)
        fixture.scheduler.advance(by: 0.35)
        #expect(workspace.deckState(on: main) == .dormant)
    }

    @Test func `hiding Notic is a toggle that leaves notes untouched`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        let id = workspace.createNote()
        #expect(!workspace.isHidden)

        workspace.toggleHidden()
        #expect(workspace.isHidden)
        #expect(workspace.activeNotes.map(\.id) == [id])

        workspace.toggleHidden()
        #expect(!workspace.isHidden)
    }

    @Test func `a longer open delay is honoured instead of the default`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.updateSettings { $0.openDelay = 0.3 }
        workspace.attachDisplay(main)

        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: 0.2)
        #expect(workspace.deckState(on: main) == .dormant)

        fixture.scheduler.advance(by: 0.1)
        #expect(workspace.deckState(on: main) == .fanned)
    }

    @Test func `with the fan trigger set to click, hovering never fans the deck`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.updateSettings { $0.fanTrigger = .click }
        workspace.attachDisplay(main)

        workspace.pointerEntered(main)
        fixture.scheduler.advance(by: 5)
        #expect(workspace.deckState(on: main) == .dormant)

        workspace.revealDeck(on: main)
        #expect(workspace.deckState(on: main) == .fanned)
    }

    @Test func `keeping the deck open starts a new display fanned and survives pointer exit`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.updateSettings { $0.keepsDeckOpen = true }

        workspace.attachDisplay(main)
        #expect(workspace.deckState(on: main) == .fanned)

        workspace.pointerEntered(main)
        workspace.pointerExited(main)
        fixture.scheduler.advance(by: 5)
        #expect(workspace.deckState(on: main) == .fanned)
    }

    @Test func `turning keep-the-deck-open on fans an open deck, and turning it off collapses it`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.attachDisplay(main)
        workspace.attachDisplay(side)
        #expect(workspace.deckState(on: main) == .dormant)

        workspace.updateSettings { $0.keepsDeckOpen = true }
        #expect(workspace.deckState(on: main) == .fanned)
        #expect(workspace.deckState(on: side) == .fanned)

        workspace.updateSettings { $0.keepsDeckOpen = false }
        fixture.scheduler.advance(by: 5)
        #expect(workspace.deckState(on: main) == .dormant)
        #expect(workspace.deckState(on: side) == .dormant)
    }

    @Test func `turning keep-the-deck-open off leaves an open editor alone`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        workspace.updateSettings { $0.keepsDeckOpen = true }
        workspace.attachDisplay(main)
        let id = workspace.createNote()
        workspace.openNote(id, on: main)

        workspace.updateSettings { $0.keepsDeckOpen = false }
        fixture.scheduler.advance(by: 5)

        #expect(workspace.deckState(on: main) == .noteOpen(id))
    }
}
