# 009 — Five new preferences and Duplicate in NoticCore

- **Status**: DONE
- **Severity**: HIGH (prerequisite for 010 and 011)
- **Category**: Core state
- **Estimated scope**: 4 files, medium

## Problem

The settings window (010) and the dock menu (011) are both surfaces onto state
that does not exist yet. Five preferences are hardcoded or absent, and
Duplicate has no command behind it.

- Body text size is fixed at 21pt in the view layer (`EditorView.swift:42`).
- The open delay is a constant, `NoticTiming.hoverExpandDelay` (0.120s), read
  directly by `NoticWorkspace.pointerEntered`.
- Motion durations are constants in `Motion.swift`.
- The deck always fans on hover and always collapses on pointer exit.
- There is no `duplicateNote`.

## Change

### `NoticSettings`

```swift
public enum AnimationSpeed: String, Codable, Sendable, CaseIterable {
    case fast, normal, slow
    public var multiplier: Double  // 0.6, 1.0, 1.5
}

public enum FanTrigger: String, Codable, Sendable, CaseIterable {
    case hover, click
}

public var textSize: Int = 21             // one of `textSizeOptions`
public var openDelay: TimeInterval = 0.12 // 0...0.6, 20ms steps
public var animationSpeed: AnimationSpeed = .normal
public var fanTrigger: FanTrigger = .hover
public var keepsDeckOpen = false

public static let textSizeOptions = [15, 18, 21, 24, 28]
public static let openDelayRange = 0.0...0.6
public static let openDelayStep = 0.02
```

Every default is today's behaviour, so no existing install changes on upgrade.
The open delay default is **0.12s**, matching `NoticTiming.hoverExpandDelay`
— not the 150ms the reference app uses.

`init(from:)` already decodes every key optionally so older settings files keep
their values; the new keys follow that pattern. It gains a call to a new
`mutating func clampToSupportedValues()` which snaps `textSize` to the nearest
supported option and clamps `openDelay` into range, so a hand-edited or
future-written settings file can never put the app in an unrepresentable
state. `updateSettings` clamps too.

`NoticTiming.hoverExpandDelay` stays as the documented default and is what
`NoticSettings.openDelay` initialises from.

### `NoticWorkspace`

- `pointerEntered` schedules the fan after `settings.openDelay`, and does not
  schedule at all when `settings.fanTrigger == .click` or when
  `settings.keepsDeckOpen` is on.
- `pointerExited` does not schedule a collapse when `keepsDeckOpen` is on.
- `attachDisplay` starts a display `.fanned` rather than `.dormant` when
  `keepsDeckOpen` is on.
- `updateSettings` reacts to `keepsDeckOpen` changing: turning it on fans every
  dormant deck; turning it off collapses every fanned deck the pointer is not
  inside. Without this the preference only takes effect on the next relaunch.
- New `@discardableResult public func duplicateNote(_ id: Note.ID) -> Note.ID?`
  — copies title (suffixed `" copy"`), body, colour and editor size; keeps the
  original's lifecycle; places the copy directly after its original in the
  deck order and renumbers the whole order atomically, the way
  `moveActiveNote` does. Returns `nil` for an unknown note or one pending
  deletion. The copy gets its own `createdAt`/`modifiedAt` and no
  `editorOrigin`, so it docks to its own tab rather than inheriting a dragged
  position.

## Tests (write first, in this order)

`Tests/NoticCoreTests/SettingsTests.swift`

1. defaults: `textSize == 21`, `openDelay == 0.12`, `animationSpeed == .normal`,
   `fanTrigger == .hover`, `keepsDeckOpen == false`
2. the five new preferences survive a relaunch
3. today's settings file — the one in the existing legacy-decode test — still
   decodes, with all five new keys defaulting
4. an out-of-range file (`"textSize":19`, `"openDelay":99`) clamps to 18 and 0.6

`Tests/NoticCoreTests/DeckPresentationTests.swift`

5. a 0.3s open delay fans at 0.3s, not 0.12s
6. `fanTrigger == .click`: hovering never fans; `revealDeck` still does
7. `keepsDeckOpen`: a newly attached display starts fanned; pointer exit does
   not collapse it
8. turning `keepsDeckOpen` on fans an already-dormant deck; turning it off
   collapses it when the pointer is outside

`Tests/NoticCoreTests/NoteCreationTests.swift`

9. a duplicate copies title, body and colour and lands directly after its
   original in the deck order
10. editing the duplicate leaves the original untouched
11. duplicating an archived note produces an archived note; duplicating a note
    pending deletion returns `nil`
12. a duplicate survives a relaunch in its position

## Open product decision

The duplicate's title gets `" copy"` appended. Notes are titled with a
timestamp by default (`createNote`), so two identical titles in the deck would
be indistinguishable. Flagged, not assumed.
