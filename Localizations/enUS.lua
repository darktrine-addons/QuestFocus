-- Localizations/enUS.lua — English (US) strings.
-- Attaches to the EN table built by Localization.lua (ns.L_EN).
-- Every key must be defined here; the fallback chain in L returns the
-- raw key when a translation is missing, so this file is the source of
-- truth for the full key set. Keys are grouped by prefix.

local addonName, ns = ...
local EN = ns.L_EN

-- ============================================================
-- BINDING_ — keybinding names (Bindings.xml)
-- ============================================================

EN.BINDING_HEADER    = "QuestFocus"
EN.BINDING_FOCUS     = "Focus current zone"
EN.BINDING_FOCUS_ADD = "Focus current zone + add from log"
EN.BINDING_REVERT    = "Revert tracking"

-- ============================================================
-- STATUS_ — module status words
-- ============================================================

EN.STATUS_ENABLED      = "enabled"
EN.STATUS_DISABLED     = "disabled"
EN.STATUS_ACTIVE       = "enabled (active)"
EN.STATUS_PENDING_BOOT = "enabled (pending boot)"
EN.STATUS_ON           = "ON"
EN.STATUS_OFF          = "OFF"

-- ============================================================
-- CHAT_ — slash-command output / chat messages
-- ============================================================

EN.CHAT_MODULES               = "modules:"
EN.CHAT_TOGGLE_HINT           = "Toggle with /qf module enable|disable <name>; PartySync applies live, ZoneFilter needs /reload."
EN.CHAT_UNKNOWN_MODULE        = "unknown module: %s"
EN.CHAT_MODULE_SET            = "%s set to %s."
EN.CHAT_MODULE_SET_RELOAD     = "%s set to %s. /reload to apply."
EN.CHAT_PARTY_DEBUG           = "party debug %s"
EN.CHAT_PARTY_NOT_LOADED      = "PartySync module not loaded."
EN.CHAT_BROADCAST_RESERVED    = "broadcast is reserved and not yet implemented."
EN.CHAT_ZF_DISABLED           = "ZoneFilter module is disabled. /qf module list"
EN.CHAT_STATUS                = "filter:%s, restorable:%d"
EN.CHAT_COMMANDS              = "commands:"
EN.CHAT_HELP_BASIC            = "  /qf [filter] | promote | revert | status"
EN.CHAT_HELP_MODES            = "  Modes: /qf all | untrack | campaign | daily | weekly | important | ready | inprogress"
EN.CHAT_HELP_SETTINGS         = "  /qf settings"
EN.CHAT_HELP_MODULES          = "  /qf module list | module enable|disable <name>"
EN.CHAT_HELP_PARTY            = "  /qf party debug | party broadcast on|off"
EN.CHAT_NOTHING_TO_PREVIEW    = "no quests tracked — nothing to preview."
EN.CHAT_NO_RELOAD_PENDING     = "No pending changes require a UI reload."
EN.CHAT_CANNOT_CHANGE_COMBAT  = "cannot change tracker during combat"
EN.CHAT_UNKNOWN_MODE          = "unknown mode: %s"
EN.CHAT_APPLIED               = "%s: tracked %d, untracked %d - '/qf revert' to revert"
EN.CHAT_NO_ZONE               = "could not determine current zone"
EN.CHAT_CANNOT_REVERT_COMBAT  = "cannot revert during combat"
EN.CHAT_NO_SNAPSHOT           = "no snapshot to revert to"
EN.CHAT_REVERTED              = "revert: restored %d, removed %d"
EN.CHAT_THIS_ZONE             = "this zone"
EN.CHAT_ZONE_CHANGED          = "Zone changed — %s has |cffffffff%d|r of your quests."
EN.CHAT_REFOCUS_LINK          = "[Re-focus]"
EN.CHAT_DOT_HINT              = "Party dots are live — hover a quest row for each member's progress. Colours and shapes: /qf settings."

-- ============================================================
-- CHAT_MODE_ — mode display names in chat context
-- ============================================================

