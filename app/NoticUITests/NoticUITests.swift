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
    private var deck: XCUIElement { app.otherElements["notic.deck"] }
    private var editorBody: XCUIElement { app.textViews["notic.editor.body"] }

    private func assertEditorIsCentered(file: StaticString = #filePath, line: UInt = #line) {
        let panel = app.windows["notic.editorPanel"]
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

        pill.hover()

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

        pill.hover()

        XCTAssertTrue(app.staticTexts["notic.firstNotePrompt"].waitForExistence(timeout: 3))
        app.buttons["notic.newNote"].click()
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        assertEditorIsCentered()
        assertEditorHasTimestampTitle()
        XCTAssertFalse(app.staticTexts["notic.firstNotePrompt"].exists)
    }

    // MARK: Opening, editing, closing

    func testClickingACardOpensItsEditorAndOnlyAnEditorClickActivatesNotic() {
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCUIApplication(bundleIdentifier: "com.apple.finder").activate()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 3))
        pill.hover()
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))

        app.buttons["notic.card.0"].click()

        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningBackground, "Opening a note from the deck must not activate Notic")

        editorBody.click()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3), "Clicking into the editor activates Notic")

        editorBody.typeText(" appended")
        XCTAssertFalse(app.staticTexts["notic.saveState.saved"].exists)
        XCTAssertFalse(app.staticTexts["notic.saveState.unsaved"].exists)
    }

    func testClosingAnEditorKeepsTheNoteInTheDeck() {
        launch(seeding: 2, openingFirst: true)
        XCTAssertTrue(editorBody.waitForExistence(timeout: 5))

        app.buttons["notic.closeEditor"].click()

        XCTAssertFalse(editorBody.waitForExistence(timeout: 1))
        pill.hover()
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["notic.card.1"].exists)
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

        pin.click()

        XCTAssertEqual(pin.value as? String, "Pinned")
    }

    // MARK: Overflow and library

    func testMoreThanEightNotesShowsAnOverflowTileThatOpensTheLibrary() {
        launch(seeding: 10)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.hover()

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
        app.menuItems["All Notes"].click()

        let library = app.windows["All Notes"]
        XCTAssertTrue(library.waitForExistence(timeout: 3))
        let search = library.textFields["notic.library.search"]
        search.click()
        search.typeText("note 2")
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
        app.menuItems["New Note"].click()

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
            if pill.exists { pill.hover() }
            let card = app.buttons["notic.card.0"]
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            card.click()
            XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
            app.buttons["notic.closeEditor"].click()
        }
    }

    private func openSettings() -> XCUIElement {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5))
        statusItem.click()
        app.menuItems["Settings…"].click()
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
        pill.hover()
        XCTAssertTrue(deck.waitForExistence(timeout: 3))

        app.buttons["notic.card.0"].rightClick()
        XCTAssertTrue(app.menuItems["Duplicate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.menuItems["Color"].exists)
        XCTAssertTrue(app.menuItems["Archive Note"].exists)
        app.menuItems["Duplicate"].click()

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
