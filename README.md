# QuestFocus

> 🚧 **Beta in active development.** Core features work and the addon is daily-driver stable, but the surface is still evolving — expect occasional polish-level changes between releases. Feedback, bug reports, and feature ideas welcome on the [issue tracker](https://github.com/darktrine-addons/QuestFocus/issues).

**Make the quest tracker do exactly what you want, at a glance.**

QuestFocus puts a couple of small buttons on the objective tracker that narrow your watch list to what you actually care about right now — the zone you're in, the campaign you're following, weeklies you haven't finished, or any one of nine tracker modes you pick from a right-click menu. When you're in a party, every tracked row gets a coloured dot showing how the quest stands across your group: who has it, who's ready to turn in, who isn't on it at all. Hover the row and you'll see the per-member breakdown right inside Blizzard's own quest tooltip.

Retail only. Requires Midnight (Interface 120005+).

---

## At a glance

- **🔍 Focus button** + **↶ Revert button** on the objective tracker and the world-map quest log.
- **Right-click the lens** for nine one-click tracker modes (all / current zone / campaign / daily / weekly / Important / ready-to-turn-in / in-progress / untrack everything).
- **One-click revert** to whatever you were tracking before, with merge semantics: any quest you accepted while the filter was on stays accepted.
- **Coloured indicator dots** on each tracked quest row when you're in a party — green / yellow / blue / orange tell you instantly whether your party is aligned, mixed, ready to turn in, or in a "I'm the only one on this quest" share opportunity.
- **Party-state breakdown** appended to Blizzard's tracker row tooltip — class-coloured names, per-member status.
- **Native settings panel** under *Escape → Options → AddOns → QuestFocus*: indicator size, shape, position, three colour palettes (incl. red-green-friendly and blue-yellow-friendly), opacity, raid threshold, and a manual-untrack-clears-snapshot toggle.

---

## ZoneFilter

Two small buttons attach to the objective tracker and to the world-map quest log. They share state — pressing one updates the other instantly.

### What it does

- **🔍 Focus** *(left-click)* — Narrow your watch list to quests with an objective in the current zone. Quests in the zone you haven't tracked are left alone.
- **🔍 Focus + promote** *(shift-left-click)* — Same untrack pass, *plus* promote any zone-relevant quest from your quest log into the watch list.
- **🔍 Tracker mode menu** *(right-click)* — Nine one-click modes covering all the most common "show me only X" cases. Each entry previews how many quests it would track; entries that would empty the tracker flag a warning glyph.
- **↶ Revert** — Restores the watch list to the snapshot taken when you first applied a filter, **plus any quests you've added since** (manually or via Blizzard's `autoQuestWatch`). Per-character snapshot survives `/reload`.
- **Re-apply button** (green ↶) — Appears between the lens and the revert button when a non-zone tracker mode is active and the watch list has drifted. One click cleans the drift without leaving the current mode.

### Tracker-state indicator

The 🔍 icon colour tells you what the filter is doing:

- **White** — no filter applied
- **Green** — filter active, watch list matches what the filter left it as
- **Orange** — filter active, but quests have been added or removed since (it pulses briefly when this state transitions)

The lens tooltip headline shows the current state in plain language: *No filter*, *Filter: weeklies only*, *Filter: campaign quests only (1 added)*, colour-matched to the dot.

### Tracker modes (right-click menu)

| Mode | What it tracks |
|---|---|
| Track all quests in log | Every accepted quest |
| Track current zone (Focus) | Plain Focus — narrow to zone, no promote |
| Track current zone + promote from log | Focus + Shift — narrow + add zone-relevant from log |
| Track campaign quests only | Only quests in a campaign chain |
| Track daily quests only | `Enum.QuestFrequency.Daily` |
| Track weeklies only | `Enum.QuestFrequency.Weekly` |
| Track Important quests only | The purple-triangle quests Blizzard tags as Important (TWW 11.0.2+) |
| Track ready-to-turn-in only | Quests with `C_QuestLog.IsComplete` |
| Track in-progress only | The opposite — drop ready-to-turn-in rows |
| Untrack everything | Clears the watch list (tracker hides until you re-track) |

The currently-active mode is annotated `(active)` in green or `(drifted)` in orange. Slash commands cover every mode for macro use.

