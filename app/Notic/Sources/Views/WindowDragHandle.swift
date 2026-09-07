import AppKit
import SwiftUI

/// A transparent region that moves its window when dragged, the way a title
/// bar does. Placed behind the editor's header, so clicks on the title field
/// and buttons still reach them while the empty chrome moves the note.
/// Double-clicking returns the note to its tab.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> HandleView {
        HandleView()
    }

    func updateNSView(_ nsView: HandleView, context: Context) {}

    /// Tracks the drag itself rather than handing it to `performDrag(with:)`,
    /// which returns before the drag ends and gives no mouse-up. Owning the
    /// loop means the panel knows exactly when the user lets go and where.
    final class HandleView: NSView {
        private var grabOffset: CGPoint?

        override var mouseDownCanMoveWindow: Bool { false }

        /// A title bar moves the window on the click that brings it forward;
        /// without this the first drag on a background note would be swallowed.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                grabOffset = nil
                (window as? EditorPanel)?.returnToTab()
                return
            }
            let pointer = NSEvent.mouseLocation
            grabOffset = CGPoint(x: pointer.x - window.frame.origin.x, y: pointer.y - window.frame.origin.y)
            (window as? EditorPanel)?.userDragBegan()
        }

        override func mouseDragged(with event: NSEvent) {
            guard let window, let grabOffset else { return }
            let pointer = NSEvent.mouseLocation
            let origin = CGPoint(x: pointer.x - grabOffset.x, y: pointer.y - grabOffset.y)
            if let panel = window as? EditorPanel {
                panel.userDragMoved(to: origin)
            } else {
                window.setFrameOrigin(origin)
            }
        }

        override func mouseUp(with event: NSEvent) {
            guard grabOffset != nil else { return }
            grabOffset = nil
            (window as? EditorPanel)?.userDragEnded()
        }

        override func resetCursorRects() {
            // No special cursor: macOS title bars use the arrow too.
        }
    }
}
