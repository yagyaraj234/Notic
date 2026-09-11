import AppKit
import XCTest

/// Application accessibility seam: launches the built app against clean local
/// data and drives it through its accessible UI and system-visible behaviour.
///
/// Requires macOS automation permission for the Xcode test runner. Run from
/// Xcode (Product ▸ Test) or `xcodebuild -scheme Notic test`.
final class NoticUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
    }

    /// Launches Notic with a fresh store inside its sandbox container.
    private func launch(seeding count: Int = 0, openingFirst: Bool = false, openingSettings: Bool = false) {
        app = XCUIApplication()
        if let screen = NSScreen.main {
            CGWarpMouseCursorPosition(CGPoint(x: screen.frame.midX, y: screen.frame.height / 2))
        }
        // NSHomeDirectory points inside the test runner's own sandbox.
        let home = String(cString: getpwuid(getuid())!.pointee.pw_dir)
        let container = home + "/Library/Containers/com.yagyaraj.notic/Data/tmp/uitests"
        app.launchArguments = ["-NoticDataDirectory", container, "-NoticResetData"]
        if count > 0 {
            app.launchArguments += ["-NoticSeedNotes", String(count)]
        }
        if openingFirst {
            app.launchArguments.append("-NoticOpenSeededNote")
        }
        if openingSettings {
            app.launchArguments.append("-NoticOpenSettings")
        }
        app.launch()
    }

    private var pill: XCUIElement { app.buttons["notic.pill"] }
    private var deck: XCUIElement { app.descendants(matching: .any)["notic.deck"] }
    private var editorBody: XCUIElement { app.textViews["notic.editor.body"] }

    // Drive screen coordinates through the app already in front. Targeting a
    // background Notic element directly makes XCTest activate it before the event.
    private func pointer(at point: CGPoint) -> XCUICoordinate {
        let foreground = NSWorkspace.shared.frontmostApplication!.bundleIdentifier!
        let driver = XCUIApplication(bundleIdentifier: foreground)
        // Application frames can be infinite (accessory apps) or change as
        // Finder windows move. The menu bar gives a stable screen anchor.
        let origin = driver.menuBars.firstMatch.coordinate(withNormalizedOffset: .zero)
        XCTAssertTrue(origin.screenPoint.x.isFinite && origin.screenPoint.y.isFinite)
        return origin.withOffset(CGVector(dx: point.x - origin.screenPoint.x, dy: point.y - origin.screenPoint.y))
    }

    private func movePointer(to point: CGPoint) {
        pointer(at: point).hover()
    }

    private func click(_ element: XCUIElement, at offset: CGVector = CGVector(dx: 0.5, dy: 0.5), button: CGMouseButton = .left) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        let screen = NSScreen.main!.frame
        let bounds = CGRect(x: screen.minX, y: NSScreen.screens[0].frame.maxY - screen.maxY, width: screen.width, height: screen.height)
        let visible = element.frame.intersection(bounds)
        XCTAssertFalse(visible.isNull || visible.isEmpty, "Cannot click an off-screen element")
        let point = CGPoint(x: visible.minX + visible.width * offset.dx, y: visible.minY + visible.height * offset.dy)
        if button == .right { pointer(at: point).rightClick() }
        else { pointer(at: point).click() }
    }

    private func hoverPill() {
        movePointer(to: CGPoint(x: pill.frame.midX, y: pill.frame.midY))
    }

    private func type(_ text: String) {
        for character in text { app.typeKey(String(character), modifierFlags: []) }
    }

    private func assertEditorIsCentered(file: StaticString = #filePath, line: UInt = #line) {
        let panel = app.descendants(matching: .any)["notic.editorPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3), file: file, line: line)
        guard let screen = NSScreen.main else {
            XCTFail("Main screen is unavailable", file: file, line: line)
            return
        }
        let expected = CGPoint(
            x: screen.visibleFrame.midX,
            y: screen.frame.maxY - screen.visibleFrame.midY
        )
        XCTAssertEqual(panel.frame.midX, expected.x, accuracy: 2, file: file, line: line)
        XCTAssertEqual(panel.frame.midY, expected.y, accuracy: 2, file: file, line: line)
    }

    private func assertEditorHasTimestampTitle(file: StaticString = #filePath, line: UInt = #line) {
        let title = app.textFields["notic.editor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), file: file, line: line)
        let value = title.value as? String ?? ""
        XCTAssertNotEqual(value, "Untitled note", file: file, line: line)
        XCTAssertNotNil(
            value.range(of: #"^\d{1,2} [A-Z][a-z]{2} \d{4} · \d{1,2}:\d{2} (AM|PM)$"#, options: .regularExpression),
            "Unexpected generated title: \(value)",
            file: file,
            line: line
        )
    }

    // MARK: Edge pill and focus safety

    func testLaunchStaysInBackgroundAndShowsThePill() {
        launch()

        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5), "A menu-bar utility must not become frontmost on launch")
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertEqual(pill.label, "Notic notes")
    }

    func testHoveringThePillFansTheDeckWithoutActivatingNotic() {
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))

        hoverPill()

        XCTAssertTrue(deck.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["notic.card.0"].exists)
        XCTAssertEqual(app.state, .runningBackground, "Hovering must never activate Notic")
    }

    func testHoverActivationRequiresTheOuterTwoAndAHalfPercent() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        CGWarpMouseCursorPosition(CGPoint(x: screen.frame.midX, y: screen.frame.height / 2))
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        let anchor = pill.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        let card = app.buttons["notic.card.0"]
        for depth in [0.08, 0.03] {
            anchor.withOffset(CGVector(dx: -screen.visibleFrame.width * depth, dy: 0)).hover()
            XCTAssertFalse(card.waitForExistence(timeout: 1))
        }
        anchor.withOffset(CGVector(dx: -screen.visibleFrame.width * 0.02, dy: 0)).hover()
        XCTAssertTrue(card.waitForExistence(timeout: 3))
    }

    func testFirstRunPromptAppearsUntilANoteExists() {
        launch()
        XCTAssertTrue(pill.waitForExistence(timeout: 5))

        hoverPill()

        XCTAssertTrue(app.staticTexts["notic.firstNotePrompt"].waitForExistence(timeout: 3))
        click(app.buttons["notic.newNote"])
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        assertEditorIsCentered()
        assertEditorHasTimestampTitle()
        XCTAssertFalse(app.staticTexts["notic.firstNotePrompt"].exists)
    }

    func testBlankBodyClickAndUndoRedoShortcuts() {
        launch(seeding: 1, openingFirst: true)
        XCTAssertTrue(editorBody.waitForExistence(timeout: 5))
        let original = editorBody.value as? String ?? ""
        click(editorBody, at: CGVector(dx: 0.7, dy: 0.85))
        type(" caret check")
        let edited = original + " caret check"
        XCTAssertEqual(editorBody.value as? String, edited)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(editorBody.value as? String, original)
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(editorBody.value as? String, edited)
        // Reproduce typing after redo before converting the line to a task.
        click(editorBody, at: CGVector(dx: 0.7, dy: 0.85))
        type(" more")
        let beforeTask = edited + " more"
        XCTAssertEqual(editorBody.value as? String, beforeTask)
        app.buttons["notic.editor.addTask"].click()
        let task = editorBody.value as? String
        XCTAssertNotEqual(task, beforeTask)
        app.typeKey("z", modifierFlags: .command)
        XCTAssertEqual(editorBody.value as? String, beforeTask)
        app.typeKey("z", modifierFlags: [.command, .shift])
        XCTAssertEqual(editorBody.value as? String, task)
    }

    // MARK: Opening, editing, closing

    func testClickingACardOpensItsEditorAndOnlyAnEditorClickActivatesNotic() {
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 3))
        hoverPill()
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))

        click(app.buttons["notic.card.0"], at: CGVector(dx: 0.5, dy: 0.1))

        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningBackground, "Opening a note from the deck must not activate Notic")

        click(editorBody)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3), "Clicking into the editor activates Notic")

        type(" appended")
        XCTAssertTrue((editorBody.value as? String)?.hasSuffix(" appended") == true)
        XCTAssertFalse(app.staticTexts["notic.saveState.saved"].exists)
        XCTAssertFalse(app.staticTexts["notic.saveState.unsaved"].exists)
    }

    func testClosingAnEditorKeepsTheNoteInTheDeck() {
        launch(seeding: 2, openingFirst: true)
        XCTAssertTrue(editorBody.waitForExistence(timeout: 5))

        app.buttons["notic.closeEditor"].click()

        XCTAssertFalse(editorBody.waitForExistence(timeout: 1))
        hoverPill()
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["notic.card.1"].exists)
    }

    func testKeyboardCloseAndEscapeAllowImmediateReopening() {
        launch(seeding: 1, openingFirst: true)
        XCTAssertTrue(editorBody.waitForExistence(timeout: 5))
        click(editorBody)
        app.typeKey("w", modifierFlags: .command)
        XCTAssertFalse(editorBody.exists)
        app.typeKey("n", modifierFlags: [.option, .command])
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        XCTAssertFalse(editorBody.exists)
        app.typeKey("n", modifierFlags: [.option, .command])
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
    }

    func testEditorActionsStayOnOneRowAndPinToggles() {
        launch(seeding: 1, openingFirst: true)
        XCTAssertTrue(editorBody.waitForExistence(timeout: 5))

        let addTask = app.buttons["notic.editor.addTask"]
        let delete = app.buttons["notic.editor.delete"]
        let pin = app.buttons["notic.editor.pin"]
        XCTAssertTrue(addTask.exists)
        XCTAssertTrue(delete.exists)
        XCTAssertFalse(app.buttons["notic.editor.archive"].exists)
        XCTAssertEqual(addTask.frame.midY, delete.frame.midY, accuracy: 1)
        XCTAssertEqual(pin.value as? String, "Not pinned")

        click(pin)

        XCTAssertEqual(pin.value as? String, "Pinned")
    }

    // MARK: Overflow and library

    func testMoreThanEightNotesShowsAnOverflowTileThatOpensTheLibrary() {
        launch(seeding: 10)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        hoverPill()

        let overflow = app.buttons["notic.overflow"]
        XCTAssertTrue(overflow.waitForExistence(timeout: 3))
        XCTAssertEqual(overflow.label, "2 more notes")
        XCTAssertFalse(app.buttons["notic.card.8"].exists)

        overflow.click()
        XCTAssertTrue(app.windows["All Notes"].waitForExistence(timeout: 3))
    }

    func testMenuBarOpensTheLibraryAndSearchFiltersNotes() {
        launch(seeding: 3)
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        statusItem.click()
        click(app.menuItems["All Notes…"])

        let library = app.windows["All Notes"]
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        let search = library.textFields["notic.library.search"]
        search.click()
        type("note 2")
        XCTAssertTrue(library.staticTexts["Seeded note 2"].waitForExistence(timeout: 2))
        XCTAssertFalse(library.staticTexts["Seeded note 1"].exists)
    }

    func testGlobalShortcutCreatesANoteFromAnotherApplication() {
        launch()
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 3))

        // Typed into another application so the global hot key, not a menu
        // key equivalent, must deliver the command.
        let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: 3))
        finder.typeKey("n", modifierFlags: [.option, .command])

        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        assertEditorIsCentered()
        assertEditorHasTimestampTitle()
    }

    func testMenuBarNewNoteOpensCenteredWithATimestampTitle() {
        launch()
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))

        statusItem.click()
        click(app.menuItems["New Note"])

        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        assertEditorIsCentered()
        assertEditorHasTimestampTitle()
    }

    // MARK: Settings window

    func testStackPositionMovesDeckAndCardsStillOpen() {
        launch(seeding: 3, openingSettings: true)
        let settings = app.windows["notic.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        for position in ["Left", "Bottom", "Right"] {
            let picker = settings.popUpButtons["notic.settings.stackPosition"]
            XCTAssertTrue(picker.waitForExistence(timeout: 3))
            picker.click()
            app.menuItems[position].click()
            let frame = app.descendants(matching: .any)["notic.edgePanel"].frame
            let screen = NSScreen.main!
            if position == "Left" {
                XCTAssertEqual(frame.minX, screen.visibleFrame.minX, accuracy: 2)
            } else if position == "Bottom" {
                XCTAssertEqual(frame.maxY, screen.frame.maxY - screen.visibleFrame.minY, accuracy: 2)
                XCTAssertGreaterThan(frame.width, frame.height)
            } else {
                XCTAssertEqual(frame.maxX, screen.visibleFrame.maxX, accuracy: 2)
            }
            if pill.exists { hoverPill() }
            let card = app.buttons["notic.card.0"]
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            card.click()
            XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
            app.buttons["notic.closeEditor"].click()
        }
    }

    func testDraggingStackMovesVerticallyAndDocksToEveryEdge() throws {
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        let screen = try XCTUnwrap(NSScreen.main)
        let panel = app.descendants(matching: .any)["notic.edgePanel"]
        let original = panel.frame
        let start = pill.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -140)))
        XCTAssertLessThan(panel.frame.midY, original.midY - 70)
        if pill.exists { hoverPill() }
        let stack = app.buttons["notic.card.0"]
        XCTAssertTrue(stack.waitForExistence(timeout: 3))
        func drag(to point: CGPoint) {
            if pill.exists { hoverPill() }
            XCTAssertTrue(stack.waitForExistence(timeout: 3))
            // Tabs deliberately extend beyond the screen. Grab visible paper.
            let paper = stack.frame.intersection(panel.frame)
            XCTAssertFalse(paper.isNull)
            let from = panel.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: paper.midX - panel.frame.minX, dy: paper.midY - panel.frame.minY)
            )
            let destination = from.withOffset(CGVector(dx: point.x - paper.midX, dy: point.y - paper.midY))
            from.press(forDuration: 0.05, thenDragTo: destination)
        }
        drag(to: CGPoint(x: screen.visibleFrame.maxX - 2, y: original.midY + 120))
        XCTAssertGreaterThan(panel.frame.midY, original.midY + 60)
        drag(to: CGPoint(x: screen.visibleFrame.minX + 2, y: original.midY))
        XCTAssertEqual(panel.frame.minX, screen.visibleFrame.minX, accuracy: 2)
        drag(to: CGPoint(x: screen.visibleFrame.midX, y: screen.frame.maxY - screen.visibleFrame.minY - 30))
        XCTAssertEqual(panel.frame.maxY, screen.frame.maxY - screen.visibleFrame.minY, accuracy: 2)
        XCTAssertGreaterThan(panel.frame.width, panel.frame.height)
        drag(to: CGPoint(x: screen.visibleFrame.maxX - 2, y: original.midY - 100))
        XCTAssertEqual(panel.frame.maxX, screen.visibleFrame.maxX, accuracy: 2)
        let saved = panel.frame
        app.terminate()
        app.launchArguments = Array(app.launchArguments.prefix(2))
        app.launch()
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(panel.frame.midY, saved.midY, accuracy: 2)
        if pill.exists { hoverPill() }
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))
        click(app.buttons["notic.card.0"], at: CGVector(dx: 0.5, dy: 0.1))
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
    }

    private func openSettings() -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        click(app.menuItems["Settings…"])
        let settings = app.windows["notic.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        return settings
    }

    func testSettingsHasGeneralAndAboutPanesWithTheDeckControls() {
        launch()
        let settings = openSettings()

        XCTAssertTrue(settings.buttons["notic.settings.pane.general"].exists)
        XCTAssertTrue(settings.buttons["notic.settings.pane.about"].exists)

        for identifier in [
            "notic.settings.textSize",
            "notic.settings.openDelay",
            "notic.settings.fanTrigger",
            "notic.settings.keepsDeckOpen",
            "notic.settings.animationSpeed",
            "notic.settings.launchAtLogin",
        ] {
            XCTAssertTrue(
                settings.descendants(matching: .any)[identifier].waitForExistence(timeout: 2),
                "Missing settings control \(identifier)"
            )
        }

        settings.buttons["notic.settings.pane.about"].click()
        let version = settings.staticTexts["notic.settings.version"]
        XCTAssertTrue(version.waitForExistence(timeout: 2))
        XCTAssertTrue((version.value as? String ?? version.label).hasPrefix("Version"))
        XCTAssertTrue(settings.links["notic.settings.byline"].exists)
    }

    func testKeepingTheDeckOpenLeavesTheDeckFannedWithoutHovering() {
        launch(seeding: 2)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))

        let settings = openSettings()
        settings.checkBoxes["notic.settings.keepsDeckOpen"].click()
        settings.buttons[XCUIIdentifierCloseWindow].click()

        XCTAssertTrue(deck.waitForExistence(timeout: 3))
        XCTAssertFalse(pill.exists)
    }

    // MARK: Dock menu

    func testSecondaryClickingATabShowsTheNoteCommandsAndDuplicatesIt() {
        launch(seeding: 2)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        hoverPill()
        XCTAssertTrue(deck.waitForExistence(timeout: 3))

        app.activate()
        click(app.buttons["notic.card.0"], at: CGVector(dx: 0.5, dy: 0.1), button: .right)
        XCTAssertTrue(app.menuItems["Duplicate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Color"].exists)
        XCTAssertTrue(app.menuItems["Archive Note"].exists)
        click(app.menuItems["Duplicate"])
        if pill.exists { hoverPill() }

        XCTAssertTrue(app.buttons["notic.card.2"].waitForExistence(timeout: 3))
    }

    func testSecondaryClickingTheBareDockShowsOnlyTheApplicationCommands() {
        launch()
        XCTAssertTrue(pill.waitForExistence(timeout: 5))

        pill.rightClick()
        XCTAssertTrue(app.menuItems["New Note"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Settings…"].exists)
        XCTAssertFalse(app.menuItems["Duplicate"].exists)
        XCTAssertFalse(app.menuItems["Delete"].exists)
    }
}
