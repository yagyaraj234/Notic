# 010 — Rebuild the settings window with General and About panes

- **Status**: DONE
- **Severity**: HIGH
- **Category**: Settings
- **Estimated scope**: 4 files, medium
- **Depends on**: 009

## Problem

`SettingsView` is a single 440pt `Form` with four sections, in a plain
`NSWindow` sized 440×420 (`SettingsView.swift:5`, `:66`). It has nowhere to put
the five new preferences from 009, no About pane, and no identity — it looks
like a generic preferences sheet rather than part of Notic.

## Change

A two-row sidebar — **General** and **About** — beside one pane at a time,
built the way the library window is (an `HStack` over `NotePalette`
backgrounds) rather than with `NavigationSplitView`, whose translucent sidebar
material fights Notic's paper palette. Native controls throughout — `Form`,
`Picker`, `Slider`, `Toggle`; Notic's own palette
(`NotePalette.windowBackground` is already wired up) and type. Not a
reimplementation of the reference app's cream chrome — see ADR 0001 and
`SPEC.md`'s originality requirement.

The sidebar carries the app icon, "Notic", and "Settings" as its header, then
the two rows.

### General

Grouped cards, in this order:

**Notes** — Handwriting, Text size (stepper over `textSizeOptions`), Paper,
Lean the tabs.

**Deck** — Open delay (slider, `openDelayRange` in `openDelayStep` steps,
value shown in ms), Fan (segmented: On hover / On click), Keep the deck open
(toggle), Animation speed (segmented: Fast / Normal / Slow).

**Visibility** — Show notes above all apps, Show over full-screen apps.

**Application** — Show Notic in the Dock, **Launch at Login**.

The read-only Shortcuts section is dropped: every shortcut is already shown
beside its item in the quick menu.

### About

App icon, "Notic", version and build from `Info.plist`
(`CFBundleShortVersionString` / `CFBundleVersion`), "by Raj" linking to
`https://x.com/heyraj__`, the privacy paragraph moved out of General
(`SettingsView.swift:41`), and the Patrick Hand acknowledgement — the font
ships under the OFL (`app/Notic/Resources/Fonts/OFL.txt`) which requires
attribution, so this is a licence obligation, not decoration.

### Wiring

- `EditorView` reads `workspace.settings.textSize` instead of the literal 21.
- `Motion` gains a speed multiplier applied to every duration it hands out,
  set from `settings.animationSpeed` by the existing settings observation in
  `AppDelegate.apply(settings:)`.
- `SettingsWindowController` grows to fit the split view and keeps its
  `notic.settings` accessibility identifier.

Every new control gets a `notic.settings.*` accessibility identifier, matching
the existing ones, so 010's XCUITests can drive them.

## Tests

- XCUITest: opening Settings shows both sidebar rows; General exposes the five
  new controls by identifier; About shows a version string and the byline.
- XCUITest: changing Text size changes the editor's body font size.
- By hand / by screenshot: light and dark appearance, and Increase Contrast.
