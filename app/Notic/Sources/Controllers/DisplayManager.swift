import AppKit
import NoticCore

/// Keeps one `DisplayCoordinator` per attached screen and reconciles them when
/// displays connect, disconnect, or change resolution.
final class DisplayManager: NSObject {
    private let workspace: NoticWorkspace
    private let commands: AppCommands
    private var coordinators: [DisplayID: DisplayCoordinator] = [:]

    init(workspace: NoticWorkspace, commands: AppCommands) {
        self.workspace = workspace
        self.commands = commands
        super.init()
        reconcile()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        reconcile()
    }

    /// The display the pointer is currently on.
    func displayUnderPointer() -> DisplayID? {
        let location = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(location) }?.noticDisplayID
    }

    func primaryDisplay() -> DisplayID? {
        NSScreen.main?.noticDisplayID ?? NSScreen.screens.first?.noticDisplayID
    }

    /// Activates Notic and puts the insertion point in the open editor.
    func focusEditor(on display: DisplayID) {
        coordinators[display]?.focusEditor()
    }

    private func reconcile() {
        var seen: Set<DisplayID> = []
        for screen in NSScreen.screens {
            guard let id = screen.noticDisplayID else { continue }
            seen.insert(id)
            if let coordinator = coordinators[id] {
                coordinator.screenDidChange(screen)
            } else {
                workspace.attachDisplay(id)
                coordinators[id] = DisplayCoordinator(display: id, screen: screen, workspace: workspace, commands: commands)
            }
        }
        for (id, coordinator) in coordinators where !seen.contains(id) {
            coordinator.tearDown()
            coordinators[id] = nil
            workspace.detachDisplay(id)
        }
    }
}

extension NSScreen {
    /// The `CGDirectDisplayID` for this screen, as a workspace display identifier.
    var noticDisplayID: DisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return DisplayID(rawValue: number.uint32Value)
    }
}