### Auto-promote

While a filter is active, any new quest entering your log that matches the current zone is added to the watch list automatically. Closes the gap with Blizzard's `autoQuestWatch` on event quests like *Void Assaults* that get pushed into your log on first progress without auto-tracking. Manually un-tracking an auto-promoted quest keeps it un-tracked — only *new* arrivals get promoted, no infinite-loop re-tracking.

### Revert semantics

```
revert_target = snapshot ∪ quests_added_since
```

Anything you've manually accepted or tracked between filter-apply and revert is preserved. Quests the filter itself added get cleaned up. Strict by default: if you manually un-track a quest that was in the snapshot, revert restores it. Flip the per-character setting *Manual un-track also clears the snapshot* if you'd rather revert respect your manual removal.

---

## PartySync

When you're in a party, every tracked quest in the objective tracker gets a small coloured dot. The colour tells you at a glance how the quest stands across your group:

- 🟢 **Green** — *aligned*: every partymate is on the quest and progressing
- 🟡 **Yellow** — *mixed*: some partymates are on it, some aren't (coordination opportunity)
- 🔵 **Blue** — *ready to turn in*: at least one partymate has the objectives complete
- 🟠 **Orange** — *shareable*: only you have it, and at least one partymate is in the same zone (share the quest)
- *no dot* — no actionable group state, or you're solo

Hover any tracked quest row as you normally would — Blizzard's tooltip appears with the quest description and objectives, and PartySync **appends** a "Party state:" section below: each member's name in their class colour, with their state on the right (`Ready to turn in` / `In progress (K/N)` / `Not on quest`). "You" comes first, then partymates sorted by state. In groups of 10+ members the section is hidden automatically (configurable threshold). The indicator dots themselves are click-through — they're visual signals only, not separate hover targets.

PartySync attaches to both the regular quest tracker and the campaign quest tracker.

### BNet visibility caveat

`C_TooltipInfo.GetQuestPartyProgress`, the API PartySync relies on, only returns real data for partymates who are **BNet-visible** to you. If a partymate has set themselves "appear offline" on Battle.net, they'll show up as `Not on quest` regardless of their actual state — and the aggregate dot may misfire (e.g. show orange "shareable" when they actually have the quest). In practice this matches the audience: cooperative questing is almost always between BNet friends who are visible to each other. If you spot inconsistent data, check BNet visibility before filing a bug.

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
/qf party broadcast on|off   reserved; not yet implemented

/questfocus                  long alias for /qf
```

---

## What it doesn't do (yet)

- ZoneFilter has no auto-on-zone-change mode.
- PartySync covers tracker rows only — no world-map quest log indicators.
- PartySync doesn't broadcast over addon channels (consequently can't see BNet-hidden partymates).
- Doesn't collapse tracker sections.
- Doesn't call any API during combat. Buttons disable visually and become click-through.

---

## Technical notes

- **Tracker pair**: parented to `ObjectiveTrackerFrame.Header` (with fallback to `HeaderMenu` / `ObjectiveTrackerFrame` itself on older builds). Inherits visibility from the tracker — when nothing is tracked and the tracker hides itself, the buttons hide too. Edit Mode movement and scaling carry the buttons.
- **Quest-log pair**: parented to `QuestMapFrame`, anchored directly above `QuestMapFrame.QuestsTab`. Visible whenever the world map is open. Shares state with the tracker pair — pressing one updates both.
- **Zone-relevance check**: a quest counts as relevant if `info.isOnMap`, `info.hasLocalPOI`, or `C_QuestLog.IsOnMap(questID)` returns true. The third fallback catches completed quests whose turn-in is in the current zone.
- **Taint posture**: no custom field writes onto Blizzard frames. Indicator dots are addon-owned `CreateFrame` widgets parented to tracker blocks for visibility-inheritance only; release re-parents to UIParent.

---

## Changelog

### v0.9.1-beta

**Behind the scenes:**

- Activate the CurseForge and Wago publishing pipeline (project IDs wired into the TOC). No functional changes.

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
- **Raid handling.** In groups of 10+ members the per-member tooltip section is hidden automatically (it'd be too long). Indicator dots still show. Configurable threshold: always show / hide at 10+ / hide at 20+.
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
