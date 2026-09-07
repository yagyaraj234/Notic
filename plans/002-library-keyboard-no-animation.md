# 002 — Remove animation from library keyboard navigation

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: HIGH
- **Category**: Purpose & frequency
- **Estimated scope**: 1 file, tiny

## Problem

Holding ↑/↓ in the library is a high-frequency keyboard action. Two
animations fire on every step: the row highlight eases for 120ms, and the
detail card remounts (`.id`) then crossfades for 150ms. That makes the
list feel late and can double-expose two notes.

Keyboard-initiated navigation must not animate.

```swift
/* app/Notic/Sources/Views/LibraryView.swift:223-227 — current */
if let focusedNote {
    NoteDetailCard(note: focusedNote, fontChoice: workspace.settings.fontChoice, paperStyle: workspace.settings.paperStyle)
        .id(focusedNote.id)
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: focusedNote.id)
}
```

```swift
/* app/Notic/Sources/Views/LibraryView.swift:372-376 — current */
.background(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(isFocused ? 0.06 : 0))
        .animation(.easeOut(duration: 0.12), value: isFocused)
)
```

Arrow handling itself is already instant (`moveFocus` writes `model.focused`).
Only the view layer is late.

## Target

Instant focus ring. Instant detail swap. No remount, no transition, no
implicit animation keyed on focus.

```swift
/* app/Notic/Sources/Views/LibraryView.swift — detail */
if let focusedNote {
    NoteDetailCard(note: focusedNote, fontChoice: workspace.settings.fontChoice, paperStyle: workspace.settings.paperStyle)
}
```

```swift
/* app/Notic/Sources/Views/LibraryView.swift — row */
.background(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(isFocused ? 0.06 : 0))
)
```

`NoteDetailCard` updates in place when `note` changes. Pointer clicks that
set `model.focused` are instant too — that is correct; do not special-case
the mouse.

## Repo conventions to follow

- Settings already disables motion on preference flips:
  `app/Notic/Sources/Views/SettingsView.swift` uses `.animation(nil, value: settings)`.
  Same idea: a control the user hammers should not interpolate.
- Do not replace these with `Motion.settle` or `Motion.hover`. The fix is
  deletion, not a faster curve.

## Steps

1. In `app/Notic/Sources/Views/LibraryView.swift` `detailPane`, on the
   `NoteDetailCard` call, delete these three modifiers and nothing else:
   `.id(focusedNote.id)`, `.transition(.opacity)`, and
   `.animation(.easeOut(duration: 0.15), value: focusedNote.id)`.
   Keep the `if let focusedNote` / `else` empty-selection branch.

2. In `LibraryRow.body`, delete
   `.animation(.easeOut(duration: 0.12), value: isFocused)`
   from the focused-row `RoundedRectangle` fill. Leave the fill, corner
   radius, and padding as they are.

## Boundaries

- Do NOT add a new animation, `Motion` token, or `reduceMotion` branch.
- Do NOT change `onMoveCommand`, `moveFocus`, search, filters, or
  `PaneButton` hover (plan 003).
- Do NOT change `LibraryRow` checkbox press feedback.
- Do NOT add a list fade here — that is plan 007 and keys on `model.filter`,
  not focus.
- If the cited lines have drifted since commit `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Open All Notes (⌥⌘L), focus the list, hold ↓ then ↑. The highlight
    and the detail card must track the key, with no fade and no stacked
    cards. At 10% animation playback the focus change is still a hard cut.
  - Click a row with the pointer: same instant swap.
  - Type in search and change All / Active / Archived: list behaviour is
    unchanged by this plan (still a hard cut until 007).
- **Done when**: grepping `LibraryView.swift` finds no
  `.animation(` keyed on `focusedNote.id` or `isFocused`, and no
  `.id(focusedNote.id)`.
