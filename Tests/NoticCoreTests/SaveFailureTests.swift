import Foundation
import Testing
import NoticCore

@Suite("Save failure and retry")
struct SaveFailureTests {
    @Test func `a failed save keeps content, reports the failure, and retries until it succeeds`() throws {
        let fixture = try WorkspaceFixture()
        let (workspace, store) = try fixture.launchWithFailableStore()
        let id = workspace.createNote()

        store.shouldFail = true
        workspace.updateBody(of: id, to: "Important thought")
        fixture.scheduler.advance(by: 0.25)

        #expect(workspace.saveState == .failed("Disk unavailable"))
        #expect(workspace.note(id)?.body == "Important thought")
        #expect(try fixture.launch().note(id)?.body == "")

        fixture.scheduler.advance(by: 2)
        #expect(workspace.saveState == .failed("Disk unavailable"))

        store.shouldFail = false
        fixture.scheduler.advance(by: 2)

        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().note(id)?.body == "Important thought")
    }

    @Test func `edits made while a save is failing are included in the retry`() throws {
        let fixture = try WorkspaceFixture()
        let (workspace, store) = try fixture.launchWithFailableStore()
        let id = workspace.createNote()

        store.shouldFail = true
        workspace.updateBody(of: id, to: "First")
        fixture.scheduler.advance(by: 0.25)
        workspace.updateBody(of: id, to: "First and second")
        store.shouldFail = false
        fixture.scheduler.advance(by: 2)

        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().note(id)?.body == "First and second")
    }
}
