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

    @Test func `creating a note gives it a local timestamp and places it first in the active deck`() throws {
        let now = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 8, hour: 15, minute: 42)))
        let scheduler = TestScheduler(now: now)
        let workspace = try WorkspaceFixture(scheduler: scheduler).launch()

        let first = workspace.createNote()
        let second = workspace.createNote()

        #expect(workspace.activeNotes.map(\.id) == [second, first])
        let note = try #require(workspace.activeNotes.first)
        #expect(note.title == "8 Sep 2026 · 3:42 PM")
        #expect(note.body == "")
        #expect(note.color == .yellow)
        #expect(note.lifecycle == .active)
    }
}
