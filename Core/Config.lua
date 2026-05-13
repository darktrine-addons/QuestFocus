-- Core/Config.lua — shared module-toggle scaffold.
--
-- Backs `QuestFocusDB.modules[name] = { enabled = true|false }` against a
-- known-module allowlist. Unknown names default to enabled so a future
-- module that ships before the allowlist is updated isn't silently
-- disabled. Toggling a module requires /reload — modules read this flag
-- at bootstrap time only.

local addonName, ns = ...
ns.Config = ns.Config or {}

local KNOWN_MODULES = { "ZoneFilter", "PartySync" }

function ns.Config.EnsureDB()
    QuestFocusDB         = QuestFocusDB         or {}
    QuestFocusDB.modules = QuestFocusDB.modules or {}
    for _, name in ipairs(KNOWN_MODULES) do
        if QuestFocusDB.modules[name] == nil then
            QuestFocusDB.modules[name] = { enabled = true }
        end
    end
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
