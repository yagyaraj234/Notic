import Foundation
import Testing
import NoticCore

@Suite("Note colour and editor size")
struct NoteAppearanceTests {
    @Test(arguments: NoteColor.allCases)
    func `a note can take any palette colour and keeps it across relaunch`(color: NoteColor) throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.setColor(of: id, to: color)

        #expect(workspace.note(id)?.color == color)
        #expect(try fixture.launch().note(id)?.color == color)
    }

    @Test func `the palette keeps the five original colours first and adds three light ones`() {
        #expect(NoteColor.allCases == [.yellow, .coral, .mint, .blue, .lavender, .peach, .sage, .rose])
    }

    @Test func `new notes still default to yellow`() throws {
        let workspace = try WorkspaceFixture().launch()
        let id = workspace.createNote()

        #expect(workspace.note(id)?.color == .yellow)
    }

    @Test func `a new note opens at the default editor size`() throws {
        let workspace = try WorkspaceFixture().launch()
        let id = workspace.createNote()

        #expect(workspace.note(id)?.editorSize == CGSize(width: 580, height: 420))
    }

    @Test func `resizing is clamped to sensible bounds and restored after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        workspace.setEditorSize(of: id, to: CGSize(width: 700, height: 500))
        #expect(workspace.note(id)?.editorSize == CGSize(width: 700, height: 500))

        workspace.setEditorSize(of: id, to: CGSize(width: 10, height: 10))
        #expect(workspace.note(id)?.editorSize == CGSize(width: 320, height: 220))

        workspace.setEditorSize(of: id, to: CGSize(width: 9000, height: 9000))
        #expect(workspace.note(id)?.editorSize == CGSize(width: 1200, height: 900))

        workspace.setEditorSize(of: id, to: CGSize(width: 640, height: 480))
        fixture.scheduler.advance(by: 0.25)
        #expect(try fixture.launch().note(id)?.editorSize == CGSize(width: 640, height: 480))
    }

    @Test func `a dragged editor origin is restored after relaunch and can be cleared`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()

        #expect(workspace.note(id)?.editorOrigin == nil)

        workspace.setEditorOrigin(of: id, to: CGPoint(x: 420, y: 180))
        fixture.scheduler.advance(by: 0.25)
        #expect(try fixture.launch().note(id)?.editorOrigin == CGPoint(x: 420, y: 180))

        let again = try fixture.launch()
        again.setEditorOrigin(of: id, to: nil)
        again.flushPendingChanges()
        #expect(try fixture.launch().note(id)?.editorOrigin == nil)
    }

    @Test func `typing does not clear a placed editor origin`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        let id = workspace.createNote()
        workspace.setEditorOrigin(of: id, to: CGPoint(x: 300, y: 200))
        workspace.flushPendingChanges()

        workspace.updateBody(of: id, to: "still here")
        #expect(workspace.note(id)?.editorOrigin == CGPoint(x: 300, y: 200))

        fixture.scheduler.advance(by: 0.25)
        #expect(try fixture.launch().note(id)?.editorOrigin == CGPoint(x: 300, y: 200))
        #expect(try fixture.launch().note(id)?.body == "still here")
    }
}
