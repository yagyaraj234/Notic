# 0001 — Keep the dock on the right edge, and keep "lock" out of the product

- **Status**: Accepted
- **Date**: 2026-09-08

## Context

Notic's settings window was rebuilt around two panes, General and About, and
five new preferences (text size, open delay, animation speed, fan trigger,
keep the deck open). The design work was done against screenshots of a
comparable edge-docked notes application, whose settings screen also offers:

- **Screen side** — left, right, or bottom edge for the dock
- **Display** — which screens carry a dock
- **Lock notes** — hide note contents until the user authenticates

All three were considered and rejected. A future reader holding those same
screenshots will wonder why Notic's settings stop where they do, which is why
this is written down.

## Decision

**Screen side is out.** The dock lives on the right edge only.

`EdgeLayout` computes every frame from the right edge: pill and deck frames,
the shingle step, editor placement level with its tab, and the direction a tab
leans. Tab labels are drawn rotated for a vertical edge and would need a
different orientation entirely on the bottom. Supporting three sides is not a
preference, it is a rewrite of the geometry layer plus per-display state for
which side each dock is on. It is also directly contrary to `SPEC.md` user
stories 1 and 2, which specify the right edge on every display.

**The display picker is out.** `DisplayCoordinator` attaches a dock to every
active display, and `NoticWorkspace` reconciles displays as they connect and
disconnect so notes are never stranded off-screen. Letting the user exclude a
display adds a persisted set that has to survive display identifiers changing
between sessions, for a preference nobody has asked for.

**"Lock" stays out of the vocabulary.** The feature was first specified as
deletion protection rather than authentication, and then dropped entirely. Had
it shipped under the name "lock", Notic would have used a word that means
authentication everywhere else in this product category to mean something
weaker. Deletion is already protected by a ten-second Undo window that
survives relaunch (`NoticWorkspace.delete`, SPEC stories 40–42), which covers
the accidental click that deletion protection would have covered.

## Consequences

- The geometry layer stays single-purpose and the right edge stays an
  invariant that `EdgeLayout` and the panel controllers can rely on.
- If screen side is ever wanted, it is a project of its own: a new ADR, a
  change to SPEC stories 1–2, per-display side state, and a rewrite of tab
  label orientation and editor placement. It is not a settings row.
- Notic has no authentication and no encryption story, and does not imply one.
  Notes are plain text in the app sandbox, as the About pane states.
- Anyone comparing Notic's settings to the reference screenshots will find
  three deliberate absences rather than three oversights.
