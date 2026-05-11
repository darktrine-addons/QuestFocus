-- Apply.lua — the Filter operation.
--
-- First call: snapshot the current watch list, compute zone-relevant set,
--             apply the diff. Set lastApplied = relevant set.
--
-- Subsequent call (re-apply): if we're "dirty" (current has quests that
--             weren't in lastApplied), those drift adds get folded into
--             snapshot first — so future revert preserves them. Then
--             recompute relevant for the current zone, apply the diff,
--             update lastApplied.
--
-- After any successful call: drift_adds = ∅ (lastApplied has just been
--             refreshed), so the indicator returns to green.

local addonName, ns = ...
ns.Core = ns.Core or {}
local Apply = {}
ns.Core.Apply = Apply

local function notify(msg)
    print("|cffffcc00QuestFocus|r " .. msg)
end

function Apply.Filter()
    if InCombatLockdown() then
        notify("cannot filter during combat")
        return
    end

    local State     = ns.Core.State
    local Relevance = ns.Core.Relevance

    local mapID = Relevance.GetCurrentMapID()
    if not mapID then
        notify("could not determine current zone")
        return
    end

    local current = State.GetCurrentWatches()

    if not State.GetFilterActive() then
        -- First filter — snapshot the current watch list as the revert base.
        State.SetSnapshot(current)
        State.SetFilterActive(true)
    else
        -- Re-apply: accumulate drift_adds into snapshot so they're preserved
        -- on future revert. (current ∖ lastApplied = quests added since the
        -- last filter; they represent user / auto-track choices we shouldn't
        -- silently lose.)
        local last = State.GetLastApplied()
        if last then
            local snap = State.GetSnapshot() or {}
            for qid in pairs(current) do
                if not last[qid] then
                    snap[qid] = true
                end
            end
            State.SetSnapshot(snap)
        end
    end

    local relevant = Relevance.GetRelevantQuests()
    local untracked, tracked = 0, 0

    for qid in pairs(current) do
        if not relevant[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            untracked = untracked + 1
        end
    end

    for qid in pairs(relevant) do
        if not current[qid] then
            C_QuestLog.AddQuestWatch(qid)
            tracked = tracked + 1
        end
    end

    -- Record the new post-filter state for drift detection.
    State.SetLastApplied(relevant)

    notify(string.format("focus: tracked %d, untracked %d", tracked, untracked))

    if ns.UI and ns.UI.OnStateChanged then ns.UI.OnStateChanged() end
end
