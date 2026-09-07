import AppKit
import NoticCore
import SwiftUI

struct SettingsView: View {
    let workspace: NoticWorkspace

    var body: some View {
        let settings = workspace.settings
        Form {
            Section("Notes") {
                Picker("Font", selection: binding(\.fontChoice)) {
                    Text("Handwriting (Patrick Hand)").tag(NoticSettings.FontChoice.handwriting)
                    Text("System font").tag(NoticSettings.FontChoice.system)
                }
                .accessibilityIdentifier("notic.settings.font")
                Picker("Paper", selection: binding(\.paperStyle)) {
                    Text("Pastel — light in dark mode too").tag(NoticSettings.PaperStyle.pastel)
                    Text("Match appearance").tag(NoticSettings.PaperStyle.adaptive)
                }
                .accessibilityIdentifier("notic.settings.paper")
                Toggle("Lean the tabs in the deck", isOn: binding(\.tiltsTabs))
                    .accessibilityIdentifier("notic.settings.tilt")
                Toggle("Show notes above all apps", isOn: binding(\.showsAboveAllApps))
                    .accessibilityIdentifier("notic.settings.aboveAll")
                Toggle("Show over full-screen apps", isOn: binding(\.visibleOverFullScreenApps))
                    .accessibilityIdentifier("notic.settings.fullScreen")
            }
            Section("Application") {
                Toggle("Show Notic in the Dock", isOn: binding(\.showsDockIcon))
                    .accessibilityIdentifier("notic.settings.dock")
                Toggle("Launch at Login", isOn: binding(\.launchAtLogin))
                    .accessibilityIdentifier("notic.settings.launchAtLogin")
            }
            Section("Shortcuts") {
                LabeledContent("New Note", value: "⌥⌘N")
                LabeledContent("All Notes", value: "⌥⌘L")
                LabeledContent("Archive", value: "⌥⌘A")
                LabeledContent("Hide or show Notic", value: "⌃⌥⌘H")
            }
            Section("Privacy") {
                Text("Notes are stored only in Notic's sandbox on this Mac. Notic makes no network requests and collects no analytics.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(NotePalette.windowBackground)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .animation(nil, value: settings)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<NoticSettings, Value>) -> Binding<Value> {
        Binding(
            get: { workspace.settings[keyPath: keyPath] },
            set: { value in workspace.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}

final class SettingsWindowController: NSWindowController {
    init(workspace: NoticWorkspace) {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notic Settings"
        window.isReleasedWhenClosed = false
        window.setAccessibilityIdentifier("notic.settings")
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView(workspace: workspace))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    func show() {
        presentActivating()
    }
}
