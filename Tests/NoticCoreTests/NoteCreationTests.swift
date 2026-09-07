import Foundation
import Testing
import NoticCore

@Suite("Note creation")
struct NoteCreationTests {
    @Test func `a new workspace has no notes`() throws {
        let workspace = try WorkspaceFixture().launch()

        #expect(workspace.activeNotes.isEmpty)
        #expect(workspace.archivedNotes.isEmpty)
    }

    @Test func `creating a note places an empty yellow note first in the active deck`() throws {
        let workspace = try WorkspaceFixture().launch()

        let first = workspace.createNote()
        let second = workspace.createNote()

        #expect(workspace.activeNotes.map(\.id) == [second, first])
        let note = try #require(workspace.activeNotes.first)
        #expect(note.title == "")
        #expect(note.body == "")
        #expect(note.color == .yellow)
        #expect(note.lifecycle == .active)
    }
}
