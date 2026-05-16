# QuestFocus Phase 3 — roadmap

Successor to [Phase2-roadmap.md](Phase2-roadmap.md). Phase 2 shipped at `v0.9.0-beta` / `v0.9.1-beta` and covers the settings panel, the tracker-mode menu, the state-machine refactor, and the polish backlog from issue #1 (which is now closed).

This document captures the candidate bundles for the next round, written so it survives a context loss. Plan is **not** committed to implementation order yet — see the Sequencing section at the bottom for the current recommendation and the rationale that may change it.

---

## Bundle E — Session-state-aware tooltip rewrite

**The headline change.** The current "Party state:" section appended to Blizzard's row tooltip largely duplicates Blizzard's per-player objective listing (the same names, the same `K/N`-style info phrased differently). The genuinely unique signal — the aggregate categorisation — already lives on the indicator dot, so the tooltip body adds little.

**Proposed replacement:** tooltip surfaces only information **not** derivable from Blizzard's own data, tracked across the in-session lifetime of a party.

### E1 — Session observation layer

New file: `PartySync/Core/SessionLog.lua`.

Holds a small in-memory table keyed by `(questID, partymate-GUID)` recording state transitions observed by polling `Fetch.GetPartyProgress`:

```
sessionLog[questID][guid] = {
    state          = "in_progress" | "complete" | "not_on_quest" | nil,
    joinedAt       = timestamp,    -- when partymate first appeared on this quest
    leftAt         = timestamp,    -- when partymate dropped from this quest (turned in / abandoned)
    completedAt    = timestamp,    -- when state first transitioned to complete
}
```

