import Foundation
import os
import ServiceManagement

/// Launch at Login through `SMAppService`; nothing is registered until the
/// user opts in.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func apply(enabled: Bool, log: Logger) {
        guard enabled != isEnabled else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Launch at Login change failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
