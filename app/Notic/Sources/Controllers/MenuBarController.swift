import AppKit
import NoticCore

/// The status-bar item and the quick menu it drops down. The menu itself is
/// defined once in `NoticMenus`; this owns the item, refills the menu each
/// time it opens, and carries the save warning on its icon.
final class MenuBarController: NSObject, NSMenuDelegate {
    private let workspace: NoticWorkspace
    private let menus: NoticMenus
    private let statusItem: NSStatusItem
    private var saveStateObservation: ObservationToken?

    init(workspace: NoticWorkspace, menus: NoticMenus) {
        self.workspace = workspace
        self.menus = menus
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.setAccessibilityIdentifier("notic.menuBar")
        }
        // The menu-bar icon is the one surface that is always visible, so it
        // carries the non-blocking save warning when no editor is open.
        saveStateObservation = ObservationToken.track({ workspace.saveState }) { [weak self] state in
            self?.showSaveState(state)
        }

        let menu = menus.quickMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// Hide/Show flips with `workspace.isHidden`, so the menu is refilled from
    /// the shared definition every time it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menus.populate(menu, forNote: nil, includeOpen: false)
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
}
