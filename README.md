# Notic

A local-first macOS 14+ menu-bar utility that keeps short-lived notes reachable
from the selected edge of every display (Settings ▸ General ▸ Deck ▸ Stack position:
Right, Left, or Bottom). Drag the resting pill or the expanded stack directly to
move the stack up/down or dock it to the left, right, or bottom. Its position
is remembered after relaunch. Option-drag a note tab to reorder notes. At rest the deck is a row or column of coloured
dashes, one per note, floating over the desktop. Hover and the notes shingle
down the edge as colour tabs, each with a vertical label and its own slight
lean; click one and it slides out level with its tab as a resizable plain-text
editor. Drag the editor by its tab strip or header to move it anywhere;
double-click the header to send it back beside its tab. Type `[] ` at the
start of a line (or press ⇧⌘T / Add to-do) for a checkbox to-do; click the
box to mark it done. Notes come in
eight pastel colours that stay light in dark mode by default (Settings ▸ Paper
switches to darker paper that matches the appearance; the lean can be turned
off there too). Everything is managed in a searchable two-pane library. No
account, no network, no telemetry. Choose Patrick Hand, System font, Chalkboard,
Marker Felt, Georgia, or Menlo in Settings → General → Notes, with a live preview.

The product specification lives in [`SPEC.md`](SPEC.md).

## Layout

| Path | Purpose |
| --- | --- |
| `Package.swift`, `Sources/NoticCore` | `NoticCore` — the `NoticWorkspace` public seam, SwiftData persistence, scheduler boundary, deck state machine, edge geometry. |
| `Tests/NoticCoreTests` | Swift Testing suite for the workspace seam against a real temporary store. |
| `app/project.yml` | [XcodeGen](https://github.com/yonaskolb/XcodeGen) definition of the app and UI-test targets. |
| `app/Notic` | The macOS app: AppKit panels, SwiftUI views, menu bar, hot keys, settings. |
| `app/NoticUITests` | XCUITest suite for the application accessibility seam. |

## Building

```sh
# Core library and its tests
swift test

# App (regenerate the project after adding files)
cd app && xcodegen generate
xcodebuild -project Notic.xcodeproj -scheme Notic -configuration Debug build

# Application accessibility tests (needs automation permission for Xcode's test runner)
xcodebuild -project Notic.xcodeproj -scheme Notic test
```

The Debug build is ad-hoc signed and sandboxed. Release distribution requires a
Developer ID certificate, notarization, and stapling as described in the
deployment checklist in `SPEC.md`.

To install a local build and produce a shareable disk image without a
Developer ID (recipients must right-click ▸ Open the first time, or allow it in
System Settings ▸ Privacy & Security):

```sh
./scripts/package.sh            # builds Release, installs to /Applications, writes dist/Notic-<version>.dmg
```

## Shortcuts

| Action | Shortcut |
| --- | --- |
| New note | ⌥⌘N |
| All notes | ⌥⌘L |
| Archive | ⌥⌘A |
| Hide or show Notic | ⌃⌥⌘H |

Shortcuts are registered with the Carbon hot-key API, which does not require
Accessibility or Input Monitoring permission.

Keyboard-only use: the edge deck is deliberately a non-activating surface that
never takes keyboard focus, so it is reached with the pointer or VoiceOver. The
keyboard path is ⌥⌘N to create and start typing, and ⌥⌘L for the library,
where arrow keys select notes, Return opens the selected active note, and the
Archive/Restore/Delete buttons act on the selection. Inside an editor, ⌘W
closes it.

The pill and fanned deck always float so they stay reachable; the *Show notes
above all apps* preference applies to expanded editors.

## Data, privacy, and uninstalling

- By default, notes and settings live inside the app sandbox at
  `~/Library/Containers/com.yagyaraj.notic/Data/Library/Application Support/Notic/`
  (`Notes.store` is a SwiftData/SQLite store; `Settings.json` holds preferences).
- Settings → General → Storage → Choose Folder copies the entire library into a new
  subfolder and switches future saves there. The old library stays as a backup.
  Preferences stay in the sandbox. This stores a Notic database, not individual text files.
  Keep the chosen folder available; Notic reports an error if it cannot reopen it.
  Cloud-folder providers may upload these files; simultaneous multi-Mac editing is unsupported.
- Notic never opens a network connection and contains no analytics,
  crash-reporting, or third-party SDKs.
- Notes are not encrypted by Notic; the sandbox, your macOS account, and
  FileVault protect default storage; custom folders use their filesystem permissions.
  Back up your selected notes folder and the settings directory (or rely on
  Time Machine) — deleting a note permanently removes it from the store ten
  seconds after the Undo window closes.
- To uninstall: quit Notic, turn off *Launch at Login* in Settings if you enabled
  it, move `Notic.app` to the Trash, and delete the container folder above. Custom libraries and old backups remain in their chosen folders.

## Test-only launch arguments

The UI tests (and manual verification) can start the app against clean data:

| Argument | Effect |
| --- | --- |
| `-NoticDataDirectory <path>` | Use this directory (must be writable inside the sandbox container). |
| `-NoticResetData` | Delete the data directory before opening it. |
| `-NoticSeedNotes <n>` | Create `n` titled, coloured notes on launch. |
| `-NoticOpenSeededNote` | Open the first seeded note on the primary display. |

## Font licence

The bundled display font is *Patrick Hand* by Patrick Wagesreiter, licensed under
the SIL Open Font License 1.1. The licence text ships with the app in
`app/Notic/Resources/Fonts/OFL.txt`.
