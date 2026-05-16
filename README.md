# QuestFocus

**Two small features for the quest tracker.** Narrow your watch list to the current zone with one click and revert it just as easily. When you're in a party, see at a glance which quests your partymates share, who's ready to turn in, and who isn't on the quest at all.

Retail only. Requires Midnight (Interface 120005+).

## Modules

QuestFocus ships two independently togglable modules:

- **ZoneFilter** — two small buttons attached to the objective tracker and to the world-map quest log: narrow the watch list to the current zone, then merge-revert when you're done.
- **PartySync** — coloured dots on each tracked quest row when you're in a party, plus an Alt-hover tooltip with per-member detail.

Both are on by default. Disable either via `/qf module disable <name>` — PartySync applies live, ZoneFilter requires `/reload`.

---

## ZoneFilter

### What it does

- **🔍 Focus button** — Click: narrow your watch list — untrack quests with no objective in the current zone. Quests in the zone that you haven't tracked are left alone. **Shift-click**: same untrack pass, *plus* promote any zone-relevant quest from your quest log into the watch list. Idempotent and safe to re-apply when you change zones.
- **↶ Revert button** — Restores the watch list to the snapshot taken when you first pressed Focus, **plus any quests you've added since** (manually or via Blizzard's `autoQuestWatch`). Snapshot is per-character and survives `/reload`.
- **Tri-state filter indicator** — The 🔍 icon shows:
  - White: no filter applied
  - Green: filter applied, watch list still matches what the filter left it as
  - **Orange**: filter applied, but quests have been added to the watch list since (e.g. you accepted a new quest with `autoQuestWatch` on)
- **Restorable-count badge** — A small yellow number on the ↶ button shows how many quests would be re-tracked on revert. Hidden when zero.

### Auto-promote while filter is active

When a new quest enters your log while the filter is active, QuestFocus checks whether it's zone-relevant. If yes, it's added to the watch list immediately, no click needed.

This closes a gap with Blizzard's `autoQuestWatch`: event quests like *Void Assaults: Eversong Woods* enter your log on first progress without auto-tracking, so they'd otherwise stay invisible behind a filter. Auto-promote treats them the same way `autoQuestWatch` treats normally-accepted quests.

If you manually un-track an auto-promoted quest, it stays un-tracked — we only promote *new* arrivals, not "re-promote anything zone-relevant on every quest-log update."

### Re-applying the filter

Press 🔍 while in the orange state and the interim quests are folded into the snapshot before re-narrowing. They're preserved if you later revert. The indicator returns to green after re-apply.

### Revert semantics (merge)

```
revert_target = snapshot ∪ quests_added_since
```

This preserves any quest you've accepted/tracked since the filter was applied. Quests the filter itself added (zone-relevant additions) get cleaned up. The only case where revert overrides a user choice is if you manually *un-tracked* a quest that was in the original snapshot — revert re-tracks it, on the principle that "revert" means "go back to that snapshot." A configurable opt-in for "user untracks also remove from snapshot" is on the polish backlog.

### Layout

**Tracker pair**: parented to `ObjectiveTrackerFrame.Header` (modern retail; falls back to `HeaderMenu` / `ObjectiveTrackerFrame` itself on older builds). Anchored next to the minimize button. Inherits visibility from the tracker — when nothing is tracked and the tracker hides itself, the buttons hide too. When Edit Mode moves or scales the tracker, the buttons follow.

