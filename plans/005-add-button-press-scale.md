# 005 — Match the add-button press scale to the deck

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: LOW
- **Category**: Physicality & origin
- **Estimated scope**: 1 file, one token

## Problem

Press feedback must stay in **0.95–0.98**. Deck tabs use 0.98; the default
`PressFeedbackStyle` is 0.97. The add button uses **0.92**, so it punches
harder than everything around it.

```swift
/* app/Notic/Sources/Views/DeckView.swift:211 — current */
.buttonStyle(PressFeedbackStyle(scale: 0.92))
```

```swift
/* app/Notic/Sources/Views/Motion.swift:53-54 — default, the target scale */
struct PressFeedbackStyle: ButtonStyle {
    var scale: CGFloat = 0.97
```

```swift
/* app/Notic/Sources/Views/DeckView.swift:356 — tabs, for comparison */
.buttonStyle(PressFeedbackStyle(scale: 0.98))
```

## Target

Use the default 0.97 press. No new style, no new duration.

```swift
/* app/Notic/Sources/Views/DeckView.swift — addButton */
.buttonStyle(.pressFeedback)
```

`.pressFeedback` is the existing `ButtonStyle` sugar for
`PressFeedbackStyle()` at scale 0.97. Equivalent:
`PressFeedbackStyle(scale: 0.97)`. Prefer `.pressFeedback`.

Leave the animation on `PressFeedbackStyle` as-is (`.spring(duration: 0.16, bounce: 0)` or `Motion.press` after plan 003). This plan does not retune timing.

## Repo conventions to follow

- `UndoChip` in the same file already uses `.buttonStyle(.pressFeedback)`.
  Imitate that, not a one-off `PressFeedbackStyle(scale:)`.
- Tiny chrome (window dots at 0.85, swatches at 0.9) is a different size
  class. Do not “fix” those here.

## Steps

1. In `app/Notic/Sources/Views/DeckView.swift`, in `addButton` only,
   replace `.buttonStyle(PressFeedbackStyle(scale: 0.92))` with
   `.buttonStyle(.pressFeedback)`.

## Boundaries

- Do NOT change `PressFeedbackStyle` defaults, opacity 0.82, or duration.
- Do NOT change `NoteTabView`, `OverflowTab`, `WindowDot`, or
  `ColorSwatchButton` scales.
- Do NOT add dependencies.
- If that line has drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Fan the deck. Press + and a colour tab in turn: the add button’s
    shrink should read as the same family as a tab (subtle), not a deep
    squash. Target scale is 0.97.
  - Reduce Motion: scale does not run; opacity dim remains.
- **Done when**: `DeckView.swift` has no `PressFeedbackStyle(scale: 0.92)`.
