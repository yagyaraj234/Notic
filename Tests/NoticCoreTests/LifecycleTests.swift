import Foundation
import Testing
import NoticCore

@Suite("Archive, restore, and deletion")
struct LifecycleTests {
    @Test func `archiving removes a note from the deck and keeps it in the archive across relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let keep = workspace.createNote()
        let archived = workspace.createNote()

        workspace.archive([archived])

        #expect(workspace.activeNotes.map(\.id) == [keep])
        #expect(workspace.archivedNotes.map(\.id) == [archived])
        #expect(workspace.note(archived)?.lifecycle == .archived)

        let relaunched = try fixture.launch()
        #expect(relaunched.activeNotes.map(\.id) == [keep])
        #expect(relaunched.archivedNotes.map(\.id) == [archived])
    }

    @Test func `restoring an archived note returns it to the front of the deck`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let older = workspace.createNote()
        let newer = workspace.createNote()
        workspace.archive([older])

        workspace.restore([older])

        #expect(workspace.activeNotes.map(\.id) == [older, newer])
        #expect(workspace.archivedNotes.isEmpty)
    }

    @Test func `deleting a note can be undone within ten seconds`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.updateBody(of: id, to: "Keep me")
        workspace.flushPendingChanges()

        workspace.delete([id])

        #expect(workspace.activeNotes.isEmpty)
        #expect(workspace.pendingDeletions.map(\.id) == [id])

        fixture.scheduler.advance(by: 9.9)
        workspace.undoDelete([id])

        #expect(workspace.pendingDeletions.isEmpty)
        #expect(workspace.activeNotes.map(\.id) == [id])
        #expect(workspace.note(id)?.body == "Keep me")
        fixture.scheduler.advance(by: 60)
        #expect(try fixture.launch().activeNotes.map(\.id) == [id])
    }

    @Test func `undo puts an active note back in its previous deck position`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let c = workspace.createNote()
        let b = workspace.createNote()
        let a = workspace.createNote()

        workspace.delete([b])
        workspace.undoDelete([b])

        #expect(workspace.activeNotes.map(\.id) == [a, b, c])
    }

    @Test func `undo returns an archived note to the archive, not the deck`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.archive([id])

        workspace.delete([id])
        workspace.undoDelete([id])

        #expect(workspace.activeNotes.isEmpty)
        #expect(workspace.archivedNotes.map(\.id) == [id])
    }

    @Test func `a deletion is finalised once its window expires`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.delete([id])
        fixture.scheduler.advance(by: 10)

        #expect(workspace.pendingDeletions.isEmpty)
        #expect(workspace.note(id) == nil)
        #expect(try fixture.launch().note(id) == nil)
    }

    @Test func `a pending deletion survives relaunch and can still be undone`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.delete([id])
        fixture.scheduler.advance(by: 4)

        let relaunched = try fixture.launch()

        #expect(relaunched.pendingDeletions.map(\.id) == [id])
        relaunched.undoDelete([id])
        #expect(relaunched.activeNotes.map(\.id) == [id])
    }

    @Test func `a pending deletion whose deadline passed while quit is finalised at launch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.delete([id])

        // The clock moves on without the first workspace running its timers.
        let laterScheduler = TestScheduler(now: fixture.scheduler.now.addingTimeInterval(30))
        let relaunched = try NoticWorkspace(directory: fixture.directory, scheduler: laterScheduler)

        #expect(relaunched.pendingDeletions.isEmpty)
        #expect(relaunched.note(id) == nil)
        #expect(try fixture.launch().note(id) == nil)
    }

    @Test func `a pending deletion resumes its remaining time after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.delete([id])
        fixture.scheduler.advance(by: 4)

        let relaunched = try fixture.launch()
        fixture.scheduler.advance(by: 5.9)
        #expect(relaunched.pendingDeletions.map(\.id) == [id])

        fixture.scheduler.advance(by: 0.1)
        #expect(relaunched.pendingDeletions.isEmpty)
        #expect(relaunched.note(id) == nil)
    }
}
