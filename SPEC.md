# Notic MVP Specification

## Problem Statement

Mac users need a fast place to capture short-lived notes without opening a full notes application, rearranging their workspace, or losing focus from the task in front of them. Traditional sticky-note windows create clutter, while conventional note libraries hide information behind navigation.

Notic should keep active notes immediately reachable at the edge of every display. It should reveal them through a lightweight pointer interaction, preserve them automatically, and provide a searchable library without requiring an account, network connection, or external service.

## Solution

Notic is a local-first macOS 14+ menu-bar application. A narrow pill rests on the right edge of each active display. Hovering over the pill fans out the active note deck without taking focus from the current application. Selecting a note opens a resizable editor beside the deck; clicking into the editor activates Notic and allows plain-text editing.

Users can create, color, reorder, archive, restore, search, and delete notes. Notic autosaves edits, restores state after relaunch, supports global keyboard shortcuts, and provides accessible alternatives for motion, typography, contrast, and navigation. Version one is entirely offline and uses no account, telemetry, or network access.

The interaction concept may be inspired by edge-docked note applications, but Notic will use original branding, dimensions, typography, animation, controls, and visual assets.

## User Stories

1. As a Mac user, I want a narrow note pill at the right edge of my display, so that my notes remain available without occupying meaningful screen space.
2. As a multi-display user, I want an edge pill on every active display, so that I can reach my notes from whichever screen I am using.
3. As a focused user, I want the pill to stay dormant until I approach it, so that it does not distract me.
4. As a user, I want the deck to fan out when I hover over the pill, so that I can inspect active notes without clicking.
5. As a user working in another application, I want hovering over Notic to preserve my current application focus, so that exploration does not interrupt typing or keyboard shortcuts.
6. As a user, I want the fanned notes to retain their colors and labels, so that I can identify them quickly.
7. As a user, I want the deck to collapse shortly after my pointer leaves, so that it gets out of the way without flickering during small pointer movements.
8. As a user, I want to click a fanned note to open its editor beside the deck, so that the note remains spatially connected to its tab.
9. As a user, I want clicking into the editor to activate Notic and place the insertion point, so that I can begin typing immediately.
10. As a user, I want at most one note expanded on each display, so that open notes do not create uncontrolled clutter.
11. As a user, I want opening another note on the same display to collapse the current note, so that the interaction remains predictable.
12. As a user, I want closing an editor to collapse it without deleting or archiving the note, so that closing is always safe.
13. As a user, I want a visible add control in the deck, so that I can create a note with the pointer.
14. As a keyboard-focused user, I want to create a note with Option-Command-N, so that capture is instant from any application.
15. As a user, I want new notes placed first in the active deck, so that newly captured information is immediately visible.
16. As a user, I want each note to have a title and body, so that I can label and write the note independently.
17. As a user, I want plain-text editing with normal line wrapping, so that writing remains simple and reliable.
18. As a user, I want a handwriting-style display font, so that notes feel personal and visually distinct.
19. As a user who needs maximum legibility, I want to switch to the macOS system font, so that the editor is comfortable to read.
20. As a user, I want to choose from yellow, coral, mint, blue, and lavender note colors, so that I can distinguish notes visually.
21. As a user, I want text and controls to remain legible for every note color, so that color choice never harms readability.
22. As a user, I want to resize an expanded note within sensible bounds, so that I can fit longer or shorter content.
23. As a returning user, I want each note's size to be restored, so that the workspace remains familiar.
24. As a user, I want edits saved automatically shortly after typing stops, so that I do not need a Save command.
25. As a user, I want pending edits saved immediately when I close a note or quit Notic, so that recent text is not lost.
26. As a returning user, I want active notes, archived notes, colors, sizes, ordering, and text restored after relaunch, so that Notic resumes where I left it.
27. As a user, I want to drag active notes into a custom order, so that the deck reflects my priorities.
28. As a returning user, I want my custom deck order preserved across launches, so that notes do not move unexpectedly.
29. As a user with more than eight active notes, I want a “+N more” tile, so that the deck stays usable on a finite-height display.
30. As a user, I want the “+N more” tile to open the note library, so that overflow notes remain reachable.
31. As a user, I want one library window containing all notes, so that I can manage information beyond the visible deck.
32. As a keyboard-focused user, I want to open the library with Option-Command-L, so that I can reach it globally.
33. As a user, I want to search note titles and bodies, so that I can find content without remembering its location.
34. As a user, I want to filter the library by active or archived state, so that I can focus on the relevant set.
35. As a user, I want to select multiple notes in the library, so that bulk archive, restore, and deletion are efficient.
36. As a user, I want to archive an active note, so that it leaves the edge deck without being lost.
37. As a keyboard-focused user, I want to open the archive with Option-Command-A, so that archived material is quickly available.
38. As a user, I want to restore an archived note, so that it returns to the active deck.
39. As a user, I want archived notes retained indefinitely, so that archiving is never equivalent to deletion.
40. As a user, I want deleting a note to provide a ten-second Undo opportunity, so that accidental deletion is recoverable.
41. As a user, I want a note permanently removed after its deletion window expires, so that explicit deletion eventually clears its data.
42. As a user, I want deletion state to survive an unexpected relaunch, so that an interrupted timer cannot create inconsistent behavior.
43. As a user with no notes, I want the edge pill and add button to remain available, so that the empty state is actionable.
44. As a first-time user, I want a short “Create your first note” prompt, so that the interaction is self-explanatory.
45. As a user, I want Notic available from the menu bar, so that settings, library access, and Quit are always reachable.
46. As a user who prefers a background utility, I want Notic hidden from the Dock by default, so that it does not behave like a document application.
47. As a user who prefers conventional app switching, I want an option to show Notic in the Dock, so that I can reach it with Command-Tab.
48. As a user, I want Notic to remain running when its visible windows close, so that the edge deck remains available.
49. As a user, I want quitting to require an explicit menu action, so that closing a note cannot terminate the application.
50. As a user, I want an optional Launch at Login setting that is disabled by default, so that startup behavior remains under my control.
51. As a user, I want to hide or restore all Notic UI with Control-Option-Command-H, so that I can temporarily clear the screen.
52. As a user, I want notes to participate across normal desktop Spaces, so that changing Spaces does not make the utility disappear.
53. As a user, I want an optional “Show above all apps” setting, so that notes can remain visible while I work.
54. As a user, I want full-screen-app visibility to be opt-in, so that Notic does not intrude on full-screen work by default.
55. As a Stage Manager user, I want the deck to remain consistently reachable, so that its utility role is not tied to one app group.
56. As a user who connects or disconnects displays, I want pills and open-note state reconciled safely, so that notes are never stranded off-screen.
57. As a user, I want all displays to show one shared collection of notes, so that each display does not create a separate data silo.
58. As a user, I want resizing or resolution changes to keep Notic inside visible screen bounds, so that controls remain reachable.
59. As a user, I want Notic to avoid silently discarding edits when persistence fails, so that my writing remains recoverable.
60. As a user, I want a non-blocking save warning and automatic retry, so that a temporary failure does not interrupt writing.
61. As a VoiceOver user, I want meaningful labels, values, and actions for every control and note, so that I can use the full application.
62. As a keyboard-only user, I want complete navigation and activation without a pointer, so that all core workflows are accessible.
63. As a user with Reduce Motion enabled, I want deck movement replaced with restrained fades, so that animation does not cause discomfort.
64. As a user with increased contrast or dark appearance enabled, I want the interface to adapt automatically, so that content remains readable.
65. As a user with larger text needs, I want the editor to support scalable typography, so that note content remains comfortable to read.
66. As a privacy-conscious user, I want notes stored locally inside the application sandbox, so that another company does not hold my data.
67. As a privacy-conscious user, I want Notic to work without an account, so that note-taking requires no identity.
68. As an offline user, I want every version-one capability to work without a network connection, so that Notic is dependable anywhere.
69. As a privacy-conscious user, I want no analytics, telemetry, crash-reporting SDK, or hidden network request, so that application behavior is transparent.
70. As a user, I want Notic to request no Accessibility, Screen Recording, or Input Monitoring permission for normal operation, so that it keeps a minimal permission footprint.

