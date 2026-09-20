import AppKit
import NoticCore
import SwiftUI

/// Plain-text note body that treats GitHub-style task lines as real to-dos:
/// a gutter checkbox for each `- [ ]` / `- [x]` line, typed shorthands
/// (`[] `, `[x] `) become the canonical marker, and Return continues the list.
struct NoteBodyEditor: NSViewRepresentable {
    var text: String
    var font: NSFont
    var ink: NSColor
    var onChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = BodyScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let textView = BodyTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.onToggle = { [weak coordinator = context.coordinator] offset in
            coordinator?.toggle(at: offset)
        }
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 5
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.setAccessibilityIdentifier("notic.editor.body")
        textView.setAccessibilityLabel("Note body")

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.apply(text: text, font: font, ink: ink, notify: false)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.onChange = onChange
        context.coordinator.apply(text: text, font: font, ink: ink, notify: false)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var onChange: (String) -> Void
        weak var textView: BodyTextView?
        /// Last string we pushed into the workspace, so an echo update does
        /// not reset the insertion point.
        private var lastPosted = ""

        init(onChange: @escaping (String) -> Void) {
            self.onChange = onChange
        }

        func apply(text: String, font: NSFont, ink: NSColor, notify: Bool) {
            guard let textView else { return }
            textView.ink = ink
            textView.typingFont = font
            textView.insertionPointColor = ink
            textView.selectedTextAttributes = [
                .backgroundColor: ink.withAlphaComponent(0.18),
                .foregroundColor: ink,
            ]
            if textView.string != text {
                let selected = textView.selectedRange()
                textView.string = text
                let length = (text as NSString).length
                textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))
            }
            textView.applyTaskStyling()
            lastPosted = text
            if notify { onChange(text) }
        }

        func toggle(at offset: Int) {
            guard let textView else { return }
            let next = TaskMarkup.toggling(lineContaining: offset, in: textView.string)
            textView.replaceBody(with: next, cursor: textView.selectedRange().location)
        }

        func insertTask() {
            guard let textView else { return }
            let cursor = textView.selectedRange().location
            let result = TaskMarkup.insertingTask(at: cursor, in: textView.string)
            textView.replaceBody(with: result.text, cursor: result.cursor)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            let raw = textView.string
            let cursor = textView.selectedRange().location
            let canonical = TaskMarkup.canonicalized(raw, cursor: cursor)
            if canonical.text != raw, textView.undoManager?.isUndoing != true,
               textView.undoManager?.isRedoing != true {
                textView.replaceBody(with: canonical.text, cursor: canonical.cursor)
                return
            }
            textView.applyTaskStyling()
            if raw != lastPosted {
                lastPosted = raw
                onChange(raw)
            }
        }
    }

    /// Keep blank space below short notes inside the clickable text view.
    final class BodyScrollView: NSScrollView {
        override func tile() {
            super.tile()
            guard let textView = documentView as? NSTextView else { return }
            textView.minSize = contentSize
            if textView.frame.height < contentSize.height {
                textView.setFrameSize(NSSize(width: contentSize.width, height: contentSize.height))
            }
        }
    }

    /// The text view itself: gutter checkboxes, Return continues a task list.
    final class BodyTextView: NSTextView {
        var ink: NSColor = .textColor
        var typingFont: NSFont = .systemFont(ofSize: 21)
        var onToggle: ((Int) -> Void)?
        private var taskControls: [Int: TaskCheckbox] = [:]

        override func accessibilityChildren() -> [Any]? {
            (super.accessibilityChildren() ?? []) + taskControls.sorted { $0.key < $1.key }.map(\.value)
        }

        nonisolated final class TaskCheckbox: NSAccessibilityElement {
            let frame: @MainActor @Sendable () -> NSRect
            let press: @MainActor @Sendable () -> Bool

            init(frame: @escaping @MainActor @Sendable () -> NSRect,
                 press: @escaping @MainActor @Sendable () -> Bool) {
                self.frame = frame
                self.press = press
                super.init()
            }

            override func accessibilityFrame() -> NSRect {
                MainActor.assumeIsolated(frame)
            }

            override func accessibilityPerformPress() -> Bool {
                MainActor.assumeIsolated(press)
            }
        }

        private func updateTaskAccessibility() {
            let markers = taskMarkers()
            let offsets = Set(markers.map { $0.range.lowerBound })
            taskControls = taskControls.filter { offsets.contains($0.key) }
            let ns = string as NSString
            for marker in markers {
                let offset = marker.range.lowerBound
                let control = taskControls[offset] ?? TaskCheckbox(frame: { [weak self] in
                    guard let self, let window,
                          let marker = TaskMarkup.marker(onLineContaining: offset, in: string),
                          let layout = layoutManager, let container = textContainer else { return .zero }
                    let rect = checkboxRect(for: marker, layout: layout, container: container, origin: textContainerOrigin)
                    return window.convertToScreen(convert(rect, to: nil))
                }, press: { [weak self] in
                    guard let self, let control = taskControls[offset],
                          TaskMarkup.marker(onLineContaining: offset, in: string) != nil else { return false }
                    onToggle?(offset)
                    NSAccessibility.post(element: control, notification: .valueChanged)
                    return true
                })
                control.setAccessibilityElement(true)
                control.setAccessibilityEnabled(true)
                control.setAccessibilityIdentifier("notic.task.\(offset)")
                control.setAccessibilityParent(self)
                control.setAccessibilityRole(.checkBox)
                control.setAccessibilityValue(marker.isChecked ? 1 : 0)
                let line = ns.lineRange(for: NSRange(location: offset, length: 0))
                let title = ns.substring(with: NSRange(location: marker.range.upperBound, length: NSMaxRange(line) - marker.range.upperBound))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                control.setAccessibilityLabel(title.isEmpty ? "To-do" : title)
                control.setAccessibilityHelp("Toggle to-do. In the text editor, press Command-Return.")
                taskControls[offset] = control
            }
        }

        override var acceptsFirstResponder: Bool { true }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func insertNewline(_ sender: Any?) {
            let cursor = selectedRange().location
            if let edit = TaskMarkup.newline(at: cursor, in: string) {
                if shouldChangeText(in: NSRange(location: edit.replace.lowerBound, length: edit.replace.count), replacementString: edit.with) {
                    replaceCharacters(in: NSRange(location: edit.replace.lowerBound, length: edit.replace.count), with: edit.with)
                    didChangeText()
                    setSelectedRange(NSRange(location: edit.replace.lowerBound + (edit.with as NSString).length, length: 0))
                }
                return
            }
            super.insertNewline(sender)
        }

        override func keyDown(with event: NSEvent) {
            let modifiers = event.modifierFlags.intersection([.command, .shift, .control, .option])
            if event.keyCode == 36, modifiers == .command {
                onToggle?(selectedRange().location)
                return
            }
            // ⌘⇧T turns the current line into a to-do (or adds another).
            if event.modifierFlags.contains(.command), event.modifierFlags.contains(.shift),
               event.charactersIgnoringModifiers == "t" {
                let result = TaskMarkup.insertingTask(at: selectedRange().location, in: string)
                replaceBody(with: result.text, cursor: result.cursor)
                return
            }
            super.keyDown(with: event)
        }

        func replaceBody(with text: String, cursor: Int) {
            guard text != string else { return }
            breakUndoCoalescing()
            insertText(text, replacementRange: NSRange(location: 0, length: (string as NSString).length))
            setSelectedRange(NSRange(location: min(cursor, (string as NSString).length), length: 0))
            breakUndoCoalescing()
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeKey()
            window?.makeFirstResponder(self)
            let point = convert(event.locationInWindow, from: nil)
            if let offset = taskOffset(at: point) {
                onToggle?(offset)
                return
            }
            super.mouseDown(with: event)
        }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            drawCheckboxes()
        }

        /// Clears the markdown boxes and strikes through completed items so
        /// the gutter control is what the user acts on.
        func applyTaskStyling() {
            guard let storage = textStorage else { return }
            let ns = string as NSString
            let full = NSRange(location: 0, length: ns.length)
            storage.beginEditing()
            storage.addAttributes([
                .font: typingFont,
                .foregroundColor: ink,
                .strikethroughStyle: 0,
                .strikethroughColor: ink.withAlphaComponent(0.55),
            ], range: full)
            var location = 0
            while location <= ns.length {
                let line = ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0))
                if let marker = TaskMarkup.marker(onLineContaining: line.location, in: string) {
                    let markerNS = NSRange(location: marker.range.lowerBound, length: marker.range.count)
                    storage.addAttributes([
                        .foregroundColor: NSColor.clear,
                        .kern: -0.2,
                    ], range: markerNS)
                    if marker.isChecked {
                        let rest = NSRange(
                            location: marker.range.upperBound,
                            length: max(0, line.location + line.length - marker.range.upperBound)
                        )
                        if rest.length > 0 {
                            storage.addAttributes([
                                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                .foregroundColor: ink.withAlphaComponent(0.45),
                            ], range: rest)
                        }
                    }
                }
                let next = line.location + line.length
                if next <= location { break }
                location = next
                if location >= ns.length { break }
            }
            storage.endEditing()
            updateTaskAccessibility()
            typingAttributes = [
                .font: typingFont,
                .foregroundColor: ink,
            ]
            needsDisplay = true
        }

        /// Character offset of the task whose box contains `point`.
        private func taskOffset(at point: NSPoint) -> Int? {
            guard let layout = layoutManager, let container = textContainer else { return nil }
            let origin = textContainerOrigin
            for marker in taskMarkers() {
                let box = checkboxRect(for: marker, layout: layout, container: container, origin: origin)
                if box.insetBy(dx: -4, dy: -3).contains(point) {
                    return marker.range.lowerBound
                }
            }
            return nil
        }

        private func drawCheckboxes() {
            guard let layout = layoutManager, let container = textContainer else { return }
            let origin = textContainerOrigin
            for marker in taskMarkers() {
                let box = checkboxRect(for: marker, layout: layout, container: container, origin: origin)
                let path = NSBezierPath(roundedRect: box, xRadius: 3.5, yRadius: 3.5)
                if marker.isChecked {
                    ink.withAlphaComponent(0.8).setFill()
                    path.fill()
                    let check = NSAttributedString(
                        string: "✓",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                            .foregroundColor: NSColor.white,
                        ]
                    )
                    let size = check.size()
                    check.draw(at: NSPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2 - 0.5))
                } else {
                    ink.withAlphaComponent(0.45).setStroke()
                    path.lineWidth = 1.4
                    path.stroke()
                }
            }
        }

        private func taskMarkers() -> [TaskMarkup.Marker] {
            let ns = string as NSString
            var markers: [TaskMarkup.Marker] = []
            var location = 0
            while location <= ns.length {
                let line = ns.lineRange(for: NSRange(location: min(location, ns.length), length: 0))
                if let marker = TaskMarkup.marker(onLineContaining: line.location, in: string) {
                    markers.append(marker)
                }
                let next = line.location + line.length
                if next <= location { break }
                location = next
                if location >= ns.length { break }
            }
            return markers
        }

        /// Sits over the hidden `- [ ] ` / `- [x] ` marker, inside the text
        /// container — NSTextView clips drawing in the inset, so a gutter
        /// box would never appear.
        private func checkboxRect(for marker: TaskMarkup.Marker, layout: NSLayoutManager, container: NSTextContainer, origin: NSPoint) -> NSRect {
            let characters = NSRange(location: marker.range.lowerBound, length: marker.range.count)
            let glyphs = layout.glyphRange(forCharacterRange: characters, actualCharacterRange: nil)
            let used = layout.boundingRect(forGlyphRange: glyphs, in: container)
            let size: CGFloat = 13
            return NSRect(
                x: used.minX + origin.x + 2,
                y: used.minY + origin.y + max(0, (used.height - size) / 2),
                width: size,
                height: size
            )
        }
    }
}

/// Lets the footer button reach the text view hosted in this editor.
enum NoteBodyEditorBridge {
    /// Walks the key window for the note body and inserts a to-do there.
    @MainActor
    static func focusKeyEditor() {
        guard let view = findBodyTextView(in: NSApp.keyWindow?.contentView) else { return }
        view.window?.makeFirstResponder(view)
    }

    static func insertTaskInKeyEditor() {
        guard let view = findBodyTextView(in: NSApp.keyWindow?.contentView) else { return }
        let result = TaskMarkup.insertingTask(at: view.selectedRange().location, in: view.string)
        view.replaceBody(with: result.text, cursor: result.cursor)
        view.window?.makeFirstResponder(view)
    }

    private static func findBodyTextView(in view: NSView?) -> NoteBodyEditor.BodyTextView? {
        guard let view else { return nil }
        if let body = view as? NoteBodyEditor.BodyTextView { return body }
        for child in view.subviews {
            if let found = findBodyTextView(in: child) { return found }
        }
        return nil
    }
}
