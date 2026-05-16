-- ZoneFilter/Core/Hygiene.lua — quest-log event hygiene for the filter
-- state. Two responsibilities:
--
-- D2 — prune completed / abandoned quests from currentApplication.
--      Listens to QUEST_TURNED_IN and QUEST_REMOVED, calls
--      State.PruneQuest. Unconditional cleanup so SV doesn't bloat
--      over time. No-op when no filter is active.
--
-- D1 — optional "manual un-track clears snapshot" behaviour. When the
--      per-character setting QuestFocusCharDB.zoneFilter
--      .untrackClearsSnapshot is true AND a filter is active, manually
--      un-tracking a quest also removes it from snapshot + target so
--      revert respects the choice. Off by default — preserves the
--      original strict-revert behaviour.

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}

-- ============================================================
-- D2: prune state on quest log churn
-- ============================================================

local function PruneOne(questID)
    if ns.ZoneFilter.State and ns.ZoneFilter.State.PruneQuest then
        ns.ZoneFilter.State.PruneQuest(questID)
    end
end

-- ============================================================
-- D1: untrack-clears-snapshot — diff watch-list events to detect
-- manual un-tracks, prune when configured.
-- ============================================================

local previousWatches = {}

local function UntrackClearsEnabled()
    return QuestFocusCharDB
       and QuestFocusCharDB.zoneFilter
       and QuestFocusCharDB.zoneFilter.untrackClearsSnapshot == true
end

local function DiffAndMaybePrune()
    local State = ns.ZoneFilter.State
    if not State or not State.GetCurrentWatches then return end
    local current = State.GetCurrentWatches()

    if State.GetFilterActive() and UntrackClearsEnabled() then
        local pruned = 0
        for qid in pairs(previousWatches) do
            if not current[qid] then
                State.PruneQuest(qid)
                pruned = pruned + 1
            end
        end
        if pruned > 0 and ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then
            ns.ZoneFilter.UI.OnStateChanged()
        end
    end
    previousWatches = current
end

-- ============================================================
-- Event wiring
-- ============================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_REMOVED")
frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        PruneOne(arg1)
    elseif event == "QUEST_WATCH_LIST_CHANGED" then
        DiffAndMaybePrune()
    end
end)