## Implementation Decisions

- The deployment target is macOS 14 Sonoma or newer.
- The application will be implemented in Swift, using SwiftUI for application views and targeted AppKit APIs for menu-bar presence, panels, focus behavior, Spaces behavior, screen coordination, and window-level control.
- Notic will behave as a menu-bar utility and hide its Dock icon by default. A preference may switch the application activation policy to expose the Dock icon.
- The visible edge surfaces and expanded editors will use managed AppKit panels. Hovering and fanning must remain non-activating; an explicit editor click may activate Notic.
- The core deck interaction will be modeled as explicit observable states: dormant, fanned, and note-open. State transitions will be driven by pointer entry, pointer exit, note selection, close, hide, display removal, and application lifecycle events.
- The default edge is the right side. Positioning logic will represent an edge explicitly so support for other edges can be added without rewriting screen geometry.
- Each active display gets its own presentation coordinator, while every coordinator observes one shared workspace and note collection.
- A display may have at most one expanded note. If that display disappears, its open editor closes safely and all pending content is persisted; the note itself remains available.
- The dormant pill will expand after approximately 120 milliseconds of sustained hover and collapse approximately 350 milliseconds after pointer exit. These delays prevent accidental activation and pointer-boundary flicker.
- Fanned notes will animate with a short spring and approximately 45 milliseconds of stagger between cards. Reduce Motion replaces positional spring movement with restrained opacity transitions.
- The active deck displays at most eight notes. Overflow is represented by a “+N more” tile linked to the library.
- An expanded note defaults to approximately 580 by 420 points and can be resized within defined minimum and maximum bounds. Restored frames are clamped to the current display's visible frame.
- The visual palette contains yellow, coral, mint, blue, and lavender. Semantic foreground colors, controls, and borders must meet accessible contrast in light mode, dark mode, and Increased Contrast.
- Typed note content is plain text. A bundled, redistributable handwriting-style font is the default display choice, with a system-font preference for accessibility and legibility.
- The persistent note model contains a stable identifier, title, body, color, manual order, editor size, creation date, modification date, lifecycle state, and optional pending-deletion deadline.
- Note lifecycle state distinguishes active, archived, and pending deletion. Closing an editor changes presentation state only and never changes note lifecycle state.
- SwiftData is the local persistence technology. Version one has one local store inside the application sandbox and no CloudKit configuration.
- Text edits use a 250-millisecond trailing autosave debounce. Pending edits flush on editor close, application termination, and relevant scene lifecycle changes.
- A failed save retains current content in memory, exposes a non-blocking error state, and schedules retry. The UI must not report “Saved” until persistence succeeds.
- Deletion marks a note as pending deletion for ten seconds. Undo restores the note to its prior lifecycle state. Expired deletions are finalized during normal operation and reconciled at launch.
- New notes are inserted first in manual deck order. User-driven reordering updates stable ordering values and persists atomically.
- The library searches titles and bodies, filters active and archived notes, and supports multi-selection for archive, restore, and delete commands.
- Global keyboard shortcuts are Option-Command-N for a new note, Option-Command-L for the library, Option-Command-A for the archive, and Control-Option-Command-H for global hide/show.
- Global shortcuts will use a macOS system hotkey mechanism that does not require Accessibility or Input Monitoring permission.
- Launch at Login will use the supported macOS service-management API and remain disabled until the user opts in.
- Panels participate across normal Spaces. Always-on-top and full-screen visibility are independent opt-in preferences and are expressed through AppKit window levels and collection behavior.
- Settings persist locally and include font choice, Dock icon visibility, Launch at Login, always-on-top behavior, and full-screen visibility.
- The menu-bar menu provides New Note, All Notes, Archive, Hide/Show Notic, Settings, and Quit.
- Version one performs no network requests and includes no authentication, analytics, telemetry, advertising, crash-reporting SDK, or third-party service integration.
- Note content is not encrypted by Notic in version one. The security boundary is the application sandbox plus the user's macOS account and optional FileVault protection.
- Notic will use original product naming, iconography, measurements, font selection, controls, and animation details rather than duplicating another application's visual identity.
- Initial distribution targets a sandboxed development build followed by signed and notarized direct distribution outside the Mac App Store.

