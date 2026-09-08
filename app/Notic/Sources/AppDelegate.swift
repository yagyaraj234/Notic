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
        do {
            usesTestDirectory = launchOptions.dataDirectory != nil
            if !usesTestDirectory, let location = UserDefaults.standard.dictionary(forKey: Self.storageBookmarkKey) {
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
                customNotesDirectory = library
                guard FileManager.default.fileExists(atPath: library.appending(path: "Notes.store").path) else {
                    throw CocoaError(.fileNoSuchFile)
                }
                if stale {
                    let refreshed = try folder.bookmarkData(options: .withSecurityScope)
                    UserDefaults.standard.set(["bookmark": refreshed, "library": name], forKey: Self.storageBookmarkKey)
                }
            }
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

        let menus = NoticMenus(workspace: workspace, commands: commands)
        self.menus = menus

        menuBar = MenuBarController(workspace: workspace, menus: menus)
        displays = DisplayManager(workspace: workspace, commands: commands)
        let library = LibraryWindowController(workspace: workspace, commands: commands)
        self.library = library
        menus.openNote = { [weak library] id in library?.openNote(id) }
        settingsWindow = SettingsWindowController(workspace: workspace, chooseNotesFolder: { [weak self] in self?.chooseNotesFolder() })

        hotKeys = HotKeyCenter()
        hotKeys?.register(.newNote) { commands.newNote(nil) }
        hotKeys?.register(.showLibrary, action: commands.showLibrary)
        hotKeys?.register(.showArchive, action: commands.showArchive)
        hotKeys?.register(.toggleHidden, action: commands.toggleHidden)

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
        if let display = requestedDisplay ?? displays.displayUnderPointer() ?? displays.primaryDisplay() {
            if let screen = NSScreen.screens.first(where: { $0.noticDisplayID == display }),
               let size = workspace.note(id)?.editorSize {
                workspace.setEditorOrigin(
                    of: id,
                    to: CGPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.midY - size.height / 2)
                )
            }
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

    private func apply(_ settings: NoticSettings) {
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

    private func chooseNotesFolder() {
        guard let workspace else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose Notes Folder"
        panel.message = "Notic creates a new library folder here and copies all notes into it. The previous library stays as a backup."
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        let accessing = parent.startAccessingSecurityScopedResource()
        defer { if accessing { parent.stopAccessingSecurityScopedResource() } }
        let destination = parent.appending(path: "Notic Library \(UUID().uuidString)", directoryHint: .isDirectory)
        var newAccess: URL?
        do {
            // Capture access before switching stores. Resolve on relaunch using the same bookmark.
            let bookmark = try parent.bookmarkData(options: .withSecurityScope)
            var stale = false
            let resolved = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &stale)
            guard resolved.startAccessingSecurityScopedResource() else { throw CocoaError(.fileWriteNoPermission) }
            newAccess = resolved
            try workspace.relocateNotes(to: destination)
            if !usesTestDirectory {
                UserDefaults.standard.set(["bookmark": bookmark, "library": destination.lastPathComponent], forKey: Self.storageBookmarkKey)
            }
            storageAccess?.stopAccessingSecurityScopedResource()
            storageAccess = resolved
        } catch {
            newAccess?.stopAccessingSecurityScopedResource()
            let alert = NSAlert()
            alert.messageText = "Couldn’t change the notes folder"
            alert.informativeText = "Your current library is still in use.\n\n\(error.localizedDescription)"
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
    let showLibrary: () -> Void
    let showArchive: () -> Void
    let toggleHidden: () -> Void
    let showSettings: () -> Void
    let quit: () -> Void
}
