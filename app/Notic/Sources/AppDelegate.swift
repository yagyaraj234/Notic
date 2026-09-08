import AppKit
import NoticCore
import os

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.yagyaraj.notic", category: "app")

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
            workspace = try NoticWorkspace(directory: launchOptions.resolveDataDirectory(default: Self.dataDirectory))
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
        settingsWindow = SettingsWindowController(workspace: workspace)

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

    /// Notes live in the sandbox container's Application Support folder.
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
