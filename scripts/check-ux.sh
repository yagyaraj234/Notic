#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build --quiet
check_dir=$(mktemp -d "${TMPDIR:-/tmp/}notic-ux-check.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
cat > "$check_dir/main.swift" <<'SWIFT'
import AppKit
import SwiftUI
import NoticCore

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.finishLaunching()
// SwiftUI exposes its full accessibility tree when an accessibility client requests it.
app.perform(NSSelectorFromString("accessibilitySetValue:forAttribute:"), with: NSNumber(value: true), with: "AXEnhancedUserInterface")
let directory = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appending(path: "data")
defer { try? FileManager.default.removeItem(at: directory) }
let clock = TestScheduler(now: .now)
let workspace = try NoticWorkspace(directory: directory, scheduler: clock)
var created = false
let commands = AppCommands(newNote: { _ in created = true }, showLibrary: {}, showArchive: {}, toggleHidden: {}, showSettings: {}, quit: {})
let menus = NoticMenus(workspace: workspace, commands: commands)
let a = workspace.createNote(), b = workspace.createNote()
workspace.delete([a])
clock.advance(by: 2)
workspace.delete([b])
assert(DeletionCountdown.secondsRemaining(in: workspace.pendingDeletions, at: clock.now) == 8)
clock.advance(by: 8)
assert(workspace.note(a) == nil)
assert(DeletionCountdown.secondsRemaining(in: workspace.pendingDeletions, at: clock.now) == 2)
let menu = menus.quickMenu()
let undoIndex = menu.indexOfItem(withTitle: "Undo Delete")
assert(undoIndex >= 0)
menu.performActionForItem(at: undoIndex)
assert(workspace.note(b)?.lifecycle == .active)
assert(menus.quickMenu().indexOfItem(withTitle: "Undo Delete") == -1)
assert(DeletionCountdown.secondsRemaining(in: [], at: clock.now) == 0)
menus.failedShortcuts = [.newNote]
assert(menus.quickMenu().items.contains { $0.title.contains("⌥⌘N unavailable") && !$0.isEnabled })
let firstKeys = HotKeyCenter(), secondKeys = HotKeyCenter()
firstKeys.register(.newNote) {}
secondKeys.register(.newNote) {}
assert(!firstKeys.failedShortcuts.isEmpty || secondKeys.failedShortcuts == [.newNote])
firstKeys.unregisterAll(); secondKeys.unregisterAll()
print("PASS: independent deletion deadlines, menu Undo restores, unavailable shortcut fallback")

DispatchQueue.main.async {
    let model = LibraryModel()
    let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 860, height: 560), styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: LibraryView(workspace: workspace, model: model, commands: commands, openNote: { _ in }))
    window.contentView?.frame = NSRect(x: 0, y: 0, width: 860, height: 560)
    window.contentView?.layoutSubtreeIfNeeded()
    window.makeKeyAndOrderFront(nil)
    app.activate()
    func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.6)) }
    func attribute(_ node: NSObject, _ name: String) -> Any? {
        if node.responds(to: NSSelectorFromString(name)) { return node.value(forKey: name) }
        let legacy = NSSelectorFromString("accessibilityAttributeValue:")
        let attributes = ["accessibilityChildren": "AXChildren", "accessibilityIdentifier": "AXIdentifier", "accessibilityRole": "AXRole", "accessibilityLabel": "AXDescription"]
        guard node.responds(to: legacy), let attribute = attributes[name] else { return nil }
        return node.perform(legacy, with: attribute)?.takeUnretainedValue()
    }
    func nodes(_ node: Any, depth: Int = 0) -> [NSObject] {
        guard depth < 30, let accessible = node as? NSObject else { return [] }
        return [accessible] + ((attribute(accessible, "accessibilityChildren") as? [Any]) ?? []).flatMap { nodes($0, depth: depth + 1) }
    }
    func button(_ identifier: String) -> NSObject {
        settle()
        guard let button = nodes(window).first(where: { attribute($0, "accessibilityIdentifier") as? String == identifier }) else {
            print("Missing control: \(identifier)"); exit(1)
        }
        return button
    }
    func press(_ node: NSObject) -> Bool {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        guard node.responds(to: selector) else { return false }
        let action = unsafeBitCast(node.method(for: selector), to: (@convention(c) (AnyObject, Selector) -> Bool).self)
        return action(node, selector)
    }
    model.query = "no match"
    assert(press(button("notic.library.clearSearch")))
    settle(); assert(model.query.isEmpty)
    let c = workspace.createNote()
    workspace.archive([b])
    model.selection = [b, c]
    model.focused = c
    let archive = button("notic.library.archive"), restore = button("notic.library.restore")
    assert(attribute(archive, "accessibilityLabel") as? String == "Archive (1)")
    assert(attribute(restore, "accessibilityLabel") as? String == "Restore (1)")
    assert(press(restore))
    settle(); assert(workspace.note(b)?.lifecycle == .active)
    assert(workspace.note(c)?.lifecycle == .active)
    assert(press(button("notic.library.archive")))
    settle(); assert(workspace.note(b)?.lifecycle == .archived && workspace.note(c)?.lifecycle == .archived)
    model.selection = []
    model.filter = .active
    assert(press(button("notic.library.newNote")))
    assert(created)
    var taskBody = "- [ ] Ship"
    window.contentView = NSHostingView(rootView: NoteBodyEditor(text: taskBody, font: .systemFont(ofSize: 21), ink: .black, onChange: { taskBody = $0 }))
    assert(press(button("notic.task.0")))
    assert(taskBody == "- [x] Ship")
    window.close()
    print("PASS: hosted task checkbox is discoverable and toggles through accessibility")
    print("PASS: hosted library Clear search/New Note, mixed Archive/Restore counts and actions")
    exit(0)
}
app.run()
SWIFT
build_dir=$(swift build --show-bin-path)
app_sources=(${(f)"$(rg --files app/Notic/Sources -g '*.swift' | rg -v '/NoticApp.swift$')"})
swiftc -swift-version 6 -default-isolation MainActor \
  -enable-upcoming-feature NonisolatedNonsendingByDefault \
  -I "$build_dir/Modules" \
  "${app_sources[@]}" "$check_dir/main.swift" "$build_dir"/NoticCore.build/*.o \
  -o "$check_dir/check"
"$check_dir/check"
