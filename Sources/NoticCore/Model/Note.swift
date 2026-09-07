import CoreGraphics
import Foundation

/// The note palette: the five original colours followed by three lighter
/// additions. Order is the order swatches are offered in.
public nonisolated enum NoteColor: String, CaseIterable, Codable, Sendable, Hashable {
    case yellow
    case coral
    case mint
    case blue
    case lavender
    case peach
    case sage
    case rose
}

/// Where a note lives. Closing an editor never changes this.
public nonisolated enum NoteLifecycle: Hashable, Sendable {
    case active
    case archived
    /// The note is scheduled for permanent removal at `deadline` unless the
    /// user undoes the deletion first. `restoreTo` is the state Undo returns to.
    case pendingDeletion(deadline: Date, restoreTo: RetainedState)

    public enum RetainedState: String, Codable, Sendable, Hashable {
        case active
        case archived
    }

    public var isPendingDeletion: Bool {
        if case .pendingDeletion = self { return true }
        return false
    }

    /// The state a deletion would restore to; `nil` once already pending.
    var retainedState: RetainedState? {
        switch self {
        case .active: .active
        case .archived: .archived
        case .pendingDeletion: nil
        }
    }
}

/// A persisted title/body record, exposed to callers as a value.
public nonisolated struct Note: Identifiable, Hashable, Sendable {
    public typealias ID = UUID

    public let id: ID
    public var title: String
    public var body: String
    public var color: NoteColor
    /// Manual deck position. Lower values are shown first.
    public var sortOrder: Int
    public var editorSize: CGSize
    /// Where the user last dragged this note's editor. `nil` means it opens
    /// level with its tab.
    public var editorOrigin: CGPoint?
    public let createdAt: Date
    public var modifiedAt: Date
    public var lifecycle: NoteLifecycle

    public init(
        id: ID = UUID(),
        title: String = "",
        body: String = "",
        color: NoteColor = .yellow,
        sortOrder: Int = 0,
        editorSize: CGSize = EditorSizing.defaultSize,
        editorOrigin: CGPoint? = nil,
        createdAt: Date,
        modifiedAt: Date,
        lifecycle: NoteLifecycle = .active
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.color = color
        self.sortOrder = sortOrder
        self.editorSize = editorSize
        self.editorOrigin = editorOrigin
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.lifecycle = lifecycle
    }
}

/// Bounds for an expanded note editor, in points.
public nonisolated enum EditorSizing {
    public static let defaultSize = CGSize(width: 580, height: 420)
    public static let minimumSize = CGSize(width: 320, height: 220)
    public static let maximumSize = CGSize(width: 1200, height: 900)

    /// Clamps a requested size into the allowed range.
    public static func clamped(_ size: CGSize) -> CGSize {
        CGSize(
            width: min(max(size.width, minimumSize.width), maximumSize.width),
            height: min(max(size.height, minimumSize.height), maximumSize.height)
        )
    }
}
