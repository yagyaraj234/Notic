import Foundation

/// Notes as standalone Markdown files, so they can leave Notic.
public nonisolated enum NoteExport {
    /// A `.md` file per note: the title as a heading, then the body as typed.
    /// Names are made safe for the file system and unique within the batch;
    /// `taken` lists names already present where the files will be written.
    public static func files(for notes: [Note], avoiding taken: Set<String> = []) -> [(name: String, contents: String)] {
        var used = Set(taken.map { $0.lowercased() })
        return notes.map { note in
            let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let stem = String(
                (title.isEmpty ? "Untitled" : title)
                    .map { "/:\\\n\r".contains($0) ? "-" : $0 }
                    .prefix(100)
            ).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            var name = (stem.isEmpty ? "Untitled" : stem) + ".md"
            var counter = 2
            while used.contains(name.lowercased()) {
                name = "\(stem.isEmpty ? "Untitled" : stem) \(counter).md"
                counter += 1
            }
            used.insert(name.lowercased())
            let contents = title.isEmpty ? note.body : "# \(title)\n\n\(note.body)"
            return (name, contents.hasSuffix("\n") ? contents : contents + "\n")
        }
    }
}
