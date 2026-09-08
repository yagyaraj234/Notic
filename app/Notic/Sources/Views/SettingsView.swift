import AppKit
import NoticCore
import SwiftUI

/// The settings window: a two-row sidebar and one pane at a time. Native
/// controls in Notic's own shell, matching the library window rather than
/// the system's own preferences chrome.
struct SettingsView: View {
    let workspace: NoticWorkspace
    let chooseNotesFolder: () -> Void

    enum Pane: String, CaseIterable, Hashable {
        case general
        case about

        var title: String {
            switch self {
            case .general: "General"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "slider.horizontal.3"
            case .about: "info.circle"
            }
        }
    }

    @State private var pane: Pane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 208)
                .background(NotePalette.paneBackground)
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(NotePalette.windowBackground)
        .frame(minWidth: 700, minHeight: 520)
        .animation(nil, value: workspace.settings)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notic")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 44)
            .padding(.bottom, 16)
            .accessibilityElement(children: .combine)

            ForEach(Pane.allCases, id: \.self) { candidate in
                SidebarRow(
                    title: candidate.title,
                    symbol: candidate.symbol,
                    isSelected: pane == candidate
                ) {
                    pane = candidate
                }
                .accessibilityIdentifier("notic.settings.pane.\(candidate.rawValue)")
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)
        }
    }

    // MARK: Detail

    @ViewBuilder private var detail: some View {
        switch pane {
        case .general: general
        case .about: about
        }
    }

    private var general: some View {
        pane(title: "General", subtitle: "How notes and the deck look and behave.") {
            Section("Notes") {
                Picker("Note font", selection: binding(\.fontChoice)) {
                    ForEach(NoticSettings.FontChoice.allCases, id: \.self) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .accessibilityIdentifier("notic.settings.font")

                Text("A little space for your thoughts.")
                    .font(Font(FontRegistry.nsFont(workspace.settings.fontChoice, size: CGFloat(workspace.settings.textSize))))
                    .padding(.vertical, 4)
                    .accessibilityLabel("Note font preview")
                    .accessibilityIdentifier("notic.settings.fontPreview")

                Picker("Text size", selection: binding(\.textSize)) {
                    ForEach(NoticSettings.textSizeOptions, id: \.self) { size in
                        Text("\(size) pt").tag(size)
                    }
                }
                .accessibilityIdentifier("notic.settings.textSize")

                Picker("Paper", selection: binding(\.paperStyle)) {
                    Text("Pastel — light in dark mode too").tag(NoticSettings.PaperStyle.pastel)
                    Text("Match appearance").tag(NoticSettings.PaperStyle.adaptive)
                }
                .accessibilityIdentifier("notic.settings.paper")

                Toggle("Lean the tabs in the deck", isOn: binding(\.tiltsTabs))
                    .accessibilityIdentifier("notic.settings.tilt")
            }

            Section("Deck") {
                Picker("Stack position", selection: binding(\.stackPosition)) {
                    Text("Right").tag(ScreenEdge.right)
                    Text("Left").tag(ScreenEdge.left)
                    Text("Bottom").tag(ScreenEdge.bottom)
                }
                .accessibilityIdentifier("notic.settings.stackPosition")

                LabeledContent {
                    HStack(spacing: 10) {
                        Slider(
                            value: binding(\.openDelay),
                            in: NoticSettings.openDelayRange,
                            step: NoticSettings.openDelayStep
                        )
                        .frame(width: 180)
                        .accessibilityIdentifier("notic.settings.openDelay")
                        Text("\(Int((workspace.settings.openDelay * 1000).rounded())) ms")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                } label: {
                    Text("Open delay")
                    Text("How long the pointer rests on the dock before the deck fans")
                }
                .accessibilityValue("\(Int((workspace.settings.openDelay * 1000).rounded())) milliseconds")

                LabeledContent {
                    Picker("Fan the deck", selection: binding(\.fanTrigger)) {
                        Text("On hover").tag(NoticSettings.FanTrigger.hover)
                        Text("On click").tag(NoticSettings.FanTrigger.click)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("notic.settings.fanTrigger")
                } label: {
                    Text("Fan the deck")
                    Text("Whether hovering fans the notes out, or only a click does")
                }

                Toggle(isOn: binding(\.keepsDeckOpen)) {
                    Text("Keep the deck open")
                    Text("The deck stays fanned at the edge instead of resting as the dock")
                }
                .accessibilityIdentifier("notic.settings.keepsDeckOpen")

                LabeledContent {
                    Picker("Animation speed", selection: binding(\.animationSpeed)) {
                        Text("Fast").tag(NoticSettings.AnimationSpeed.fast)
                        Text("Normal").tag(NoticSettings.AnimationSpeed.normal)
                        Text("Slow").tag(NoticSettings.AnimationSpeed.slow)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityIdentifier("notic.settings.animationSpeed")
                } label: {
                    Text("Animation speed")
                    Text("How briskly the deck moves")
                }
            }

            Section("Visibility") {
                Toggle("Show notes above all apps", isOn: binding(\.showsAboveAllApps))
                    .accessibilityIdentifier("notic.settings.aboveAll")
                Toggle("Show over full-screen apps", isOn: binding(\.visibleOverFullScreenApps))
                    .accessibilityIdentifier("notic.settings.fullScreen")
            }

            Section("Storage") {
                LabeledContent("Notes folder") {
                    Text(workspace.notesDirectory?.path(percentEncoded: false) ?? "Default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("notic.settings.notesFolder")
                }
                HStack {
                    Button("Choose Folder…", action: chooseNotesFolder)
                        .accessibilityIdentifier("notic.settings.chooseNotesFolder")
                    Button("Show in Finder") {
                        if let directory = workspace.notesDirectory { NSWorkspace.shared.open(directory) }
                    }
                }
                Text("Changing folders copies all notes into a new Notic library. The previous library stays as a backup. Notes are stored in Notic’s database format.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Application") {
                Toggle("Show Notic in the Dock", isOn: binding(\.showsDockIcon))
                    .accessibilityIdentifier("notic.settings.dock")
                Toggle("Open Notic at login", isOn: binding(\.launchAtLogin))
                    .accessibilityIdentifier("notic.settings.launchAtLogin")
            }
        }
    }

    private var about: some View {
        pane(title: "About", subtitle: nil) {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Notic")
                            .font(.system(size: 17, weight: .semibold))
                        Text(Self.versionSummary)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("notic.settings.version")
                        Link("by Raj", destination: URL(string: "https://x.com/heyraj__")!)
                            .font(.system(size: 11, weight: .medium))
                            .accessibilityIdentifier("notic.settings.byline")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section("Privacy") {
                Text("Notes are stored in the notes folder shown in General settings. Notic makes no network requests and collects no analytics. If you choose a cloud-synced folder, its provider may upload your notes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Acknowledgements") {
                Text("Patrick Hand by Patricia Marziali is bundled under the SIL Open Font License 1.1. Other font choices use fonts installed with macOS.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The chrome every pane shares: a heading and a grouped form beneath it.
    private func pane(title: String, subtitle: String?, @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 3)
                }
                Form(content: content)
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, -20)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static var versionSummary: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<NoticSettings, Value>) -> Binding<Value> {
        Binding(
            get: { workspace.settings[keyPath: keyPath] },
            set: { value in workspace.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}

/// One row of the settings sidebar.
private struct SidebarRow: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.1 : (hovering ? 0.05 : 0)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.pressFeedback)
        .focusEffectDisabled()
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

final class SettingsWindowController: NSWindowController {
    init(workspace: NoticWorkspace, chooseNotesFolder: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 660),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Notic Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setAccessibilityIdentifier("notic.settings")
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView(workspace: workspace, chooseNotesFolder: chooseNotesFolder))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not supported")
    }

    func show() {
        presentActivating()
    }
}
