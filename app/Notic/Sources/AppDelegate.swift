import AppKit
import NoticCore
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.yagyaraj.notic", category: "app")

    private var storageAccess: URL?
    private var customNotesDirectory: URL?
    private var usesTestDirectory = false
    private static let storageBookmarkKey = "notesFolderBookmark"

    private var workspace: NoticWorkspace?
    private var menuBar: MenuBarController?
    private var displays: DisplayManager?
    private var hotKeys: HotKeyCenter?
    private var library: LibraryWindowController?
    private var menus: NoticMenus?
    private var settingsWindow: SettingsWindowController?
    private var settingsObservation: ObservationToken?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FontRegistry.registerBundledFonts()

        let launchOptions = LaunchOptions(arguments: CommandLine.arguments)
        let workspace: NoticWorkspace
        usesTestDirectory = launchOptions.dataDirectory != nil
        if !usesTestDirectory {
            do {
                customNotesDirectory = try resolveCustomLibrary()
            } catch {
                log.error("Custom notes folder unavailable: \(error.localizedDescription, privacy: .public)")
                // A missing drive or moved folder must not lock the user out.
                guard offerDefaultLibrary(after: error) else {
                    NSApp.terminate(nil)
                    return
                }
            }
        }
        do {
            workspace = try NoticWorkspace(
                directory: launchOptions.resolveDataDirectory(default: Self.dataDirectory),
                notesDirectory: customNotesDirectory
            )
        } catch {
            log.fault("Could not open the note store: \(error.localizedDescription, privacy: .public)")
            presentFatalStoreError(error)
            return
        }
        self.workspace = workspace

        var commands = AppCommands(
            newNote: { [weak self] display in self?.createNoteAndOpen(on: display) },
            showLibrary: { [weak self] in self?.showLibrary(filter: .all) },
            showArchive: { [weak self] in self?.showLibrary(filter: .archived) },
            toggleHidden: { [weak self] in self?.toggleHidden() },
            showSettings: { [weak self] in self?.showSettings() },
            quit: { NSApp.terminate(nil) }
        )
        // The menus need the commands, and the surfaces that show them need
        // the menus, so the factories reach the menu object indirectly.
        commands.dockMenu = { [weak self] (id: Note.ID?) in self?.menus?.dockMenu(forNote: id) ?? NSMenu() }
        commands.libraryMenu = { [weak self] (id: Note.ID) in self?.menus?.libraryMenu(forNote: id) ?? NSMenu() }
        commands.exportNotes = { [weak self] notes in self?.exportNotes(notes) }

        let menus = NoticMenus(workspace: workspace, commands: commands)
        self.menus = menus

        menuBar = MenuBarController(workspace: workspace, menus: menus)
        displays = DisplayManager(workspace: workspace, commands: commands)
        let library = LibraryWindowController(workspace: workspace, commands: commands)
        self.library = library
        menus.openNote = { [weak library] id in library?.openNote(id) }
        settingsWindow = SettingsWindowController(
            workspace: workspace,
            chooseNotesFolder: { [weak self] in self?.chooseNotesFolder() },
            useDefaultNotesFolder: { [weak self] in self?.useDefaultNotesFolder() }
        )
        self.commands = commands

        settingsObservation = ObservationToken.track({ workspace.settings }) { [weak self] settings in
            self?.apply(settings)
        }

        // Sleep and logout can interrupt the autosave debounce; write early.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(flushPendingChanges),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(flushPendingChanges),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )

        launchOptions.seed(workspace, displays: displays)
        if launchOptions.opensSettings {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspace?.flushPendingChanges()
    }

    @objc private func flushPendingChanges() {
        workspace?.flushPendingChanges()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLibrary(filter: .all)
        return false
    }

    // MARK: Commands

    private func createNoteAndOpen(on requestedDisplay: DisplayID?) {
        guard let workspace, let displays else { return }
        let id = workspace.createNote()
        // Opens wherever the last note was placed, like every other note.
        if let display = requestedDisplay ?? displays.displayUnderPointer() ?? displays.primaryDisplay() {
            workspace.openNote(id, on: display)
            if requestedDisplay == nil {
                displays.focusEditor(on: display)
            }
        }
    }

    private func showLibrary(filter: LibraryFilter) {
        library?.show(filter: filter)
    }

    private func showSettings() {
        settingsWindow?.show()
    }

    /// Hides or restores every Notic surface, including the library and
    /// settings windows; the per-display panels follow `workspace.isHidden`.
    private func toggleHidden() {
        guard let workspace else { return }
        workspace.toggleHidden()
        if workspace.isHidden {
            library?.window?.orderOut(nil)
            settingsWindow?.window?.orderOut(nil)
        }
    }

    // MARK: Settings

    private var hasReconciledLaunchAtLogin = false
    private var commands: AppCommands?

    /// Registers or releases the system-wide shortcuts to match the preference.
    private func applyGlobalShortcuts(enabled: Bool) {
        guard enabled != (hotKeys != nil), let commands else { return }
        if enabled {
            let hotKeys = HotKeyCenter()
            hotKeys.register(.newNote) { commands.newNote(nil) }
            hotKeys.register(.showLibrary, action: commands.showLibrary)
            hotKeys.register(.showArchive, action: commands.showArchive)
            hotKeys.register(.toggleHidden, action: commands.toggleHidden)
            self.hotKeys = hotKeys
        } else {
            hotKeys?.unregisterAll()
            hotKeys = nil
        }
        menus?.showsShortcuts = enabled
        menus?.failedShortcuts = hotKeys?.failedShortcuts ?? []
        menuBar?.refreshStatus()
    }

    private func apply(_ settings: NoticSettings) {
        applyGlobalShortcuts(enabled: settings.globalShortcutsEnabled)
        Motion.speed = settings.animationSpeed.multiplier
        let policy: NSApplication.ActivationPolicy = settings.showsDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
        }
        // On the first pass adopt what the user may have set in System Settings
        // rather than silently unregistering it; afterwards the preference rules.
        if !hasReconciledLaunchAtLogin {
            hasReconciledLaunchAtLogin = true
            if LaunchAtLogin.isEnabled != settings.launchAtLogin {
                workspace?.updateSettings { $0.launchAtLogin = LaunchAtLogin.isEnabled }
                return
            }
        }
        LaunchAtLogin.apply(enabled: settings.launchAtLogin, log: log)
    }

    // MARK: Storage

    /// The library folder the user chose, or `nil` for the default one.
    /// Starts security-scoped access to it; throws if it can't be reached.
    private func resolveCustomLibrary() throws -> URL? {
        guard let location = UserDefaults.standard.dictionary(forKey: Self.storageBookmarkKey) else { return nil }
        guard let bookmark = location["bookmark"] as? Data else { throw CocoaError(.fileReadCorruptFile) }
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
        guard folder.startAccessingSecurityScopedResource() else {
            throw CocoaError(.fileReadNoPermission)
        }
        storageAccess = folder
        guard let name = location["library"] as? String,
              name.hasPrefix("Notic Library "), !name.contains("/") else { throw CocoaError(.fileReadCorruptFile) }
        let library = folder.appending(path: name, directoryHint: .isDirectory)
        guard FileManager.default.fileExists(atPath: library.appending(path: "Notes.store").path) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: library.path(percentEncoded: false)])
        }
        if stale {
            let refreshed = try folder.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(["bookmark": refreshed, "library": name], forKey: Self.storageBookmarkKey)
        }
        return library
    }

    /// Asks whether to fall back to the default library when the chosen one
    /// can't be reached. Returns `false` if the user would rather quit and
    /// reconnect the folder.
    private func offerDefaultLibrary(after error: any Error) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Notic can’t find its notes folder"
        alert.informativeText = """
            If your notes are on an external or network drive, connect it and open Notic again.

            Use Default Library forgets the missing folder and opens Notic’s built-in library instead. \
            The missing folder is not deleted.

            \(error.localizedDescription)
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Use Default Library")
        NSApp.activate()
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        UserDefaults.standard.removeObject(forKey: Self.storageBookmarkKey)
        storageAccess?.stopAccessingSecurityScopedResource()
        storageAccess = nil
        return true
    }

    private func chooseNotesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.message = "Notic creates a new library folder here and moves all notes into it. Don’t choose a folder synced by iCloud Drive, Dropbox, or similar."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        let accessing = parent.startAccessingSecurityScopedResource()
        defer { if accessing { parent.stopAccessingSecurityScopedResource() } }
        // The store is a SQLite database: sync services upload its files
        // independently and can corrupt it, or evict it so Notic can't start.
        guard !Self.isCloudSynced(parent) else {
            showStorageError(CocoaError(.fileWriteNoPermission, userInfo: [
                NSLocalizedDescriptionKey: "That folder is synced by a cloud service, which can corrupt Notic’s notes database. Choose a local folder instead.",
            ]))
            return
        }
        do {
            // Capture access before switching stores. Resolve on relaunch using the same bookmark.
            let bookmark = try parent.bookmarkData(options: .withSecurityScope)
            var stale = false
            let resolved = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            guard resolved.startAccessingSecurityScopedResource() else { throw CocoaError(.fileWriteNoPermission) }
            let destination = parent.appending(path: "Notic Library \(UUID().uuidString)", directoryHint: .isDirectory)
            do {
                try switchLibrary(to: destination) {
                    UserDefaults.standard.set(["bookmark": bookmark, "library": destination.lastPathComponent], forKey: Self.storageBookmarkKey)
                }
            } catch {
                resolved.stopAccessingSecurityScopedResource()
                throw error
            }
            storageAccess?.stopAccessingSecurityScopedResource()
            storageAccess = resolved
        } catch {
            showStorageError(error)
        }
    }

    /// Moves the notes back into Notic’s built-in folder.
    private func useDefaultNotesFolder() {
        do {
            try switchLibrary(to: Self.dataDirectory) {
                UserDefaults.standard.removeObject(forKey: Self.storageBookmarkKey)
            }
            storageAccess?.stopAccessingSecurityScopedResource()
            storageAccess = nil
        } catch {
            showStorageError(error)
        }
    }

    /// Copies every note into `destination`, records the new location, then
    /// moves the previous library to the Trash so deleted notes don't live on
    /// in old copies. The Trash keeps it recoverable until emptied.
    private func switchLibrary(to destination: URL, remember: () -> Void) throws {
        guard let workspace, let previous = workspace.notesDirectory else { return }
        try workspace.relocateNotes(to: destination)
        if !usesTestDirectory { remember() }
        // A chosen library is a folder of its own; the default one shares its
        // folder with Settings.json, so only the store files go.
        let doomed = previous.lastPathComponent.hasPrefix("Notic Library ")
            ? [previous]
            : ["Notes.store", "Notes.store-shm", "Notes.store-wal"].map { previous.appending(path: $0) }
        for url in doomed where FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                log.error("Could not move the previous library to the Trash: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func isCloudSynced(_ url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path(percentEncoded: false)
        if path.contains("/Library/Mobile Documents/") || path.contains("/Library/CloudStorage/") { return true }
        return (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
    }

    private func showStorageError(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t change the notes folder"
        alert.informativeText = "Your current library is still in use.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.runModal()
    }

    // MARK: Export

    /// Writes notes as Markdown files into a folder the user picks.
    func exportNotes(_ notes: [Note]) {
        guard !notes.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.title = notes.count == 1 ? "Export Note" : "Export \(notes.count) Notes"
        panel.message = "Each note is saved as a Markdown (.md) file in the folder you choose."
        panel.prompt = "Export"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        do {
            let existing = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))
            for file in NoteExport.files(for: notes, avoiding: existing) {
                try Data(file.contents.utf8).write(to: folder.appending(path: file.name), options: .withoutOverwriting)
            }
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t export notes"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    /// Default library and settings live in Application Support.
    private static var dataDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Notic", directoryHint: .isDirectory)
    }

    private func presentFatalStoreError(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "Notic can't open its notes"
        alert.informativeText = "The local note store could not be opened.\n\n\(error.localizedDescription)"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}

/// The user-level actions shared by the menu bar, global shortcuts, and panels.
struct AppCommands {
    let newNote: (DisplayID?) -> Void
    /// The dock menu for the tab under the pointer, or for the bare dock.
    var dockMenu: (Note.ID?) -> NSMenu = { _ in NSMenu() }
    /// The library row menu for one note.
    var libraryMenu: (Note.ID) -> NSMenu = { _ in NSMenu() }
    /// Saves the given notes as Markdown files in a folder the user picks.
    var exportNotes: ([Note]) -> Void = { _ in }
    let showLibrary: () -> Void
    let showArchive: () -> Void
    let toggleHidden: () -> Void
    let showSettings: () -> Void
    let quit: () -> Void
}
