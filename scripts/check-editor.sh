#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --quiet
check_dir=$(mktemp -d "${TMPDIR:-/tmp/}notic-editor-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
cat > "$check_dir/main.swift" <<'SWIFT'
import AppKit
import SwiftUI
import NoticCore

let app = NSApplication.shared
let window = EditorPanel(noteID: UUID(), content: EmptyView(), onResize: { _ in }, onLiveResizeEnded: {}, onMove: { _ in }, onClose: {})
let scroll = NoteBodyEditor.BodyScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
let body = NoteBodyEditor.BodyTextView(frame: .zero)
body.isRichText = false
body.allowsUndo = true
body.isVerticallyResizable = true
body.autoresizingMask = [.width]
scroll.documentView = body
window.contentView = scroll
scroll.tile()
assert(body.frame.height >= scroll.contentSize.height)
window.makeFirstResponder(body)
assert(window.firstResponder === body)
var posted = ""
let coordinator = NoteBodyEditor.Coordinator { posted = $0 }
coordinator.textView = body
body.delegate = coordinator
body.onToggle = { coordinator.toggle(at: $0) }
coordinator.apply(text: "hello", font: .systemFont(ofSize: 21), ink: .black, notify: false)
let undo = body.undoManager!
undo.groupsByEvent = false
func edit(_ work: () -> Void) { undo.beginUndoGrouping(); work(); undo.endUndoGrouping() }
body.setSelectedRange(NSRange(location: 5, length: 0))
edit { body.insertText(" world", replacementRange: body.selectedRange()) }
assert(posted == "hello world")
undo.undo(); assert(body.string == "hello" && posted == "hello")
undo.redo(); assert(body.string == "hello world")
edit { body.insertText(" again", replacementRange: body.selectedRange()) }
assert(body.string == "hello world again")
edit { coordinator.insertTask() }
let task = body.string
assert(task.contains("- [ ]"))
undo.undo(); assert(body.string == "hello world again")
undo.redo(); assert(body.string == task)
edit { coordinator.toggle(at: 0) }
assert(body.string.contains("- [x]"))
undo.undo(); assert(body.string == task)
undo.redo(); assert(body.string.contains("- [x]"))
undo.removeAllActions()
coordinator.apply(text: "", font: .systemFont(ofSize: 21), ink: .black, notify: false)
edit { body.insertText("[] ", replacementRange: NSRange(location: 0, length: 0)) }
assert(body.string == "- [ ] ")
undo.undo(); assert(body.string.isEmpty)
undo.redo(); assert(body.string == "- [ ] ")
print("PASS: blank-area sizing, focus, typing undo/redo, task insertion/toggle, shorthand undo/redo")

func key(_ modifiers: NSEvent.ModifierFlags) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                    timestamp: 0, windowNumber: window.windowNumber, context: nil,
                    characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6)!
}
undo.removeAllActions()
coordinator.apply(text: "", font: .systemFont(ofSize: 21), ink: .black, notify: false)
edit { body.insertText("routing", replacementRange: NSRange(location: 0, length: 0)) }
assert(window.performKeyEquivalent(with: key([.command, .capsLock])))
assert(body.string.isEmpty)
assert(window.performKeyEquivalent(with: key([.command, .shift, .capsLock])))
assert(body.string == "routing")
window.sendEvent(key(.command))
assert(body.string.isEmpty)
window.sendEvent(key([.command, .shift]))
assert(body.string == "routing")
print("PASS: panel key equivalents, Caps Lock, direct key-event undo/redo")
coordinator.apply(text: "- [ ] Buy milk\n- [x] Call home", font: .systemFont(ofSize: 21), ink: .black, notify: false)
let boxes = body.accessibilityChildren()!.compactMap { $0 as? NoteBodyEditor.BodyTextView.TaskCheckbox }
assert(boxes.count == 2)
assert(boxes[0].accessibilityLabel() == "Buy milk")
assert((boxes[0].accessibilityValue() as? Int) == 0)
assert((boxes[1].accessibilityValue() as? Int) == 1)
edit { assert(boxes[0].accessibilityPerformPress()) }
assert(body.string.hasPrefix("- [x] Buy milk"))
assert((boxes[0].accessibilityValue() as? Int) == 1)
undo.undo(); assert(body.string.hasPrefix("- [ ] Buy milk"))
body.setSelectedRange(NSRange(location: 8, length: 0))
let toggleKey = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
    timestamp: 0, windowNumber: window.windowNumber, context: nil,
    characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
edit { window.sendEvent(toggleKey) }
assert(body.string.hasPrefix("- [x] Buy milk"))
coordinator.apply(text: "plain text", font: .systemFont(ofSize: 21), ink: .black, notify: false)
assert(body.accessibilityChildren()!.compactMap { $0 as? NoteBodyEditor.BodyTextView.TaskCheckbox }.isEmpty)
assert(!boxes[0].accessibilityPerformPress())
edit { window.sendEvent(toggleKey) }
assert(body.string == "plain text")
print("PASS: accessible task labels/state/press/undo, Command-Return, stale control and plain-line safety")
SWIFT
build_dir=$(swift build --show-bin-path)
swiftc -swift-version 6 -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -I "$build_dir/Modules" \
  app/Notic/Sources/Views/NoteBodyEditor.swift \
  app/Notic/Sources/Panels/EditorPanel.swift \
  app/Notic/Sources/Views/Motion.swift \
  "$check_dir/main.swift" "$build_dir"/NoticCore.build/*.o \
  -o "$check_dir/check"
"$check_dir/check"
