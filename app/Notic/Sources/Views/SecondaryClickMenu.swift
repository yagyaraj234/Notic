import AppKit
import SwiftUI

/// Attaches a secondary-click menu built in AppKit to a SwiftUI view, so the
/// dock, the deck tabs and the library rows can all show the one shared
/// `NoticMenus` definition. SwiftUI's own `contextMenu` would need a second
/// definition of every item; this keeps one.
///
/// The menu is built at click time, so it always reflects the note's current
/// colour and lifecycle.
struct SecondaryClickMenu: ViewModifier {
    let menu: () -> NSMenu
    /// Containers place their catcher *behind* their content so a child's own
    /// catcher — a deck tab's, say — is the deeper hit and answers first.
    let behind: Bool

    func body(content: Content) -> some View {
        if behind {
            content.background(MenuCatcher(menu: menu))
        } else {
            content.overlay(MenuCatcher(menu: menu))
        }
    }

    private struct MenuCatcher: NSViewRepresentable {
        let menu: () -> NSMenu

        func makeNSView(context: Context) -> CatcherView {
            let view = CatcherView()
            view.provider = menu
            return view
        }

        func updateNSView(_ view: CatcherView, context: Context) {
            view.provider = menu
        }
    }

    /// Transparent to everything but a secondary click: the pill and tabs stay
    /// clickable, hover tracking is untouched, and AppKit pops the menu itself.
    final class CatcherView: NSView {
        var provider: (() -> NSMenu)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent else { return nil }
            switch event.type {
            case .rightMouseDown, .rightMouseUp:
                return super.hitTest(point)
            case .leftMouseDown, .leftMouseUp where event.modifierFlags.contains(.control):
                return super.hitTest(point)
            default:
                return nil
            }
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            provider?()
        }
    }
}

extension View {
    /// Shows `menu` on secondary-click (or control-click) of this view.
    /// Pass `behind: true` on a container whose children carry menus of their
    /// own, so the child's menu wins where they overlap.
    func secondaryClickMenu(behind: Bool = false, _ menu: @escaping () -> NSMenu) -> some View {
        modifier(SecondaryClickMenu(menu: menu, behind: behind))
    }
}
