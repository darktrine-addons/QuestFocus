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
        if ns.Settings and ns.Settings.Register then ns.Settings.Register() end
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
-- Keybindings (Bindings.xml) — names + handlers
-- ============================================================

BINDING_HEADER_QUESTFOCUS         = "QuestFocus"
BINDING_NAME_QUESTFOCUS_FOCUS     = "Focus current zone"
BINDING_NAME_QUESTFOCUS_FOCUS_ADD = "Focus current zone + add from log"
BINDING_NAME_QUESTFOCUS_REVERT    = "Revert tracking"

function QuestFocus_BindingFocus()
    if ZoneFilterEnabled() and ns.ZoneFilter and ns.ZoneFilter.Apply then
        ns.ZoneFilter.Apply.Filter(false)
    end
end

function QuestFocus_BindingFocusAdd()
    if ZoneFilterEnabled() and ns.ZoneFilter and ns.ZoneFilter.Apply then
        ns.ZoneFilter.Apply.Filter(true)
    end
end

function QuestFocus_BindingRevert()
    if ZoneFilterEnabled() and ns.ZoneFilter and ns.ZoneFilter.Revert then
        ns.ZoneFilter.Revert.Revert()
    end
end

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
    print("  |cffaaaaaaToggle with /qf module enable|disable <name>; PartySync applies live, ZoneFilter needs /reload.|r")
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

    -- PartySync supports runtime hot-toggle. ZoneFilter still needs
    -- /reload (its tracker buttons can't cleanly tear themselves down
    -- without one).
    if name == "PartySync" and ns.PartySync and ns.PartySync.SetActive then
        ns.PartySync.SetActive(enabled)
        print(string.format("|cffffcc00QuestFocus|r %s set to %s.",
            name, colourEnabled(enabled)))
    else
        print(string.format("|cffffcc00QuestFocus|r %s set to %s. |cffaaaaaa/reload|r to apply.",
            name, colourEnabled(enabled)))
    end
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

    -- Settings panel — available regardless of which modules are enabled
    if msg == "settings" or msg == "options" or msg == "config" then
        if ns.Settings and ns.Settings.Open then ns.Settings.Open() end
        return
    end

    -- PartySync utility sub-commands
    if msg == "party debug" then
        if ns.PartySync then
            ns.PartySync.debug = not ns.PartySync.debug
            print(string.format("|cffffcc00QuestFocus|r party debug %s",
                ns.PartySync.debug and "|cff44ff44ON|r" or "|cffff7777OFF|r"))
        else
            print("|cffffcc00QuestFocus|r PartySync module not loaded.")
        end
        return
    end
    if msg == "party broadcast on" or msg == "party broadcast off" then
        print("|cffffcc00QuestFocus|r broadcast is reserved and not yet implemented.")
        return
    end

    -- ZoneFilter commands require ZoneFilter enabled
    if not ZoneFilterEnabled() then
        print("|cffffcc00QuestFocus|r ZoneFilter module is disabled. |cffaaaaaa/qf module list|r")
        return
    end

    if msg == "filter" or msg == "" then
        ns.ZoneFilter.Apply.Filter(false)
    elseif msg == "filtershift" or msg == "promote" then
        ns.ZoneFilter.Apply.Filter(true)
    elseif msg == "untrack" or msg == "untrackall" then
        ns.ZoneFilter.Apply.Mode("untrackAll")
    elseif msg == "all" or msg == "trackall" then
        ns.ZoneFilter.Apply.Mode("trackAll")
    elseif msg == "campaign" or msg == "campaignonly" then
        ns.ZoneFilter.Apply.Mode("campaignOnly")
    elseif msg == "daily" or msg == "dailies" then
        ns.ZoneFilter.Apply.Mode("dailyOnly")
    elseif msg == "weekly" or msg == "weeklies" then
        ns.ZoneFilter.Apply.Mode("weekliesOnly")
    elseif msg == "important" or msg == "importantonly" then
        ns.ZoneFilter.Apply.Mode("importantOnly")
    elseif msg == "ready" or msg == "turnin" then
        ns.ZoneFilter.Apply.Mode("readyOnly")
    elseif msg == "inprogress" then
        ns.ZoneFilter.Apply.Mode("inProgressOnly")
    elseif msg == "revert" then
        ns.ZoneFilter.Revert.Revert()
    elseif msg == "status" then
        local active = ns.ZoneFilter.State.GetFilterActive()
        local restorable = ns.ZoneFilter.State.GetRevertAddCount()
        print(string.format("|cffffcc00QuestFocus|r filter:%s, restorable:%d",
            tostring(active), restorable))
    else
        print("|cffffcc00QuestFocus|r commands:")
        print("  |cffffff88/qf|r [filter] | promote | revert | status")
        print("  Modes: |cffffff88/qf|r all | untrack | campaign | daily | weekly | important | ready | inprogress")
        print("  |cffffff88/qf|r settings")
        print("  |cffffff88/qf|r module list | module enable|disable <name>")
        print("  |cffffff88/qf|r party debug | party broadcast on|off")
    end
end
