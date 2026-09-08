# Notic — domain language

The words Notic uses, and what they mean. Implementation lives in the code;
this file is only the glossary. If a term here disagrees with the code, the
code is wrong.

## Surfaces

**Dock** — the resting marker at the right edge of a display: one coloured
dash per note in the deck, floating directly over the desktop with nothing
behind it. Always reachable, even when Notic is not the active application.

**Deck** — the same notes fanned out down the edge as colour tabs. The deck is
what the dock becomes; it is not a separate collection. At most eight notes
fan out; the rest sit behind the overflow tab.

**Tab** — one note's colour tab in the fanned deck, carrying a vertical label
and its own slight lean.

**Editor** — the expanded plain-text panel for one note, opened from its tab.
At most one editor is open per display.

**Library** — the one window listing every note, searchable, filterable by
lifecycle, with multi-selection for bulk actions.

**Archive** — where a note goes instead of being deleted. Reversible and
retained indefinitely. Archiving is never destruction.

**Quick menu** — the menu of the menu-bar status item: New Note, All Notes,
Archive, Hide, Settings, Quit. The one surface always on screen. It is *not* a
separate feature from the menu-bar item; it is that item's menu.

**Dock menu** — the menu shown on secondary-click of the dock or a tab. It
carries the note-level commands for the tab under the pointer, plus the
app-level commands of the quick menu. Both menus are built from one
definition, so they can never drift apart.

## Notes

**Note** — a title and a plain-text body, one colour, one size, one place in
the deck order. The unit of everything.

**Lifecycle** — a note is *active* (in the deck), *archived* (retained, out of
the deck), or *pending deletion* (inside its ten-second Undo window).

**To-do** — a line of a note's body marked up as a checkbox, written `[] ` at
the start of the line.

**Duplicate** — a new note copying an existing note's title, body, colour and
editor size, placed directly after its original in the deck order. A copy, not
a link: editing one never changes the other.

**Pin** — floats notes above other applications. Application-wide, not
per-note: there is no such thing as one pinned note.

**Paper** — the note's background. *Pastel* keeps it light in dark mode too;
*adaptive* darkens it to match the system appearance.

## Behaviour

**Open delay** — how long the pointer must rest on the dock before the deck
fans. Sustained hover, not a hover event: a pointer passing through does not
fan the deck.

**Fan trigger** — whether the deck fans on hover or only on click.

**Keep the deck open** — the deck stays fanned at the edge instead of resting
as the dock. It never collapses on pointer exit.

**Animation speed** — a multiplier over every duration in Notic's motion
vocabulary. It scales motion; it does not change which curve is used.

## Words Notic deliberately does not use

**Lock** — every comparable app uses it for hiding note contents behind
authentication. Notic has no such feature, so the word stays free rather than
being redefined as deletion protection. See ADR 0001.

**Screen side** — the dock lives on the right edge. There is no side to
choose. See ADR 0001.

**Dock style** — the dock is a column of dashes. There is no alternative
presentation to pick between.
