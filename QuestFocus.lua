-- QuestFocus — bootstrap.
-- Loads last per TOC; routes ADDON_LOADED / PLAYER_ENTERING_WORLD to the
-- ZoneFilter module and exposes slash commands that delegate into it.
-- Future modules (PartySync, …) plug in alongside the same dispatcher.

local addonName, ns = ...

local function ZoneFilterEnabled()
    return ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self, event, who)
    if event == "ADDON_LOADED" and who == addonName then
        if ZoneFilterEnabled() then
            ns.ZoneFilter.State.EnsureDB()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if ZoneFilterEnabled() then
            ns.ZoneFilter.UI.MountTrackerButtons()
            ns.ZoneFilter.UI.MountQuestLogButtons()
        end
    end
end)

SLASH_QUESTFOCUS1 = "/qf"
SLASH_QUESTFOCUS2 = "/questfocus"
SlashCmdList.QUESTFOCUS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if not ZoneFilterEnabled() then
        print("|cffffcc00QuestFocus|r ZoneFilter module is disabled.")
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
        print("|cffffcc00QuestFocus|r commands: |cffffff88/qf|r [filter] | promote | revert | status")
    end
end
