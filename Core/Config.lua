-- Core/Config.lua — shared module-toggle scaffold + SV defaults.
--
-- SavedVariables split convention (followed throughout the addon):
--
--   QuestFocusDB       — account-wide. Module enable flags, PartySync
--                        visual preferences (size, shape, palette, etc),
--                        anything that should feel the same across every
--                        character on the account.
--
--   QuestFocusCharDB   — per-character. ZoneFilter's currentApplication
--                        struct (the live filter state), per-character
--                        behaviour preferences like untrackClearsSnapshot.
--
-- Rule of thumb when adding a new setting: behaviour state and per-char
-- preferences → QuestFocusCharDB. Visual / cosmetic preferences and
-- module-level toggles → QuestFocusDB. If you're unsure, ask "would a
-- user reasonably want this setting to differ between their characters?"
-- — yes → CharDB, no → DB.
--
-- Backs `QuestFocusDB.modules[name] = { enabled = true|false }` against a
-- known-module allowlist. Unknown names default to enabled so a future
-- module that ships before the allowlist is updated isn't silently
-- disabled. Toggling a module requires /reload — modules read this flag
-- at bootstrap time only.

local addonName, ns = ...
ns.Config = ns.Config or {}

local KNOWN_MODULES = { "ZoneFilter", "PartySync" }

local PARTYSYNC_VISUAL_DEFAULTS = {
    indicatorSize    = 10,               -- 6 / 8 / 10 / 12 (px)
    indicatorShape   = "circle",         -- "square" | "circle" | "diamond"
    indicatorAnchor  = "leftOfTitle",    -- leftOfTitle | rightOfTitle | topRight
    palette          = "default",        -- "default" | "deuteranopia" | "tritanopia"
    indicatorOpacity = 1.0,              -- 0.4 .. 1.0
    raidThreshold    = 10,               -- 0 (always full list) | 10 | 20 — D5: summarize tooltip in large groups
}

function ns.Config.EnsureDB()
    QuestFocusDB         = QuestFocusDB         or {}
    QuestFocusCharDB     = QuestFocusCharDB     or {}

    QuestFocusDB.modules = QuestFocusDB.modules or {}
    for _, name in ipairs(KNOWN_MODULES) do
        if QuestFocusDB.modules[name] == nil then
            QuestFocusDB.modules[name] = { enabled = true }
        end
    end
    QuestFocusDB.partySync = QuestFocusDB.partySync or {}
    for k, v in pairs(PARTYSYNC_VISUAL_DEFAULTS) do
        if QuestFocusDB.partySync[k] == nil then
            QuestFocusDB.partySync[k] = v
        end
    end
    -- Migration: "topLeft" anchor was removed (overlapped the quest
    -- icons); flip any leftover SV value to the default.
    if QuestFocusDB.partySync.indicatorAnchor == "topLeft" then
        QuestFocusDB.partySync.indicatorAnchor = "topRight"
    end

    -- Per-character ZoneFilter settings — behavior preferences that
    -- follow the character, not the account.
    QuestFocusCharDB.zoneFilter = QuestFocusCharDB.zoneFilter or {}
    if QuestFocusCharDB.zoneFilter.untrackClearsSnapshot == nil then
        QuestFocusCharDB.zoneFilter.untrackClearsSnapshot = false
    end
end

function ns.Config.GetPartySyncSetting(key)
    if QuestFocusDB and QuestFocusDB.partySync and QuestFocusDB.partySync[key] ~= nil then
        return QuestFocusDB.partySync[key]
    end
    return PARTYSYNC_VISUAL_DEFAULTS[key]
end

function ns.Config.SetPartySyncSetting(key, value)
    QuestFocusDB           = QuestFocusDB or {}
    QuestFocusDB.partySync = QuestFocusDB.partySync or {}
    QuestFocusDB.partySync[key] = value
end

function ns.Config.IsModuleEnabled(name)
    if not QuestFocusDB or not QuestFocusDB.modules then return true end
    local m = QuestFocusDB.modules[name]
    if not m then return true end
    return m.enabled == true
end

function ns.Config.SetModuleEnabled(name, enabled)
    QuestFocusDB         = QuestFocusDB         or {}
    QuestFocusDB.modules = QuestFocusDB.modules or {}
    QuestFocusDB.modules[name] = QuestFocusDB.modules[name] or {}
    QuestFocusDB.modules[name].enabled = enabled and true or false
end

function ns.Config.GetKnownModules()
    return KNOWN_MODULES
end
