import AppKit
import CoreText
import NoticCore
import SwiftUI

/// Registers the bundled handwriting font and resolves the user's font choice.
enum FontRegistry {
    /// Family name of the bundled OFL-licensed display font.
    static let handwritingFamily = "Patrick Hand"

    static func registerBundledFonts() {
        guard let fontsFolder = Bundle.main.resourceURL?.appending(path: "Fonts", directoryHint: .isDirectory),
              let files = try? FileManager.default.contentsOfDirectory(at: fontsFolder, includingPropertiesForKeys: nil)
        else { return }
        for url in files where url.pathExtension.lowercased() == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    private static func family(_ choice: NoticSettings.FontChoice) -> String? {
        switch choice {
        case .handwriting: handwritingFamily
        case .system: nil
        case .chalkboard: "Chalkboard"
        case .markerFelt: "MarkerFelt-Thin"
        case .georgia: "Georgia"
        case .menlo: "Menlo-Regular"
        }
    }

    /// AppKit counterpart of `font(_:size:relativeTo:)`, for the note body view.
    static func nsFont(_ choice: NoticSettings.FontChoice, size: CGFloat) -> NSFont {
        family(choice).flatMap { NSFont(name: $0, size: size) } ?? .systemFont(ofSize: size)
    }

    /// A font for `choice` that scales with the system text size.
    static func font(_ choice: NoticSettings.FontChoice, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        if let family = family(choice), let resolved = NSFont(name: family, size: size) {
            return .custom(resolved.fontName, size: size, relativeTo: style)
        }
        return .system(style, design: .default)
    }
}
