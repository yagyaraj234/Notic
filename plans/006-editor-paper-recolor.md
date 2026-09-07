# 006 — Ease the editor paper when the swatch changes

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 2 files, small

## Problem

Choosing a colour in the editor footer swaps the whole sheet — fill, ink,
border, tab strip — in one frame. The swatch ring already animates; the
paper it belongs to teleports.

```swift
/* app/Notic/Sources/Views/EditorView.swift:29-78 — current */
private func content(for note: Note) -> some View {
    let swatch = NotePalette.swatch(for: note.color, paper: workspace.settings.paperStyle)
    // ...
    return HStack(spacing: 0) {
        TabLabel(title: note.title, swatch: swatch, visibleLength: EdgeLayout.tabHeight)
        // ...
    }
    .foregroundStyle(swatch.foreground)
    .tint(swatch.foreground)
    .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(swatch.background)
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(swatch.border.opacity(0.6), lineWidth: 0.5)
    )
    // no animation on note.color
}
```

`NoteBodyEditor` sets AppKit `ink` directly. That text colour will still
snap — do not try to animate `NSTextView` textColor in this plan.

## Target

A 200ms strong ease-in-out on `note.color` for the SwiftUI paper only.
This is an on-screen morph (the sheet stays put; its colour changes), not
a hover and not a layout spring.

```swift
/* app/Notic/Sources/Views/Motion.swift — add if missing */
/// Recolour a surface that is already on screen.
/// cubic-bezier(0.77, 0, 0.175, 1), 200ms.
static func recolor(reduceMotion: Bool) -> Animation {
    reduceMotion
        ? .easeOut(duration: 0.15)
        : .timingCurve(0.77, 0, 0.175, 1, duration: 0.2)
}
```

```swift
/* app/Notic/Sources/Views/EditorView.swift — content(for:) */
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// on EditorView, next to @FocusState

// at the end of the returned HStack modifiers, before .onAppear:
.animation(Motion.recolor(reduceMotion: reduceMotion), value: note.color)
```

Keep Reduce Motion’s fade-like 150ms ease-out — colour/opacity feedback
stays; we are not introducing travel.

Do not key the animation on `paperStyle` or `fontChoice`. Settings already
uses `.animation(nil, value: settings)`.

## Repo conventions to follow

- New curves live on `Motion` as `static func` taking `reduceMotion: Bool`.
- Exemplar: `Motion.hover` / `Motion.settle` in
  `app/Notic/Sources/Views/Motion.swift`. Same shape, different curve
  and duration.
- Swatch buttons stay on `Motion.hover` (plan 003) or their current
  200ms spring. This plan animates the *sheet*, not the 16pt chip.

## Steps

1. In `app/Notic/Sources/Views/Motion.swift`, add `recolor(reduceMotion:)`
   after `hover` / `press` (wherever those sit). If a function of that
   name already exists, do not duplicate it — use it.

2. In `app/Notic/Sources/Views/EditorView.swift`, add
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion`
   on `EditorView`. On the view returned by `content(for:)`, after the
   border overlays and before `.onAppear`, add
   `.animation(Motion.recolor(reduceMotion: reduceMotion), value: note.color)`.

## Boundaries

- Do NOT animate `NoteBodyEditor` / `NSTextView` ink.
- Do NOT animate title/body text changes, save-state, or window frame.
- Do NOT use `Motion.settle` (320ms is a layout spring) or `Motion.hover`
  (120ms is a peek).
- Do NOT change `ColorSwatchButton` scales or its own animation.
- Do NOT add dependencies.
- If cited lines have drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Open a note. Click through yellow → coral → mint. The paper, border,
    and SwiftUI chrome should ease over ~200ms with no bounce and no
    position change. Body text colour may still cut; that is accepted.
  - At 10% playback: one continuous recolour, not a flash of two papers.
  - Type in the body while idle: no interpolation on keystrokes
    (`value` is `note.color` only).
  - Reduce Motion: recolour still happens, shorter ease-out, no motion.
- **Done when**: `Motion.recolor` exists with duration `0.2` and curve
  `(0.77, 0, 0.175, 1)`, and `EditorView.content` keys an animation on
  `note.color` only.