EN.CHAT_MODE_ZONE_FILTER = "zone-filter"
EN.CHAT_MODE_UNTRACK_ALL = "untrack-all"
EN.CHAT_MODE_TRACK_ALL   = "track-all"
EN.CHAT_MODE_CAMPAIGN    = "campaign-only"
EN.CHAT_MODE_DAILY       = "daily-only"
EN.CHAT_MODE_WEEKLIES    = "weeklies-only"
EN.CHAT_MODE_IMPORTANT   = "important-only"
EN.CHAT_MODE_READY       = "ready-to-turn-in"
EN.CHAT_MODE_IN_PROGRESS = "in-progress"

-- ============================================================
-- MODE_ — mode descriptions (menus, tooltips)
-- ============================================================

EN.MODE_ZONE_FILTER = "current zone (Focus)"
EN.MODE_TRACK_ALL   = "all in log"
EN.MODE_CAMPAIGN    = "campaign quests only"
EN.MODE_DAILY       = "daily quests only"
EN.MODE_WEEKLIES    = "weeklies only"
EN.MODE_IMPORTANT   = "Important quests only"
EN.MODE_READY       = "ready-to-turn-in only"
EN.MODE_IN_PROGRESS = "in-progress only"
EN.MODE_UNTRACK_ALL = "untrack-all"
EN.MODE_ACTIVE      = "active"

-- ============================================================
-- SECTION_ — settings panel section headers
-- ============================================================

EN.SECTION_GLOBAL     = "Global"
EN.SECTION_ZONEFILTER = "ZoneFilter"
EN.SECTION_PARTYSYNC  = "PartySync"

-- ============================================================
-- SETTING_ — settings panel labels + tooltips
-- ============================================================

EN.SETTING_STYLE_PREVIEW       = "Style preview"
EN.SETTING_ZF_ENABLE           = "Enable ZoneFilter"
EN.SETTING_ZF_ENABLE_TIP       = "Filter your watch list to quests with objectives in the current zone, with one-click revert. Adds two small buttons to the objective tracker and the world-map quest log.\n\n|cffff8c26Requires /reload to apply changes to this checkbox.|r"
EN.SETTING_PS_ENABLE           = "Enable PartySync"
EN.SETTING_PS_ENABLE_TIP       = "Coloured indicator dots on each tracked quest row when you're in a party, plus a 'Party state:' section appended to the row's tooltip showing every member's progress.\n\n|cff44ff44Applied immediately.|r"
EN.SETTING_RELOAD_UI           = "Reload UI"
EN.SETTING_RELOAD_UI_TIP       = "Click to /reload when a setting marked 'Requires /reload' has been changed. No-op when nothing is pending."
EN.SETTING_ZF_UNTACK_CLEARS    = "Revert respects manual un-tracks"
EN.SETTING_ZF_UNTACK_CLEARS_TIP = "When checked, quests you un-track by hand while a filter is active are treated as deliberate: Revert won't bring them back. Per-character.\n\n|cffaaaaaaDefault off: Revert restores your watch list exactly as it was when you applied the filter, even if you un-tracked some of those quests since.|r"
EN.SETTING_ZF_ZONE_NUDGE       = "Zone-change reminder"
EN.SETTING_ZF_ZONE_NUDGE_TIP   = "When the zone filter is active and you enter a new zone, pulse the lens and print a chat line with a one-click [Re-focus] link. Nothing is re-tracked until you click. Per-character."

-- ============================================================
-- SIZE_ / SHAPE_ / ANCHOR_ / PALETTE_ / RAID_ — dropdown options
-- ============================================================

EN.SIZE_TINY  = "Tiny (6px)"
EN.SIZE_SMALL = "Small (8px)"
EN.SIZE_MEDIUM = "Medium (10px)"
EN.SIZE_LARGE  = "Large (12px)"

EN.SHAPE_SQUARE  = "Square"
EN.SHAPE_CIRCLE  = "Circle"
EN.SHAPE_DIAMOND = "Diamond"

EN.ANCHOR_TOP_RIGHT      = "Top-right corner"
EN.ANCHOR_RIGHT_OF_TITLE = "Right of title text"
EN.ANCHOR_LEFT_OF_TITLE  = "Left of title text"

