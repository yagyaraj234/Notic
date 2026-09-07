import Foundation

/// Markdown task-list markup inside a note body. Notes stay plain text: a
/// line beginning with `- [ ] ` is an open task and `- [x] ` a completed one,
/// which is what Bear, Obsidian, GitHub, and most Markdown tools understand.
/// All offsets are UTF-16, matching `NSString` and the text system.
public nonisolated enum TaskMarkup {
    public static let unchecked = "- [ ] "
    public static let checked = "- [x] "

    public struct Marker: Equatable, Sendable {
        /// The marker text itself, excluding any indentation before it.
        public let range: Range<Int>
        public let isChecked: Bool
    }

    public struct Edit: Equatable, Sendable {
        public let replace: Range<Int>
        public let with: String

        public init(replace: Range<Int>, with: String) {
            self.replace = replace
            self.with = with
        }
    }

    public struct Progress: Equatable, Sendable {
        public let done: Int
        public let total: Int

        public init(done: Int, total: Int) {
            self.done = done
            self.total = total
        }
    }

    // `- [ ] ` or `- [x] ` after optional indentation.
    private static let canonicalPattern = try! NSRegularExpression(pattern: #"^[ \t]*(- \[( |x|X)\] )"#)
    // Shorthands worth accepting as typed: `[] `, `[ ] `, `[x] `, `* [ ] `.
    private static let shorthandPattern = try! NSRegularExpression(pattern: #"^([ \t]*)(?:\* )?\[( |x|X)?\] "#)

    /// The task marker on the line containing `offset`, if the line is a task.
    public static func marker(onLineContaining offset: Int, in text: String) -> Marker? {
        let ns = text as NSString
        let line = ns.lineRange(for: NSRange(location: min(offset, ns.length), length: 0))
        return marker(inLine: line, of: ns)
    }

    private static func marker(inLine line: NSRange, of ns: NSString) -> Marker? {
        guard let match = canonicalPattern.firstMatch(in: ns as String, range: line) else { return nil }
        let markerRange = match.range(at: 1)
        let box = ns.substring(with: match.range(at: 2))
        return Marker(range: markerRange.location..<(markerRange.location + markerRange.length), isChecked: box != " ")
    }

    /// Flips the box on the line containing `offset`.
    public static func toggling(lineContaining offset: Int, in text: String) -> String {
        guard let marker = marker(onLineContaining: offset, in: text) else { return text }
        return replacing(marker.range, in: text, with: marker.isChecked ? unchecked : checked)
    }

    /// Adds an open box to the line containing `offset`, or removes whatever
    /// box it has.
    public static func settingTask(_ isTask: Bool, onLineContaining offset: Int, in text: String) -> String {
        let existing = marker(onLineContaining: offset, in: text)
        switch (isTask, existing) {
        case (true, nil):
            let ns = text as NSString
            let line = ns.lineRange(for: NSRange(location: min(offset, ns.length), length: 0))
            let indent = leadingWhitespace(ofLine: line, in: ns)
            return replacing(indent..<indent, in: text, with: unchecked)
        case (false, let marker?):
            return replacing(marker.range, in: text, with: "")
        default:
            return text
        }
    }

    /// Rewrites typed shorthands (`[] `, `[ ] `, `[x] `, `* [ ] `) at the
    /// start of a line into the canonical marker, shifting `cursor` for any
    /// growth that happens before it.
    public static func canonicalized(_ text: String, cursor: Int) -> (text: String, cursor: Int) {
        let ns = text as NSString
        var result = text
        var cursor = cursor
        var delta = 0
        for line in lineRanges(of: ns) {
            guard let match = shorthandPattern.firstMatch(in: text, range: line) else { continue }
            let full = match.range
            let indentLength = match.range(at: 1).length
            let boxRange = match.range(at: 2)
            let isChecked = boxRange.location != NSNotFound && ns.substring(with: boxRange).lowercased() == "x"
            let replacement = isChecked ? checked : unchecked
            let shorthandStart = full.location + indentLength
            let shorthandRange = (shorthandStart + delta)..<(full.location + full.length + delta)
            result = replacing(shorthandRange, in: result, with: replacement)
            let growth = (replacement as NSString).length - (full.length - indentLength)
            if cursor >= full.location + full.length + delta {
                cursor += growth
            } else if cursor > shorthandStart + delta {
                // Cursor inside the shorthand: park it after the new marker.
                cursor = shorthandStart + delta + (replacement as NSString).length
            }
            delta += growth
        }
        return (result, cursor)
    }

    /// What pressing Return at `cursor` should do on a task line: continue the
    /// list with a fresh open box, or, on an item with no text, end the list
    /// by removing the box. `nil` means the line is not a task; insert a
    /// newline as usual.
    public static func newline(at cursor: Int, in text: String) -> Edit? {
        guard let marker = marker(onLineContaining: cursor, in: text) else { return nil }
        let ns = text as NSString
        let line = ns.lineRange(for: NSRange(location: min(cursor, ns.length), length: 0))
        var content = ns.substring(with: NSRange(location: marker.range.upperBound, length: line.location + line.length - marker.range.upperBound))
        if content.hasSuffix("\n") { content.removeLast() }
        if content.isEmpty {
            return Edit(replace: marker.range, with: "")
        }
        return Edit(replace: cursor..<cursor, with: "\n" + unchecked)
    }

    /// The body with markers drawn as boxes, for previews and lists.
    public static func preview(_ text: String) -> String {
        let ns = text as NSString
        var result = text
        var delta = 0
        for line in lineRanges(of: ns) {
            guard let marker = marker(inLine: line, of: ns) else { continue }
            let range = (marker.range.lowerBound + delta)..<(marker.range.upperBound + delta)
            let glyph = marker.isChecked ? "☑ " : "☐ "
            result = replacing(range, in: result, with: glyph)
            delta += (glyph as NSString).length - marker.range.count
        }
        return result
    }

    /// Turns the line containing `cursor` into an open task, or, if it already
    /// is one, inserts a fresh open task on the next line. Used by the editor's
    /// Add to-do control.
    public static func insertingTask(at cursor: Int, in text: String) -> (text: String, cursor: Int) {
        if text.isEmpty {
            return (unchecked, (unchecked as NSString).length)
        }
        if marker(onLineContaining: cursor, in: text) != nil {
            let ns = text as NSString
            let line = ns.lineRange(for: NSRange(location: min(cursor, ns.length), length: 0))
            let end = line.location + line.length
            let lineText = ns.substring(with: line)
            if lineText.hasSuffix("\n") {
                let inserted = replacing(end..<end, in: text, with: unchecked)
                return (inserted, end + (unchecked as NSString).length)
            }
            let inserted = replacing(end..<end, in: text, with: "\n" + unchecked)
            return (inserted, end + 1 + (unchecked as NSString).length)
        }
        let made = settingTask(true, onLineContaining: cursor, in: text)
        if let marker = marker(onLineContaining: cursor + (unchecked as NSString).length, in: made)
            ?? marker(onLineContaining: cursor, in: made) {
            return (made, marker.range.upperBound)
        }
        return (made, cursor)
    }

    /// How many tasks are done, or `nil` when the body has none.
    public static func progress(in text: String) -> Progress? {
        let ns = text as NSString
        var done = 0
        var total = 0
        for line in lineRanges(of: ns) {
            guard let marker = marker(inLine: line, of: ns) else { continue }
            total += 1
            if marker.isChecked { done += 1 }
        }
        return total == 0 ? nil : Progress(done: done, total: total)
    }

    // MARK: Helpers

    private static func lineRanges(of ns: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = 0
        while location < ns.length {
            let line = ns.lineRange(for: NSRange(location: location, length: 0))
            ranges.append(line)
            location = line.location + line.length
        }
        return ranges
    }

    private static func leadingWhitespace(ofLine line: NSRange, in ns: NSString) -> Int {
        var index = line.location
        let end = line.location + line.length
        while index < end, let scalar = Unicode.Scalar(ns.character(at: index)), scalar == " " || scalar == "\t" {
            index += 1
        }
        return index
    }

    private static func replacing(_ range: Range<Int>, in text: String, with replacement: String) -> String {
        (text as NSString).replacingCharacters(in: NSRange(location: range.lowerBound, length: range.count), with: replacement)
    }
}
