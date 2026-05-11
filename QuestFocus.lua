-- QuestFocus — bootstrap.
-- Loads last per TOC; ties State/Apply/Revert/UI together and provides slash commands.

local addonName, ns = ...

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self, event, who)
    if event == "ADDON_LOADED" and who == addonName then
        ns.Core.State.EnsureDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.UI.MountTrackerButtons()
        ns.UI.MountQuestLogButtons()
    end
end)

SLASH_QUESTFOCUS1 = "/qf"
SLASH_QUESTFOCUS2 = "/questfocus"
SlashCmdList.QUESTFOCUS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "filter" or msg == "" then
        ns.Core.Apply.Filter()
    elseif msg == "revert" then
        ns.Core.Revert.Revert()
    elseif msg == "status" then
        local active = ns.Core.State.GetFilterActive()
        local restorable = ns.Core.State.GetRevertAddCount()
        print(string.format("|cffffcc00QuestFocus|r filter:%s, restorable:%d",
            tostring(active), restorable))
    else
        print("|cffffcc00QuestFocus|r commands: |cffffff88/qf|r [filter] | revert | status")
    end
end
