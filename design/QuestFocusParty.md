# QuestFocusParty — Design Document

Status: draft, not yet implemented
Audience: future implementers, design reviewers
Last update: scaffolded alongside QuestFocus v0.1.x; revised after native-API discovery

---

## 0. Native API discovery (post-initial-draft)

After the first draft of this design committed to a broadcast-based protocol (Route 1), follow-up research surfaced the canonical Blizzard API that already exposes the data:

**`C_TooltipInfo.GetQuestPartyProgress(questID [, omitTitle, ignoreActivePlayer]) → TooltipData`**

Sourced from Blizzard's API documentation at `Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua` in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source):

```lua
Name = "GetQuestPartyProgress",
Type = "Function",
MayReturnNothing = true,
SecretArguments = "AllowedWhenUntainted",
Arguments = {
    { Name = "questID",            Type = "number", Nilable = false },
    { Name = "omitTitle",          Type = "bool",   Nilable = true  },
    { Name = "ignoreActivePlayer", Type = "bool",   Nilable = true  },
},
Returns = {
    { Name = "data", Type = "TooltipData", Nilable = false },
},
```

This is the getter half of `GameTooltip:SetQuestPartyProgress(questID, omitTitle, ignoreActivePlayer)` — the exact call Blizzard's own quest map log uses to render party progress lines on quest title hover (see `Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua`, `QuestMapLogTitleButton_OnEnter`). The accessor delegation is explicit in `TooltipDataHandler.lua`:

```lua
local accessors = {
    SetQuestPartyProgress = "GetQuestPartyProgress",
    ...
};
```

### What this means for the design

The native API returns the **same data Blizzard renders in its own tooltip**: per-party-member progress lines, names, objective counts, completion state. As `TooltipData` — a structured table of `lines`, each with `leftText`, `rightText`, color, etc. — accessible to addon Lua, no comm protocol required.

**Implication: the broadcast-based design (Route 1) is no longer required for MVP.** We poll `C_TooltipInfo.GetQuestPartyProgress` per tracked quest on relevant events, parse the returned lines, compute the aggregate state, render the indicator. The protocol-design and library-embedding work originally in Phase 2 can defer to Phase 3 or be dropped entirely.

### Caveats specific to this API

- **`SecretArguments = "AllowedWhenUntainted"`** — the same flag family that bit us in the QLC investigations. Calling the function from addon-tainted Lua is permitted, but numeric fields in the returned `TooltipData` may be "secret numbers": arithmetic on them throws "attempt to perform arithmetic on a secret number value" errors. Mitigation: read line *strings* (e.g. `line.leftText = "Player: 3/5"`) and parse the progress text with string functions. Never do math on the structured numeric fields directly. Pattern is well-trodden in WoW addons — Questie, SmartQuest, etc. use it for similar reasons.
- **`MayReturnNothing = true`** — the function can return nil. Handle it: solo player, quest with no shareable progress, quest types Blizzard excludes (scenarios, certain campaign quests).
- **No "party progress changed" event.** We poll. Triggers: `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE`, `UNIT_QUEST_LOG_CHANGED` (fires on party members), and a coarse periodic timer (~3s) as a safety net for events we don't subscribe.
- **Updates lag the server.** Same constraint Blizzard's own UI has — client only knows what the server has pushed. Acceptable for an at-a-glance indicator; UX consequence is "occasional state staleness" not "wrong data."

### Revised approach

- MVP becomes the full feature on native data only. No broadcast.
- Architecture below is rewritten as Section 6 (Communication / data plane) — the broadcast protocol description is preserved as Phase 3 future work but is no longer in the MVP critical path.

---

## 1. Overview

QuestFocusParty is a second module shipped within the same `QuestFocus` addon. Its purpose is to show, at-a-glance, the **per-quest state of your party** in the objective tracker — so the user doesn't have to ask "do you have this quest?" / "is yours complete yet?" repeatedly during group play.

This document specifies the user-facing behavior, the state and communication model, and the architectural footprint. No implementation code is written yet.

The existing QuestFocus zone-filter feature stays untouched. The two modules become **independently togglable** within the addon's settings.

---

## 2. Scope

### In scope

