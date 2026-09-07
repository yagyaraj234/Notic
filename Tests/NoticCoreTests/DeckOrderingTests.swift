import Foundation
import Testing
import NoticCore

@Suite("Deck ordering and overflow")
struct DeckOrderingTests {
    @Test func `dragging a note to a new position is kept across relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let c = workspace.createNote()
        let b = workspace.createNote()
        let a = workspace.createNote()
        #expect(workspace.activeNotes.map(\.id) == [a, b, c])

        workspace.moveActiveNote(c, toIndex: 0)
        #expect(workspace.activeNotes.map(\.id) == [c, a, b])

        workspace.moveActiveNote(a, toIndex: 2)
        #expect(workspace.activeNotes.map(\.id) == [c, b, a])

        #expect(try fixture.launch().activeNotes.map(\.id) == [c, b, a])
    }

    @Test func `a note created after reordering still goes first`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let b = workspace.createNote()
        let a = workspace.createNote()
        workspace.moveActiveNote(b, toIndex: 0)

        let newest = workspace.createNote()

        #expect(workspace.activeNotes.map(\.id) == [newest, b, a])
    }

    @Test func `the deck shows at most eight notes and counts the overflow`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        for _ in 1...8 { workspace.createNote() }
        #expect(workspace.deckNotes.count == 8)
        #expect(workspace.overflowCount == 0)

        let ninth = workspace.createNote()
        let tenth = workspace.createNote()
        let eleventh = workspace.createNote()

        #expect(workspace.deckNotes.count == 8)
        #expect(workspace.deckNotes.prefix(3).map(\.id) == [eleventh, tenth, ninth])
        #expect(workspace.overflowCount == 3)
    }

    @Test func `archiving a deck note lets an overflow note into the deck`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        var ids: [Note.ID] = []
        for _ in 1...9 { ids.append(workspace.createNote()) }
        let overflowed = ids[0]
        #expect(!workspace.deckNotes.map(\.id).contains(overflowed))

        workspace.archive([ids[8]])

        #expect(workspace.deckNotes.map(\.id).contains(overflowed))
        #expect(workspace.overflowCount == 0)
    }
}
