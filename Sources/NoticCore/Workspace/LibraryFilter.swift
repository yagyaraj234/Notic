import Foundation

/// Which notes the library window lists. Notes pending deletion are never shown.
public nonisolated enum LibraryFilter: String, CaseIterable, Sendable, Hashable {
    case all
    case active
    case archived

    func includes(_ lifecycle: NoteLifecycle) -> Bool {
        switch (self, lifecycle) {
        case (_, .pendingDeletion): false
        case (.all, _): true
        case (.active, .active): true
        case (.archived, .archived): true
        default: false
        }
    }
}
