import Foundation

/// Locally persisted preferences.
public nonisolated struct NoticSettings: Codable, Equatable, Sendable {
    public enum FontChoice: String, Codable, Sendable, CaseIterable {
        /// The bundled handwriting-style display font.
        case handwriting
        /// The macOS system font, for maximum legibility.
        case system
    }

    /// How note paper responds to the system appearance.
    public enum PaperStyle: String, Codable, Sendable, CaseIterable {
        /// Always the light pastel paper, in light and dark mode alike.
        case pastel
        /// Darker paper in dark mode, matching the rest of the desktop.
        case adaptive
    }

    public var fontChoice: FontChoice = .handwriting
    public var paperStyle: PaperStyle = .pastel
    /// Tabs in the fanned deck lean a degree or two, like paper tabs do.
    public var tiltsTabs = true
    public var showsDockIcon = false
    public var launchAtLogin = false
    public var showsAboveAllApps = false
    public var visibleOverFullScreenApps = false
    /// Cleared once the user has created a note; drives the first-run prompt.
    public var hasCreatedFirstNote = false

    public init() {}

    // Every key is optional when decoding so a settings file written by an
    // earlier version, before a preference existed, keeps its other values.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NoticSettings()
        fontChoice = try container.decodeIfPresent(FontChoice.self, forKey: .fontChoice) ?? defaults.fontChoice
        paperStyle = try container.decodeIfPresent(PaperStyle.self, forKey: .paperStyle) ?? defaults.paperStyle
        tiltsTabs = try container.decodeIfPresent(Bool.self, forKey: .tiltsTabs) ?? defaults.tiltsTabs
        showsDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? defaults.showsDockIcon
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showsAboveAllApps = try container.decodeIfPresent(Bool.self, forKey: .showsAboveAllApps) ?? defaults.showsAboveAllApps
        visibleOverFullScreenApps = try container.decodeIfPresent(Bool.self, forKey: .visibleOverFullScreenApps) ?? defaults.visibleOverFullScreenApps
        hasCreatedFirstNote = try container.decodeIfPresent(Bool.self, forKey: .hasCreatedFirstNote) ?? defaults.hasCreatedFirstNote
    }
}
