-- Apply.lua — the Filter operation.
--
-- Two click modes:
--   Plain click (addFromLog = false): narrow only. Untrack any watch-list
--     entry whose quest isn't in the current zone. Do not promote
--     untracked zone-relevant quests from the quest log.
--   Shift-click (addFromLog = true): narrow + promote. Same untrack pass,
--     plus AddQuestWatch on any quest log entry that's zone-relevant but
--     not currently watched.
--
-- First call: snapshot the current watch list, apply the chosen mode, set
--             lastApplied to the post-filter watch state.
--
-- Subsequent call (re-apply): if we're "dirty" (current has quests that
--             weren't in lastApplied), those drift adds get folded into
--             snapshot first — so future revert preserves them. Then
--             re-apply with the chosen mode and refresh lastApplied.
--
-- After any successful call: drift_adds = ∅ (lastApplied has just been
--             refreshed), so the indicator returns to green.

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local Apply = {}
ns.ZoneFilter.Apply = Apply

local function notify(msg)
    print("|cffffcc00QuestFocus|r " .. msg)
end

function Apply.Filter(addFromLog)
    if InCombatLockdown() then
        notify("cannot filter during combat")
        return
    end

    local State     = ns.ZoneFilter.State
    local Relevance = ns.ZoneFilter.Relevance

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

    -- Always: untrack any current watch that's not zone-relevant
    for qid in pairs(current) do
        if not relevant[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            untracked = untracked + 1
        end
    end

    -- Compute the post-untrack survivors (= current ∩ relevant).
    local newLastApplied = {}
    for qid in pairs(current) do
        if relevant[qid] then newLastApplied[qid] = true end
    end

    -- Shift-click only: also promote untracked zone-relevant quests from the log
    if addFromLog then
        for qid in pairs(relevant) do
            if not current[qid] then
                C_QuestLog.AddQuestWatch(qid)
                tracked = tracked + 1
                newLastApplied[qid] = true
            end
        end
    end

    -- Record the new post-filter state for drift detection.
    State.SetLastApplied(newLastApplied)
    State.SetLastMode("zoneFilter")

    if addFromLog then
        notify(string.format("focus: tracked %d, untracked %d", tracked, untracked))
    else
        notify(string.format("focus: untracked %d (shift-click to add untracked zone quests)", untracked))
    end

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then ns.ZoneFilter.UI.OnStateChanged() end
end

-- ============================================================
-- Apply.Mode(modeName) — generalised "select target set, untrack the
-- rest, promote new ones, save lastApplied" applied for non-zone modes.
-- Shares the same snapshot / drift / revert state machine as
-- Apply.Filter, so the user can revert any mode to the pre-mode state.
--
-- Available modes:
--   untrackAll     — target = ∅; clears the watch list entirely
--   campaignOnly   — target = every campaign quest in the log
--   weekliesOnly   — target = every weekly-frequency quest in the log
--   importantOnly  — target = every quest Blizzard tags as "Important"
--                    (purple-triangle icon; questClassification = Important).
--                    TWW 11.0.2+ API, current in Interface 120005+.
-- ============================================================

local WEEKLY_FREQUENCY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or 2
local DAILY_FREQUENCY  = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Daily)  or 1
local IMPORTANT_CLASS  = (Enum and Enum.QuestClassification and Enum.QuestClassification.Important) or 0

local function QuestIsComplete(questID)
    if C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(questID) and true or false
    end
    return false
end

local function SelectQuestsBy(predicate)
    local set = {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries then return set end
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID then
            if predicate(info) then
                set[info.questID] = true
            end
        end
    end
    return set
end

local PREDICATES = {
    untrackAll     = function(info) return false end,
    trackAll       = function(info) return true  end,
    campaignOnly   = function(info) return info.campaignID ~= nil end,
    dailyOnly      = function(info) return info.frequency == DAILY_FREQUENCY end,
    weekliesOnly   = function(info) return info.frequency == WEEKLY_FREQUENCY end,
    importantOnly  = function(info) return info.questClassification == IMPORTANT_CLASS end,
    readyOnly      = function(info) return QuestIsComplete(info.questID) end,
    inProgressOnly = function(info) return not QuestIsComplete(info.questID) end,
}

local MODE_LABELS = {
    untrackAll     = "untrack-all",
    trackAll       = "track-all",
    campaignOnly   = "campaign-only",
    dailyOnly      = "daily-only",
    weekliesOnly   = "weeklies-only",
    importantOnly  = "important-only",
    readyOnly      = "ready-to-turn-in",
    inProgressOnly = "in-progress",
}

-- Public: how many quests would this mode end up tracking after Apply?
-- Used by the right-click menu to show a `(N)` preview per entry and
-- to flag the "tracker will hide" 0-warning ahead of the click.
function Apply.CountForMode(modeName)
    local predicate = PREDICATES[modeName]
    if not predicate then return 0 end
    local count = 0
    for _ in pairs(SelectQuestsBy(predicate)) do count = count + 1 end
    return count
end

-- Public: how many quests would the zone-filter operations end up
-- tracking after Apply? `addFromLog == true` mirrors shift-click
-- (narrow + promote); false mirrors plain left-click (narrow only).
function Apply.CountForFilter(addFromLog)
    local State     = ns.ZoneFilter.State
    local Relevance = ns.ZoneFilter.Relevance
    if not State or not Relevance then return 0 end
    if not Relevance.GetCurrentMapID or not Relevance.GetCurrentMapID() then return 0 end
    local relevant = Relevance.GetRelevantQuests()
    local current  = State.GetCurrentWatches()
    local count = 0
    if addFromLog then
        -- Result = all zone-relevant quests in log.
        for _ in pairs(relevant) do count = count + 1 end
    else
        -- Result = current ∩ relevant (narrow only).
        for qid in pairs(current) do
            if relevant[qid] then count = count + 1 end
        end
    end
    return count
end

function Apply.Mode(modeName)
    if InCombatLockdown() then
        notify("cannot change tracker during combat")
        return
    end
    local predicate = PREDICATES[modeName]
    if not predicate then
        notify("unknown mode: " .. tostring(modeName))
        return
    end

    local State   = ns.ZoneFilter.State
    local current = State.GetCurrentWatches()

    -- Same snapshot / drift handling as Apply.Filter — a mode-apply is
    -- conceptually a fresh Filter operation under a different predicate.
    if not State.GetFilterActive() then
        State.SetSnapshot(current)
        State.SetFilterActive(true)
    else
        local last = State.GetLastApplied()
        if last then
            local snap = State.GetSnapshot() or {}
            for qid in pairs(current) do
                if not last[qid] then snap[qid] = true end
            end
            State.SetSnapshot(snap)
        end
    end

    local target = SelectQuestsBy(predicate)

    local untracked, tracked = 0, 0
    for qid in pairs(current) do
        if not target[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            untracked = untracked + 1
        end
    end
    for qid in pairs(target) do
        if not current[qid] then
            C_QuestLog.AddQuestWatch(qid)
            tracked = tracked + 1
        end
    end

    State.SetLastApplied(target)
    State.SetLastMode(modeName)

    notify(string.format("%s: tracked %d, untracked %d",
        MODE_LABELS[modeName] or modeName, tracked, untracked))

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then
        ns.ZoneFilter.UI.OnStateChanged()
    end
end
