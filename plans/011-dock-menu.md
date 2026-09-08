# 011 — One menu definition behind the dock menu, the quick menu, and the library

- **Status**: DONE
- **Severity**: MEDIUM
- **Category**: Menus
- **Estimated scope**: 4 files, medium
- **Depends on**: 009, 010

## Problem

Notic has one context menu, on library rows (`LibraryView.swift:95`), and one
status-item menu built inline in `MenuBarController.swift:29`. Secondary-click
does nothing on the dock, on a tab, or in the editor. The two existing menus
share no code, so they already disagree about what a note's commands are —
"Mark complete" in the library, an unlabelled dot in the editor.

## Change

### One definition

A new `Controllers/NoticMenus.swift` describes every menu item once — title,
optional SF Symbol, shortcut, whether it needs a note, and its action — and
emits an `NSMenu`. Three call sites consume it:

- the **quick menu** (the status item)
- the **dock menu** (secondary-click on the dock or a tab)
- the **library row menu**

### Dock menu contents

Secondary-click anywhere on the dock or a tab:

```
Color            ▸    (the eight swatches)
Duplicate
─────────────────
New Note              ⌥⌘N
─────────────────
All Notes…            ⌥⌘L
Show Archive…         ⌥⌘A
Settings…             ⌘,
─────────────────
Archive Note
Delete
─────────────────
Hide Notic            ⌃⌥⌘H
Quit Notic            ⌘Q
```

The note-level items (`Color`, `Duplicate`, `Archive Note`, `Delete`) appear
only when the click landed on a tab, and always target the tab **under the
pointer** — not the note whose editor happens to be open. Position is the only
unambiguous signal. On the bare dock they are hidden, not greyed: a menu of
dead items reads as broken.

`Delete` goes through `workspace.delete`, so the ten-second Undo chip appears
as it does everywhere else.

### Hit testing

Neither of the two paths first considered. SwiftUI's `.contextMenu` would have
needed a second definition of every item in SwiftUI's own vocabulary, and a
`rightMouseDown` hit test in `HoverTrackingHostingView` would have duplicated
`EdgeLayout`'s tab geometry.

Instead `SecondaryClickMenu` (`Views/SecondaryClickMenu.swift`) overlays an
`NSView` that is transparent to `hitTest` for every event except a secondary
or control-click, and answers `menu(for:)` with an `NSMenu` built at click
time. SwiftUI's layout supplies the hit testing, AppKit pops the menu, the
pill and tabs stay clickable, and hover tracking is untouched. The same
modifier carries the library row menu, which replaced its SwiftUI
`contextMenu`.

### Menu-bar icon — reproduced, root cause NOT found

Rebuilt and checked, and the status item really is missing on this Mac. What
the evidence says:

- The item is created and healthy: `isVisible == true`, the button exists in
  an `NSStatusBarWindow`, `alphaValue == 1`, `isHidden == false`, and
  `button.image` holds the `note.text` symbol.
- Its status-bar **window is parked off-screen** — `(0, -7, 38, 22)`, with the
  screen at `(0, 0, 1440, 900)`. An identical item created in a minimal path
  inside the same bundle lands correctly at `(1402, 878)`, and a separate
  throwaway process's item both places correctly and paints.
- So third-party status items work on this Mac (no hider app is running, and
  the menu bar has free space); it is Notic's own item that never gets placed.
- Ruled out: a stale bundle; a menu-bar hider; the app sandbox (reproduces
  with sandboxing off); `statusItem.autosaveName`; creating the item late;
  the edge panels; `Control Center`'s hidden `NSStatusItem Visible Item-N`
  keys (Notic's own defaults hold no visibility key at all).
- A bisect of the launch sequence pointed first at
  `FontRegistry.registerBundledFonts()` and then at `NoticWorkspace` init, but
  both results **failed to reproduce on a re-run**: placement is
  non-deterministic, and neither is confirmed. The launch sequence was left
  exactly as it was.

Left as it stands: `note.text`, unnamed item, no reordering. Note that
`Info.plist` already sets `ATSApplicationFontsPath = Fonts`, so the bundled
font resolves (`NSFont(name: "Patrick Hand")` returns
`PatrickHand-Regular`) even without the manual `CTFontManagerRegisterFontsForURL`
call — that call is redundant, which is worth revisiting if the placement
question is picked up again.

`-NoticOpenSettings` was added to `LaunchOptions` during this work: it opens
the settings window on launch, for screenshots and manual checks.

## Tests

- XCUITest: secondary-click a tab shows the note items; secondary-click the
  bare dock shows only the app items.
- XCUITest: Duplicate from the dock menu adds a tab; Delete shows the Undo chip.
- By hand: keyboard navigation of both menus, and VoiceOver reading them.