EN.PALETTE_DEFAULT      = "Default (G/Y/B/O)"
EN.PALETTE_DEUTERANOPIA = "Deuteranopia (red-green friendly)"
EN.PALETTE_TRITANOPIA   = "Tritanopia (blue-yellow friendly)"

EN.RAID_ALWAYS = "Always show full list"
EN.RAID_AT_10  = "Summarize at 10+ members"
EN.RAID_AT_20  = "Summarize at 20+ members"

-- ============================================================
-- SETTING_PS_ — PartySync visual settings labels + tooltips
-- ============================================================

EN.SETTING_PS_SIZE            = "Indicator size"
EN.SETTING_PS_SIZE_TIP        = "Diameter of the indicator dot on each tracked quest row."
EN.SETTING_PS_SHAPE           = "Indicator shape"
EN.SETTING_PS_SHAPE_TIP       = "Shape of the indicator dot. Circle uses a circular alpha mask over the solid colour; diamond is the same texture rotated 45°."
EN.SETTING_PS_ANCHOR          = "Indicator position"
EN.SETTING_PS_ANCHOR_TIP      = "Where to place the indicator on each tracker row. 'Left of title' is offset 30px to clear the quest-type icon. Either 'of title' option falls back to the top-right corner when the row's title text isn't found."
EN.SETTING_PS_PALETTE         = "Colour palette"
EN.SETTING_PS_PALETTE_TIP     = "Alternate colour palettes for users with colour-vision differences. Default = green / yellow / blue / orange."
EN.SETTING_PS_OPACITY         = "Indicator opacity"
EN.SETTING_PS_OPACITY_TIP     = "Brightness of the indicator dots. 40% blends them into the background; 100% is fully opaque."
EN.SETTING_PS_RAID_THRESHOLD  = "Summarize tooltip in large groups"
EN.SETTING_PS_RAID_THRESHOLD_TIP = "In larger groups the per-member 'Party state' tooltip list would be too long. Once the group size meets the threshold, it's replaced by a one-line rollup: how many members are on the quest, ready to turn in, or not on it. Indicator dots still show as usual."
EN.SETTING_PREVIEW_TRACKER    = "Preview on tracker (30s)"
EN.SETTING_PREVIEW_TRACKER_TIP = "Temporarily attaches up to 4 demo indicator dots to your tracker rows so you can see how the current style looks in context. Truncates if fewer than 4 quests are tracked; no-op when nothing is tracked. Click again to extend the 30s timer; closing the settings panel ends the preview."

-- ============================================================
-- PREVIEW_ — on-tracker / inline preview labels + tooltips
-- ============================================================

EN.PREVIEW_ALIGNED    = "Aligned"
EN.PREVIEW_MIXED      = "Mixed"
EN.PREVIEW_READY      = "Ready"
EN.PREVIEW_SHAREABLE  = "Shareable"
EN.PREVIEW_TIP_ALIGNED   = "Every party member is on this quest and progressing. No coordination needed."
EN.PREVIEW_TIP_MIXED     = "Some party members are on the quest, some aren't. Worth checking in."
EN.PREVIEW_TIP_READY     = "At least one party member has the quest objectives complete and ready to turn in."
EN.PREVIEW_TIP_SHAREABLE = "Only you have this quest, and at least one partymate is in the same zone — share opportunity."

-- ============================================================
-- MENU_ — tracker mode menu entries + footers
-- ============================================================

EN.MENU_API_UNAVAILABLE = "menu API unavailable on this client."
EN.MENU_ACTIVE          = "(active)"
EN.MENU_DRIFTED         = "(drifted)"
EN.MENU_TITLE           = "Tracker modes"
EN.MENU_TRACK_ALL       = "Track all quests in log"
EN.MENU_FOCUS           = "Track current zone (Focus)"
EN.MENU_FOCUS_ADD       = "Track current zone + add from log"
EN.MENU_CAMPAIGN        = "Track campaign quests only"
EN.MENU_DAILY           = "Track daily quests only"
EN.MENU_WEEKLIES        = "Track weeklies only"
EN.MENU_IMPORTANT       = "Track Important quests only"
EN.MENU_READY           = "Track ready-to-turn-in only"
EN.MENU_IN_PROGRESS     = "Track in-progress only"
EN.MENU_UNTRACK_ALL     = "Untrack everything"
EN.MENU_OPEN_SETTINGS   = "Open settings…"
EN.MENU_WARN_FOOTER     = "action would clear the tracker (it hides)."
EN.MENU_REVERT_FOOTER   = "/qf revert restores the previous state."