Polled on the same triggers MountTracker.Refresh uses (`QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `GROUP_ROSTER_UPDATE`, `UNIT_QUEST_LOG_CHANGED`, 3 s safety ticker). The log is **session-only** — no SavedVariables — and is wiped on:
- `PLAYER_LEAVING_WORLD`
- `GROUP_LEFT_PARTY` / `GROUP_LEFT_RAID`
- Roster churn that drops the relevant peer

**Risk:** medium. New code with new state. Throttle the poll cadence to avoid CPU drag in larger parties.

### E2 — New tooltip format

Replace the current "Party state:" section with derived facts only Blizzard's tooltip doesn't already show:

```
Shareable with: PlayerA, PlayerB      ← members in caller's zone who could accept
Completed: PlayerC                    ← members holding ready-to-turn-in right now
Recently turned in: PlayerD           ← within last ~5 min (SessionLog.leftAt while completed)
Recently accepted: PlayerE            ← since last poll (SessionLog.joinedAt within poll window)
```

Each row is **only** rendered when relevant — empty section when there's nothing unique to say. Names are class-coloured. The BNet-visibility footer stays for `Not on quest` rows.

Names that appear in multiple rows (e.g. PlayerC is recently turned in AND recently accepted again — quest reset?) are de-duplicated; pick the most-actionable line.

### E3 — Clickable share affordance

When the aggregate state is `alone_shareable`, replace the indicator dot with a small **"S"** button (out of combat). One click opens the quest-share popup for the most-likely target.

Target-resolution heuristic:
1. If only one partymate is "Shareable with"-eligible, target them
2. If multiple, pick closest by `C_Map.GetBestMapForUnit` distance, falling back to party-order
3. In combat, suppress the share button and fall back to the regular dot

Implementation notes:
- `QuestUtils_GetQuestShareableInfo(questID)` to validate shareability
- `QuestLogPushQuest(questLogIndex)` or `C_QuestLog.SetSelectedQuest(questID); QuestLogPushQuest()` for the actual share
- Both are secure-action-API-adjacent; verify they're callable from a regular OnClick without taint propagation

**Risk:** the share button is the riskiest sub-slice. Quest-sharing API has historically had taint edges; needs careful empirical validation before relying on it.

**Estimated effort:** 4–6 commits across E1, E2, E3.

---

## Bundle F — Phase 2 polish leftovers

Low-risk, ~one commit each.

### F1 — True circle indicator shape

Currently the "circle" dropdown option falls back to square + rotate-45° = diamond. The user asked for an actual circle. Two paths:

- **Atlas** — find a reliable Blizzard atlas that renders as a circle of arbitrary tint. Most candidates we explored had baked-in colour or weren't reliably present. Possibilities still worth trying: `services-icon-warning` family (we used the warning variant), `talents-button-pvp-greenglow`, `loottoast-iconborder-purple-large`. Each needs in-game verification.
- **Bundled texture** — ship a small `circle.tga` or `circle.blp` (white, alpha-masked circle, 32×32). Indicator.lua's `SetTexture(path) + SetVertexColor` would tint per state. Adds a ~1 KB asset, but guarantees behaviour.

Recommendation: bundle the texture. Predictable across clients.

### F2 — Monochrome + glyph palette

Add a fourth palette option for users with strong colour-vision differences or who prefer minimalist UI:

- All dots greyscale (light grey base)
- Each state gets a distinct small glyph overlay: `●` (aligned) / `◆` (mixed) / `▲` (ready) / `■` (shareable) — or atlas equivalents
- Glyph rendered as a FontString or a second texture on the indicator frame

**Risk:** medium — the glyph layer needs space inside the dot. May not work at 6 px. Consider hiding glyph below 10 px and just using the greyscale gradient.

### F3 — Architecture docs / mechanical cleanup

Small items from the Phase 2 architecture review:

- **#6** — One-paragraph SV-storage rationale comment in `Config.lua` explaining the `QuestFocusDB` (account-wide visuals + module toggles) vs `QuestFocusCharDB` (per-character behaviour state) split. Stops future settings from landing on the wrong side.
- **#7** — Command-table dispatcher in `QuestFocus.lua`. Replace the flat `if/elseif` chain with `COMMANDS["all"] = function() Apply.Mode("trackAll") end` etc. Worth doing only if commands grow past ~20; currently at ~15 so not urgent.
- **#8** — Brief comment on `TRACKER_MODULES = { ... }` in `MountTracker.lua` flagging it as the extension point for adding new tracker module types (if Blizzard introduces a new one).

**Estimated effort:** 1–2 commits.

---

## Bundle G — Auto-on-zone-change for ZoneFilter

A per-character opt-in: when a new zone is entered (`ZONE_CHANGED_NEW_AREA`), if the active mode is `zoneFilter` AND the user has the setting on, re-apply automatically.

### Design questions to resolve

- **Scope: zone-filter only, or all modes?** Probably zone-filter only — that's the only mode whose target genuinely changes with the zone. Re-applying campaign / weeklies / important on zone change would be noise, not value.
- **Cooldown?** Yes — at least 5 s between auto-reapplies to avoid storming during portal chains, login sequences, or rapid sub-zone hops.
- **Narrow vs narrow+promote?** Default to narrow only (less surprising — doesn't auto-track quests the user wasn't watching). Could be a separate setting.
- **Combat?** Skip during combat (consistent with manual Apply).
- **Notification?** A brief chat line ("QuestFocus: auto-applied Focus on zone change — untracked 2, kept 1") so the user knows what happened.

### Risks

- Real risk of unexpected un-track surprises if the user isn't watching. Mitigate with: default OFF, explicit setting in panel, optional chat notification, throttle.
- The user has already declared "no auto-on-zone-change (yet)" in the README's "What it doesn't do". Shipping this is reversing a stated non-goal — flag in the changelog clearly.

**Estimated effort:** 2–3 commits.

**Verdict:** medium-priority. Worth doing only if users explicitly ask. Could also be a community-PR-friendly feature.

---

## Bundle H — Addon-channel broadcast

The big one. AceComm + LibSerialize + DELTA / HELLO / ROSTER protocol from `design/QuestFocusParty.md §6.1`.

### What it unlocks

- **BNet-hidden partymate visibility** — same-realm party members can opt in to share quest state via addon comm, bypassing the BNet visibility gate entirely.
- **Cross-client accept-recency** — Bundle E's `Recently accepted` row currently works only from local observation (partymate appearing on a quest between polls). With broadcast, partymates explicitly announce "I just accepted X", giving sub-second accuracy.
- **Future cross-client coordination** — auto-share-on-pickup, coordinated turn-in callouts, etc.

### Cost

- Library embedding: AceComm-3.0 (with LibStub + CallbackHandler-1.0), LibSerialize, possibly LibDeflate. ~50 KB of bundled code.
- Protocol versioning: `HELLO`, `DELTA`, `ZONE`, `BYE` messages with major/minor version handshake (sketched in `QuestFocusParty.md §6.6`).
- Privacy controls: `/qf party broadcast on|off` becomes real; default decision needed (on with opt-out vs off with opt-in).
- Throttling, taint posture for `CHAT_MSG_ADDON`, raid (>5 members) message-volume considerations.

### Estimated effort

8–10 commits across protocol, comms layer, integration with Bundle E's SessionLog (broadcast updates feed the same observation table), settings UI, privacy opt-out.

**Verdict:** lowest urgency, highest effort. Defer unless real demand emerges from user feedback.

---

## Sequencing recommendation (subject to revision)

1. **Bundle F first.** Polish leftovers, low risk, knocks out the architecture-review tail. Ship as `v0.9.2-beta`.
2. **Bundle E second.** The user's own ask; transforms the tooltip from duplicate-of-Blizzard to unique-information. Ship as `v0.10.0-beta` (or `v1.0.0-beta` if positioned as "the last big addition before stable").
3. **Pause for live feedback.** With the addon now on CurseForge / Wago (post-`v0.9.1-beta`), real users will surface real demands. Phase 3 work after this point should be **informed** by issue-tracker traffic and review comments, not pre-planned.
4. **Bundle G third — only if asked for.** Auto-on-zone-change reverses a stated non-goal; needs explicit user pull, not push.
5. **Bundle H last — or never.** Broadcast cost is high; user pool is narrow. Defer until BNet-hidden friction is a real, recurring complaint.

---

## Quick-context-recall hooks (for resumption)

If returning to this plan cold after time away:

- **What was just shipped:** `v0.9.0-beta` (Phase 2 polish + tracker modes + architecture refactor) and `v0.9.1-beta` (CurseForge/Wago publishing pipeline activation). Tag is on origin; CurseForge ID 1544844, Wago ID `RNLkP0Go`.
- **What's NOT in flight:** no active branch, no half-finished work in the working tree. Last commit is `56cc277` on `main`.
- **GH issues:** none open. Issue #1 closed on completion of Bundle D + quest-log pair work.
- **Next concrete step (per current recommendation):** Bundle F1 (true circle indicator) is the smallest possible warm-up. Or skip directly to Bundle E if the appetite is for the bigger value.
- **The Phase 3 design lives here.** Don't re-derive — read, refine, decide.
