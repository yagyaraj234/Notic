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
    private func launch(seeding count: Int = 0, openingFirst: Bool = false) {
        app = XCUIApplication()
        let container = NSHomeDirectory() + "/Library/Containers/com.yagyaraj.notic/Data/tmp/uitests"
        app.launchArguments = ["-NoticDataDirectory", container, "-NoticResetData"]
        if count > 0 {
            app.launchArguments += ["-NoticSeedNotes", String(count)]
        }
        if openingFirst {
            app.launchArguments.append("-NoticOpenSeededNote")
        }
        app.launch()
    }

    private var pill: XCUIElement { app.buttons["notic.pill"] }
    private var deck: XCUIElement { app.otherElements["notic.deck"] }
    private var editorBody: XCUIElement { app.textViews["notic.editor.body"] }

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

    func testFirstRunPromptAppearsUntilANoteExists() {
        launch()
        XCTAssertTrue(pill.waitForExistence(timeout: 5))

        pill.hover()

        XCTAssertTrue(app.staticTexts["notic.firstNotePrompt"].waitForExistence(timeout: 3))
        app.buttons["notic.newNote"].click()
        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["notic.firstNotePrompt"].exists)
    }

    // MARK: Opening, editing, closing

    func testClickingACardOpensItsEditorAndOnlyAnEditorClickActivatesNotic() {
        launch(seeding: 3)
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.hover()
        XCTAssertTrue(app.buttons["notic.card.0"].waitForExistence(timeout: 3))

        app.buttons["notic.card.0"].click()

        XCTAssertTrue(editorBody.waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningBackground, "Opening a note from the deck must not activate Notic")

        editorBody.click()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 3), "Clicking into the editor activates Notic")

        editorBody.typeText(" appended")
        XCTAssertTrue(app.staticTexts["notic.saveState.saved"].waitForExistence(timeout: 3))
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
    }
}
