-- Relevance.lua — pure determination of "is this quest relevant to my current zone?"

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local Relevance = {}
ns.ZoneFilter.Relevance = Relevance

function Relevance.GetCurrentMapID()
    return C_Map.GetBestMapForUnit("player")
end

-- A quest counts as "in current zone" if any of:
--   info.isOnMap     — quest has an objective marker on the current map
--   info.hasLocalPOI — quest has a POI (objective dot or turn-in "?") on
--                      the current map
--   C_QuestLog.IsOnMap(questID) — direct API query; in practice this is
--                      more inclusive than the cached info fields, and
--                      crucially it tends to pick up completed quests with
--                      turn-in NPCs in the current zone (which the cached
--                      info fields sometimes miss).
--
-- Inclusive-by-design: when a user clicks "Focus on this zone" they usually
-- mean "everything I can advance here" — a completed quest whose turn-in is
-- in the zone is something they'll act on while here.
function Relevance.IsQuestInCurrentZone(questInfo)
    if not questInfo or not questInfo.questID then return false end
    if questInfo.isOnMap     == true then return true end
    if questInfo.hasLocalPOI == true then return true end
    if C_QuestLog.IsOnMap and C_QuestLog.IsOnMap(questInfo.questID) then return true end
    return false
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
