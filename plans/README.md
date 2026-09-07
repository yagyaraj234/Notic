# Animation plans

| # | Title | Severity | Status |
| --- | --- | --- | --- |
| 001 | [Use a 120ms hover curve for pill and tab peeks](001-snappy-hover-peeks.md) | HIGH | DONE |
| 002 | [Remove animation from library keyboard navigation](002-library-keyboard-no-animation.md) | HIGH | DONE |
| 003 | [Route chrome, press, and panel curves through Motion](003-motion-token-cohesion.md) | MEDIUM | DONE |
| 004 | [Give the overflow tab the same hover peek as note tabs](004-overflow-tab-peek.md) | MEDIUM | DONE |
| 005 | [Match the add-button press scale to the deck](005-add-button-press-scale.md) | LOW | DONE |
| 006 | [Ease the editor paper when the swatch changes](006-editor-paper-recolor.md) | LOW | DONE |
| 007 | [Crossfade the library list when the filter or emptiness changes](007-library-filter-crossfade.md) | LOW | DONE |
| 008 | [Fan the first-note prompt in with the empty deck](008-first-note-prompt-entrance.md) | LOW | DONE |

## Execution order

Implemented together. Original order was `001` → `002` → `003` → `004` → lows.

Run with `improve-animations execute <slug>` or any agent given the plan file.
