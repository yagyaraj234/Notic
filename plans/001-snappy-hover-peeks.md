# 001 — Use a 120ms hover curve for pill and tab peeks

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: HIGH
- **Category**: Purpose & frequency / Easing & duration
- **Estimated scope**: 3 files, small

## Problem

The 2pt pill peek and the 6pt tab peek — both hit tens of times a day, every
time the pointer approaches the edge — are driven by `Motion.settle`, a
**320ms** critically damped spring meant for fan, collapse, and reflow.

The dormant pill is supposed to answer the pointer *before* the deck fans.
Fan delay is `NoticTiming.hoverExpandDelay` = **0.120s**. A 320ms peek is
still in flight when the pill is replaced by the deck, so the anticipation
never finishes.

```swift
/* app/Notic/Sources/Views/Motion.swift:8-16 — current */
/// Response of the everyday settle: fan, collapse, reflow.
static let response: TimeInterval = 0.32

static func settle(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: response, bounce: 0)
}
```

```swift
/* app/Notic/Sources/Views/EdgeSurfaceView.swift:58-61 — current */
// Respond on approach, before the fan delay elapses: the stripe
// eases off the edge in the direction the deck will come from.
.offset(x: hovering && !reduceMotion ? -2 : 0)
.animation(Motion.settle(reduceMotion: reduceMotion), value: hovering)
```

```swift
/* app/Notic/Sources/Views/DeckView.swift:360-365 — current */
// Hint toward the pull-out: the tab eases off the edge under the pointer.
.offset(x: hovering && !isOpen && !isLifted && !reduceMotion ? -6 : 0)
.scaleEffect(isLifted && !reduceMotion ? 1.04 : 1, anchor: .trailing)
.animation(Motion.settle(reduceMotion: reduceMotion), value: hovering)
.animation(Motion.settle(reduceMotion: reduceMotion), value: isLifted)
.animation(Motion.settle(reduceMotion: reduceMotion), value: isOpen)
```

## Target

Add a hover token to `Motion` and use it **only** on the two peek
`.animation(..., value: hovering)` call sites. Offsets stay −2pt (pill) and
−6pt (tab). Reduce Motion still zeros the offset; the new curve is for
pointer users.

```swift
/* app/Notic/Sources/Views/Motion.swift — add next to settle */
/// Pointer peeks: 2–6pt travel that must finish before the 120ms fan delay.
/// Strong ease-out (starts fast). Not a spring — springs belong on layout.
static func hover(reduceMotion: Bool) -> Animation {
    // cubic-bezier(0.23, 1, 0.32, 1), 120ms — hover budget is 100–160ms
    reduceMotion
        ? .easeOut(duration: 0.12)
        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
}
```

```swift
/* app/Notic/Sources/Views/EdgeSurfaceView.swift — peek only */
.offset(x: hovering && !reduceMotion ? -2 : 0)
.animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
```

```swift
/* app/Notic/Sources/Views/DeckView.swift — peek only; leave lift/open on settle */
.offset(x: hovering && !isOpen && !isLifted && !reduceMotion ? -6 : 0)
.scaleEffect(isLifted && !reduceMotion ? 1.04 : 1, anchor: .trailing)
.animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
.animation(Motion.settle(reduceMotion: reduceMotion), value: isLifted)
.animation(Motion.settle(reduceMotion: reduceMotion), value: isOpen)
```

Do not change `Motion.response`, `settle`, `momentum`, `handoff`, or any
other `.animation(Motion.settle, …)` site.

## Repo conventions to follow

- Motion lives in `app/Notic/Sources/Views/Motion.swift` as static functions
  that take `reduceMotion: Bool`. Call sites pass
  `@Environment(\.accessibilityReduceMotion)`.
- Exemplar of a short, non-layout curve already in this file:
  `PressFeedbackStyle` uses `.spring(duration: 0.16, bounce: 0)` for press —
  160ms, no bounce. Hover is even shorter and uses a timing curve, not a
  spring, because it is a pointer peek rather than a press or a reflow.
- Chrome color hovers elsewhere already use `.easeOut(duration: 0.12)`
  (`EditorView.swift` `WindowDot` / `ChromeButton`). The new token matches
  that duration so peeks and color hovers feel like one family. Do not
  migrate those chrome call sites in this plan.

## Steps

1. In `app/Notic/Sources/Views/Motion.swift`, add `hover(reduceMotion:)`
   immediately after `settle(reduceMotion:)`, with the exact body in
   Target. Update the file-header comment only if it would become a lie —
   it currently says “Springs everywhere”; change that sentence to note
   that pointer peeks use a 120ms ease-out and springs remain the default
   for layout and gestures. Do not rewrite the rest of the comment.

2. In `app/Notic/Sources/Views/EdgeSurfaceView.swift`, on `PillView` only,
   replace
   `.animation(Motion.settle(reduceMotion: reduceMotion), value: hovering)`
   with
   `.animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)`.
   Leave the −2 offset, the comment above it, and the
   `Motion.settle` animation on `EdgeSurfaceView` (pill ↔ deck swap)
   untouched.

3. In `app/Notic/Sources/Views/DeckView.swift`, on `NoteTabView` only,
   replace the `value: hovering` animation with `Motion.hover`. Leave the
   `value: isLifted` and `value: isOpen` animations on `Motion.settle`.
   Leave `FanIn`, reorder `handoff` / `settle`, and `OverflowTab` untouched.

## Boundaries

- Do NOT touch `OverflowTab`, library views, editor chrome, `EditorPanel`,
  or `DisplayCoordinator`.
- Do NOT change peek distances (−2 / −6), press scales, fan stagger, or
  `NoticTiming.hoverExpandDelay`.
- Do NOT change `Motion.settle` duration or any `value: isLifted` /
  `value: isOpen` / `value: notes.map(\.id)` / `value: footerRows` /
  `value: state == .dormant` animation.
- Do NOT add dependencies.
- If the cited lines have drifted since commit `3b240fc`, STOP and report
  instead of improvising.

## Verification

- **Mechanical**: from the repo root,
  `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build`
  — expected: BUILD SUCCEEDED. No new compiler warnings on the three files.
- **Feel check**:
  - Hover the dormant pill and hold past the fan: the 2pt peek should
    finish (or be obviously done) *before* the deck replaces the pill.
    At 10% animation playback (Simulator or Slow Animations), the peek
    reads as a quick ease-out, not a 320ms settle.
  - Sweep the pointer down a fanned deck: each tab’s 6pt peek should
    retarget immediately when you enter/leave. No honey, no bounce.
  - Drag a tab (lift + reorder) and click a tab open: lift scale, straighten,
    and editor present must still use the 320ms settle / existing AppKit
    slide. If those feel snappier than before, you changed the wrong
    animation.
  - Enable Reduce Motion (System Settings ▸ Accessibility ▸ Display):
    pill and tabs must not translate on hover; fan still fades in place.
- **Done when**: `Motion.hover` exists with duration `0.12` and curve
  `(0.23, 1, 0.32, 1)`; only the two `value: hovering` peek sites call it;
  settle-driven motion is unchanged.
