# QuestFocus Phase 2 — polish + tracker modes

Successor to [QuestFocusParty-MVP-slices.md](QuestFocusParty-MVP-slices.md). The MVP (v0.3.0-beta) shipped the two core features; Phase 2 sands the edges and adds a feature class (tracker modes) the user has explicit demand for.

Organised as **four bundles**. Within each bundle, slices are sequential; bundles can run in any order. Bundle A (Settings) is a prerequisite for the user-facing surfaces in B and C, so it goes first.

---

## Bundle A — Settings UI panel

**Why first:** all subsequent polish (B) and modes (C) want toggles. Building them against slash commands alone would mean a second round of UI work later. Cheaper to lay the foundation once.

### A1 — Native AddOn settings panel scaffold

- Register a top-level entry under WoW's built-in Settings → AddOns → QuestFocus.
- Three sub-categories: **General**, **ZoneFilter**, **PartySync**.
- "General" hosts module-enable toggles (mirror of `/qf module enable|disable`). Disabling PartySync routes through `SetActive`; ZoneFilter still says "/reload to apply".
- Persist via `QuestFocusDB.settings` (account-wide) and `QuestFocusCharDB.settings` (per-character) — both already exist as SV roots.
- Existing slash commands stay; the panel writes the same SV keys.

**Acceptance:** Escape → Options → AddOns → QuestFocus shows the three sub-categories. Toggling PartySync OFF in the panel releases dots immediately (mirrors `/qf module disable PartySync`).

### A2 — Shift-Right-click on filter button opens settings

- Pattern from NosyKeys / Broker_PlayerCoords: Shift-Right-click any of QuestFocus's broker-like buttons opens the settings panel.
- Implementation: extend `UI/Buttons.lua` button factory to handle Shift-Right-click via `:RegisterForClicks("LeftButtonUp", "RightButtonUp")` + click-handler.
- README updated; tooltips on the buttons mention "Shift-Right-click for settings".

**Acceptance:** Shift-Right-click on the focus button on either the tracker or the world-map pair opens the Settings panel pointed at QuestFocus.

---

## Bundle B — Visual polish

UX choices the user explicitly flagged. Each slice is a setting backed by Bundle-A's panel.

### B1 — Indicator size

- Setting: `partySync.indicatorSize` ∈ { 6, 8, 10, 12 } px. Default 8.
- `Indicator.NewFrame` reads from `ns.Config` at frame-construction time; `Indicator.Acquire` re-applies size on every acquire so the pool stays consistent.
- Panel: dropdown or radio.

**UX analysis:** 8 px is the current production value and works fine; 6 is for minimal-noise users, 10/12 for accessibility / large displays. Fixed step set rather than a slider — easier to reason about and matches the discreteness of pixel art.

### B2 — Indicator shape

