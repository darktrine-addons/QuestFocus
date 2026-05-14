# QuestFocus

Narrow the set of tracked quests to ones relevant to your current zone, with one-click revert. Two small buttons attach to the objective tracker, and a mirror pair attaches above the world-map quest log's tab strip. No settings panel; no auto mode (yet).

## What it does

- **🔍 Focus button** — Click: narrow your watch list — untrack quests with no objective in the current zone. Quests in the zone that you haven't tracked are left alone. **Shift-click**: same untrack pass, *plus* promote any zone-relevant quest from your quest log into the watch list. Idempotent and safe to re-apply when you change zones.
- **↶ Revert button** — Restores the watch list to the snapshot taken when you first pressed Focus, **plus any quests you've added since** (manually or via Blizzard's auto-track). Snapshot is per-character and survives `/reload`.
- **Tri-state filter indicator** — The 🔍 icon shows:
  - White: no filter applied
  - Green: filter applied, watch list still matches what the filter left it as
  - **Yellow**: filter applied, but quests have been added to the watch list since (e.g. you accepted a new quest with autoQuestWatch on)
- **Restorable-count badge** — A small yellow number on the ↶ button shows how many quests would be re-tracked on revert. Hidden when zero.

## Re-applying the filter

When you press 🔍 while in the yellow state, the interim quests are folded into the snapshot before re-narrowing. That way they're preserved if you later revert. The indicator returns to green after re-apply.

## Auto-promote while filter is active

When a new quest enters your log while the filter is active, QuestFocus checks whether it's zone-relevant. If yes, it's added to the watch list immediately, no click needed.

This closes a gap with Blizzard's `autoQuestWatch`: event quests like *Void Assaults: Eversong Woods* enter your log on first progress without auto-tracking, so they'd otherwise stay invisible behind a filter. Auto-promote treats them the same way `autoQuestWatch` treats normally-accepted quests.

Caveat: if you manually un-track an auto-promoted quest, it stays un-tracked — we only promote *new* arrivals, not "re-promote anything zone-relevant on every quest-log update."

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

**Quest-log pair**: parented to `QuestMapFrame`, anchored directly above `QuestMapFrame.QuestsTab` (the small tab on the panel's upper-left in modern retail). Visible whenever the world map is open. Shares all state with the tracker pair — pressing one updates the other instantly.

## Slash commands

Work in any context, including with the world map open:

- `/qf` (or `/qf filter`) — focus on current zone (narrow only)
- `/qf promote` (or `/qf filtershift`) — shift-click equivalent: also promote untracked zone quests from your log
- `/qf revert` — restore pre-filter watch list plus any quests you've added since
- `/qf status` — print current filter / restorable counts

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
