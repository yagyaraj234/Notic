import AppKit
import Carbon.HIToolbox

/// Global shortcuts via the Carbon hot-key API, which needs neither
/// Accessibility nor Input Monitoring permission.
final class HotKeyCenter {
    enum Shortcut: UInt32, CaseIterable {
        case newNote = 1
        case showLibrary
        case showArchive
        case toggleHidden

        var keyCode: UInt32 {
            switch self {
            case .newNote: UInt32(kVK_ANSI_N)
            case .showLibrary: UInt32(kVK_ANSI_L)
            case .showArchive: UInt32(kVK_ANSI_A)
            case .toggleHidden: UInt32(kVK_ANSI_H)
            }
        }

        var carbonModifiers: UInt32 {
            switch self {
            case .newNote, .showLibrary, .showArchive: UInt32(optionKey | cmdKey)
            case .toggleHidden: UInt32(controlKey | optionKey | cmdKey)
            }
        }

        /// The same shortcut expressed for menu items.
        var keyEquivalent: (String, NSEvent.ModifierFlags) {
            switch self {
            case .newNote: ("n", [.option, .command])
            case .showLibrary: ("l", [.option, .command])
            case .showArchive: ("a", [.option, .command])
            case .toggleHidden: ("h", [.control, .option, .command])
            }
        }
    }

    private static let signature: OSType = 0x4E54_4943 // "NTIC"

    private var actions: [UInt32: () -> Void] = [:]
    private var registrations: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
    }

    func register(_ shortcut: Shortcut, action: @escaping () -> Void) {
        actions[shortcut.rawValue] = action
        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: shortcut.rawValue)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &reference)
        if status == noErr, let reference {
            registrations.append(reference)
        }
    }

    fileprivate func handle(id: UInt32) {
        actions[id]?()
    }

    /// Releases every registration. The centre lives for the app's lifetime,
    /// so this is only needed if shortcuts are ever rebuilt.
    func unregisterAll() {
        for reference in registrations {
            UnregisterEventHotKey(reference)
        }
        registrations.removeAll()
        actions.removeAll()
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
    }
}

/// Carbon delivers hot-key events on the main thread.
private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        center.handle(id: hotKeyID.id)
    }
    return noErr
}
