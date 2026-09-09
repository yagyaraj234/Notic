import Foundation

/// Locally persisted preferences.
public nonisolated struct NoticSettings: Codable, Equatable, Sendable {
    public enum FontChoice: String, Codable, Sendable, CaseIterable {
        /// The bundled handwriting-style display font.
        case handwriting
        /// The macOS system font, for maximum legibility.
        case system
        case chalkboard
        case markerFelt
        case georgia
        case menlo

        public var title: String {
            switch self {
            case .handwriting: "Patrick Hand"
            case .system: "System font"
            case .chalkboard: "Chalkboard"
            case .markerFelt: "Marker Felt"
            case .georgia: "Georgia"
            case .menlo: "Menlo"
            }
        }
    }

    /// How note paper responds to the system appearance.
    public enum PaperStyle: String, Codable, Sendable, CaseIterable {
        /// Always the light pastel paper, in light and dark mode alike.
        case pastel
        /// Darker paper in dark mode, matching the rest of the desktop.
        case adaptive
    }

    /// A multiplier over every duration in Notic's motion vocabulary. It
    /// scales motion; it never changes which curve is used.
    public enum AnimationSpeed: String, Codable, Sendable, CaseIterable {
        case fast
        case normal
        case slow

        public var multiplier: Double {
            switch self {
            case .fast: 0.6
            case .normal: 1
            case .slow: 1.5
            }
        }
    }

    /// What it takes to fan the dock out into the deck.
    public enum FanTrigger: String, Codable, Sendable, CaseIterable {
        /// Sustained hover, after `openDelay`.
        case hover
        /// Only an explicit click on the dock.
        case click
    }

    /// Body text sizes offered for notes, in points.
    public static let textSizeOptions = [15, 18, 21, 24, 28]
    /// How long the pointer may be asked to rest on the dock, in seconds.
    public static let openDelayRange = 0.0...0.6
    /// The granularity the open-delay slider moves in, in seconds.
    public static let openDelayStep = 0.02

    public var fontChoice: FontChoice = .handwriting
    public var paperStyle: PaperStyle = .pastel
    /// Body text size in points. Always one of `textSizeOptions`.
    public var textSize = 21
    /// Tabs in the fanned deck lean a degree or two, like paper tabs do.
    public var tiltsTabs = true
    /// How long the pointer rests on the dock before the deck fans.
    public var openDelay = NoticTiming.hoverExpandDelay
    public var animationSpeed: AnimationSpeed = .normal
    public var fanTrigger: FanTrigger = .hover
    public var stackPosition: ScreenEdge = .right
    /// Normalized position along the edge, measured from the bottom or left.
    public var stackOffset: Double = 0.5
    /// The deck stays fanned at the edge instead of resting as the dock.
    public var keepsDeckOpen = false
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
        textSize = try container.decodeIfPresent(Int.self, forKey: .textSize) ?? defaults.textSize
        tiltsTabs = try container.decodeIfPresent(Bool.self, forKey: .tiltsTabs) ?? defaults.tiltsTabs
        openDelay = try container.decodeIfPresent(TimeInterval.self, forKey: .openDelay) ?? defaults.openDelay
        animationSpeed = try container.decodeIfPresent(AnimationSpeed.self, forKey: .animationSpeed) ?? defaults.animationSpeed
        fanTrigger = try container.decodeIfPresent(FanTrigger.self, forKey: .fanTrigger) ?? defaults.fanTrigger
        stackPosition = try container.decodeIfPresent(ScreenEdge.self, forKey: .stackPosition) ?? defaults.stackPosition
        stackOffset = try container.decodeIfPresent(Double.self, forKey: .stackOffset) ?? defaults.stackOffset
        keepsDeckOpen = try container.decodeIfPresent(Bool.self, forKey: .keepsDeckOpen) ?? defaults.keepsDeckOpen
        showsDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showsDockIcon) ?? defaults.showsDockIcon
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showsAboveAllApps = try container.decodeIfPresent(Bool.self, forKey: .showsAboveAllApps) ?? defaults.showsAboveAllApps
        visibleOverFullScreenApps = try container.decodeIfPresent(Bool.self, forKey: .visibleOverFullScreenApps) ?? defaults.visibleOverFullScreenApps
        hasCreatedFirstNote = try container.decodeIfPresent(Bool.self, forKey: .hasCreatedFirstNote) ?? defaults.hasCreatedFirstNote
        // A hand-edited or future-written file must never leave the app in a
        // state its own controls cannot represent.
        clampToSupportedValues()
    }

    /// Snaps the numeric preferences back onto the values Notic supports.
    public mutating func clampToSupportedValues() {
        if !Self.textSizeOptions.contains(textSize) {
            textSize = Self.textSizeOptions.min {
                (abs($0 - textSize), $0) < (abs($1 - textSize), $1)
            } ?? 21
        }
        stackOffset = stackOffset.isFinite ? min(max(stackOffset, 0), 1) : 0.5
        openDelay = min(max(openDelay, Self.openDelayRange.lowerBound), Self.openDelayRange.upperBound)
    }
}
