-- ZoneFilter/UI/Buttons/Constants.lua — strings and tables shared
-- between the tooltip renderers (Tooltips.lua) and the right-click
-- menu (Menu.lua). Lives at the very top of the Buttons/ load order so
-- both files see them as proper upvalues.

local addonName, ns = ...
ns.ZoneFilter    = ns.ZoneFilter    or {}
ns.ZoneFilter.UI = ns.ZoneFilter.UI or {}

-- Yellow warning triangle from Blizzard's services UI atlas. Used to
-- flag actions that would empty the watch list (causing the tracker
-- to hide). Swap to a texture-path fallback if your client doesn't
-- render this atlas:
--   "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:14:14|t"
ns.ZoneFilter.UI.WARN_ICON = "|A:services-icon-warning:14:14|a"

-- Human-readable labels for the "Current mode" tooltip line and the
-- re-apply button's tooltip. Falls back to the raw mode key for
-- unknown values; mode-key-to-label.
ns.ZoneFilter.UI.MODE_DISPLAY = {
    zoneFilter     = "current zone (Focus)",
    trackAll       = "all in log",
    campaignOnly   = "campaign quests only",
    dailyOnly      = "daily quests only",
    weekliesOnly   = "weeklies only",
    importantOnly  = "Important quests only",
    readyOnly      = "ready-to-turn-in only",
    inProgressOnly = "in-progress only",
    untrackAll     = "untrack-all",
}
