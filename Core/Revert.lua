-- Revert.lua — strict revert: restore the snapshot exactly, dropping any interim changes.

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
    local added, removed = 0, 0

    -- Untrack quests currently watched but not in snapshot (user's interim adds + our zone additions)
    for qid in pairs(current) do
        if not snap[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            removed = removed + 1
        end
    end

    -- Re-track quests in snapshot but not currently watched
    for qid in pairs(snap) do
        if not current[qid] then
            C_QuestLog.AddQuestWatch(qid)
            added = added + 1
        end
    end

    State.ClearSnapshot()
    State.SetFilterActive(false)

    notify(string.format("revert: restored %d, removed %d", added, removed))

    if ns.UI and ns.UI.OnStateChanged then ns.UI.OnStateChanged() end
end
