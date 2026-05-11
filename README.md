# QuestFocus

Narrow the set of tracked quests to ones relevant to your current zone, with one-click revert. Two small buttons attach to the objective tracker AND inside the world-map quest log; no settings panel; no auto mode (yet). Both locations share state — pressing one button affects the other.

## What it does

- **🔍 Focus button** — Re-tracks only the quests that have an objective or POI in your current zone. Quests outside the zone are un-tracked. Idempotent and safe to re-apply when you change zones.
- **↶ Revert button** — Restores the watch list to the snapshot taken when you first pressed Focus, **plus any quests you've added since** (manually or via Blizzard's auto-track). Snapshot is per-character and survives `/reload`.
- **Tri-state filter indicator** — The 🔍 icon shows:
  - White: no filter applied
  - Green: filter applied, watch list still matches what the filter left it as
  - **Yellow**: filter applied, but quests have been added to the watch list since (e.g. you accepted a new quest with autoQuestWatch on)
- **Restorable-count badge** — A small yellow number on the ↶ button shows how many quests would be re-tracked on revert. Hidden when zero.

## Re-applying the filter

When you press 🔍 while in the yellow state, the interim quests are folded into the snapshot before re-narrowing. That way they're preserved if you later revert. The indicator returns to green after re-apply.

## Revert semantics (merge)

`revert_target = snapshot ∪ quests_added_since`

This preserves any quest you've accepted/tracked since the filter was applied. Quests the filter itself added (zone-relevant additions) get cleaned up. The only case where revert overrides a user choice is if you manually *un-tracked* a quest that was in the original snapshot — revert re-tracks it, on the principle that "revert" means "go back to that snapshot." A configurable opt-in for "user untracks also remove from snapshot" is on the polish backlog.

## What it doesn't do

- No settings panel, no auto-on-zone-change (yet).
- No buttons inside the quest log panel — only on the tracker.
- Does not collapse tracker sections.
- Does not write any custom keys onto Blizzard frames.
- Does not call any API during combat. Buttons disable visually and become click-through, so clicks pass through to whatever is behind.

## Layout

**Tracker pair**: parented to `ObjectiveTrackerFrame.Header` (modern retail; falls back to `HeaderMenu` / `ObjectiveTrackerFrame` itself on older builds). Anchored next to the minimize button. Inherit visibility from the tracker — when nothing is tracked and the tracker hides itself, the buttons hide too. When Edit Mode moves or scales the tracker, the buttons follow.

**Quest-log pair**: parented to `QuestMapFrame` (the side panel inside `WorldMapFrame`). Anchored to the top-right corner of the quest log panel. Inherit visibility from the panel — when the world map is closed or the side panel is collapsed, the buttons hide. Available whenever the quest log is open.

Both pairs share the same underlying state, so toggling filter or revert from one location updates the visual state of the other immediately.

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
