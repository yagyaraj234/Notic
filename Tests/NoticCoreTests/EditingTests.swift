import Foundation
import Testing
import NoticCore

@Suite("Editing and autosave")
struct EditingTests {
    @Test func `edits appear immediately and are saved 250ms after typing stops`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.updateTitle(of: id, to: "Groceries")
        workspace.updateBody(of: id, to: "Milk\nEggs")

        #expect(workspace.note(id)?.title == "Groceries")
        #expect(workspace.note(id)?.body == "Milk\nEggs")
        #expect(workspace.saveState == .unsaved)

        fixture.scheduler.advance(by: 0.249)
        #expect(workspace.saveState == .unsaved)

        fixture.scheduler.advance(by: 0.001)
        #expect(workspace.saveState == .saved)

        let relaunched = try fixture.launch()
        #expect(relaunched.note(id)?.title == "Groceries")
        #expect(relaunched.note(id)?.body == "Milk\nEggs")
    }

    @Test func `continued typing postpones the autosave`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.updateBody(of: id, to: "M")
        fixture.scheduler.advance(by: 0.2)
        workspace.updateBody(of: id, to: "Mi")
        fixture.scheduler.advance(by: 0.2)

        #expect(workspace.saveState == .unsaved)
        #expect(try fixture.launch().note(id)?.body == "")

        fixture.scheduler.advance(by: 0.05)
        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().note(id)?.body == "Mi")
    }

    @Test func `flushing pending edits writes them before the debounce elapses`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.updateBody(of: id, to: "Call the bank")
        workspace.flushPendingChanges()

        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().note(id)?.body == "Call the bank")
    }

    @Test func `editing marks the note as modified without changing its creation date`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        let created = try #require(workspace.note(id))

        fixture.scheduler.advance(by: 60)
        workspace.updateTitle(of: id, to: "Later")

        let edited = try #require(workspace.note(id))
        #expect(edited.createdAt == created.createdAt)
        #expect(edited.modifiedAt == created.modifiedAt.addingTimeInterval(60))
    }
}
