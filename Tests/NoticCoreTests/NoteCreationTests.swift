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

    @Test func `a duplicate copies the note and lands directly after its original`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let third = workspace.createNote()
        let original = workspace.createNote()
        let first = workspace.createNote()
        workspace.updateBody(of: original, to: "milk, eggs")
        workspace.setColor(of: original, to: .mint)

        let copy = try #require(workspace.duplicateNote(original))

        #expect(workspace.activeNotes.map(\.id) == [first, original, copy, third])
        let duplicate = try #require(workspace.note(copy))
        let source = try #require(workspace.note(original))
        #expect(duplicate.body == "milk, eggs")
        #expect(duplicate.color == .mint)
        #expect(duplicate.title == source.title + " copy")
        #expect(duplicate.editorSize == source.editorSize)
        #expect(duplicate.editorOrigin == nil)
        #expect(duplicate.lifecycle == .active)
    }

    @Test func `editing a duplicate leaves its original untouched`() throws {
        let workspace = try WorkspaceFixture().launch()
        let original = workspace.createNote()
        workspace.updateBody(of: original, to: "original")
        let copy = try #require(workspace.duplicateNote(original))

        workspace.updateBody(of: copy, to: "changed")
        workspace.setColor(of: copy, to: .rose)

        #expect(workspace.note(original)?.body == "original")
        #expect(workspace.note(original)?.color == .yellow)
    }

    @Test func `duplicating an archived note produces another archived note`() throws {
        let workspace = try WorkspaceFixture().launch()
        let original = workspace.createNote()
        workspace.archive([original])

        let copy = try #require(workspace.duplicateNote(original))

        #expect(workspace.note(copy)?.lifecycle == .archived)
        #expect(workspace.activeNotes.isEmpty)
        #expect(workspace.archivedNotes.count == 2)
    }

    @Test func `a note pending deletion cannot be duplicated`() throws {
        let workspace = try WorkspaceFixture().launch()
        let original = workspace.createNote()
        workspace.delete([original])

        #expect(workspace.duplicateNote(original) == nil)
        #expect(workspace.duplicateNote(UUID()) == nil)
    }

    @Test func `a duplicate keeps its position after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let last = workspace.createNote()
        let original = workspace.createNote()
        let copy = try #require(workspace.duplicateNote(original))

        let relaunched = try fixture.launch()
        #expect(relaunched.activeNotes.map(\.id) == [original, copy, last])
    }
}
