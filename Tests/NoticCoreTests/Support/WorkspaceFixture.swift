import Foundation
import NoticCore

/// Builds workspaces against a real temporary SwiftData store so tests observe
/// the same persistence behaviour the app does.
struct WorkspaceFixture {
    let directory: URL
    let scheduler: TestScheduler

    init(scheduler: TestScheduler = TestScheduler()) throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "notic-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.scheduler = scheduler
    }

    /// Opens a workspace on the fixture's store. Call again to simulate a relaunch.
    func launch() throws -> NoticWorkspace {
        try NoticWorkspace(directory: directory, scheduler: scheduler)
    }
}
