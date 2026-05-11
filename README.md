# QuestFocus

Narrow the set of tracked quests to the ones relevant to your current zone, with one-click revert. Designed to be quiet, predictable, and taint-free.

> **Status:** Scaffold only. No features wired yet. The release packaging pipeline is in place; the actual filter / revert logic, UI buttons, and optional auto-on-zone-change mode are not yet implemented.

## Planned behavior

- **Focus button** — Re-tracks only the quests that have an objective or POI in your current zone. Quests outside the zone are un-tracked.
- **Revert button** — Restores the watch list to whatever it was before the first Focus action. Snapshot is per-character and survives `/reload`.
- **Optional auto-focus** — A setting that re-runs the filter automatically when you change zones (debounced; skipped inside instances if "Open World Only" mode is chosen).
- **Buttons in two places** — adjacent to the objective tracker's minimize button, and inside the quest log panel on the world map.

## What it does *not* do

- Does not collapse tracker sections (that's the problem space of QuestLogCollapse and is constrained by Blizzard's UIWidget pool taint mechanics — see issue #25 / PR #29 / PR #30 in the QLC repo).
- Does not modify quest progress or state. The only thing it touches is the watch list (`C_QuestLog.AddQuestWatch` / `RemoveQuestWatch`).
- Does not hook Blizzard frames or write custom keys onto them.

## Slash commands

- `/qf` — short alias
- `/questfocus` — full

Both currently print a "scaffold loaded" message and nothing else.

## License

GNU General Public License v2 (see `LICENSE`).
