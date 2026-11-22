## v0.9.4-beta — 2026-11-22

### New features

- feat: **keybindings** for *Focus current zone*, *Focus current zone + add from log* and *Revert tracking* — set them under *Options → Keybindings → AddOns → QuestFocus*.
- feat: **zone-change reminder** — while the zone filter is active and you move to a new zone, the filter button pulses and a chat line tells you how many of your quests are there, with a one-click **[Re-focus]** link. Nothing is re-tracked until you click. On by default; can be turned off in the settings (per character).
- feat: `/qf settings` (also `/qf options` and `/qf config`) opens the settings panel.

### Improvements

- New quests you accept are now added to the tracker automatically whenever they match the **active** tracker mode (campaign, weeklies, Important, …) — previously this only worked for the zone filter.
- In large groups the party tooltip now shows a **one-line summary** ("N on quest · N ready · N not on it") instead of disappearing. The threshold is in the settings under *Summarize tooltip in large groups*.
- The party tooltip now includes a small colour legend for the indicator dots, and the first time dots appear you get a one-time chat hint explaining them.
- Clearer wording throughout: "promote" is now **"add from log"**, and the snapshot option is now called **"Revert respects manual un-tracks"**. Existing slash commands keep working.

### Behind the scenes

- Updated for WoW patch 12.1.5, and ready for 12.1.7 (Interface 120105, 120107).

[Full Changelog](https://github.com/darktrine-addons/QuestFocus/compare/v0.9.3-beta...v0.9.4-beta) · [All Releases](https://github.com/darktrine-addons/QuestFocus/releases) · [Changelog](https://github.com/darktrine-addons/QuestFocus/blob/main/CHANGELOG.md)
