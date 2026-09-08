import AppKit
import NoticCore

/// Every menu item Notic offers, defined once. Three surfaces are built from
/// here — the quick menu on the status item, the dock menu on secondary-click
/// of the dock or a tab, and the library row menu — so they cannot drift
/// apart. Note-level items act on the note they were built for; on the bare
/// dock they are omitted rather than disabled, because a menu of dead items
/// reads as broken.
@MainActor
final class NoticMenus: NSObject {
    private let workspace: NoticWorkspace
    private let commands: AppCommands
    /// Set by the library so its row menu can open a note in place.
    var openNote: ((Note.ID) -> Void)?

    init(workspace: NoticWorkspace, commands: AppCommands) {
        self.workspace = workspace
        self.commands = commands
        super.init()
    }

    // MARK: Surfaces

    /// The status-item menu: application commands only.
    func quickMenu() -> NSMenu {
        let menu = NSMenu()
        populate(menu, forNote: nil, includeOpen: false)
        return menu
    }

    /// The dock menu. `note` is the tab under the pointer, or `nil` on the
    /// bare dock.
    func dockMenu(forNote note: Note.ID?) -> NSMenu {
        let menu = NSMenu()
        populate(menu, forNote: note, includeOpen: false)
        return menu
    }

    /// The library row menu: the same note commands, plus Open, without the
    /// application commands the library already has elsewhere.
    func libraryMenu(forNote note: Note.ID) -> NSMenu {
        let menu = NSMenu()
        appendNoteItems(to: menu, note: note, includeOpen: true)
        return menu
    }

    /// Fills `menu` in place, so a live status-item menu can be refreshed on
    /// each open without being rebuilt from the outside.
    func populate(_ menu: NSMenu, forNote note: Note.ID?, includeOpen: Bool) {
        menu.removeAllItems()
        if let note, workspace.note(note) != nil {
            appendNoteItems(to: menu, note: note, includeOpen: includeOpen)
            menu.addItem(.separator())
        }
        menu.addItem(item("New Note", #selector(newNote), shortcut: .newNote))
        menu.addItem(.separator())
        menu.addItem(item("All Notes…", #selector(showLibrary), shortcut: .showLibrary))
        menu.addItem(item("Show Archive…", #selector(showArchive), shortcut: .showArchive))
        let settings = item("Settings…", #selector(showSettings))
        settings.keyEquivalent = ","
        settings.keyEquivalentModifierMask = .command
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(item(workspace.isHidden ? "Show Notic" : "Hide Notic", #selector(toggleHidden), shortcut: .toggleHidden))
        let quit = item("Quit Notic", #selector(quit))
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = .command
        menu.addItem(quit)
    }

    // MARK: Note items

    private func appendNoteItems(to menu: NSMenu, note id: Note.ID, includeOpen: Bool) {
        guard let note = workspace.note(id) else { return }
        let pending = note.lifecycle.isPendingDeletion

        if includeOpen, note.lifecycle == .active {
            menu.addItem(item("Open", #selector(open(_:)), note: id))
        }

        let color = item("Color", nil, note: id)
        color.submenu = colorSubmenu(for: note)
        color.isEnabled = !pending
        menu.addItem(color)

        let duplicate = item("Duplicate", #selector(duplicate(_:)), note: id)
        duplicate.isEnabled = !pending
        menu.addItem(duplicate)

        menu.addItem(.separator())

        switch note.lifecycle {
        case .active:
            menu.addItem(item("Archive Note", #selector(archive(_:)), note: id))
        case .archived:
            menu.addItem(item("Restore Note", #selector(restore(_:)), note: id))
        case .pendingDeletion:
            menu.addItem(item("Undo Delete", #selector(undoDelete(_:)), note: id))
        }

        if !pending {
            menu.addItem(item("Delete", #selector(delete(_:)), note: id))
        }
    }

    /// The eight swatches, each showing its own colour, with the note's
    /// current colour ticked.
    private func colorSubmenu(for note: Note) -> NSMenu {
        let submenu = NSMenu()
        for color in NoteColor.allCases {
            let entry = NSMenuItem(title: NotePalette.name(for: color), action: #selector(setColor(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = ColorChoice(note: note.id, color: color)
            entry.state = note.color == color ? .on : .off
            entry.image = swatchImage(for: color)
            submenu.addItem(entry)
        }
        return submenu
    }

    private func swatchImage(for color: NoteColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(NotePalette.swatch(for: color).paper).setFill()
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            path.fill()
            NSColor.black.withAlphaComponent(0.15).setStroke()
            path.lineWidth = 1
            path.stroke()
            return true
        }
        // Drawn in the note's own colour, so it must not be tinted as a template.
        image.isTemplate = false
        return image
    }

    // MARK: Item construction

    private struct ColorChoice {
        let note: Note.ID
        let color: NoteColor
    }

    private func item(_ title: String, _ action: Selector?, shortcut: HotKeyCenter.Shortcut? = nil, note: Note.ID? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = note
        if let shortcut {
            let (key, modifiers) = shortcut.keyEquivalent
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = modifiers
        }
        return item
    }

    private func noteID(from sender: Any?) -> Note.ID? {
        (sender as? NSMenuItem)?.representedObject as? Note.ID
    }

    // MARK: Actions

    @objc private func open(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        openNote?(id)
    }

    @objc private func duplicate(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        workspace.duplicateNote(id)
    }

    @objc private func archive(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        workspace.archive([id])
    }

    @objc private func restore(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        workspace.restore([id])
    }

    @objc private func delete(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        workspace.delete([id])
    }

    @objc private func undoDelete(_ sender: Any?) {
        guard let id = noteID(from: sender) else { return }
        workspace.undoDelete([id])
    }

    @objc private func setColor(_ sender: Any?) {
        guard let choice = (sender as? NSMenuItem)?.representedObject as? ColorChoice else { return }
        workspace.setColor(of: choice.note, to: choice.color)
    }

    @objc private func newNote() { commands.newNote(nil) }
    @objc private func showLibrary() { commands.showLibrary() }
    @objc private func showArchive() { commands.showArchive() }
    @objc private func toggleHidden() { commands.toggleHidden() }
    @objc private func showSettings() { commands.showSettings() }
    @objc private func quit() { commands.quit() }
}
