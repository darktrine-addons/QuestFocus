-- QuestFocus
-- Narrow tracked quests to the current zone, with one-click revert.
-- Scaffold only — no features wired yet.

local addonName, ns = ...

local QuestFocus = CreateFrame("Frame")
QuestFocus:RegisterEvent("ADDON_LOADED")
QuestFocus:SetScript("OnEvent", function(self, event, who)
    if event == "ADDON_LOADED" and who == addonName then
        QuestFocusDB     = QuestFocusDB     or {}
        QuestFocusCharDB = QuestFocusCharDB or {}
    end
end)

SLASH_QUESTFOCUS1 = "/qf"
SLASH_QUESTFOCUS2 = "/questfocus"
SlashCmdList.QUESTFOCUS = function(msg)
    print("|cffffcc00QuestFocus|r scaffold loaded. No commands implemented yet.")
end
