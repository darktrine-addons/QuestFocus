# QuestFocusParty MVP — slice plan

Companion to [QuestFocusParty.md](QuestFocusParty.md). That document describes
*what* we build; this one describes *the order* in which we build it, broken
into commit-sized slices that each leave the addon in a working, testable state.

Every slice ends with: addon loads cleanly, `/qf` filter buttons still work,
new behaviour can be tested in isolation. No slice introduces a half-functional
intermediate state that can't be merged on its own.

---

## Pre-flight assumptions

- We commit to a `feat/party` topic branch off `main`; merge to `main` only
  after slice 9 passes UX review.
- `Test/PartyProbe.lua` stays in tree through slice 7 (we re-probe at each
  milestone). Removed in slice 10.
- Each slice gets its own commit. No squashing on merge — keep the history
  legible for future debugging.

---

## Slice 0 — Refactor `ZoneFilter/` subtree (pre-requisite)

**Goal:** move the existing filter/revert code into a `ZoneFilter/` namespace
so the new party module has a peer namespace to land in.

- Move `Core/*.lua` → `ZoneFilter/Core/*.lua`
- Move `UI/Buttons.lua`, `UI/ButtonTracker.lua`, `UI/ButtonQuestLog.lua` →
  `ZoneFilter/UI/*.lua`
- Update TOC load order accordingly
- Introduce empty `Core/Config.lua` with `ns.Config = { modules = {} }` —
  populated by future slices
- Update `QuestFocus.lua` bootstrap to call into `ZoneFilter` namespace
  (`ns.ZoneFilter.Boot()`) instead of `ns.Core.*` directly. Keep the slash
  command handlers where they are; they call the same Apply/Revert functions
  through the new module path.

**Files touched:** TOC, every Core/UI file (path move), QuestFocus.lua

**Acceptance:** addon loads; filter and revert buttons behave identically;
slash commands work; no behavioural change. Diff is almost entirely renames.

**Risk:** low. Pure mechanical refactor. The one risk is `ns.Core.*` callers
in `UI/` files — search-and-replace.

---

## Slice 1 — Module-toggle scaffold

**Goal:** introduce `ns.Config.IsModuleEnabled(name)` so future slices can
gate registration behind it.

- Flesh out `Core/Config.lua`:
  - Read `QuestFocusDB.modules` on `ADDON_LOADED`
  - Default both modules to `enabled = true` if absent
  - Export `IsModuleEnabled(name)` accessor
- Wrap `ZoneFilter` boot in `if ns.Config.IsModuleEnabled("ZoneFilter") then …`
- Add `/qf module list` slash sub-command (read-only for now)

**Acceptance:** `/qf module list` prints `ZoneFilter: enabled`. Toggling
`QuestFocusDB.modules.ZoneFilter.enabled = false` in SavedVars and `/reload`
makes the filter buttons not mount. Re-enable + `/reload` restores them.

**Risk:** low. Affects bootstrap order only.

---

## Slice 2 — `PartySync/` skeleton + dormant load

**Goal:** create the new module's file layout, loadable, but doing nothing.

- Create `PartySync/Core/State.lua` with empty `ns.PartySync.State = {}`
- Create `PartySync/Boot.lua` that registers `ns.PartySync.Boot()` and
  early-returns if `Config.IsModuleEnabled("PartySync") == false`
- Add `PartySync/Boot.lua` and `PartySync/Core/State.lua` to TOC
- Wire `QuestFocus.lua` to call `ns.PartySync.Boot()` after `ns.ZoneFilter.Boot()`
- Default `QuestFocusDB.modules.PartySync = { enabled = true }`
- `/qf module list` now lists both modules

**Acceptance:** addon loads; both modules listed; PartySync.Boot() runs but is
a no-op past the enable check. Disabling via SavedVars + reload makes the
boot function return immediately.

**Risk:** low.

---

## Slice 3 — Pure data plane: parse `GetQuestPartyProgress`

**Goal:** wire the API call + line-walk parser as pure functions, validate
against the probe data, no UI.

- `PartySync/Core/Fetch.lua` exports `Fetch.GetPartyProgress(questID) →
  { [guid] = { name, objectives = { {text, completed, numFulfilled,
  numRequired}, ... } } }`
- Calls `C_TooltipInfo.GetQuestPartyProgress(questID, true, true)` and walks
  `data.lines` per §6.0 of the design doc
