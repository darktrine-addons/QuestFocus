-- Relevance.lua — pure determination of "is this quest relevant to my current zone?"

local addonName, ns = ...
ns.Core = ns.Core or {}
local Relevance = {}
ns.Core.Relevance = Relevance

function Relevance.GetCurrentMapID()
    return C_Map.GetBestMapForUnit("player")
end

-- A quest counts as "in current zone" if it has an objective marker or a local POI here.
-- These are the two fields the quest log gives us that reflect map relevance.
function Relevance.IsQuestInCurrentZone(questInfo)
    if not questInfo then return false end
    return (questInfo.isOnMap == true) or (questInfo.hasLocalPOI == true)
end

-- Walk the quest log once and return the set of questIDs relevant to the current zone.
-- Returns { [questID] = true, ... }
function Relevance.GetRelevantQuests()
    local relevant = {}
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            if Relevance.IsQuestInCurrentZone(info) then
                relevant[info.questID] = true
            end
        end
    end
    return relevant
end
