import Foundation
import Testing
import NoticCore

@Suite("Library search and filtering")
struct LibraryTests {
    private func populated() throws -> (WorkspaceFixture, NoticWorkspace, groceries: Note.ID, meeting: Note.ID, archived: Note.ID) {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let groceries = workspace.createNote()
        workspace.updateTitle(of: groceries, to: "Groceries")
        workspace.updateBody(of: groceries, to: "Milk, eggs, café beans")
        let meeting = workspace.createNote()
        workspace.updateTitle(of: meeting, to: "Standup")
        workspace.updateBody(of: meeting, to: "Ask about the milk budget")
        let archived = workspace.createNote()
        workspace.updateTitle(of: archived, to: "Old milk recipe")
        workspace.archive([archived])
        workspace.flushPendingChanges()
        return (fixture, workspace, groceries, meeting, archived)
    }

    @Test func `search matches titles and bodies case-insensitively`() throws {
        let (_, workspace, groceries, meeting, archived) = try populated()

        let results = workspace.libraryNotes(matching: "MILK", filter: .all).map(\.id)

        #expect(results.contains(groceries))
        #expect(results.contains(meeting))
        #expect(results.contains(archived))
        #expect(workspace.libraryNotes(matching: "cafe", filter: .all).map(\.id) == [groceries])
    }

    @Test func `filters narrow the library to active or archived notes`() throws {
        let (_, workspace, groceries, meeting, archived) = try populated()

        #expect(Set(workspace.libraryNotes(matching: "", filter: .active).map(\.id)) == [groceries, meeting])
        #expect(workspace.libraryNotes(matching: "", filter: .archived).map(\.id) == [archived])
        #expect(workspace.libraryNotes(matching: "milk", filter: .archived).map(\.id) == [archived])
    }

    @Test func `archiving then searching finds the note in the archive filter only`() throws {
        let (_, workspace, groceries, _, _) = try populated()

        workspace.archive([groceries])

        #expect(workspace.libraryNotes(matching: "groceries", filter: .active).isEmpty)
        #expect(workspace.libraryNotes(matching: "groceries", filter: .archived).map(\.id) == [groceries])
    }

    @Test func `a search with no matches is empty and notes pending deletion are hidden`() throws {
        let (_, workspace, groceries, _, _) = try populated()

        #expect(workspace.libraryNotes(matching: "zebra", filter: .all).isEmpty)

        workspace.delete([groceries])
        #expect(!workspace.libraryNotes(matching: "", filter: .all).map(\.id).contains(groceries))
    }

    @Test func `bulk archive, restore, and delete act on every selected note`() throws {
        let (_, workspace, groceries, meeting, archived) = try populated()

        workspace.archive([groceries, meeting])
        #expect(workspace.activeNotes.isEmpty)
        #expect(workspace.archivedNotes.count == 3)

        workspace.restore([groceries, archived])
        #expect(Set(workspace.activeNotes.map(\.id)) == [groceries, archived])

        workspace.delete([groceries, meeting, archived])
        #expect(workspace.pendingDeletions.count == 3)
        #expect(workspace.libraryNotes(matching: "", filter: .all).isEmpty)
    }
}
