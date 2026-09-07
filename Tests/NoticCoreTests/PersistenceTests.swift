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
}