-- ============================================================
-- KEY_ / TIP_KEY_ — mouse-key labels (menu vs tooltip casing)
-- ============================================================

EN.KEY_LEFT_CLICK          = "Left-click"
EN.KEY_SHIFT_LEFT_CLICK    = "Shift+Left-click"
EN.TIP_KEY_LEFT_CLICK      = "Left-Click"
EN.TIP_KEY_SHIFT_LEFT_CLICK = "Shift-Left-Click"

-- ============================================================
-- TIP_ — tracker button tooltips
-- ============================================================

EN.TIP_NO_FILTER       = "No filter"
EN.TIP_FILTER_DRIFT    = "Filter: %s (%s)"
EN.TIP_FILTER_CLEAN    = "Filter: %s"
EN.TIP_DRIFT_BOTH      = "%d added, %d removed"
EN.TIP_DRIFT_ADDED     = "%d added"
EN.TIP_DRIFT_REMOVED   = "%d removed"
EN.TIP_NARROW_DESC     = "Narrow your watch list to quests with objectives in this zone."
EN.TIP_NO_CHANGES      = "(no changes)"
EN.TIP_MAP_UNKNOWN     = "Current zone unknown — open the world map once."
EN.TIP_FOCUS_LINE      = "%s: Focus current zone %s |cffaaaaaa(%d tracked)|r%s"
EN.TIP_FOCUS_ADD_LINE  = "%s: Focus current zone + add from log %s |cffaaaaaa(%d tracked)|r%s"
EN.TIP_REAPPLY_HINT    = "The |cff44ff44green button|r|cffaaaaaa re-applies the current mode.|r"
EN.TIP_WARN_LEGEND     = "= tracker would hide"
EN.TIP_HOTKEYS         = "Right-click: mode menu  |  Shift-Right: settings"
EN.TIP_RESTORE_TITLE   = "Restore tracking"
EN.TIP_NOTHING_TO_RESTORE = "Nothing to restore."
EN.TIP_RESTORES_N      = "Restores %d quest|4quest:quests| from before the filter."
EN.TIP_KEEPS_N         = "Keeps %d quest|4quest:quests| you've added since."
EN.TIP_CLEARS_FILTER   = "Clears filter state — no changes to tracking."
EN.TIP_REAPPLY_TITLE   = "Re-apply tracker mode"
EN.TIP_CURRENT_MODE    = "Current mode: %s"
EN.TIP_REAPPLY_DESC    = "Clears drift and re-applies the selected mode."
EN.TIP_NO_MODE_ACTIVE  = "No mode active."

-- ============================================================
-- PARTY_ — party progress tooltip + dots
-- ============================================================

EN.PARTY_READY_TO_TURN_IN  = "Ready to turn in"
EN.PARTY_NOT_ON_QUEST      = "Not on quest"
EN.PARTY_IN_PROGRESS_COUNT = "In progress (%d/%d)"
EN.PARTY_IN_PROGRESS       = "In progress"
EN.PARTY_SUMMARY           = "Party: |cffffffff%d|r on quest · |cff66ff66%d|r ready · |cff888888%d|r not on it"
EN.PARTY_STATE             = "Party state:"
EN.PARTY_YOU               = "You"
EN.PARTY_DOT_LEGEND        = "Dot:  %s   %s   %s   %s"
EN.PARTY_DOT_READY         = "ready"
EN.PARTY_DOT_SHARE         = "share"
EN.PARTY_DOT_MIXED         = "mixed"
EN.PARTY_DOT_ALIGNED       = "aligned"
EN.PARTY_VISIBILITY_FOOTER = "Hidden / not-on-quest rows depend on BNet visibility."