**Quest-log pair**: parented to `QuestMapFrame`, anchored directly above `QuestMapFrame.QuestsTab` (the small tab on the panel's upper-left in modern retail). Visible whenever the world map is open. Shares all state with the tracker pair — pressing one updates the other instantly.

### How "relevant" is decided

A quest counts as relevant to your current zone if its quest log entry's `isOnMap` or `hasLocalPOI` is true, or if `C_QuestLog.IsOnMap(questID)` returns true. The last fallback catches completed quests whose turn-in is in the current zone — generally what you want when "focusing here".

---

## PartySync

### What it does

When you're in a party, every tracked quest in the objective tracker gets a small coloured dot in its top-right corner. The colour tells you at a glance how the quest stands across your group:

- 🟢 **Green** — *aligned*: every partymate is on the quest and progressing
- 🟡 **Yellow** — *mixed*: some partymates are on it, some aren't (coordination opportunity)
- 🔵 **Blue** — *ready to turn in*: at least one partymate has the objectives complete
- 🟠 **Orange** — *shareable*: only you have it, and at least one partymate is in the same zone (share the quest)
- *no dot* — no actionable group state, or you're solo

### Per-member detail in the row tooltip

Hover any tracked quest row as you normally would — Blizzard's tooltip appears with the quest description and objectives, and PartySync **appends** a "Party state:" section below: each member's name in their class colour, with their state on the right (`Ready to turn in` / `In progress (K/N)` / `Not on quest`). "You" comes first, then partymates sorted by state.

The indicator dots themselves are click-through — they're visual signals only, not separate hover targets.

### BNet visibility caveat

`C_TooltipInfo.GetQuestPartyProgress`, the API PartySync relies on, only returns real data for partymates who are **BNet-visible** to you. If a partymate has set themselves "appear offline" on Battle.net, they'll show up as `Not on quest` in the tooltip regardless of their actual state — and the aggregate dot may misfire (e.g. show orange "shareable" when they actually have the quest).

In practice this matches the audience: cooperative questing is almost always between BNet friends who are visible to each other. If you spot inconsistent data, BNet visibility is the first thing to check before filing a bug.

### Why no broadcast / addon-comm protocol?

Earlier drafts of this module assumed we'd need a custom `CHAT_MSG_ADDON` channel to share quest state between party members. The native `C_TooltipInfo.GetQuestPartyProgress` API covers everything the MVP needs — same data Blizzard's own quest-log tooltips render — so we use that instead. A broadcast layer is sketched out as Phase 3 future work in case it turns out to add value (BNet-hidden partymates, accept-recency, etc.).

---

## Slash commands

```
/qf                          apply ZoneFilter to current zone (narrow only)
/qf promote                  same plus promote untracked zone quests from log
/qf revert                   restore pre-filter watch list (merge semantics)
/qf status                   print filter active / restorable counts

/qf all                      track every quest in the log
/qf untrack                  untrack everything
/qf campaign                 track only campaign quests
/qf daily                    track only daily quests
/qf weekly                   track only weekly quests
/qf important                track only Important quests (purple triangle)
/qf ready                    track only ready-to-turn-in quests
/qf inprogress               track only in-progress quests

/qf module list              show enable/active state of both modules
/qf module enable <name>     enable a module (PartySync applies live; ZoneFilter needs /reload)
/qf module disable <name>    disable a module

/qf party debug              toggle per-quest aggregate-state diff prints (PartySync)
/qf party broadcast on|off   reserved; not implemented in MVP

/questfocus                  long alias for /qf
```

---

## What it doesn't do

- ZoneFilter has no auto-on-zone-change mode (yet).
- PartySync covers the tracker rows only — no world-map quest log indicators.
- PartySync does not broadcast or interpret addon-channel messages.
- Does not collapse tracker sections.
- Does not write any custom keys onto Blizzard frames (taint-safe by construction).
- ZoneFilter does not call any API during combat. Buttons disable visually and become click-through.

---

## Changelog

### v0.9.0-beta

**New features:**

- **Native settings panel.** Find QuestFocus under *Escape → Options → AddOns → QuestFocus*. Or Shift-Right-click any of the filter buttons.
- **Tracker mode menu.** Right-click the focus (🔍) button to pick from nine one-click tracker modes: *Track all*, *Track current zone*, *Track current zone + promote from log*, *Track campaign quests only*, *Track daily quests only*, *Track weeklies only*, *Track Important quests only* (the purple-triangle quests Blizzard marks), *Track ready-to-turn-in only*, *Track in-progress only*, *Untrack everything*. Each entry previews how many quests it would track and flags actions that would empty the tracker.
- **Active-mode awareness.** The menu shows which mode is currently in effect (`(active)` in green, `(drifted)` in orange). The lens tooltip headline now reads what the filter is doing right now — *No filter*, *Filter: weeklies only*, *Filter: campaign quests only (1 added)*, etc. — colour-matched to the lens dot.
- **Re-apply button** appears between the revert and lens buttons when a tracker mode is active and the watch list has drifted. One click cleans the drift without leaving the current mode. Hidden otherwise.
- **PartySync visual settings.** Tune indicator dots in the settings panel: size (6 / 8 / 10 / 12 px), shape (square / diamond), position (top-right corner / right of title / left of title), three colour palettes including red-green-friendly and blue-yellow-friendly variants, and a 40 %–100 % opacity slider. Inline style preview shows the current look; on-tracker preview button previews on real rows.
- **Quest-log autopilot.** Quests that complete or get abandoned are removed from filter state automatically.

**Improvements:**

- **Optional revert behaviour:** new per-character setting *Manual un-track also clears the snapshot*. When on, manually un-tracking a quest while a filter is active means revert won't restore it. Off by default (preserves the original behaviour where revert restores the exact pre-filter watch list).
- **Drift pulse.** When the filter transitions from clean to dirty (e.g. a new quest is auto-tracked while a filter is active), the lens icon briefly flashes to draw attention.
- **Raid handling.** In groups of 10 + members the per-member tooltip section is hidden automatically (it'd be too long). Indicator dots still show. Configurable threshold: always show / hide at 10 + / hide at 20 +.
- **Quest-icon clearance.** *Left of title text* indicator position now offsets 30 px to clear the quest-type icon column instead of overlapping it.
- **Click-binding hints in the menu** — the two zone-filter rows are labelled `[Left-click]` and `[Shift+Left-click]` so it's obvious which menu entry corresponds to which keyboard shortcut.
- **Slash commands** for every tracker mode: `/qf all`, `/qf untrack`, `/qf campaign`, `/qf daily`, `/qf weekly`, `/qf important`, `/qf ready`, `/qf inprogress` (existing `/qf`, `/qf promote`, `/qf revert`, `/qf status` still work).

**Fixes:**

- The triangular re-apply button no longer overflows off the world-map quest log's frame edge.
- PartySync indicators no longer attach to account-shared (warband) or bonus-objective quests where party state has no meaning.

**Behind the scenes:**

- State model and tracker-mode plumbing consolidated; reduces the chance of "you forgot to update X when Y changed" bugs as the addon grows.

### v0.3.0-beta

- **PartySync module** — coloured dot on every tracked quest row when in a party (green/yellow/blue/orange/hidden). Hover the row and Blizzard's normal quest tooltip gets a "Party state:" section appended: class-coloured member names with their state (`Ready to turn in` / `In progress (K/N)` / `Not on quest`) and a BNet-visibility footer when relevant. Attaches to both `QuestObjectiveTracker` and `CampaignQuestObjectiveTracker`, so campaign quests get the same treatment.
- **Auto-promote in ZoneFilter** — new quests entering the log while the filter is active are added to the watch list immediately if they're zone-relevant. Closes the `autoQuestWatch` gap on event quests like *Void Assaults*.
- **Module-toggle slash commands** — `/qf module list`, `/qf module enable|disable <name>`. PartySync hot-toggles; ZoneFilter still wants `/reload`.
- Source restructured under `ZoneFilter/` and `PartySync/` namespaces.

### v0.1.x

- Initial ZoneFilter feature: filter/revert buttons on the tracker and the world-map quest log.
- Merge revert semantics: pre-filter snapshot ∪ quests-added-since.
- Tri-state filter indicator (white / green / orange).
- Restorable-count badge on the revert button.
- Slash commands: `/qf`, `/qf promote`, `/qf revert`, `/qf status`.

---

## License

GNU General Public License v2 (see `LICENSE`).
