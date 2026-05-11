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
ns.Core = ns.Core or {}
local Revert = {}
ns.Core.Revert = Revert

local function notify(msg)
    print("|cffffcc00QuestFocus|r " .. msg)
end

function Revert.Revert()
    if InCombatLockdown() then
        notify("cannot revert during combat")
        return
    end

    local State = ns.Core.State
    local snap = State.GetSnapshot()
    if not snap then
        notify("no snapshot to revert to")
        return
    end

    local current = State.GetCurrentWatches()
    local last    = State.GetLastApplied()

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

    State.ClearSnapshot()
    State.ClearLastApplied()
    State.SetFilterActive(false)

    notify(string.format("revert: restored %d, removed %d", added, removed))

    if ns.UI and ns.UI.OnStateChanged then ns.UI.OnStateChanged() end
end
