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

    /// AppKit counterpart of `font(_:size:relativeTo:)`, for the note body view.
    static func nsFont(_ choice: NoticSettings.FontChoice, size: CGFloat) -> NSFont {
        switch choice {
        case .handwriting:
            NSFont(name: handwritingFamily, size: size) ?? .systemFont(ofSize: size)
        case .system:
            .systemFont(ofSize: size)
        }
    }

    /// A font for `choice` that scales with the system text size.
    static func font(_ choice: NoticSettings.FontChoice, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        switch choice {
        case .handwriting:
            .custom(handwritingFamily, size: size, relativeTo: style)
        case .system:
            .system(style, design: .default)
        }
    }
}