- A small visual indicator (one "aggregate dot") to the right of each tracked quest title in the objective tracker
- A detailed per-party-member tooltip on Alt-hover
- Cross-client state synchronization via `CHAT_MSG_ADDON` (sender + receiver protocol)
- Detection of these states:
  - All party members on the quest (aligned)
  - Mixed (some on, some not, varied progress)
  - At least one party member has it complete and ready to turn in
  - You're alone, but at least one party member is nearby and could plausibly accept it
- Module toggle in SavedVars to disable the feature entirely
- Compatibility-friendly behavior when other party members don't have the addon installed

### Out of scope (explicitly, for the first ship)

- Showing party state in the world-map quest log (we restrict to the tracker for MVP)
- Sharing quest pickup automatically (no `QuestSession` interaction)
- Voice / spoken alerts
- Raid support (>5 members) — we'll display in raids but only aggregate, no per-member tooltip
- Cross-faction parties (the relevant ones now are Mercenary mode etc., low priority)
- Reading other party members' specific objective progress quantities (e.g., "3/5 fish caught") — too chatty over the wire; we show a coarser "in progress / complete" instead

---

## 3. User stories

| Story | Why it matters |
|---|---|
| As a leveling-party member, I see at a glance that the quest I just picked up is also held by everyone else in my group, so we can go do it together | Avoids "do you have…?" chat |
| As a leveling-party member, I see that my quest has a colored dot indicating somebody else in my group has it complete — so I head to the turn-in NPC knowing they'll be there | Coordinates turn-ins |
| As a leveling-party member, I see a colored dot indicating *I'm the only one in the party on this quest*, and at least one other member is nearby — prompting me to share it before we move on | Action prompt |
| As a leveling-party member, Alt-hovering the dot tells me each member's name and state (in progress / completed / not on quest) | Drill-down when summary isn't enough |
| As a solo player, no indicators appear; the addon doesn't add visual clutter when not in a party | Clean default |
| As a user who doesn't want this feature, I toggle the module off and all party-related code stops running | Modularity |

---

## 4. Visual design

### 4.1 Indicator placement

A single small **dot** (~7-9 px diameter) is rendered to the right of each tracked quest's title, in the small whitespace before any progress text Blizzard renders. The indicator follows the tracker row through Edit-Mode movement and resize.

When the row's content overflows or wraps, the dot stays anchored to the title's right edge — never overlapping objective text.

### 4.2 Dot color states

Priority order (highest priority wins if multiple apply):

| Priority | Color | State | Action signal |
|---|---|---|---|
| 1 | **Blue** `(0.35, 0.7, 1.0)` | At least one party member has the quest objectives complete and not yet turned in | If you're heading there anyway, you can meet for shared turn-in |
| 2 | **Orange** `(1.0, 0.55, 0.15)` | You're alone on this quest **and** at least one party member is in the same zone and on no incompatible state for accepting it | Share-quest opportunity — this is the state the user explicitly called out as missing in v0.1 |
| 3 | **Yellow** `(1.0, 0.85, 0.2)` | Mixed: some party members on the quest, some not, no completed-yet state | Coordination needed |
| 4 | **Green** `(0.4, 1.0, 0.4)` | All party members on the same quest, progressing | Aligned — no action needed |
| – | hidden | No party, or the quest is not actionable for party state (e.g., scenario-only) | Default suppressed |

Notes:
- The orange "alone + shareable" state conflicts visually with QuestFocus's existing "drift" orange (`#ff8c26`). They appear in entirely different contexts (filter button vs. tracker row dot), so the overload is acceptable. If user testing finds them confusing, we'll re-tone — candidates: a slightly cooler orange or a purple/magenta for the share state.
- We deliberately drop a "red / you're alone and nothing can be done" state. It's accurate but it's not actionable, and "no information" beats "useless information" in dense UIs.

### 4.3 Tooltip on Alt-hover

Default hover: no tooltip from QuestFocusParty. The user is already hovering tracker rows for Blizzard's own info; we don't want to compete.

Holding **Alt** while hovering the dot loads a focused tooltip:

```
Quest Title
─────────────────────────────
Party state:
  ● You             In progress (2/3)
  ● PlayerTwo       Completed (ready to turn in)
  ● PlayerThree     Not on quest
  ● PlayerFour      In progress (1/3)
```

