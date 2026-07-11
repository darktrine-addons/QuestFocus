# QuestFocus

> 🚧 **Beta in active development.** Core features work and the addon is daily-driver stable, but the surface is still evolving — expect occasional polish-level changes between releases. Feedback, bug reports, and feature ideas welcome on the [issue tracker](https://github.com/darktrine-addons/QuestFocus/issues).

**Make the quest tracker do exactly what you want, at a glance.**

QuestFocus puts a couple of small buttons on the objective tracker that narrow your watch list to what you actually care about right now — the zone you're in, the campaign you're following, weeklies you haven't finished, or any one of nine tracker modes you pick from a right-click menu. When you're in a party, every tracked row gets a coloured dot showing how the quest stands across your group: who has it, who's ready to turn in, who isn't on it at all. Hover the row and you'll see the per-member breakdown right inside Blizzard's own quest tooltip.

Retail only. Requires Midnight (Interface 120007+).

---

## At a glance

- **🔍 Focus button** + **↶ Revert button** on the objective tracker and the world-map quest log.
- **Right-click the lens** for nine one-click tracker modes (all / current zone / campaign / daily / weekly / Important / ready-to-turn-in / in-progress / untrack everything).
- **One-click revert** to whatever you were tracking before, with merge semantics: any quest you accepted while the filter was on stays accepted.
- **Coloured indicator dots** on each tracked quest row when you're in a party — green / yellow / blue / orange tell you instantly whether your party is aligned, mixed, ready to turn in, or in a "I'm the only one on this quest" share opportunity.
- **Party-state breakdown** appended to Blizzard's tracker row tooltip — class-coloured names, per-member status.
- **Zone-change reminder** — when the zone filter goes stale after a zone change, the lens pulses and a chat line offers a one-click *[Re-focus]* link. Nothing changes until you click.
- **Keybindings** for Focus, Focus + add from log, and Revert under *Options → Keybindings → AddOns*.
- **Native settings panel** under *Escape → Options → AddOns → QuestFocus* (or `/qf settings`): indicator size, shape, position, three colour palettes (incl. red-green-friendly and blue-yellow-friendly), opacity, raid threshold, and a revert-respects-manual-un-tracks toggle.

---

## ZoneFilter

Two small buttons attach to the objective tracker and to the world-map quest log. They share state — pressing one updates the other instantly.

### What it does

- **🔍 Focus** *(left-click)* — Narrow your watch list to quests with an objective in the current zone. Quests in the zone you haven't tracked are left alone.
- **🔍 Focus + add from log** *(shift-left-click)* — Same untrack pass, *plus* adds any zone-relevant quest from your quest log to the watch list.
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
| Track current zone (Focus) | Plain Focus — narrow to zone, nothing added |
| Track current zone + add from log | Focus + Shift — narrow, then add zone-relevant quests from your log |
| Track campaign quests only | Only quests in a campaign chain |
| Track daily quests only | `Enum.QuestFrequency.Daily` |
| Track weeklies only | `Enum.QuestFrequency.Weekly` |
| Track Important quests only | The purple-triangle quests Blizzard tags as Important (TWW 11.0.2+) |
| Track ready-to-turn-in only | Quests with `C_QuestLog.IsComplete` |
| Track in-progress only | The opposite — drop ready-to-turn-in rows |
| Untrack everything | Clears the watch list (tracker hides until you re-track) |

The currently-active mode is annotated `(active)` in green or `(drifted)` in orange. Slash commands cover every mode for macro use.

### The filter stays true

While a filter is active, any new quest entering your log that **matches the active mode** is tracked automatically — a new weekly under *weeklies only*, a zone quest under *Focus*, a campaign quest under *campaign only*. No orange drift to clean up for quests the filter would have picked anyway. This also closes the gap with Blizzard's `autoQuestWatch` on event quests like *Void Assaults* that get pushed into your log on first progress without auto-tracking. Manually un-tracking an auto-added quest keeps it un-tracked — only *new* arrivals are added, no infinite-loop re-tracking.

### Zone-change reminder

When the zone filter is active and you enter a new zone where your watch list no longer matches, the lens pulses and one chat line appears: *Zone changed — Duskwood has 4 of your quests. [Re-focus]*. Clicking the link runs Focus + add from log for the new zone; ignoring it costs nothing. Deliberately a reminder rather than an auto-apply — the addon never re-tracks anything without your click. Per-character toggle in the settings panel (default on), 10-second cooldown so portal chains don't spam.

### Revert semantics

```
revert_target = snapshot ∪ quests_added_since
```

Anything you've manually accepted or tracked between filter-apply and revert is preserved. Quests the filter itself added get cleaned up. Strict by default: if you manually un-track a quest that was in the snapshot, revert restores it. Flip the per-character setting *Revert respects manual un-tracks* if you'd rather revert respect your manual removal.

---

## PartySync

When you're in a party, every tracked quest in the objective tracker gets a small coloured dot. The colour tells you at a glance how the quest stands across your group:

- 🟢 **Green** — *aligned*: every partymate is on the quest and progressing
- 🟡 **Yellow** — *mixed*: some partymates are on it, some aren't (coordination opportunity)
- 🔵 **Blue** — *ready to turn in*: at least one partymate has the objectives complete
- 🟠 **Orange** — *shareable*: only you have it, and at least one partymate is in the same zone (share the quest)
- *no dot* — no actionable group state, or you're solo

Hover any tracked quest row as you normally would — Blizzard's tooltip appears with the quest description and objectives, and PartySync **appends** a "Party state:" section below: each member's name in their class colour, with their state on the right (`Ready to turn in` / `In progress (K/N)` / `Not on quest`). "You" comes first, then partymates sorted by state. In groups of 10+ members the list is replaced by a one-line rollup — *Party: 14 on quest · 3 ready · 2 not on it* (configurable threshold). The indicator dots themselves are click-through — they're visual signals only, not separate hover targets.

PartySync attaches to both the regular quest tracker and the campaign quest tracker.

### BNet visibility caveat

`C_TooltipInfo.GetQuestPartyProgress`, the API PartySync relies on, only returns real data for partymates who are **BNet-visible** to you. If a partymate has set themselves "appear offline" on Battle.net, they'll show up as `Not on quest` regardless of their actual state — and the aggregate dot may misfire (e.g. show orange "shareable" when they actually have the quest). In practice this matches the audience: cooperative questing is almost always between BNet friends who are visible to each other. If you spot inconsistent data, check BNet visibility before filing a bug.

---

## Slash commands

```
/qf                          apply ZoneFilter to current zone (narrow only)
/qf promote                  same plus add untracked zone quests from log
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

/qf settings                 open the settings panel (aliases: options, config)

/qf module list              show enable/active state of both modules
/qf module enable <name>     enable a module (PartySync applies live; ZoneFilter needs /reload)
/qf module disable <name>    disable a module

/qf party debug              toggle per-quest aggregate-state diff prints (PartySync)
/qf party broadcast on|off   reserved; not yet implemented

/questfocus                  long alias for /qf
```

---

## What it doesn't do (yet)

- ZoneFilter never re-applies automatically on zone change — it reminds you with a clickable chat link instead (and even that can be turned off).
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

See [CHANGELOG.md](https://github.com/darktrine-addons/QuestFocus/blob/main/CHANGELOG.md) for the full version history. The notes for each release are also posted with the download on CurseForge and Wago.

---

## License

GNU General Public License v2 (see `LICENSE`).
