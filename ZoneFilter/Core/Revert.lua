-- Revert.lua — merge revert.
--
-- target = snapshot ∪ drift_adds
--        = (pre-filter watch list) ∪ (quests added since last filter)
--
-- This preserves anything the user (or autoQuestWatch) added after the
-- filter was applied, while still restoring the original watch list.
-- Quests we added during the filter that the user didn't subsequently
-- accept-or-untrack get cleaned up.

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local Revert = {}
ns.ZoneFilter.Revert = Revert

local function notify(msg)
    print("|cffffcc00QuestFocus|r " .. msg)
end

function Revert.Revert()
    if InCombatLockdown() then
        notify("cannot revert during combat")
        return
    end

    local State = ns.ZoneFilter.State
    local snap = State.GetSnapshot()
    if not snap then
        notify("no snapshot to revert to")
        return
    end

    local current = State.GetCurrentWatches()
    local last    = State.GetLastApplied()

    -- Same guard as Apply.Mode: our bulk watch changes must not read as
    -- manual un-tracks to Hygiene's D1 diff (see Hygiene.SetSuppressed).
    local Hygiene = ns.ZoneFilter.Hygiene
    if Hygiene then
        Hygiene.SetSuppressed(true)
        C_Timer.After(0, function() Hygiene.SetSuppressed(false) end)
    end

    -- target = snapshot ∪ drift_adds  (drift_adds = current ∖ lastApplied)
    local target = {}
    for qid in pairs(snap) do target[qid] = true end
    if last then
        for qid in pairs(current) do
            if not last[qid] then target[qid] = true end
        end
    end

    local added, removed = 0, 0

    for qid in pairs(current) do
        if not target[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            removed = removed + 1
        end
    end

    for qid in pairs(target) do
        if not current[qid] then
            C_QuestLog.AddQuestWatch(qid)
            added = added + 1
        end
    end

    State.ClearFilter()

    notify(string.format("revert: restored %d, removed %d", added, removed))

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then ns.ZoneFilter.UI.OnStateChanged() end
end
