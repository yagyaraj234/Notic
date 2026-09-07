import AppKit
import NoticCore

/// The status-bar item and its menu: New Note, All Notes, Archive,
/// Hide/Show Notic, Settings, and Quit.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let workspace: NoticWorkspace
    private let commands: AppCommands
    private let statusItem: NSStatusItem
    private let hideItem: NSMenuItem
    private var saveStateObservation: ObservationToken?

    init(workspace: NoticWorkspace, commands: AppCommands) {
        self.workspace = workspace
        self.commands = commands
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        hideItem = NSMenuItem(title: "Hide Notic", action: #selector(toggleHidden), keyEquivalent: "")
        super.init()

        if let button = statusItem.button {
            button.setAccessibilityIdentifier("notic.menuBar")
        }
        // The menu-bar icon is the one surface that is always visible, so it
        // carries the non-blocking save warning when no editor is open.
        saveStateObservation = ObservationToken.track({ workspace.saveState }) { [weak self] state in
            self?.showSaveState(state)
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("New Note", #selector(newNote), .newNote))
        menu.addItem(.separator())
        menu.addItem(item("All Notes", #selector(showLibrary), .showLibrary))
        menu.addItem(item("Archive", #selector(showArchive), .showArchive))
        menu.addItem(.separator())
        apply(shortcut: .toggleHidden, to: hideItem)
        hideItem.target = self
        menu.addItem(hideItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Notic", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        hideItem.title = workspace.isHidden ? "Show Notic" : "Hide Notic"
    }

    private func showSaveState(_ state: SaveState) {
        guard let button = statusItem.button else { return }
        if case let .failed(message) = state {
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Notic, couldn't save")
            button.toolTip = "Notic couldn't save: \(message). Retrying automatically."
            button.setAccessibilityLabel("Notic, couldn't save, retrying")
        } else {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "Notic")
            button.toolTip = nil
            button.setAccessibilityLabel("Notic")
        }
    }

    private func item(_ title: String, _ action: Selector, _ shortcut: HotKeyCenter.Shortcut) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        apply(shortcut: shortcut, to: item)
        return item
    }

    private func apply(shortcut: HotKeyCenter.Shortcut, to item: NSMenuItem) {
        let (key, modifiers) = shortcut.keyEquivalent
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = modifiers
    }

    @objc private func newNote() { commands.newNote() }
    @objc private func showLibrary() { commands.showLibrary() }
    @objc private func showArchive() { commands.showArchive() }
    @objc private func toggleHidden() { commands.toggleHidden() }
    @objc private func showSettings() { commands.showSettings() }
    @objc private func quit() { commands.quit() }
}