- Handle the documented nil case and the empty-lines case (return empty table)
- Detects "Not on quest" via `|cff7f7f7f` colour-code prefix on objective text
- Adds `/qfprobe2 <questID?>` test slash command that calls Fetch and prints
  the parsed structure for one questID (or the first watched quest if omitted)

**Acceptance:** Run `/qfprobe2` while in a party with shared quests. Output
prints partymate names + their objective rows. Output for solo player =
empty. Output for an "Armies of Legionfall"-style quest the partymate
doesn't have shows them with `state="not_on_quest"`.

**Risk:** medium. The Fetch function is the load-bearing primitive; bugs here
ripple to everything downstream. Test thoroughly with the existing probe SV
data as reference (we know what shape to expect).

---

## Slice 4 — Per-quest aggregate state

**Goal:** the 4-state ladder (green / yellow / blue / orange / hidden) derived
from Fetch output + caller's own progress.

- `PartySync/Core/Aggregate.lua` exports `Aggregate.Compute(questID) → state
  enum` where state ∈ `{ "aligned", "mixed", "ready_turn_in", "alone_shareable",
  nil }`
- Implements the §5.3 priority pseudocode using `Fetch.GetPartyProgress(qid)`
- For `alone_shareable`: needs partymate zone info. Use
  `C_Map.GetBestMapForUnit("partyN")` for each partymate; compare to
  caller's `C_Map.GetBestMapForUnit("player")`
- No UI yet — just a function returning an enum
- Extend `/qfprobe2 <questID>` to also print the aggregate state

