# 007 — Crossfade the library list when the filter or emptiness changes

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 1 file, small

## Problem

All / Active / Archived replaces the list in one frame. So does flipping
between results and “No matches”. Search-as-you-type is high-frequency and
must stay instant; the jarring seams are the occasional filter change and
the empty ↔ list swap.

```swift
/* app/Notic/Sources/Views/LibraryView.swift:70-111 — current */
if notes.isEmpty {
    emptyState
} else {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(notes) { note in
                    LibraryRow(/* ... */)
                    // ...
                }
            }
            // ...
        }
        // keyboard handlers...
    }
    .accessibilityIdentifier("notic.library.list")
}
```

Plan 002 removes focus-driven animation. This plan must not put any
animation on `model.focused` or `focusedNote.id`.

## Target

One 120ms opacity crossfade, keyed only on `model.filter` and
`notes.isEmpty`. Same curve as `Motion.hover`. Typing in search updates
rows with no animation.

```swift
/* app/Notic/Sources/Views/LibraryView.swift — listPane, replace the if/else */
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// on LibraryView

ZStack {
    if notes.isEmpty {
        emptyState
            .transition(.opacity)
    } else {
        ScrollViewReader { proxy in
            // existing ScrollView + handlers, unchanged
        }
        .accessibilityIdentifier("notic.library.list")
        .id(model.filter)
        .transition(.opacity)
    }
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.animation(Motion.hover(reduceMotion: reduceMotion), value: model.filter)
.animation(Motion.hover(reduceMotion: reduceMotion), value: notes.isEmpty)
```

`Motion.hover` (plan 001 / 003):

```swift
static func hover(reduceMotion: Bool) -> Animation {
    reduceMotion
        ? .easeOut(duration: 0.12)
        : .timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
}
```

If `Motion.hover` is missing, add that function first. Do not use
`Motion.settle`.

`.id(model.filter)` remounts the list only when the chip changes, so
All → Archived is one fade. Search keystrokes do not change `model.filter`,
so `ForEach` updates in place with no implicit animation.

Do not add `filter: blur` during the crossfade. 120ms is short enough
that a blur is not worth the Safari/AppKit cost.

## Repo conventions to follow

- `Motion.hover` is the 120ms chrome/peek curve. Filter chips are chrome.
- Title, search field, and filter chips stay outside the `ZStack` — they
  must not fade. Only the list / empty body swaps.
- Keyboard focus animation stays deleted (plan 002). If 002 has not run,
  still do not add anything keyed on `isFocused` or `focusedNote.id`.

## Steps

1. Confirm `Motion.hover` exists. If not, add it as in Target.

2. On `LibraryView`, add
   `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.

3. In `listPane`, keep the header, search field, and `filterChips` as they
   are. Replace only the `if notes.isEmpty { emptyState } else { … }`
   block with the `ZStack` in Target. Copy the existing `ScrollViewReader`
   tree verbatim into the `else` branch; do not rewrite keyboard handlers.
   Add `.id(model.filter)` and `.transition(.opacity)` on that branch,
   `.transition(.opacity)` on `emptyState`, and the two `.animation`
   modifiers on the `ZStack`.

4. Leave the pending-deletion banner below the `ZStack`, unanimated.

## Boundaries

- Do NOT animate `model.query`, row focus, or the detail pane.
- Do NOT put `.animation` on `ForEach` or `LibraryRow`.
- Do NOT fade the window title, search field, or filter chips.
- Do NOT add blur, scale, or move transitions.
- Do NOT add dependencies.
- If cited lines have drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Click All → Active → Archived: the list (or empty copy) crossfades
    in ~120ms. Chips and search stay put.
  - Type a search that goes from hits to “No matches” and back: that
    emptiness swap fades. Characters that only filter the row set must
    not fade or stagger rows.
  - Hold ↓ in the list: focus and detail stay instant (plan 002). If they
    start fading, you keyed the wrong value.
  - Reduce Motion: opacity fade may remain; no sliding.
- **Done when**: list/empty swaps on `model.filter` and `notes.isEmpty`
  only, via `Motion.hover` + `.opacity`; search typing does not interpolate
  rows.
