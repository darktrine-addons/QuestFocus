## v0.9.3-beta — 2026-07-11

### Fixes

- fix: **stopped the error spam with Circle indicators** — with the Circle shape (the default) selected, PartySync threw a Lua error on every refresh while you were in a group, which could flood BugSack in delves and dungeons. Circle dots now render correctly on client 12.0.7, and fall back to Square if the client can't do mask textures at all. Thanks to the CurseForge user who reported this!
- fix: switching tracker modes no longer eats your revert snapshot when *Manual un-track also clears the snapshot* is enabled — the filter's own untracks were being mistaken for manual ones, so Revert could restore far less than expected.
- fix: the style-preview row in the settings panel no longer risks showing up on other settings pages, and no longer leaks preview dots when the panel is reopened.
- fix: disabling the ZoneFilter module now fully stops it — previously a leftover filter state could still auto-track new zone quests and prune the snapshot while the module was off.

### Behind the scenes

- Updated for client 12.0.7 (Interface 120007).

[Full Changelog](https://github.com/darktrine-addons/QuestFocus/compare/v0.9.2-beta...v0.9.3-beta) · [All Releases](https://github.com/darktrine-addons/QuestFocus/releases) · [Changelog](https://github.com/darktrine-addons/QuestFocus/blob/main/CHANGELOG.md)
