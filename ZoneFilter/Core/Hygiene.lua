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
local Hygiene = {}
ns.ZoneFilter.Hygiene = Hygiene

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

-- D1 must only react to MANUAL un-tracks. Apply.Mode / Revert.Revert
-- untrack in bulk themselves; the resulting QUEST_WATCH_LIST_CHANGED
-- events are indistinguishable from a user click here, so without a
-- guard a mode switch with untrackClearsSnapshot ON would prune every
-- quest the new mode untracked from the snapshot — and revert would
-- silently restore less than expected. Apply/Revert raise this flag
-- around their mutations (and through the next frame, since event
-- dispatch may be deferred); while raised we just resync the baseline.
local suppressed = false

function Hygiene.SetSuppressed(on)
    suppressed = on and true or false
    if not suppressed and ns.ZoneFilter.State then
        -- Leaving the window: adopt the post-mutation watch list as the
        -- new baseline so the programmatic changes never diff as manual.
        previousWatches = ns.ZoneFilter.State.GetCurrentWatches()
    end
end

local function UntrackClearsEnabled()
    return QuestFocusCharDB
       and QuestFocusCharDB.zoneFilter
       and QuestFocusCharDB.zoneFilter.untrackClearsSnapshot == true
end

local function DiffAndMaybePrune()
    local State = ns.ZoneFilter.State
    if not State or not State.GetCurrentWatches then return end
    local current = State.GetCurrentWatches()

    if not suppressed and State.GetFilterActive() and UntrackClearsEnabled() then
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
    -- Module gate: wired at file load, so check the enable flag at
    -- event time — a disabled ZoneFilter must not touch the (possibly
    -- stale) currentApplication left in the per-char SV.
    if not (ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")) then return end
    if event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        PruneOne(arg1)
    elseif event == "QUEST_WATCH_LIST_CHANGED" then
        DiffAndMaybePrune()
    end
end)
