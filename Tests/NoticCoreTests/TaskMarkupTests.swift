import Foundation
import Testing
import NoticCore

@Suite("Task markup")
struct TaskMarkupTests {
    @Test func `a line starting with a markdown task box is a task`() {
        let text = "- [ ] Milk\n- [x] Eggs\n  - [X] Indented\nPlain"

        let milk = TaskMarkup.marker(onLineContaining: 8, in: text)
        #expect(milk?.range == 0..<6)
        #expect(milk?.isChecked == false)

        let eggs = TaskMarkup.marker(onLineContaining: 11, in: text)
        #expect(eggs?.range == 11..<17)
        #expect(eggs?.isChecked == true)

        // Indentation is allowed; the marker range excludes it.
        let indented = TaskMarkup.marker(onLineContaining: 25, in: text)
        #expect(indented?.range == 24..<30)
        #expect(indented?.isChecked == true)

        #expect(TaskMarkup.marker(onLineContaining: 40, in: text) == nil)
        #expect(TaskMarkup.marker(onLineContaining: 0, in: "Not - [ ] a task") == nil)
    }

    @Test func `toggling flips the box on that line only`() {
        let text = "- [ ] Milk\n- [x] Eggs"

        #expect(TaskMarkup.toggling(lineContaining: 8, in: text) == "- [x] Milk\n- [x] Eggs")
        #expect(TaskMarkup.toggling(lineContaining: 14, in: text) == "- [ ] Milk\n- [ ] Eggs")
        #expect(TaskMarkup.toggling(lineContaining: 3, in: "Plain") == "Plain")
    }

    @Test func `a line can be made into a task or back into plain text`() {
        #expect(TaskMarkup.settingTask(true, onLineContaining: 2, in: "Milk") == "- [ ] Milk")
        #expect(TaskMarkup.settingTask(true, onLineContaining: 8, in: "- [x] Milk") == "- [x] Milk")
        #expect(TaskMarkup.settingTask(false, onLineContaining: 8, in: "- [x] Milk") == "Milk")
        #expect(TaskMarkup.settingTask(false, onLineContaining: 2, in: "Milk") == "Milk")
        #expect(TaskMarkup.settingTask(true, onLineContaining: 6, in: "One\nTwo") == "One\n- [ ] Two")
    }

    @Test func `typed shorthands become the canonical marker and the cursor follows`() {
        let typed = TaskMarkup.canonicalized("[] Milk", cursor: 3)
        #expect(typed.text == "- [ ] Milk")
        #expect(typed.cursor == 6)

        #expect(TaskMarkup.canonicalized("[x] Eggs", cursor: 8).text == "- [x] Eggs")
        #expect(TaskMarkup.canonicalized("* [ ] Eggs", cursor: 10).text == "- [ ] Eggs")
        #expect(TaskMarkup.canonicalized("[ ] Eggs", cursor: 4) == (text: "- [ ] Eggs", cursor: 6))

        // Only at the start of a line, and only once the trailing space is typed.
        #expect(TaskMarkup.canonicalized("Buy [] milk", cursor: 11) == (text: "Buy [] milk", cursor: 11))
        #expect(TaskMarkup.canonicalized("[]", cursor: 2) == (text: "[]", cursor: 2))

        // A shorthand after the cursor does not move it; one before it does.
        #expect(TaskMarkup.canonicalized("a\n[] b", cursor: 1) == (text: "a\n- [ ] b", cursor: 1))
        #expect(TaskMarkup.canonicalized("[] a\nb", cursor: 6) == (text: "- [ ] a\nb", cursor: 9))

        // Already canonical text is untouched.
        #expect(TaskMarkup.canonicalized("- [ ] Milk", cursor: 10) == (text: "- [ ] Milk", cursor: 10))
    }

    @Test func `Return continues a task list and ends it on an empty item`() {
        // At the end of an item: a new unchecked item, even after a checked one.
        #expect(TaskMarkup.newline(at: 10, in: "- [ ] Milk") == TaskMarkup.Edit(replace: 10..<10, with: "\n- [ ] "))
        #expect(TaskMarkup.newline(at: 10, in: "- [x] Milk") == TaskMarkup.Edit(replace: 10..<10, with: "\n- [ ] "))

        // Mid-item: the rest of the line moves to the new item.
        #expect(TaskMarkup.newline(at: 8, in: "- [ ] Milk") == TaskMarkup.Edit(replace: 8..<8, with: "\n- [ ] "))

        // An empty item ends the list: the marker goes away instead.
        #expect(TaskMarkup.newline(at: 6, in: "- [ ] ") == TaskMarkup.Edit(replace: 0..<6, with: ""))
        #expect(TaskMarkup.newline(at: 17, in: "- [ ] Milk\n- [ ] ") == TaskMarkup.Edit(replace: 11..<17, with: ""))

        // Plain lines get the default behaviour.
        #expect(TaskMarkup.newline(at: 5, in: "Plain") == nil)
    }

    @Test func `previews show boxes instead of markers and count progress`() {
        let text = "- [ ] Milk\n- [x] Eggs\nNote"

        #expect(TaskMarkup.preview(text) == "☐ Milk\n☑ Eggs\nNote")
        #expect(TaskMarkup.progress(in: text) == TaskMarkup.Progress(done: 1, total: 2))
        #expect(TaskMarkup.progress(in: "Plain") == nil)
    }

    @Test func `inserting a task turns the current line into one or adds another after it`() {
        #expect(TaskMarkup.insertingTask(at: 0, in: "") == (text: "- [ ] ", cursor: 6))
        #expect(TaskMarkup.insertingTask(at: 4, in: "Milk") == (text: "- [ ] Milk", cursor: 6))
        #expect(TaskMarkup.insertingTask(at: 6, in: "One\nTwo") == (text: "One\n- [ ] Two", cursor: 10))

        let afterItem = TaskMarkup.insertingTask(at: 8, in: "- [ ] Milk")
        #expect(afterItem.text == "- [ ] Milk\n- [ ] ")
        #expect(afterItem.cursor == 17)
    }
}
