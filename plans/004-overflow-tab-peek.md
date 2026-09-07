# 004 — Give the overflow tab the same hover peek as note tabs

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: MEDIUM
- **Category**: Physicality & origin
- **Estimated scope**: 1 file, tiny

## Problem

Fanned note tabs ease −6pt off the edge under the pointer so they read as
pull-out handles. The “+N more” tab is the same shape in the same stack
and does not move, so it feels dead when you scan past it.

```swift
/* app/Notic/Sources/Views/DeckView.swift:360-366 — NoteTabView, the exemplar */
.offset(x: hovering && !isOpen && !isLifted && !reduceMotion ? -6 : 0)
.scaleEffect(isLifted && !reduceMotion ? 1.04 : 1, anchor: .trailing)
.animation(Motion.hover(reduceMotion: reduceMotion), value: hovering) // after 001; may still be Motion.settle
.animation(Motion.settle(reduceMotion: reduceMotion), value: isLifted)
.animation(Motion.settle(reduceMotion: reduceMotion), value: isOpen)
.onHover { hovering = $0 }
```

```swift
/* app/Notic/Sources/Views/DeckView.swift:375-405 — OverflowTab, current */
struct OverflowTab: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        // ...
        .buttonStyle(PressFeedbackStyle(scale: 0.98))
        .offset(x: NoteTabView.overhang)
        .accessibilityLabel("\(count) more notes")
        // no hovering state, no peek
    }
}
```

## Target

Same peek distance, same hover curve, same Reduce Motion gate. No lean,
lift, or open state — overflow is not a note.

```swift
/* app/Notic/Sources/Views/DeckView.swift — OverflowTab */
struct OverflowTab: View {
    let count: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        let swatch = NotePalette.Swatch(
            background: Color(nsColor: .windowBackgroundColor),
            foreground: .primary,
            border: .primary.opacity(0.2),
            accent: .primary,
            paper: .gray,
            destructive: NotePalette.destructive
        )
        Button(action: action) {
            TabLabel(title: "+\(count) more", swatch: swatch, visibleLength: EdgeLayout.tabHeight)
                .frame(width: EdgeLayout.tabWidth + NoteTabView.overhang, height: EdgeLayout.tabHeight, alignment: .topLeading)
                .background(
                    TabShape()
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.22), radius: 6, x: -2, y: 3)
                )
                .overlay(TabShape().strokeBorder(EdgeHighlight(), lineWidth: 1))
                .overlay(TabShape().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                .contentShape(TabShape())
        }
        .buttonStyle(PressFeedbackStyle(scale: 0.98))
        .offset(x: NoteTabView.overhang)
        .offset(x: hovering && !reduceMotion ? -6 : 0)
        .animation(Motion.hover(reduceMotion: reduceMotion), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(count) more notes")
        .accessibilityHint("Opens the note library")
        .accessibilityIdentifier("notic.overflow")
    }
}
```

`Motion.hover` must be the 120ms strong ease-out from plan 001:

```swift
static func hover(reduceMotion: Bool) -> Animation {
    reduceMotion
        ? .easeOut(duration: 0.12)
        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
}
```

If `Motion.hover` is missing, add that function first (copy from plan 001).
Do not fall back to `Motion.settle`.

## Repo conventions to follow

- Copy the peek pattern from `NoteTabView` in the same file
  (`DeckView.swift`): `@State hovering`, `@Environment` reduce motion,
  second `offset(x:)` after the overhang, `onHover`.
- Press style stays `PressFeedbackStyle(scale: 0.98)` — same as note tabs.
- Do not add `NoteTabView.lean` to overflow. Overflow is a utility tile.

## Steps

1. Confirm `Motion.hover` exists in `app/Notic/Sources/Views/Motion.swift`.
   If it does not, add it exactly as in Target before touching the tab.

2. Edit `OverflowTab` in `app/Notic/Sources/Views/DeckView.swift`: add
   `reduceMotion` and `hovering`, the −6pt offset, `Motion.hover`
   animation, and `onHover`. Do not change label, swatch, shadows, or
   accessibility strings.

## Boundaries

- Do NOT change `NoteTabView`, `FanIn`, reorder, or the add button.
- Do NOT add tilt, lift scale, or an `isOpen` path.
- Do NOT change peek distance to anything other than −6.
- Do NOT add dependencies.
- If cited lines have drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Seed more than eight notes (`-NoticSeedNotes 10`). Fan the deck.
    Hover a colour tab, then the +N tab: both ease −6pt with the same
    120ms curve. Sweeping past overflow must not feel like a dead slot.
  - Click overflow: library opens; press scale is still 0.98.
  - Reduce Motion: overflow does not translate on hover.
  - At 10% playback, overflow and note-tab peeks start and finish together.
- **Done when**: `OverflowTab` has the −6pt peek on `Motion.hover` and
  no new lean/lift behaviour.
