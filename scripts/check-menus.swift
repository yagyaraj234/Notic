import AppKit

// Run only against an isolated test instance, never the user's library.
// Launch: open -n /path/to/Debug/Notic.app --args -NoticDataDirectory <sandbox-test-directory> -NoticResetData -NoticSeedNotes 3
// Then: swift scripts/check-menus.swift
// Requires Accessibility and event-posting permission for the invoking terminal.
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.yagyaraj.notic").first!
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/ps")
process.arguments = ["-p", String(app.processIdentifier), "-o", "command="]
let pipe = Pipe()
process.standardOutput = pipe
try process.run()
let arguments = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
process.waitUntilExit()
precondition(arguments.contains("-NoticResetData") && arguments.contains("-NoticSeedNotes 3") && arguments.contains("-NoticDataDirectory"), "Launch an isolated seeded test instance first")
let root = AXUIElementCreateApplication(app.processIdentifier)
func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success else { return nil }
    return value
}
func string(_ e: AXUIElement, _ name: String) -> String { attr(e, name) as? String ?? "" }
func nodes(_ e: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 20 else { return [] }
    return [e] + ((attr(e, "AXChildren") as? [AXUIElement]) ?? []).flatMap { nodes($0, depth: depth + 1) }
}
func label(_ e: AXUIElement) -> String { ["AXTitle", "AXDescription", "AXHelp"].map { string(e, $0) }.first { !$0.isEmpty } ?? "" }
func frame(_ e: AXUIElement) -> CGRect {
    var p = CGPoint.zero, s = CGSize.zero
    if let v = attr(e, "AXPosition") { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(e, "AXSize") { AXValueGetValue(v as! AXValue, .cgSize, &s) }
    return CGRect(origin: p, size: s)
}

func wait(_ test: () -> Bool) { let end = Date().addingTimeInterval(10); while !test() && Date() < end { Thread.sleep(forTimeInterval: 0.1) }; assert(test()) }
func find(_ id: String) -> AXUIElement { var result: AXUIElement?; wait { result = nodes(root).first { string($0,"AXIdentifier") == id }; return result != nil }; return result! }
func titled(_ title: String) -> AXUIElement { var result: AXUIElement?; wait { result = nodes(root).first { label($0) == title }; return result != nil }; return result! }
func press(_ e: AXUIElement) { assert(AXUIElementPerformAction(e, kAXPressAction as CFString) == .success); Thread.sleep(forTimeInterval:0.7) }
// Opening a tracking menu may time out while it remains open; the selected
// menu item and resulting window are asserted separately.
func menu(_ title: String) { let status = find("notic.menuBar"); AXUIElementSetMessagingTimeout(status, 1); _ = AXUIElementPerformAction(status, kAXPressAction as CFString); press(titled(title)) }
func close(_ window: AXUIElement) { press(attr(window,kAXCloseButtonAttribute) as! AXUIElement) }
func key(_ code: CGKeyCode) { CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true)!.post(tap:.cghidEventTap); CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:false)!.post(tap:.cghidEventTap) }
precondition(AXIsProcessTrusted() && CGPreflightPostEventAccess(), "Terminal needs Accessibility and event-posting permission")
menu("All Notes…")
let library = titled("All Notes")
let search = find("notic.library.search")
app.activate()
Thread.sleep(forTimeInterval:0.7)
assert(AXUIElementSetAttributeValue(search,kAXFocusedAttribute as CFString,kCFBooleanTrue) == .success)
// Physical key input types "note 2" into the focused search field.
for code: CGKeyCode in [45,31,17,14,49,19] { key(code) }
wait { nodes(library).contains { string($0,"AXValue") == "Seeded note 2" } && !nodes(library).contains { string($0,"AXValue") == "Seeded note 1" } }
print("PASS: status menu opens library; typed search filters notes")
close(library)
menu("New Note")
let panel = find("notic.editorPanel")
let screen = NSScreen.main!
assert(abs(frame(panel).midX-screen.visibleFrame.midX)<2)
assert(abs(frame(panel).midY-(screen.frame.maxY-screen.visibleFrame.midY))<2)
let title = string(find("notic.editor.title"),"AXValue")
assert(title.range(of:#"^\d{1,2} [A-Z][a-z]{2} \d{4} · \d{1,2}:\d{2} (AM|PM)$"#,options:.regularExpression) != nil)
print("PASS: status menu new note opens centered with timestamp")
press(find("notic.closeEditor"))
menu("Settings…")
let settings = find("notic.settings")
for id in ["textSize","openDelay","fanTrigger","keepsDeckOpen","animationSpeed","launchAtLogin"] { _ = find("notic.settings." + id) }
press(find("notic.settings.pane.about"))
assert(label(find("notic.settings.version")).hasPrefix("Version") || string(find("notic.settings.version"),"AXValue").hasPrefix("Version"))
_ = find("notic.settings.byline")
press(find("notic.settings.pane.general"))
let keeps = find("notic.settings.keepsDeckOpen")
if (attr(keeps,"AXValue") as? NSNumber)?.boolValue != true { press(keeps) }
assert((attr(keeps,"AXValue") as? NSNumber)?.boolValue == true)
close(settings)
wait { nodes(root).contains { string($0,"AXIdentifier") == "notic.card.0" } && !nodes(root).contains { string($0,"AXIdentifier") == "notic.pill" } }
print("PASS: settings panes, controls, about; keep-open persists after window closes")
let card = find("notic.card.0")
let before = nodes(root).filter { string($0,"AXIdentifier").hasPrefix("notic.card.") }.count
let r = frame(card).intersection(CGRect(x:0,y:0,width:screen.frame.width,height:screen.frame.height))
let point = CGPoint(x:r.midX,y:r.minY+10)
CGEvent(mouseEventSource:nil,mouseType:.rightMouseDown,mouseCursorPosition:point,mouseButton:.right)!.post(tap:.cghidEventTap)
CGEvent(mouseEventSource:nil,mouseType:.rightMouseUp,mouseCursorPosition:point,mouseButton:.right)!.post(tap:.cghidEventTap)
press(titled("Duplicate"))
wait { nodes(root).filter { string($0,"AXIdentifier").hasPrefix("notic.card.") }.count == before+1 }
print("PASS: card context menu duplicate adds exactly one card")
