# QuestFocus — Changelog

User-facing changes, newest first. Internal and dev-tooling work lives in the
git history, not here.

## [v1.0.0](https://github.com/darktrine-addons/QuestFocus/releases/tag/v1.0.0) — 2026-11-23

- **Out of beta.**
- feat: **Simplified and Traditional Chinese translations** (zhCN, zhTW) for the settings panel, menus, tooltips, keybindings and chat messages — thanks to Lograthmic ([#3](https://github.com/darktrine-addons/QuestFocus/pull/3)).

## [v0.9.5-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.5-beta) — 2026-11-22

- feat: **WoW Forever support** — one download for Retail and Forever (Interface 16001 added). Campaign, weeklies and Important modes will mostly be empty in Forever.

## [v0.9.4-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.4-beta) — 2026-11-22

- feat: **keybindings** for *Focus current zone*, *Focus current zone + add from log* and *Revert tracking* (under *Keybindings → AddOns*).
- feat: **zone-change reminder** — with the zone filter active, entering a new zone pulses the filter button and prints a chat line with a one-click **[Re-focus]** link. On by default; per-character setting.
- feat: `/qf settings` (also `options` / `config`) opens the settings panel.
- feat: newly accepted quests are auto-tracked whenever they match the **active** tracker mode, not only the zone filter.
- feat: in large groups the party tooltip shows a one-line summary instead of disappearing.
- feat: dot colour legend in the party tooltip, plus a one-time chat hint the first time dots appear.
- chore: clearer wording — "promote" is now "add from log"; snapshot option renamed "Revert respects manual un-tracks". Slash commands unchanged.
- chore: updated for WoW patch 12.1.5, ready for 12.1.7 (Interface 120105, 120107).

## [v0.9.3-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.3-beta) — 2026-07-11

- fix: **stopped the error spam with Circle indicators** — with the Circle shape (the default) selected, PartySync threw a Lua error on every refresh while you were in a group, which could flood BugSack in delves and dungeons. Circle dots now render correctly on client 12.0.7, and fall back to Square if the client can't do mask textures at all.
- fix: switching tracker modes no longer eats your revert snapshot when *Manual un-track also clears the snapshot* is enabled — the filter's own untracks were being mistaken for manual ones, so Revert could restore far less than expected.
- fix: the style-preview row in the settings panel no longer risks showing up on other settings pages, and no longer leaks preview dots when the panel is reopened.
- fix: disabling the ZoneFilter module now fully stops it — previously a leftover filter state could still auto-track new zone quests and prune the snapshot while the module was off.
- chore: updated for client 12.0.7 (Interface 120007).

## [v0.9.2-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.2-beta) — 2026-06-03

- feat: the party indicator dot can now be a true **circle** — rendered via a circular alpha mask so it tints with your colour palette like Square and Diamond. Circle is the new default; existing users keep their stored choice.

## [v0.9.1-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.1-beta) — 2026-05-16

- chore: CurseForge and Wago publishing pipeline activated (no functional changes).

## [v0.9.0-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.9.0-beta) — 2026-05-16

- feat: native **settings panel** under *Escape → Options → AddOns → QuestFocus* (or Shift-Right-click any filter button).
- feat: **tracker mode menu** — right-click the 🔍 button for nine one-click modes (all / current zone / current zone + promote / campaign / daily / weekly / Important / ready-to-turn-in / in-progress / untrack everything); each entry previews how many quests it would track and flags ones that would empty the tracker.
- feat: active-mode awareness — the menu marks the current mode `(active)`/`(drifted)` and the lens tooltip describes what the filter is doing in plain language.
- feat: **re-apply button** appears when a tracker mode is active and the watch list has drifted; one click cleans the drift without leaving the mode.
- feat: PartySync visual settings — indicator size, shape, position, three colour palettes (including red-green- and blue-yellow-friendly), and an opacity slider, with live previews.
- feat: slash commands for every tracker mode (`/qf all|untrack|campaign|daily|weekly|important|ready|inprogress`).
- feat: optional per-character setting *Manual un-track also clears the snapshot* (off by default).
- feat: a drift pulse flashes the lens when the filter goes from clean to drifted; in groups of 10+ the per-member tooltip section auto-hides (configurable threshold).
- fix: the re-apply button no longer overflows off the world-map quest log frame.
- fix: PartySync indicators no longer attach to warband or bonus-objective quests, where party state has no meaning.

## [v0.3.0-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.3.0-beta) — 2026-05-15

- feat: **PartySync** — a coloured dot on every tracked quest row when you're in a party (green/yellow/blue/orange), plus a "Party state:" section appended to Blizzard's quest tooltip showing each member's status. Works on both the regular and campaign trackers.
- feat: **auto-promote** — new zone-relevant quests entering your log while a filter is active are tracked immediately, closing the `autoQuestWatch` gap on event quests like *Void Assaults*.
- feat: module-toggle slash commands (`/qf module list|enable|disable <name>`).

## [v0.2.0-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.2.0-beta) — 2026-05-12

- feat: tri-state filter indicator (white / green / orange) and a restorable-count badge on the revert button.

## [v0.1.0-beta](https://github.com/darktrine-addons/QuestFocus/releases/tag/v0.1.0-beta) — 2026-05-11

Initial public beta.

- feat: ZoneFilter — focus / revert buttons on the objective tracker and the world-map quest log, with merge revert semantics (pre-filter snapshot ∪ quests added since).
- feat: slash commands `/qf`, `/qf promote`, `/qf revert`, `/qf status`.
