import Foundation
import Testing
import NoticCore

@Suite("Note export")
struct NoteExportTests {
    private func note(_ title: String, _ body: String = "") -> Note {
        Note(title: title, body: body, createdAt: .now, modifiedAt: .now)
    }

    @Test func `each note becomes a Markdown file headed by its title`() {
        let files = NoteExport.files(for: [note("Groceries", "- [ ] Milk")])
        #expect(files.map(\.name) == ["Groceries.md"])
        #expect(files.first?.contents == "# Groceries\n\n- [ ] Milk\n")
    }

    @Test func `names are file-system safe and never collide`() {
        let files = NoteExport.files(
            for: [note("a/b: c"), note("A/B: C"), note(""), note("  "), note("Taken")],
            avoiding: ["taken.md"]
        )
        #expect(files.map(\.name) == ["a-b- c.md", "A-B- C 2.md", "Untitled.md", "Untitled 2.md", "Taken 2.md"])
        #expect(files[2].contents == "\n")
    }
}

@Suite("Note import")
struct NoteImportTests {
    @Test func `a heading becomes the title and the file name is the fallback`() {
        let titled = NoteImport.note(fileName: "x.md", contents: "# Plan\n\nBody\n")
        #expect(titled.title == "Plan" && titled.body == "Body")
        let plain = NoteImport.note(fileName: "Ideas.txt", contents: "just text\n")
        #expect(plain.title == "Ideas" && plain.body == "just text")
        #expect(NoteImport.note(fileName: "a.md", contents: "# Only title").body == "")
    }
}