## Testing Decisions

- Tests verify externally observable behavior through confirmed public seams. They do not assert private methods, storage implementation details, internal collaborator calls, or view hierarchy structure.
- Development follows vertical TDD slices: one failing behavioral test, the minimum implementation required to pass, and then the next behavioral test. Tests are not written as a speculative horizontal batch.
- Expected values come from this specification and worked behavioral examples. Tests must not reproduce production algorithms to calculate their own expected result.
- Two public test seams are confirmed:
  1. **NoticWorkspace seam:** issue user-level commands and observe published workspace state. Tests use a real temporary SwiftData store rather than mocking persistence. This seam covers note creation and editing, autosave outcomes, restoration, manual ordering, archive and restore, pending deletion and Undo, expired deletion reconciliation, search, filtering, overflow count, settings, and save-error presentation.
  2. **Application accessibility seam:** launch the built application and interact through its accessible UI and system-visible behavior. This seam covers the edge pill, fan/open/collapse behavior, focus safety, menu commands, global shortcuts, keyboard navigation, panel visibility, display-boundary behavior, accessibility labels, and reduced-motion presentation.
- Time-dependent workspace behavior will be exercised with a controllable public scheduling boundary so tests can advance the autosave debounce, hover delays, collapse grace period, and deletion deadline without sleeping.
- Persistence tests observe behavior by closing and recreating the workspace against the same temporary store, then inspecting restored public state. Tests do not query SwiftData tables directly.
- Save-failure tests use a workspace configuration whose persistence boundary can report a failure, then verify that the visible state remains unsaved, content stays present, and a later retry can succeed.
- Application tests verify that hover alone does not change the active application. Editor activation is expected only after an explicit click.
- Application tests cover display attachment, display removal, visible-frame changes, and restoration clamping at the highest reliable system boundary available in the test environment.
- Accessibility tests verify names and actions, keyboard traversal, system-font mode, dark appearance, Increased Contrast, and Reduce Motion behavior.
- Critical acceptance scenarios include relaunch with unsaved-debounce work flushed, relaunch during pending deletion, reordering followed by relaunch, archiving followed by search, more than eight active notes, removing a display with an open note, and a failed save followed by retry.
- The repository is greenfield and contains no prior test suite or comparable test seam. The first vertical slice establishes the conventions subsequent tests will follow.

