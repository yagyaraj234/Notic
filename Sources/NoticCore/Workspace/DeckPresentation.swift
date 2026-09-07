import Foundation

/// Identifies one attached display. Wraps a `CGDirectDisplayID`.
public nonisolated struct DisplayID: Hashable, Sendable, Comparable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static func < (lhs: DisplayID, rhs: DisplayID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// What one display's edge is currently showing.
public nonisolated enum DeckState: Hashable, Sendable {
    /// Only the narrow pill is visible.
    case dormant
    /// The active deck is fanned out beside the pill.
    case fanned
    /// The deck is fanned and one note's editor is expanded beside it.
    case noteOpen(Note.ID)

    public var openNoteID: Note.ID? {
        if case let .noteOpen(id) = self { return id }
        return nil
    }
}

/// Per-display presentation bookkeeping owned by the workspace. It is a struct
/// so that writing it back into the workspace's dictionary publishes the
/// change; the timer handles it holds are deliberately shared cancel tokens.
struct DisplayPresentation {
    var state: DeckState = .dormant
    var pointerInside = false
    var expandWork: (any ScheduledWork)?
    var collapseWork: (any ScheduledWork)?

    mutating func cancelTimers() {
        expandWork?.cancel()
        expandWork = nil
        collapseWork?.cancel()
        collapseWork = nil
    }
}