**Acceptance:** for a party of 2 on the same in-progress quest in the same
zone, `/qfprobe2` reports `aligned`. For a quest only the caller has,
reports `alone_shareable` (if partymate's in same zone) else `nil`. For
a partymate who completed but caller hasn't, reports `ready_turn_in`.

**Risk:** medium. Edge cases in §9 (phasing, cross-realm parties, scenario
quests) will surface here. Catalogue what we see; only fix the show-stoppers
in this slice.

---

## Slice 5 — Indicator widget pool (no tracker integration yet)

**Goal:** an addon-owned frame pool that can render a coloured dot anywhere,
de-risked separately from tracker hookup.

- `PartySync/UI/Indicator.lua` exports `Indicator.Acquire() → frame`,
  `Indicator.Release(frame)`, and `Indicator.SetState(frame, stateEnum)`
- Frame is a `CreateFrame("Frame")` of size 8×8 with a `Texture` child for
  the colour fill. Colour palette from §4.2 of design doc.
- `Indicator.Release` returns the frame to a free list (no `CreateFrame`
  churn between re-mounts)
- Test slash: `/qf party widgettest` creates 4 indicators in a row at fixed
  screen positions, one per state, to eyeball the colours

**Acceptance:** `/qf party widgettest` shows green / yellow / blue / orange
dots in the middle of the screen. Run again — old dots replaced, no leak.
`Indicator.Release` returns frame to pool (verify via `#pool` debug print).

**Risk:** low. Pure addon-side widget code. No Blizzard frame interaction.

---

## Slice 6 — Mount indicators on tracker rows

**Goal:** wire slice-5 widgets onto the actual `ObjectiveTrackerFrame` quest
rows, keyed on questID.

- `PartySync/UI/MountTracker.lua`:
  - Side-table `{ [questID] = indicatorFrame }` — keyed on questID, **never**
    written to the tracker row
  - Hook into the tracker manager's row-update callback. In modern retail
    this is via `ObjectiveTrackerManager` events or via `ObjectiveTracker_Update`
    secure hook — choose whichever path doesn't require writing fields to
    Blizzard frames (per `wow_blizzard_frame_field_write_taint.md`)
  - For each visible quest row, look up the row's questID, acquire an
    indicator (or reuse the existing one), anchor it `TOPRIGHT` of the row's
    title region offset (-2, -2), set state via `Aggregate.Compute(qid)`
  - When the row is recycled / hidden / re-purposed, release the indicator
    back to the pool
- Refresh-trigger event list per §6.0 of the design: `QUEST_LOG_UPDATE`,
  `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE`,
  `UNIT_QUEST_LOG_CHANGED`, plus a 3-second safety-net timer (only running
  while in a party)

**Acceptance:** while in a party, every watched quest in the tracker shows
the correct-colour dot. Un-track a quest — dot disappears (frame released).
Re-track — dot re-appears. Leave party — all dots hide. Re-join — they
re-appear. Edit Mode move tracker — dots follow.

**Risk:** high. Tracker row enumeration in modern retail is tricky. Fall-back
plan: if a clean row-update callback isn't available, use a per-frame
`OnUpdate` (throttled to ~3 Hz) that walks visible quest rows. Less
elegant, but no taint risk.

---

## Slice 7 — Alt-hover detail tooltip

**Goal:** Alt-hover the dot → focused tooltip with per-member breakdown,
class-coloured.

- `PartySync/UI/Tooltip.lua`:
  - On indicator's `OnEnter`, check `IsAltKeyDown()`. If true, show
    `GameTooltip` with the §4.3 layout: quest title; "Party state:"; one row
    per member with state-colour dot, class-coloured name, state text
  - Member rows sorted: self → completed → in_progress → not_on_quest
  - On `OnLeave` or `MODIFIER_STATE_CHANGED` to Alt-up, hide tooltip
- Class colour via `RAID_CLASS_COLORS[class]`; class via `UnitClass("partyN")`
  correlated by character name (strip realm suffix for the lookup)

**Acceptance:** Alt-hover any dot → tooltip appears with members listed in
correct order, class colours visible, dots beside names matching their
individual states. Release Alt or move off the dot → tooltip dismisses.

**Risk:** medium. `MODIFIER_STATE_CHANGED` is the right event but easy to
wire wrong; verify with explicit testing of "Alt down then mouse-off vs.
mouse-down then Alt-up" both dismiss correctly.

---

## Slice 8 — Edge cases + module toggle UX

**Goal:** the rough edges from §9 + a few must-have config knobs.

- Suppress indicators when:
  - Solo (no party — already implicit since `Aggregate.Compute` returns nil)
  - Quest is in caller's log but has no `numQuestWatches` row visible
- `/qf module disable PartySync` → unregister events, release all
  indicators, hide tooltip. Mirror for `enable`. Persists across reload.
- `/qf party broadcast on|off` — no-op stub for now (we have no broadcast
  in MVP). Slash command exists so the Phase-3 entry point doesn't have to
  rewire the parser later. Prints "broadcast not implemented in MVP".
- `/qf party debug` — toggle: prints aggregate-recompute events to chat with
  questID + computed state + member breakdown. Useful for further iteration.

**Acceptance:** all edge cases behave per spec. `/qf module disable PartySync`
+ no-reload required → all dots disappear, events unregistered (verify with
`/qf party debug` going silent).

**Risk:** low.

---

## Slice 9 — Documentation + README

**Goal:** ship-ready docs.

- README.md: add a "Party module (new in v0.2.0)" section with screenshots
  if available. Lists the four colour states + Alt-hover behaviour. Mentions
  `/qf module disable PartySync` for users who don't want it.
- TOC `## Notes:` updated
- CHANGELOG entry (or commit-message convention if no CHANGELOG yet)

**Acceptance:** README explains the feature without referencing internals.
A user reading only the README knows what the dots mean.

**Risk:** none.

---

## Slice 10 — Remove probe + tag v0.2.0-beta

**Goal:** clean up dev artefacts, tag a beta release.

- Delete `Test/PartyProbe.lua`
- Remove the `Test\PartyProbe.lua` line from TOC
- `git tag v0.2.0-beta` and push
- BigWigs packager runs, CurseForge picks up the beta

**Acceptance:** addon loads with no test module, no slash command pollution.
Tag visible on GitHub releases; CurseForge shows v0.2.0-beta.

**Risk:** none.

---

## Total scope estimate

10 commits, each one self-contained. Slices 0–2 are mechanical (refactor +
scaffold). Slice 3 is the load-bearing parser. Slices 4–7 are the actual
feature work. Slices 8–10 are polish + ship.

The two highest-risk slices are 3 (parser correctness — but de-risked by the
existing probe data) and 6 (tracker integration — the historical taint
minefield). Everything else is routine addon-Lua work.

If we hit a wall on slice 6 (tracker row enumeration in modern retail), the
fallback timer-driven sweep is a 1-hour change rather than a redesign — the
side-table architecture doesn't depend on which mechanism drives reconciliation.

---

## Out-of-scope reminder

Per the design doc, MVP explicitly does **not** include:
- Broadcast / addon-comm protocol (Phase 3)
- Settings UI panel (Phase 2)
- Raid (>5) per-member tooltip (Phase 2)
- World-map quest log indicators (Phase 4)
- Auto-share suggestions (Phase 4)

If any of these slip in during implementation, push back to a follow-up
phase — MVP is already 10 slices.