## Out of Scope

- iCloud, CloudKit, folder-based, server-based, or cross-device synchronization
- App-level note encryption or keychain-managed encryption keys
- Markdown rendering or syntax behavior
- Rich text, text styling, embedded links, and formatted checklists
- Images, files, audio, drawing, or other attachments
- Reminders, alarms, calendar integration, and notifications
- Tags, folders, smart groups, and saved searches
- Sharing, collaboration, accounts, teams, and permissions
- Import and export
- Version history and conflict resolution
- Licensing, subscriptions, payments, trials, and receipt validation
- Analytics, telemetry, remote logging, and third-party crash reporting
- iPhone, iPad, Apple Watch, visionOS, Windows, web, or Android applications
- Docking to edges other than the right edge in the first release
- More than one simultaneously expanded note per display
- Mac App Store submission in the initial release path

## Further Notes

- Notic is a greenfield application; the workspace contained no source files, project configuration, ADRs, domain glossary, or existing test conventions when this specification was written.
- “Note” means a persisted title/body record. “Active note” means a note shown in the edge deck. “Archived note” means a retained note excluded from the deck. “Deck” means the ordered active-note presentation. “Pill” means the dormant edge affordance. “Library” means the searchable management window.
- There is no authentication behavior because version one has no accounts. There is no mobile behavior because version one is macOS-only. Network loading states do not apply because version one is fully local.
- The main error state is persistence failure. Empty states exist for a workspace with no notes, an empty archive, and a search with no matches.
- The enclosing Git repository had no configured remote or issue tracker at specification time, so this document could not be published or labeled `ready-for-agent`.

## Build Checklist

- Establish the macOS application and test targets with macOS 14 as the minimum deployment target.
- Implement the NoticWorkspace public seam and the first create-note TDD slice.
- Add the SwiftData model and real temporary-store test configuration.
- Implement note editing and the autosave/flush lifecycle through vertical TDD slices.
- Implement archive, restore, pending deletion, Undo, and launch reconciliation.
- Implement manual ordering, search, filtering, and overflow behavior.
- Implement menu-bar presence, settings, Dock policy, and Launch at Login.
- Implement the per-display pill and deck state machine.
- Implement non-activating fan behavior and activating editor behavior.
- Implement editor resizing, frame restoration, and screen-bound clamping.
- Implement global shortcuts without sensitive permissions.
- Implement Spaces, always-on-top, full-screen, Stage Manager, and display-change behavior.
- Add the library window and multi-selection actions.
- Add original visual styling, bundled-font licensing evidence, and accessible system-font mode.
- Add VoiceOver semantics, keyboard navigation, dark appearance, Increased Contrast, and Reduce Motion.
- Add persistence-failure warning and retry behavior.

## Review Checklist

- Verify every behavior is covered at one of the two confirmed public seams.
- Reject tests coupled to private methods, SwiftData table inspection, or fragile view hierarchy details.
- Verify hovering never activates Notic or steals keyboard focus.
- Verify no close action can archive, delete, or lose a note.
- Verify every persistence path flushes or retains unsaved content safely.
- Verify pending deletions reconcile correctly across termination and relaunch.
- Verify display and Space changes cannot strand a panel off-screen.
- Verify global shortcuts do not require Accessibility or Input Monitoring permission.
- Verify the app contains no network client, analytics, telemetry, secrets, or third-party tracking SDK.
- Verify all colors and appearances retain accessible contrast.
- Verify VoiceOver, keyboard-only operation, scalable fonts, and Reduce Motion.
- Verify visual identity and assets are original.
- Verify the project contains no unlicensed bundled font or asset.

## Deployment Checklist

- Build and test the Release configuration on the oldest supported macOS version.
- Run workspace tests and application accessibility tests on clean local data.
- Exercise multiple displays, Spaces, Stage Manager, and full-screen applications manually.
- Verify sandbox entitlements and confirm no unnecessary permissions are requested.
- Verify Launch at Login registration and removal.
- Verify no outbound network traffic occurs during every core workflow.
- Sign the application with a Developer ID certificate.
- Submit the build for Apple notarization and staple the notarization ticket.
- Verify installation and first launch on a clean Mac user account.
- Document local data location, backup limitations, uninstallation, and privacy behavior.