- Setting: `partySync.indicatorShape` ∈ { square, circle }. Default circle.
- Implementation:
  - **square** = current `SetColorTexture` path
  - **circle** = swap to an atlas (`common-icon-checkmark` masked, or `Interface/COMMON/Indicator-Yellow` family that's already roundish) OR use a custom circular texture from the addon
- I'll evaluate atlas options first because they ship with the client and don't require us to bundle a custom asset.

**UX analysis:** Circle is the dominant convention for status pips in modern UI. Square reads as "addon programmer art." Default to circle if a usable atlas exists; fall back to square. Diamond / triangle deliberately omitted — colour alone already encodes state, more shapes would compete with that signal.

### B3 — Indicator position around the title

- Setting: `partySync.indicatorAnchor` ∈ { topRight, topLeft, leftOfTitle, rightOfTitle }. Default `rightOfTitle`.
- Implementation: `MountTracker.Refresh` reads the anchor mode and applies the matching `SetPoint`. `rightOfTitle` is the design's intent (§4.1: "to the right of each tracked quest's title"); the current `TOPRIGHT block TOPRIGHT (-4, -4)` is the slice-6 placeholder.
- Needs the `block.HeaderText` fallback the earlier slice plan deferred.

**UX analysis:** The "right of the title text" position is hardest to anchor reliably (HeaderText geometry varies per row). Worth getting it right; if it can't be made stable, `topRight` (current) is the fallback default.

### B4 — Colour palette

- Setting: `partySync.palette` ∈ { default, deuteranopia, tritanopia, monochrome }.
  - **default** — current `(green / yellow / blue / orange)` palette
  - **deuteranopia** — red-green friendly: green → cyan, orange → magenta (yellow / blue keep enough separation)
  - **tritanopia** — blue-yellow friendly: blue → purple, yellow → red
  - **monochrome** — single grey-to-white ramp + a small unicode glyph (●▲■◆) per state for differentiation
- `Indicator.SetState` reads palette from Config.

**UX analysis:** Adding palettes is cheap and unlocks an accessibility win. Monochrome+glyph also gives a "minimalist" aesthetic option some users prefer. Default palette stays unchanged — no regression for existing users.

### B5 — Brightness / opacity slider

- Setting: `partySync.indicatorOpacity` ∈ [0.4 … 1.0]. Default 1.0.
- Applied via `texture:SetVertexColor(r, g, b, opacity)` in `SetState`.

**UX analysis:** Some users want indicators to be ambient ("there if I look for them") rather than commanding attention. One slider, low cost. Below 0.4 they become invisible at small sizes; clamp.

---

## Bundle C — Tracker modes (right-click context menu)

The user's ask: a right-click context menu on the filter button surfacing batch operations beyond zone-filter.

### C1 — Right-click context menu scaffold

- Right-click on the 🔍 button opens a UIDropDownMenu with mode entries.
- Menu items dispatch to a registry of "mode handlers" each implementing `Apply()`.
- All mode handlers participate in the existing snapshot/lastApplied state machine — a mode-Apply is treated as a fresh filter Apply, so revert continues to work.

**Acceptance:** Right-click → menu opens with the entries from C2/C3/C4. Selecting any of them performs the action and registers it in the snapshot/lastApplied state.

### C2 — Mode: "Untrack everything"

- Removes every entry from the watch list, no snapshot interaction beyond the standard one (current state becomes the pre-filter snapshot).
- Distinct from Revert: this is a one-way "clear", not a "go back to a previous state".

**UX analysis:** User-requested. Common ask in tracker addons. Simple to implement; just iterate `GetCurrentWatches` and call `RemoveQuestWatch` for each.

### C3 — Mode: "Track campaign quests only"

- Promote every campaign quest from the log into the watch list; untrack everything else.
- Detect "campaign quest" via `C_QuestLog.GetInfo(idx).campaignID ~= nil` (or whichever field the modern retail API exposes — needs a quick in-game probe).

**UX analysis:** This and C4 are about narrowing focus to a particular kind of content. Once C2's "untrack everything" mode exists, these are essentially "untrack everything THEN promote a tagged subset" — same primitives, different selection predicate.

### C4 — Mode: "Track all weeklies"

- Detect weeklies via `C_QuestLog.GetInfo(idx).frequency` (numeric constant) or the matching `LE_QUEST_FREQUENCY_WEEKLY`.
- Same pattern as C3: clear + selectively promote.

### C5 — Optional Mode: "Track important quests only" (deferred unless we can define "important")

- "Important" needs a heuristic. Candidates: questline-completion-near-end (last quest in chain), reward-item-quality, quest-type tags like LFG, etc.
- Pulled out of the slice so we don't block C2–C4 on definition.

---

## Bundle D — Backlog from issue #1 + design Phase-2 list

Polish items already captured; do them once Bundle A exists so they can have UI surfaces.

### D1 — `untrackClearsSnapshot` per-character setting (issue #1, item 1)

- Default false (current behaviour).
- When true: hook `QUEST_WATCH_LIST_CHANGED` while filter is active; if a quest leaves the watch list AND was in the snapshot, remove it from snapshot.
- Edge case: also applies to drift-adds (symmetric).
- Bundle-A panel surface: checkbox under ZoneFilter.

### D2 — Prune completed questIDs from snapshot (issue #1, item 2)

- Hook `QUEST_TURNED_IN` (and `QUEST_REMOVED` for abandons).
- On fire: remove the questID from snapshot, lastApplied, knownLogQuests.
- Cosmetic; no behaviour change. Reduces SV bloat over time.

### D3 — Drift pulse animation (issue #1, item 3)

- When `lastApplied → drift` transition happens (filter was green, now orange), pulse the 🔍 icon briefly.
- `UIFrameFlash(icon, fadeIn, fadeOut, totalTime, showOnFinish)` — single call.
- ~10 lines in `UI/Buttons.lua`.

### D4 — Suppress PartySync indicators on non-shareable quest types

- From design Phase-2 list: scenario quests, pet-battle quests, dungeon-specific quests where party-state is meaningless.
- Implementation: filter in `Aggregate.Compute` — early-return `nil` based on quest tags.
- Needs a one-time probe to enumerate which `GetInfo` fields surface these tags.

### D5 — Raid (>5) aggregate-only mode

- In a raid, the per-member tooltip can blow up to 30+ rows. Suppress to aggregate-only (just the dot, no party-state appendage).
- Threshold setting: `partySync.raidThreshold` ∈ { off, ≥10, ≥20 }. Default ≥10.

---

## Sequencing recommendation

1. **A1, A2** — settings foundation (1 commit each).
2. **B1, B2, B4, B5** — visual polish (small commits, each surface-only). B3 (anchor) last in B because it carries the most risk.
3. **D1, D2, D3** — quick wins from issue #1 backlog, each ~one commit.
4. **C1, C2** — context menu + untrack-everything. Ship as `v0.4.0-beta`.
5. **C3, C4** — campaign-only / weeklies-only modes. Ship as `v0.4.1` or roll into `v0.4.0` if all four land together.
6. **D4, D5** — corner cases.
7. **C5** — "important" mode, only if we land on a definition.

After Bundle A is in, B/C/D slices can be cherry-picked in any order based on appetite.

---

## Out of scope (still)

- Auto-on-zone-change (would conflict with merge revert semantics)
- World-map quest log indicators for PartySync (design §11 Phase 4)
- Addon-comm broadcast for BNet-hidden partymates (design §11 Phase 3)
- Auto-share-on-pickup (design §11 Phase 4)
- Per-quest tooltip enrichment beyond the existing Party-state section

---

## UX summary in one paragraph

Settings panel makes the addon discoverable to users who don't read READMEs. Indicator size/shape/palette/opacity give visual fit-and-finish without changing semantics — palette specifically unlocks colour-vision accessibility. Tracker modes turn QuestFocus from "one filter" into "a small library of one-click watch-list operations", which is closer to how power users mentally model the feature. None of this changes the core merge-revert promise; everything is additive.
