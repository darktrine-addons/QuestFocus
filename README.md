# QuestFocus

Narrow the set of tracked quests to ones relevant to your current zone, with one-click revert. Two small buttons attach to the objective tracker; no settings panel; no auto mode (yet).

## What it does

- **🔍 Focus button** — Re-tracks only the quests that have an objective or POI in your current zone. Quests outside the zone are un-tracked. Idempotent and safe to re-apply when you change zones.
- **↶ Revert button** — Restores the watch list to exactly what it was before the first Focus action. Snapshot is per-character and survives `/reload`.
- **Filter-active feedback** — The 🔍 symbol turns green while a filter is in effect.
- **Restorable-count badge** — A small yellow number on the ↶ button shows how many quests would be re-tracked on revert. Hidden when zero.

## What it doesn't do

- No settings panel, no auto-on-zone-change (yet).
- No buttons inside the quest log panel — only on the tracker.
- Does not collapse tracker sections.
- Does not write any custom keys onto Blizzard frames.
- Does not call any API during combat. Buttons disable visually and become click-through, so clicks pass through to whatever is behind.

## Layout

The two buttons are parented to `ObjectiveTrackerFrame.Header` (modern retail; falls back to `HeaderMenu` / `ObjectiveTrackerFrame` itself on older builds). They inherit visibility from the tracker — when nothing is tracked and the tracker hides itself, the buttons hide too. When Edit Mode moves or scales the tracker, the buttons follow.

## Slash commands

- `/qf` (or `/qf filter`) — apply Focus to current zone
- `/qf revert` — restore original watch list
- `/qf status` — print whether filter is active and how many quests are restorable
- `/questfocus` — long alias for any of the above

## How "relevant" is decided

A quest counts as relevant to your current zone if its quest log entry's `isOnMap` or `hasLocalPOI` is true. These are the two fields the quest log API exposes that reflect zone relevance.

## Strict revert

If you manually add or remove watches *while a filter is active*, those interim changes are discarded on revert — the snapshot is restored exactly. Tooltip on the ↶ button warns about this.

## License

GNU General Public License v2 (see `LICENSE`).
