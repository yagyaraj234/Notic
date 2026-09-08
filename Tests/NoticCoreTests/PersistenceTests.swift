import Foundation
import Testing
import NoticCore

@Suite("Persistence and relaunch")
struct PersistenceTests {
    @Test func `a created note is restored after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let first = try fixture.launch()
        let id = first.createNote()
        #expect(first.saveState == .saved)

        let relaunched = try fixture.launch()

        #expect(relaunched.activeNotes.map(\.id) == [id])
    }
    @Test func `changing folders preserves every note and sends future saves to the new library`() throws {
        let fixture = try WorkspaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let workspace = try fixture.launch()
        let active = workspace.createNote()
        let archived = workspace.createNote()
        workspace.archive([archived])
        let deleted = workspace.createNote()
        workspace.delete([deleted])
        workspace.updateBody(of: active, to: "Unsaved edit before moving")
        workspace.setColor(of: active, to: .mint)
        workspace.setEditorOrigin(of: active, to: CGPoint(x: 123, y: 456))
        let destination = fixture.directory.appending(path: "Chosen library")

        try workspace.relocateNotes(to: destination)

        let relaunched = try NoticWorkspace(directory: fixture.directory, notesDirectory: destination, scheduler: fixture.scheduler)
        for id in [active, archived, deleted] { #expect(relaunched.note(id) == workspace.note(id)) }
        #expect(relaunched.notesDirectory == destination)
        workspace.updateBody(of: active, to: "Saved in chosen folder")
        workspace.flushPendingChanges()
        let latest = try NoticWorkspace(directory: fixture.directory, notesDirectory: destination, scheduler: fixture.scheduler)
        #expect(latest.note(active)?.body == "Saved in chosen folder")
        #expect(try fixture.launch().note(active)?.body == "Unsaved edit before moving")
    }

    @Test func `an existing destination is never overwritten and the original remains writable`() throws {
        let fixture = try WorkspaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        #expect(throws: (any Error).self) { try workspace.relocateNotes(to: fixture.directory) }
        #expect(workspace.notesDirectory == fixture.directory)
        workspace.updateBody(of: id, to: "Still writable")
        workspace.flushPendingChanges()
        #expect(try fixture.launch().note(id)?.body == "Still writable")
    }

    @Test func `failed source save prevents a folder change`() throws {
        let fixture = try WorkspaceFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let (workspace, store) = try fixture.launchWithFailableStore()
        let id = workspace.createNote()
        store.shouldFail = true
        workspace.updateBody(of: id, to: "Keep this edit")
        let destination = fixture.directory.appending(path: "Chosen library")
        #expect(throws: (any Error).self) { try workspace.relocateNotes(to: destination) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(workspace.note(id)?.body == "Keep this edit")
        store.shouldFail = false
        workspace.flushPendingChanges()
        #expect(try fixture.launch().note(id)?.body == "Keep this edit")
    }
}
