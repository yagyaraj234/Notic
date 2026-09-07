import AppKit
import NoticCore
import SwiftUI

/// Notic's palette. Every colour resolves per appearance so text and controls
/// stay legible in light mode, dark mode, and Increased Contrast. With the
/// pastel paper style the paper stays light in dark mode and the ink stays
/// dark on it; with adaptive paper both follow the appearance.
enum NotePalette {
    struct Swatch {
        let background: Color
        let foreground: Color
        let border: Color
        let accent: Color
        /// The pastel used for the pill dash and library colour bar: the paper
        /// colour in every appearance, since both sit on a neutral surface.
        let paper: Color
        /// Red for Delete controls, legible on this swatch's paper.
        let destructive: Color
    }

    static func swatch(for color: NoteColor, paper style: NoticSettings.PaperStyle = .pastel) -> Swatch {
        switch style {
        case .pastel:
            Swatch(
                background: fixedLight(lightBackground(color), highContrast: lightBackground(color).blended(withFraction: 0.25, of: .white)),
                foreground: fixedLight(ink, highContrast: .black),
                border: fixedLight(.init(white: 0, alpha: 0.18), highContrast: .init(white: 0, alpha: 0.7)),
                accent: Color(nsColor: darkBackground(color)),
                paper: Color(nsColor: lightBackground(color)),
                destructive: Color(nsColor: rgb(0xC62828))
            )
        case .adaptive:
            Swatch(
                background: dynamic(light: lightBackground(color), dark: darkBackground(color)),
                foreground: dynamic(light: ink, dark: rgb(0xF6F2EA), highContrastLight: .black, highContrastDark: .white),
                border: dynamic(light: .init(white: 0, alpha: 0.18), dark: .init(white: 1, alpha: 0.22), highContrastLight: .init(white: 0, alpha: 0.7), highContrastDark: .init(white: 1, alpha: 0.8)),
                accent: dynamic(light: darkBackground(color), dark: lightBackground(color)),
                paper: Color(nsColor: lightBackground(color)),
                destructive: destructive
            )
        }
    }

    /// Dark backing for small text chips drawn over the desktop.
    static let chipBackground = dynamic(
        light: .init(red: 0.24, green: 0.25, blue: 0.29, alpha: 0.78),
        dark: .init(red: 0.16, green: 0.17, blue: 0.2, alpha: 0.85),
        highContrastLight: .black,
        highContrastDark: .black
    )

    /// Red for Delete controls on neutral window surfaces.
    static let destructive = dynamic(light: rgb(0xC62828), dark: rgb(0xFF8A80))

    /// Warm off-white the library and settings windows are painted with.
    static let windowBackground = dynamic(light: rgb(0xF5F3EE), dark: rgb(0x1E1D1B))
    /// Slightly darker warm tone for the library's detail pane.
    static let paneBackground = dynamic(light: rgb(0xEEEBE4), dark: rgb(0x262523))

    /// Human-readable colour names for VoiceOver.
    static func name(for color: NoteColor) -> String {
        switch color {
        case .yellow: "Yellow"
        case .coral: "Coral"
        case .mint: "Mint"
        case .blue: "Blue"
        case .lavender: "Lavender"
        case .peach: "Peach"
        case .sage: "Sage"
        case .rose: "Rose"
        }
    }

    private static let ink = rgb(0x1F1A17)

    private static func lightBackground(_ color: NoteColor) -> NSColor {
        switch color {
        case .yellow: rgb(0xFFE27A)
        case .coral: rgb(0xFFB5A3)
        case .mint: rgb(0xB5EBD2)
        case .blue: rgb(0xBFD9FF)
        case .lavender: rgb(0xDCD0FF)
        case .peach: rgb(0xFFDCC2)
        case .sage: rgb(0xD6E8C8)
        case .rose: rgb(0xFFCCDD)
        }
    }

    private static func darkBackground(_ color: NoteColor) -> NSColor {
        switch color {
        case .yellow: rgb(0x655312)
        case .coral: rgb(0x752F22)
        case .mint: rgb(0x1C553C)
        case .blue: rgb(0x22467A)
        case .lavender: rgb(0x47387B)
        case .peach: rgb(0x6E4326)
        case .sage: rgb(0x3E5A2E)
        case .rose: rgb(0x71304A)
        }
    }

    private static func rgb(_ value: UInt32) -> NSColor {
        NSColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// The same colour in every appearance, with an Increased Contrast variant.
    private static func fixedLight(_ color: NSColor, highContrast: NSColor?) -> Color {
        dynamic(light: color, dark: color, highContrastLight: highContrast ?? color, highContrastDark: highContrast ?? color)
    }

    private static func dynamic(
        light: NSColor,
        dark: NSColor,
        highContrastLight: NSColor? = nil,
        highContrastDark: NSColor? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            // Increased Contrast switches the effective appearance, so views
            // redraw and this provider re-resolves automatically.
            let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
            switch match {
            case .darkAqua:
                return dark
            case .accessibilityHighContrastAqua:
                // Lighter backgrounds pull further from the dark foreground.
                return highContrastLight ?? light.blended(withFraction: 0.25, of: .white) ?? light
            case .accessibilityHighContrastDarkAqua:
                return highContrastDark ?? dark.blended(withFraction: 0.25, of: .black) ?? dark
            default:
                return light
            }
        })
    }
}
