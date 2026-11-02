import Foundation

/// Reads Markdown or plain-text files back into notes; the inverse of `NoteExport`.
public nonisolated enum NoteImport {
    /// A leading `# Heading` becomes the title (what export writes); otherwise
    /// the file name does.
    public static func note(fileName: String, contents: String) -> (title: String, body: String) {
        let text = contents.replacingOccurrences(of: "\r\n", with: "\n")
        if text.hasPrefix("# "), let end = text.firstIndex(of: "\n") ?? Optional(text.endIndex) {
            let title = text[text.index(text.startIndex, offsetBy: 2)..<end].trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                let body = text[end...].drop { $0 == "\n" }
                return (title, String(body).trimmingCharacters(in: .newlines))
            }
        }
        return ((fileName as NSString).deletingPathExtension, text.trimmingCharacters(in: .newlines))
    }
}
