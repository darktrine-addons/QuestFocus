# QuestFocus — Changelog

User-facing changes, newest first. Internal and dev-tooling work lives in the
git history, not here.

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
