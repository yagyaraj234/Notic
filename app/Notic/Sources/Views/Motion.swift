import AppKit
import NoticCore
import SwiftUI

/// Notic's motion vocabulary. Pointer peeks use a 120ms ease-out; springs
/// remain the default for layout and gestures so any transition can be
/// interrupted and re-targeted from its live value; critically damped by
/// default, with overshoot reserved for motion the user's own gesture
/// carried momentum into.
enum Motion {
    /// Scales every duration Notic hands out. Set from the Animation speed
    /// preference; the curves themselves never change.
    static var speed: Double = NoticSettings.AnimationSpeed.normal.multiplier

    /// Applies the animation-speed preference to a duration.
    static func scaled(_ duration: TimeInterval) -> TimeInterval {
        duration * speed
    }

    /// The deck fanning out of the dock.
    static var deckDuration: TimeInterval { scaled(0.2) }
    /// Folding back is the system getting out of the way rather than the user
    /// deciding, so it is shorter than the fan.
    static var deckExitDuration: TimeInterval { scaled(0.14) }

    /// The deck sliding out of, or back into, the screen edge. Strong ease-out
    /// in both directions: the travel starts at full speed, where the pointer
    /// is already looking. Driven by the deck's offset rather than by its
    /// insertion, so a fan interrupted halfway retargets from where it is.
    static func deck(fanning: Bool, reduceMotion: Bool) -> Animation {
        let duration = fanning ? deckDuration : deckExitDuration
        return reduceMotion
            ? .easeOut(duration: duration)
            : .timingCurve(0.23, 1, 0.32, 1, duration: duration)
    }

    /// Response of the everyday settle: reflow and gesture release.
    static var response: TimeInterval { scaled(0.32) }

    /// Critically damped: no overshoot. Use for anything that appears or
    /// re-lays out without a gesture behind it.
    static func settle(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: scaled(0.15)) : .spring(duration: response, bounce: 0)
    }

    /// Pointer peeks: 2–6pt travel that must finish before the 120ms fan delay.
    /// Strong ease-out (starts fast). Not a spring — springs belong on layout.
    static func hover(reduceMotion: Bool) -> Animation {
        // cubic-bezier(0.23, 1, 0.32, 1), 120ms — hover budget is 100–160ms
        reduceMotion
            ? .easeOut(duration: scaled(0.12))
            : .timingCurve(0.23, 1, 0.32, 1, duration: scaled(0.12))
    }

    /// Press scale/opacity. 160ms critically damped spring.
    static func press(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: scaled(0.12)) : .spring(duration: scaled(0.16), bounce: 0)
    }

    /// Recolour a surface that is already on screen.
    /// cubic-bezier(0.77, 0, 0.175, 1), 200ms.
    static func recolor(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: scaled(0.15))
            : .timingCurve(0.77, 0, 0.175, 1, duration: scaled(0.2))
    }

    /// A spring that continues at the gesture's release velocity. SwiftUI's
    /// interpolating spring takes velocity relative to the remaining
    /// distance, so callers pass `gestureVelocity / (target - current)`.
    static func handoff(relativeVelocity: Double, reduceMotion: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: scaled(0.15)) }
        // stiffness 200 / mass 1 is critically damped at ~28.3; 24 is a
        // damping ratio of ~0.85, a little bounce for a thrown tab.
        return .interpolatingSpring(mass: 1, stiffness: 200, damping: 24, initialVelocity: relativeVelocity)
    }

    /// Where a flick would come to rest under scroll-style deceleration
    /// (`velocity` in points per second).
    static func project(velocity: CGFloat, decelerationRate: CGFloat = 0.998) -> CGFloat {
        (velocity / 1000) * decelerationRate / (1 - decelerationRate)
    }

    /// Progressive resistance past a boundary: the further past the edge, the
    /// less the element follows.
    static func rubberband(_ overshoot: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        (overshoot * dimension * constant) / (dimension + constant * abs(overshoot))
    }

    /// AppKit editor enter / return-to-tab. Same curve the panel already uses.
    static let panelEnter = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
    /// Inverse of `panelEnter`. Do not restyle — the inverse exit is deliberate.
    static let panelExit = CAMediaTimingFunction(controlPoints: 0.7, 0, 0.8, 0.1)

    /// AppKit-side reduce-motion check for panel-level animation.
    static var systemReducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

/// Feedback on press, not on release: a small scale and dim the instant the
/// pointer goes down, springing back when it lifts.
struct PressFeedbackStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressFeedbackStyle {
    static var pressFeedback: PressFeedbackStyle { PressFeedbackStyle() }
}
