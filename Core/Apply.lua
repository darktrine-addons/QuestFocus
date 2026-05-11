-- Apply.lua — the Filter operation. Idempotent within a zone; safe to re-apply on zone change.

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

    -- First-time filter: snapshot the pre-filter watch list so Revert has a target.
    -- Subsequent filters (e.g., new zone) keep the original snapshot intact.
    if not State.GetFilterActive() then
        State.SetSnapshot(current)
        State.SetFilterActive(true)
    end

    local relevant = Relevance.GetRelevantQuests()
    local untracked, tracked = 0, 0

    -- Untrack quests in current watch list that aren't relevant to this zone
    for qid in pairs(current) do
        if not relevant[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            untracked = untracked + 1
        end
    end

    -- Track relevant quests not currently watched
    for qid in pairs(relevant) do
        if not current[qid] then
            C_QuestLog.AddQuestWatch(qid)
            tracked = tracked + 1
        end
    end

    notify(string.format("focus: tracked %d, untracked %d", tracked, untracked))

    if ns.UI and ns.UI.OnStateChanged then ns.UI.OnStateChanged() end
end
