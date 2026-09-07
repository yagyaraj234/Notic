# 008 — Fan the first-note prompt in with the empty deck

- **Status**: DONE
- **Commit**: 3b240fc
- **Severity**: LOW
- **Category**: Missed opportunity
- **Estimated scope**: 1 file, tiny

## Problem

First launch is the one moment the spec budgets for delight
(`SPEC.md` story 44). The “Create your first note” chip appears already
in place while every later tab uses `FanIn` (edge offset + fade, 45ms
stagger, `Motion.settle`).

```swift
/* app/Notic/Sources/Views/DeckView.swift:44-46 — current */
if metrics.tileCount == 0 {
    emptyPrompt
        .frame(height: EdgeLayout.emptyPromptHeight)
}
```

```swift
/* app/Notic/Sources/Views/DeckView.swift:181-191 — current */
private var emptyPrompt: some View {
    Text(workspace.showsFirstNotePrompt ? "Create your first note" : "No active notes")
        .font(.system(size: 11, weight: .semibold)
        // ...
        .accessibilityIdentifier(workspace.showsFirstNotePrompt ? "notic.firstNotePrompt" : "notic.emptyDeck")
}
```

```swift
/* app/Notic/Sources/Views/DeckView.swift:217-234 — existing entrance, reuse */
private struct FanIn: ViewModifier {
    let index: Int
    let reduceMotion: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown || reduceMotion ? 0 : EdgeLayout.tabWidth)
            .onAppear {
                withAnimation(Motion.settle(reduceMotion: reduceMotion).delay(Double(index) * 0.045)) {
                    shown = true
                }
            }
    }
}
```

## Target

On first run only, run the prompt through `FanIn` at index 0 (no stagger
delay). Same spring, same Reduce Motion fade-in-place as tabs. The
“No active notes” chip (later empty deck) stays static — that is not a
first-run moment.

```swift
/* app/Notic/Sources/Views/DeckView.swift — body */
if metrics.tileCount == 0 {
    if workspace.showsFirstNotePrompt {
        emptyPrompt
            .frame(height: EdgeLayout.emptyPromptHeight)
            .modifier(FanIn(index: 0, reduceMotion: reduceMotion))
    } else {
        emptyPrompt
            .frame(height: EdgeLayout.emptyPromptHeight)
    }
}
```

Do not change `FanIn`, copy, or accessibility identifiers. The add button
below stays un-fanned and immediately tappable.

## Repo conventions to follow

- `FanIn` is `private` in `DeckView.swift` and is already applied to
  `NoteTabView` / `OverflowTab`. Reuse it; do not write a second
  onAppear stagger.
- `DeckView` already has
  `@Environment(\.accessibilityReduceMotion) private var reduceMotion`.
  Pass that through. Do not add a second environment property.

## Steps

1. In `app/Notic/Sources/Views/DeckView.swift`, replace the
   `if metrics.tileCount == 0 { emptyPrompt.frame(...) }` branch with
   the if/else in Target. Both branches keep
   `.frame(height: EdgeLayout.emptyPromptHeight)`. Only the
   `showsFirstNotePrompt` branch gets
   `.modifier(FanIn(index: 0, reduceMotion: reduceMotion))`.

2. Do not extract a new view unless the compiler forces it. Duplicating
   the two-line `emptyPrompt` + frame is fine.

## Boundaries

- Do NOT change `FanIn`’s offset, delay formula, or spring.
- Do NOT FanIn the add button, Undo chip, or save-state footer.
- Do NOT apply `FanIn` when `showsFirstNotePrompt` is false.
- Do NOT add a new Motion token.
- Do NOT add dependencies.
- If cited lines have drifted since `3b240fc`, STOP and report.

## Verification

- **Mechanical**: `cd app && xcodegen generate && xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build` — BUILD SUCCEEDED.
- **Feel check**:
  - Launch with `-NoticResetData` (no notes). Hover the pill: “Create
    your first note” should fade/slide from the edge with the same settle
    as a single tab (index 0, no extra delay). + is visible and clickable
    the whole time.
  - After creating and archiving every note, fan again: “No active notes”
    appears in place, no FanIn.
  - Reduce Motion, reset data, fan: prompt fades in with no x offset.
- **Done when**: `FanIn(index: 0)` wraps the first-note prompt only;
  `FanIn` itself is unmodified.
