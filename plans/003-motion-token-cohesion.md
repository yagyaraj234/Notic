# 003 — Route chrome, press, and panel curves through Motion

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: MEDIUM
- **Category**: Cohesion & tokens
- **Estimated scope**: 5 files, small

## Problem

`Motion` is the vocabulary, but chrome hover, press, swatch selection, and
the editor’s AppKit glide each invent a nearby duration. `Motion.momentum`
is defined and never called.

```swift
/* app/Notic/Sources/Views/Motion.swift:18-21 — unused */
static func momentum(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.36, bounce: 0.2)
}
```

```swift
/* app/Notic/Sources/Views/Motion.swift:62 — press, ad-hoc */
.animation(.spring(duration: 0.16, bounce: 0), value: configuration.isPressed)
```

```swift
/* app/Notic/Sources/Views/EditorView.swift:200 — WindowDot */
.animation(.easeOut(duration: 0.12), value: hovering)

/* app/Notic/Sources/Views/EditorView.swift:237 — ChromeButton */
.animation(.easeOut(duration: 0.12), value: hovering)

/* app/Notic/Sources/Views/EditorView.swift:266 — ColorSwatchButton */
.animation(.spring(duration: 0.2, bounce: 0), value: isSelected)
```

```swift
/* app/Notic/Sources/Views/LibraryView.swift:475 — PaneButton */
.animation(.easeOut(duration: 0.12), value: hovering)
```

```swift
/* app/Notic/Sources/Panels/EditorPanel.swift:103 — current */
private static let enterCurve = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)

/* app/Notic/Sources/Controllers/DisplayCoordinator.swift:182-185 — duplicate */
NSAnimationContext.runAnimationGroup { context in
    context.duration = Motion.systemReducesMotion ? 0 : 0.22
    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
    editorPanel.animator().setFrame(target, display: true)
}
```

## Target

One token per job. Values are exact — do not “improve” them.

```swift
/* app/Notic/Sources/Views/Motion.swift — add / keep */
/// Pointer peeks and chrome color. 120ms, strong ease-out.
/// If this function already exists (plan 001), do not change its body.
static func hover(reduceMotion: Bool) -> Animation {
    reduceMotion
        ? .easeOut(duration: 0.12)
        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
}

/// Press scale/opacity. 160ms critically damped spring.
static func press(reduceMotion: Bool) -> Animation {
    reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.16, bounce: 0)
}

/// AppKit editor enter / return-to-tab. Same curve the panel already uses.
static let panelEnter = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
/// Inverse of `panelEnter`. Do not restyle — the inverse exit is deliberate.
static let panelExit = CAMediaTimingFunction(controlPoints: 0.7, 0, 0.8, 0.1)
```

Delete `momentum(reduceMotion:)` entirely.

Call sites:

```swift
/* PressFeedbackStyle */
.animation(Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)

/* WindowDot, ChromeButton, PaneButton — add reduceMotion env if missing */
.animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)

/* ColorSwatchButton — selection ring; 120ms hover family, not a 200ms spring */
.animation(Motion.hover(reduceMotion: reduceMotion), value: isSelected)

/* EditorPanel present */
context.timingFunction = Motion.panelEnter
/* EditorPanel dismiss */
context.timingFunction = Motion.panelExit
/* DisplayCoordinator return-to-tab */
context.timingFunction = Motion.panelEnter
```

Durations on the AppKit groups stay as they are: present 0.26 / 0.15,
dismiss 0.2 / 0.12, return-to-tab 0.22 / 0. Do not change those numbers.

## Repo conventions to follow

- Tokens are static members on `Motion` in
  `app/Notic/Sources/Views/Motion.swift`. SwiftUI tokens take
  `reduceMotion: Bool`. AppKit tokens are `CAMediaTimingFunction` lets.
- Exemplar after plan 001: peek sites already call
  `Motion.hover(reduceMotion:)`. Chrome must look like that, not like a
  raw `.easeOut(duration: 0.12)`.
- `PressFeedbackStyle` already reads
  `@Environment(\.accessibilityReduceMotion)`. Reuse that for `Motion.press`.

## Steps

1. In `Motion.swift`:
   - If `hover(reduceMotion:)` is missing, add it exactly as in Target
     (same body as plan 001).
   - Add `press(reduceMotion:)`, `panelEnter`, and `panelExit`.
   - Delete `momentum(reduceMotion:)` and any comment that only exists to
     describe it.
   - Point `PressFeedbackStyle` at `Motion.press(reduceMotion: reduceMotion)`.

2. In `EditorView.swift`, give `WindowDot` and `ChromeButton`
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
   and replace their `.easeOut(duration: 0.12)` hover animations with
   `Motion.hover(reduceMotion: reduceMotion)`. Give `ColorSwatchButton`
   the same environment property and replace the 200ms spring with
   `Motion.hover(reduceMotion: reduceMotion)`. Do not change press scales
   (`0.85`, `0.9`, default `0.97`).

3. In `LibraryView.swift` `PaneButton`, add
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
   and replace `.easeOut(duration: 0.12)` with
   `Motion.hover(reduceMotion: reduceMotion)`.

4. In `EditorPanel.swift`, delete the private `enterCurve` / `exitCurve`
   lets. Use `Motion.panelEnter` in `present` and `Motion.panelExit` in
   `dismiss`. Keep `travel`, durations, and the inverse-exit comment
   (move the comment onto `Motion.panelExit` if you want it to stay
   next to the curve).

5. In `DisplayCoordinator.swift`, replace the inline
   `CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)` with
   `Motion.panelEnter`. Leave the 0.22 / 0 duration branch as-is.

## Boundaries

- Do NOT change `Motion.settle`, `handoff`, `rubberband`, `project`, or
  `response` (0.32).
- Do NOT retarget pill/tab peek sites (plan 001) or `OverflowTab` (plan 004)
  except that they may already call `Motion.hover`.
- Do NOT change add-button scale `0.92` (plan 005).
- Do NOT change editor paper color (plan 006) or library list fades
  (plan 007).
- Do NOT restyle `panelExit` to ease-out. The inverse exit is settled.
- Do NOT add dependencies.
- If cited lines have drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
  `rg "momentum|easeOut\\(duration: 0\\.12\\)|spring\\(duration: 0\\.2|controlPoints: 0\\.2, 0\\.9" app/Notic` should not hit the migrated sites.
- **Feel check**:
  - Hover editor Close/Complete dots, footer ChromeButtons, library
    Open/Delete: color still eases in ~120ms, no bounce.
  - Press those controls: 160ms scale, same as before.
  - Click a color swatch: ring appears in ~120ms, no overshoot.
  - Open a note, then double-click the header: glide back still uses the
    existing enter curve and 220ms. Dismiss still eases out-then-in
    (inverse). If dismiss suddenly feels “snappy ease-out”, you replaced
    `panelExit`.
  - Reduce Motion: chrome color/opacity remains; press scale does not.
- **Done when**: no leftover `.easeOut(duration: 0.12)` on those four
  hover sites, `PressFeedbackStyle` calls `Motion.press`, AppKit enter
  curve has one definition, `momentum` is gone.
