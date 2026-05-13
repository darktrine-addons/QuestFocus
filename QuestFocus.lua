-- QuestFocus — bootstrap.
-- Loads last per TOC; routes ADDON_LOADED / PLAYER_ENTERING_WORLD to the
-- enabled modules and exposes slash commands that delegate into them.
-- Future modules (PartySync, …) plug in alongside the same dispatcher.

local addonName, ns = ...

local function ZoneFilterEnabled()
    return ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")
end
local function PartySyncEnabled()
    return ns.Config and ns.Config.IsModuleEnabled("PartySync")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self, event, who)
    if event == "ADDON_LOADED" and who == addonName then
        ns.Config.EnsureDB()
        if ZoneFilterEnabled() then
            ns.ZoneFilter.State.EnsureDB()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ZoneFilterEnabled() then
            ns.ZoneFilter.UI.MountTrackerButtons()
            ns.ZoneFilter.UI.MountQuestLogButtons()
            ns.ZoneFilter.booted = true
        end
        if PartySyncEnabled() then
            ns.PartySync.Boot()
        end
    end
end)

-- ============================================================
-- Slash command dispatch
-- ============================================================

local function colourEnabled(enabled)
    return enabled and "|cff44ff44enabled|r" or "|cffff7777disabled|r"
end

local function ModuleStatus(name)
    local enabled = ns.Config.IsModuleEnabled(name)
    if not enabled then return "|cffff7777disabled|r" end
    local moduleNs = ns[name]
    local booted = moduleNs and moduleNs.booted == true
    if booted then return "|cff44ff44enabled (active)|r" end
    return "|cffffff77enabled (pending boot)|r"
end

local function PrintModuleList()
    print("|cffffcc00QuestFocus|r modules:")
    for _, name in ipairs(ns.Config.GetKnownModules()) do
        print(string.format("  %s: %s", name, ModuleStatus(name)))
    end
    print("  |cffaaaaaaToggle with /qf module enable|disable <name>; /reload to apply.|r")
end

local function ToggleModule(name, enabled)
    local known = false
    for _, n in ipairs(ns.Config.GetKnownModules()) do
        if n:lower() == name:lower() then name = n; known = true; break end
    end
    if not known then
        print(string.format("|cffffcc00QuestFocus|r unknown module: %s", name))
        return
    end
    ns.Config.SetModuleEnabled(name, enabled)
    print(string.format("|cffffcc00QuestFocus|r %s set to %s. |cffaaaaaa/reload|r to apply.",
        name, colourEnabled(enabled)))
end

SLASH_QUESTFOCUS1 = "/qf"
SLASH_QUESTFOCUS2 = "/questfocus"
SlashCmdList.QUESTFOCUS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    -- module commands are available regardless of which modules are enabled
    if msg == "module" or msg == "module list" then
        PrintModuleList()
        return
    end
    local enableName  = msg:match("^module enable (%S+)$")
    local disableName = msg:match("^module disable (%S+)$")
    if enableName  then ToggleModule(enableName,  true);  return end
    if disableName then ToggleModule(disableName, false); return end

    -- ZoneFilter commands require ZoneFilter enabled
    if not ZoneFilterEnabled() then
        print("|cffffcc00QuestFocus|r ZoneFilter module is disabled. |cffaaaaaa/qf module list|r")
        return
    end

    if msg == "filter" or msg == "" then
        ns.ZoneFilter.Apply.Filter(false)
    elseif msg == "filtershift" or msg == "promote" then
        ns.ZoneFilter.Apply.Filter(true)
    elseif msg == "revert" then
        ns.ZoneFilter.Revert.Revert()
    elseif msg == "status" then
        local active = ns.ZoneFilter.State.GetFilterActive()
        local restorable = ns.ZoneFilter.State.GetRevertAddCount()
        print(string.format("|cffffcc00QuestFocus|r filter:%s, restorable:%d",
            tostring(active), restorable))
    else
        print("|cffffcc00QuestFocus|r commands: |cffffff88/qf|r [filter] | promote | revert | status | module list | module enable|disable <name>")
    end
end
