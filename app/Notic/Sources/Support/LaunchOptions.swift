import Foundation
import NoticCore

/// Command-line options used by the application accessibility tests to run
/// against clean or seeded local data. Normal launches pass none of these.
struct LaunchOptions {
    /// `-NoticDataDirectory <path>`: store notes here instead of the sandbox
    /// default. The path must be writable from inside the sandbox container.
    var dataDirectory: URL?
    /// `-NoticResetData`: delete the `-NoticDataDirectory` directory before
    /// opening it. Ignored without one.
    var resetsData = false
    /// `-NoticSeedNotes <count>`: create this many titled notes on launch.
    var seedNoteCount = 0
    /// `-NoticOpenSeededNote`: open the first seeded note on the primary display.
    var opensSeededNote = false
    /// `-NoticOpenSettings`: show the settings window on launch.
    var opensSettings = false

    init(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "-NoticDataDirectory":
                if let path = iterator.next() {
                    dataDirectory = URL(filePath: path, directoryHint: .isDirectory)
                }
            case "-NoticSeedNotes":
                if let value = iterator.next(), let count = Int(value) {
                    seedNoteCount = max(0, count)
                }
            case "-NoticResetData":
                resetsData = true
            case "-NoticOpenSeededNote":
                opensSeededNote = true
            case "-NoticOpenSettings":
                opensSettings = true
            default:
                continue
            }
        }
    }

    /// Resolves the directory to open, wiping it first when `-NoticResetData` is set.
    func resolveDataDirectory(default defaultDirectory: URL) -> URL {
        let directory = dataDirectory ?? defaultDirectory
        // Only a test directory may be wiped, never the user's real library.
        if resetsData, let dataDirectory {
            try? FileManager.default.removeItem(at: dataDirectory)
        }
        return directory
    }

    func seed(_ workspace: NoticWorkspace, displays: DisplayManager?) {
        guard seedNoteCount > 0 else { return }
        let colors = NoteColor.allCases
        var first: Note.ID?
        for index in 0..<seedNoteCount {
            let id = workspace.createNote()
            workspace.updateTitle(of: id, to: "Seeded note \(index + 1)")
            if index == 0 {
                workspace.updateBody(of: id, to: "- [ ] Milk\n- [x] Eggs\nBody of seeded note \(index + 1)")
            } else {
                workspace.updateBody(of: id, to: "Body of seeded note \(index + 1)")
            }
            workspace.setColor(of: id, to: colors[index % colors.count])
            first = first ?? id
        }
        workspace.flushPendingChanges()
        if opensSeededNote, let first, let display = displays?.primaryDisplay() {
            workspace.openNote(first, on: display)
        }
    }
}