- Member rows in class color
- Each row carries a small dot in the per-member state color (same palette as the aggregate)
- "You" is always first
- Sort order for others: completed first → in-progress → not on quest → unknown
- Member labeled "Unknown" appended in gray when their addon hasn't sent a HELLO yet (mixed-addon party — see §9.3)
- Tooltip is dismissed by releasing Alt or moving off the row

Modifier choice: **Alt** is the primary candidate. Concern: WoW's item-comparison feature binds to Alt-hover on item tooltips. Tracker rows don't appear to dispatch item compare, so the collision risk is low. Fallback if testing shows issues: **Shift**.

### 4.4 Where state is computed

The aggregate dot color is recomputed when any of these change:
- Local quest log (`QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `QUEST_TURNED_IN`)
- Party membership (`GROUP_ROSTER_UPDATE`)
- Incoming addon message about another member's quest state
- Module enable/disable

The recompute walks per-quest: for each tracked quest, derive a state from local + received party data → highest-priority color.

---

## 5. State model

### 5.1 Local state (per logged-in character)

```
local_state:
  quests: { [questID] = { isComplete : bool, isTurnedIn : bool, isWatched : bool, mapID : int }, ... }
  zone: int        -- current C_Map.GetBestMapForUnit("player")
  partyHash: string -- hash of party member roster + names; used to detect roster changes
```

### 5.2 Party state (per remote party member, received via comm)

```
party_state[memberName]:
  addonVersion: int    -- protocol version; lets us reject incompatible peers
  zone: int            -- their current map ID
  quests: { [questID] = { state : "in_progress" | "complete" | "turned_in_recently", ... } }
  lastUpdate: timestamp -- for staleness detection
```

We **do not** broadcast objective progress quantities (3/5 fish). Too chatty, low value. We compress to one of three states per quest.

`turned_in_recently` is short-lived (~60 seconds) — used so we don't flash a "blue / ready to turn in" indicator on quests one member just handed in. After expiry, the quest is dropped from their state.

### 5.3 Aggregate computation (per tracked quest, on every recompute)

Inputs: `local_state.quests[questID]`, `party_state[*].quests[questID]`, `local_state.zone`, `party_state[*].zone`.

Pseudocode:
```
function aggregate_color(qid):
    local = my_state(qid)
    if local is nil: return nil   -- I don't have the quest; nothing to indicate

    members_with    = list of party members whose state has qid in_progress or complete
    members_without = party members not in members_with
    members_ready_to_turn_in = those whose state[qid] == complete and not turned_in

    if any in members_ready_to_turn_in: return BLUE         -- priority 1
    if #members_with == 0 and any member_zone == local.zone: return ORANGE  -- priority 2 (share opportunity)
    if #members_with > 0 and #members_without > 0: return YELLOW             -- priority 3 (mixed)
    if #members_with == party_size: return GREEN                              -- priority 4 (aligned)
    return nil                                                                 -- otherwise hidden
```

Members with unknown state (no QuestFocusParty installed) are counted neither toward `members_with` nor `members_without` — they're shown in the tooltip as "Unknown" but don't affect aggregate color.

---

## 6. Data plane

**Revision after §0:** the data plane is now native-API-first. The broadcast protocol below is preserved as Phase 3 future work — useful only if we want signals not in `C_TooltipInfo.GetQuestPartyProgress` (e.g. accept-recency timestamps).

### 6.0 Native data path (MVP)

For each tracked quest, on a recompute trigger, the indicator calls:

```lua
local data = C_TooltipInfo.GetQuestPartyProgress(questID, true, true)
-- (omitTitle = true, ignoreActivePlayer = true): we don't need the
-- quest title in the lines (we know it), and we don't want our own
-- progress mixed in with party member progress.
```

Returned `data` is a `TooltipData` table with `lines = { { leftText, rightText, ... }, ... }`. Each line corresponds to one party member's row. The line text is the canonical "Name: 3/5" format Blizzard renders.

Parser: split `leftText` on `:` to extract member name and progress string. Progress string contains either a numeric "K/N" pair or a localized "Complete" / similar marker for completed-not-turned-in state. Map to internal state enum (`in_progress / complete / not_on_quest`).

Members not on the quest appear as a line distinct from in-progress members — exact format to be confirmed during implementation, but Blizzard's tooltip renders something like "Name: Not on quest" or omits the line entirely (in which case absence implies not-on-quest, cross-referenced with the party roster).

Triggers for recompute:
- `QUEST_LOG_UPDATE` (local quest log change)
- `QUEST_WATCH_LIST_CHANGED` (tracking change)
- `GROUP_ROSTER_UPDATE` (party churn)
- `UNIT_QUEST_LOG_CHANGED` with `unit == "partyN"` (party member progress event)
- Periodic 3-second sweep as a safety net for events we miss

Taint-safety:
- Never do arithmetic on numeric fields in the returned `data`. Strings only.
- Parsing `"3/5"` with `string.match` produces fresh local numbers, untainted.
- No field-writes onto Blizzard frames (tooltip data isn't a frame, but the tracker row is — rules still apply).

### 6.1 Broadcast channel (deferred, Phase 3 polish only)

`CHAT_MSG_ADDON`, prefix `QFP1` (`QuestFocusParty` v1). Sent to `PARTY` distribution.

Message size budget: WoW's addon message limit is 255 bytes per message. We chunk if larger; the libraries below handle this.

### 6.2 Library choice

Use **AceComm-3.0** (or **LibAceComm-3.0**) for message dispatch + chunking, and **LibSerialize** (fast, compact) for payload encoding. Optionally **LibDeflate** for compression on large payloads. These are standard, well-tested, and present in many addons.

Loaded as embedded libs in `QuestFocus/Libs/`. Same pattern as Broker_PlayerCoords already embeds LibStub + CallbackHandler + LibDataBroker.

### 6.3 Message types

| Type | Direction | Payload | When sent |
|---|---|---|---|
| `HELLO` | broadcast on join | `{ version, charName, zone }` | On `GROUP_ROSTER_UPDATE` (when we detect we just joined a party), or on receiving an unknown peer's message |
| `ROSTER_REPLY` | unicast to new peer | full quest list (deltas not enough at first contact) | In response to HELLO from a new peer |
| `DELTA` | broadcast | `{ adds = {qid → state}, removes = {qid} }` | On any local state change of a watched/tracked quest |
| `ZONE` | broadcast | `{ zone }` | On `ZONE_CHANGED_NEW_AREA`, throttled |
| `BYE` | broadcast | `{}` | On leaving the party / logout |

### 6.4 Quest set transmitted

We do **not** broadcast all quests in our log — only ones the user is currently tracking (via `C_QuestLog.IsOnQuest()` and the watch list). This:
- Limits privacy surface (we don't dump entire quest histories)
- Limits message size
- Matches the user's mental model — only quests visible in the tracker have UI indicators

Edge case: if a user un-tracks a quest while keeping it in their log, party members no longer see its state. Acceptable — un-tracking is a deliberate "I'm not focused on this" signal.

### 6.5 Throttling and rate limits

- DELTA: max one per 2 seconds per sender. Buffer changes during the window, send aggregated.
- ZONE: max one per 5 seconds.
- HELLO / ROSTER_REPLY: max one per peer per 30 seconds.
- Total outbound traffic budget: ~1 KB/minute per sender in normal play, bursts allowed at quest accept / complete / turn-in.

### 6.6 Protocol versioning

Each message carries a 1-byte `protocolVersion`. Receivers reject messages with major-version mismatches and downgrade gracefully (treat peer as "Unknown" in the UI). Minor-version additions stay forward-compatible by ignoring unknown fields.

Bump major version only for incompatible payload-shape changes.

### 6.7 Staleness and cleanup

Each peer's state has a `lastUpdate` timestamp. If we haven't heard from a peer in >2 minutes while still in their party, we treat their state as stale (show "Unknown" in tooltip, exclude from aggregate). On `BYE` or `GROUP_ROSTER_UPDATE` where the peer is gone, we drop their state entirely.

---

## 7. Architecture

### 7.1 Module organization within the addon

Both modules live under `QuestFocus/` and are loaded via the TOC, but each module's behavior is conditional on a per-module enable flag in SavedVars.

Target file layout (post-implementation):

```
QuestFocus/
├── Core/
│   ├── Config.lua              -- shared: SavedVars, module toggles
│   ├── DB.lua                  -- SavedVars management (shared shell)
│   └── ...
├── ZoneFilter/                 -- existing functionality, relocated here
│   ├── State.lua
│   ├── Relevance.lua
│   ├── Apply.lua
│   ├── Revert.lua
│   └── UI/
│       ├── Buttons.lua
│       ├── ButtonTracker.lua
│       └── ButtonQuestLog.lua
├── PartySync/                  -- NEW
│   ├── State.lua               -- local + party state model
│   ├── Comm.lua                -- AceComm wrapper, protocol handlers
│   ├── Aggregate.lua           -- compute aggregate dot color per quest
│   └── UI/
│       ├── Indicator.lua       -- per-tracker-row dot rendering
│       └── Tooltip.lua         -- Alt-hover detailed tooltip
├── Libs/
│   ├── LibStub/
│   ├── CallbackHandler-1.0/
│   ├── AceComm-3.0/
│   ├── LibSerialize/
│   └── LibDeflate/             -- optional
├── design/                     -- not shipped; .pkgmeta + .gitattributes exclude this folder
│   └── QuestFocusParty.md
└── QuestFocus.toc
```

Refactoring the existing `Core/` and `UI/` into a `ZoneFilter/` subtree is a pre-requisite. It's a moderate-size rename pass with no behavioral change. Worth doing in a dedicated commit before the new module starts landing.

### 7.2 Module bootstrap

A small `Core/Config.lua` reads SavedVars on load and exposes:
```
ns.Config.IsModuleEnabled("ZoneFilter")  -- bool
ns.Config.IsModuleEnabled("PartySync")   -- bool
```

Each module checks this flag at its own bootstrap entry point. If disabled:
- No event registrations
- No comm subscriptions
- No tracker hooks
- The module is effectively dormant (its files load, but install nothing)

Toggling a module at runtime: requires `/reload`. Document this. (Hot-toggle is technically possible but adds complexity for a niche operation.)

### 7.3 PartySync module structure

`State.lua` — pure data holder, no UI:
- `local_state`, `party_state` (see §5)
- Accessors / mutators
- Computes "what changed since last broadcast" deltas

`Comm.lua` — protocol I/O:
- AceComm registration, prefix subscription
- Outgoing message serialization
- Incoming message parsing + dispatch to `State.lua` mutators
- Throttling tables

`Aggregate.lua` — pure function:
- Input: questID + State
- Output: aggregate color enum + structured tooltip data

`UI/Indicator.lua` — tracker row indicators:
- Hooks into ObjectiveTracker row lifecycle (via `RegisterCallback` on tracker module update events — taint-safe)
- Maintains side-table `{ [questID] = indicatorFrame }` keyed on questID, NOT on tracker frame
- Indicator frame is addon-owned, parented to the row, anchored to the title's right
- Updates color on aggregate state change, hides when no state

`UI/Tooltip.lua` — Alt-hover tooltip:
- Listens for Alt key state via `IsAltKeyDown()` polled on `OnEnter` (the simple check; no full keybind setup needed)
- Builds tooltip text from `Aggregate.GetDetail(questID)`

### 7.4 Tracker integration — taint posture

Strict adherence to the rules from the QLC investigations (memory file `wow_blizzard_frame_field_write_taint.md`):

- **Never write a custom key onto a Blizzard tracker row frame.** Use addon-side side-tables keyed on questID, not on the row object.
- The indicator widget is an addon-`CreateFrame` parented to the row for positioning only.
- We use `RegisterCallback` on tracker manager events, not `HookScript("OnUpdate", …)` or similar invasive hooks.
- If at any point the tracker manager refuses to expose a clean callback for "row XYZ updated," we fall back to a single timer-driven sweep that walks our questID side table and reconciles positions — overhead is bounded (one pass per second, only when in a party).

The `tracker.collapsed = X` Method-2 fallback class of bug doesn't apply here — we never write tracker frame fields.

---

## 8. Configuration

### 8.1 SavedVars schema additions

```
QuestFocusDB = {
    modules = {
        ZoneFilter = { enabled = true },
        PartySync  = { enabled = true,    -- master toggle
                       broadcast = true,   -- false = listen-only (privacy mode)
                       modifier  = "Alt",  -- "Alt" | "Shift"
                     },
    },
    ...
}
```

`broadcast = false` is a privacy / paranoia escape — you receive party state from others' broadcasts but never send your own. Recipient-only mode.

### 8.2 In-game configuration surface

For MVP: slash commands only.
- `/qf module list` — show module enabled/disabled state
- `/qf module enable <name>` / `/qf module disable <name>`
- `/qf party broadcast on|off`
- `/qf party modifier alt|shift`

A proper settings panel is deferred until both modules are stable and we have real user feedback on what's worth surfacing visually.

---

## 9. Edge cases

### 9.1 Party churn

- Member joins: HELLO from them on `GROUP_ROSTER_UPDATE`, we reply with ROSTER_REPLY. They start populating `party_state[memberName]`.
- Member leaves: drop their `party_state` entry on `GROUP_ROSTER_UPDATE`.
- Party disband / leave: drop all party state. Aggregate dots disappear.

### 9.2 Cross-realm parties (Connected Realms, LFG)

Player names in `CHAT_MSG_ADDON` payloads include realm suffix when sender is cross-realm. We key `party_state` on the full normalized name (`charName-Realm`). Class color lookup needs the realm-stripped name for `UnitClass("partyN")` correlation — done at indicator render time.

### 9.3 Mixed-addon parties

If only some party members have the addon:
- Members without the addon never send messages. They appear as "Unknown" in the tooltip.
- They don't influence aggregate color (excluded from `members_with` / `members_without`).
- This is intentional — incomplete info shouldn't drive UI signaling.

### 9.4 Phasing / sharded worlds

Phasing can desync zone IDs in subtle ways. `C_Map.GetBestMapForUnit("party1")` may report a different map than `C_Map.GetBestMapForUnit("player")` even when they're "in the same zone" intuitively (different phases).

For the "alone + shareable" detection (orange dot), we compare member-zone to our zone. Some false negatives possible during phase transitions. Acceptable — it's an opt-in suggestion, not a hard guarantee.

### 9.5 Login / `/reload`

On login:
- Local state populates from quest log scan.
- If in a party, send HELLO immediately (after a 2-3 second debounce to let the party module finish its own init).
- Listen for peer HELLOs to populate `party_state`.
- Aggregate is initially empty; dots populate as peer state arrives.

If no peers respond within ~10s, assume mixed-addon party and continue with what we have.

### 9.6 Quest types we explicitly don't handle

Some quests are inherently solo and shouldn't get indicators:
- Scenario step quests
- Pet battle quests
- Some campaign quests with phasing
- Dungeon-specific quests

For MVP: still show the dot but rely on `IsUnitOnQuest` returning false consistently — the aggregate logic will produce "no party member on it," and if I'm soloing through a scenario, the orange state still triggers. That's slightly noisy but acceptable for the first ship.

Polish later: detect these via quest tags and suppress the indicator.

### 9.7 Tracker row lifecycle

The tracker uses pooled frames. When a quest is un-tracked, its row is recycled. When re-tracked, a new (or recycled) row appears.

Our indicator widgets are parented to row frames. When a row is recycled, the indicator must be unparented and either hidden or moved to the new row for that questID.

Cleanest: re-mount indicators on every tracker row update callback. Tear down → rebuild. Indicator widgets pooled in our own side table to avoid `CreateFrame` churn.

---

## 10. Privacy

What we broadcast:
- Quest IDs we're currently tracking
- A coarse state per quest (in_progress / complete / turned_in_recently)
- Our current zone map ID
- Protocol version
- Character name (implicit in CHAT_MSG_ADDON metadata)

We do **not** broadcast:
- Objective progress quantities
- Quest text
- Inventory, gold, gear, achievements
- Anything from outside the quest tracker

Audience: only the addon channel within the active party / raid. Not realm-wide, not guild, not whisper.

Opt-out: `broadcast = false` SavedVar. Recipient-only. Honest about the privacy trade-off — you see others but they don't see you.

We will document this clearly in the README and probably a one-line privacy notice in the first-run chat banner.

---

## 11. Phasing / roadmap

(Revised after §0 native-API discovery.)

### Phase 1: MVP — native API only, full aggregate states

Significantly larger scope than originally planned, because no broadcast protocol is needed.

- Pre-requisite: refactor existing files into `ZoneFilter/` subtree, introduce `Core/Config.lua` module toggle
- `PartySync` module skeleton with state + aggregate + indicator + Alt-tooltip
- Native data via `C_TooltipInfo.GetQuestPartyProgress` per tracked quest
- All four aggregate states light up: green / yellow / blue / orange (the latter two using the tooltip data's completion-state and member-presence info)
- Alt-tooltip with class-colored names and per-member state parsed from `TooltipData.lines`
- Taint-safety: string parsing, no arithmetic on returned numerics

This now ships as the full feature, not a degraded MVP.

### Phase 2: Polish and reliability

- Settings UI (rather than slash-only)
- Modifier-key configurability
- Indicator size / position tuning per user
- Suppress indicators on quest types we detect as non-shareable (scenarios, etc.)
- Real-time stress test the recompute path (3-second sweep cadence; tune if it costs CPU)
- Raid support: aggregate-only display, hide per-member tooltip beyond N members

### Phase 3: Broadcast protocol (optional, only if signal-gap motivates it)

Only revisit if Phase 1 reveals data we can't obtain natively:
- Accept-recency timestamps (the user's original "I picked this up recently in a party" signal — not present in tooltip data)
- Cross-addon coordination features (e.g. auto-share-on-pickup)
- Faster-than-poll responsiveness

If undertaken, the original broadcast design (AceComm, LibSerialize, HELLO / DELTA / ZONE / BYE messages, throttling) applies as written in §6.1.

### Phase 4: Maybe later

- Auto-share suggestion (one-click share-the-quest button)
- World-map quest log mirror of the tracker indicators
- Other group-coordination UI built on the same state model

---

## 12. Open questions

1. **Module refactor first, or alongside Phase 1?** Refactoring `Core/` and `UI/` into `ZoneFilter/` is mechanically simple but touches every file. Doing it as a separate commit before Phase 1 is cleaner for reviewing. Doing it alongside Phase 1 saves a beat but mixes concerns. *Recommendation: separate refactor commit first.*

2. **Orange-state heuristic precision.** "Party member could accept this quest" is genuinely fuzzy. Initial implementation: "they're in the same zone and don't have the quest." Later, we could refine with class/level/faction guards. *Recommendation: ship the fuzzy version, gather feedback.*

3. **Alt vs. Shift for the tooltip modifier.** Alt has slight collision risk with item-comparison logic on item-bearing tooltips; tracker rows shouldn't trigger that but it's worth verifying in-game before committing. *Recommendation: implement as configurable from day one; default to Alt.*

4. **Should we surface "I just accepted X seconds ago" as a temporal signal in the share state?** The user's instinct mentions temporal relevance ("I recently picked it up"). With broadcast, we know exactly when. Could fade the orange after, say, 5 minutes. *Recommendation: not in MVP; add as Phase 3 polish if the always-orange state feels naggy.*

5. **Indicator size — 7 / 8 / 9 px?** Probably 8 to start, tunable per user later. Below 6 reads as visual noise; above 10 starts intruding on row layout.

6. **Test fixtures.** How do we develop this without a guaranteed party of testers? Suggestion: a `/qf party debug` mode that injects synthetic peer state into `party_state` so we can exercise the rendering paths solo. Probably worth building as part of Phase 1.

---

## 13. Decision log (for the implementer)

- **Native API vs. broadcast?** → Native via `C_TooltipInfo.GetQuestPartyProgress` is the MVP data plane. Broadcast deferred to Phase 3 as optional polish, only if signal gaps surface. (Revised after §0 discovery.)
- **Same addon vs. separate?** → Same addon, two configurable modules. (User decision.)
- **Aggregate dot vs. per-member dots?** → Aggregate. Per-member is the Alt-tooltip.
- **Where do dots live?** → Tracker rows only (MVP). Not the world-map quest log.
- **Library choices?** → None for MVP (native API needs nothing extra). If Phase 3 broadcast is built later: AceComm-3.0, LibSerialize, possibly LibDeflate.
- **Privacy default?** → N/A for native-only MVP (we only read, not broadcast). If Phase 3 broadcast is built: broadcast on by default, allow opt-out.
- **Hot-toggle?** → No. `/reload` after module enable/disable. Simpler; niche operation.
- **Taint posture for native API?** → Read line strings from `TooltipData`, parse with `string.match`. Never do arithmetic on numeric fields in the returned data — they may be "secret numbers" per the `SecretArguments` flag.
