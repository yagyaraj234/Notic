import AppKit

/// Notic is a menu-bar utility, so the application is run directly with an
/// AppKit delegate rather than through a SwiftUI scene.
@main
enum NoticApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
