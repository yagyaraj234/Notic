import Foundation

/// Externally visible persistence status. `.saved` is only reported after the
/// store confirms the write.
public nonisolated enum SaveState: Equatable, Sendable {
    /// Everything is on disk.
    case saved
    /// Edits exist in memory that the autosave debounce has not flushed yet.
    case unsaved
    /// The last write failed. Content is retained in memory and a retry is scheduled.
    case failed(String)
}
