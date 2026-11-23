-- Apply.lua — the single Apply operation for every tracker mode.
--
-- All modes (zone-filter, campaign-only, weeklies-only, ready-to-turn-in,
-- untrack-all, etc.) are expressed as predicates on QuestInfo rows.
-- Apply.Mode(modeName, opts) walks the quest log with the named
-- predicate, untracks watches that aren't in the target set, optionally
-- promotes target quests not yet watched, and hands the resulting state
-- to State.TransitionToMode.
--
-- Apply.Filter(addFromLog) is sugar: zoneFilter predicate + a guard
-- for the zone map-id (so we can return a clearer message if the
-- player hasn't opened the world map yet) + opts.narrowOnly when
-- addFromLog == false (narrow-only matches plain-click behaviour).
--
-- The state machine — when to snapshot, when to accumulate drift —
-- lives in State.TransitionToMode. This file only worries about the
-- predicate, the diff, and the slash-print.

local addonName, ns = ...
local L = ns.L
ns.ZoneFilter = ns.ZoneFilter or {}
local Apply = {}
ns.ZoneFilter.Apply = Apply

local function notify(msg)
    print("|cffffcc00QuestFocus|r " .. msg)
end

-- ============================================================
-- Predicates and modes
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

local function ZoneRelevant(info)
    return ns.ZoneFilter.Relevance and ns.ZoneFilter.Relevance.IsQuestInCurrentZone(info)
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
    zoneFilter     = ZoneRelevant,
    untrackAll     = function(info) return false end,
    trackAll       = function(info) return true  end,
    campaignOnly   = function(info) return info.campaignID ~= nil end,
    dailyOnly      = function(info) return info.frequency == DAILY_FREQUENCY end,
    weekliesOnly   = function(info) return info.frequency == WEEKLY_FREQUENCY end,
    importantOnly  = function(info) return info.questClassification == IMPORTANT_CLASS end,
    readyOnly      = function(info) return QuestIsComplete(info.questID) end,
    inProgressOnly = function(info) return not QuestIsComplete(info.questID) end,
}

local MODE_CHAT_KEY = {
    zoneFilter     = "CHAT_MODE_ZONE_FILTER",
    untrackAll     = "CHAT_MODE_UNTRACK_ALL",
    trackAll       = "CHAT_MODE_TRACK_ALL",
    campaignOnly   = "CHAT_MODE_CAMPAIGN",
    dailyOnly      = "CHAT_MODE_DAILY",
    weekliesOnly   = "CHAT_MODE_WEEKLIES",
    importantOnly  = "CHAT_MODE_IMPORTANT",
    readyOnly      = "CHAT_MODE_READY",
    inProgressOnly = "CHAT_MODE_IN_PROGRESS",
}

-- ============================================================
-- Public count helpers — used by the right-click menu's `(N)` preview
-- and by the lens tooltip's resulting-watched line.
-- ============================================================

-- Does this quest-log info row match the named mode's predicate?
-- Used by AutoPromote so a newly-accepted quest that fits the ACTIVE
-- filter gets tracked immediately regardless of which mode is active.
function Apply.QuestMatchesMode(modeName, info)
    local predicate = PREDICATES[modeName]
    if not predicate or not info then return false end
    return predicate(info) and true or false
end

function Apply.CountForMode(modeName)
    local predicate = PREDICATES[modeName]
    if not predicate then return 0 end
    local count = 0
    for _ in pairs(SelectQuestsBy(predicate)) do count = count + 1 end
    return count
end

-- For the zone-filter operations specifically (addFromLog reflects the
-- shift state). Couples to State so it can return the narrow-only
-- count (current ∩ relevant) for plain click.
function Apply.CountForFilter(addFromLog)
    local State = ns.ZoneFilter.State
    if not State or not ZoneRelevant then return 0 end
    if not ns.ZoneFilter.Relevance.GetCurrentMapID
       or not ns.ZoneFilter.Relevance.GetCurrentMapID() then return 0 end
    local relevant = SelectQuestsBy(ZoneRelevant)
    local current  = State.GetCurrentWatches()
    local count = 0
    if addFromLog then
        for _ in pairs(relevant) do count = count + 1 end
    else
        for qid in pairs(current) do
            if relevant[qid] then count = count + 1 end
        end
    end
    return count
end

-- ============================================================
-- The single Apply
-- ============================================================
--
-- opts = {
--     narrowOnly = bool,   -- if true, skip the "promote new targets"
--                          -- step. Used by zoneFilter plain-click.
-- }

function Apply.Mode(modeName, opts)
    opts = opts or {}
    if InCombatLockdown() then
        notify(L.CHAT_CANNOT_CHANGE_COMBAT)
        return
    end
    local predicate = PREDICATES[modeName]
    if not predicate then
        notify(string.format(L.CHAT_UNKNOWN_MODE, tostring(modeName)))
        return
    end

    local State   = ns.ZoneFilter.State
    local current = State.GetCurrentWatches()
    local target  = SelectQuestsBy(predicate)

    -- Our own untracks must not read as manual ones to Hygiene's D1
    -- diff. Suppress through the next frame — QUEST_WATCH_LIST_CHANGED
    -- may be dispatched after this function returns.
    local Hygiene = ns.ZoneFilter.Hygiene
    if Hygiene then
        Hygiene.SetSuppressed(true)
        C_Timer.After(0, function() Hygiene.SetSuppressed(false) end)
    end

    -- Diff: untrack current watches not in target; optionally promote
    -- target quests not currently watched.
    local untracked, tracked = 0, 0
    for qid in pairs(current) do
        if not target[qid] then
            C_QuestLog.RemoveQuestWatch(qid)
            untracked = untracked + 1
        end
    end

    -- Compute the actual post-apply watch list (what lastApplied
    -- should record). For narrowOnly it's current ∩ target; otherwise
    -- it equals the full target set after the promote pass.
    local actualTarget = {}
    for qid in pairs(current) do
        if target[qid] then actualTarget[qid] = true end
    end

    if not opts.narrowOnly then
        for qid in pairs(target) do
            if not current[qid] then
                C_QuestLog.AddQuestWatch(qid)
                tracked = tracked + 1
                actualTarget[qid] = true
            end
        end
    end

    -- Pass the pre-apply watches snapshot — current was captured before
    -- any RemoveQuestWatch / AddQuestWatch calls above mutated the live
    -- list. Without this, TransitionToMode would read the post-apply
    -- watch list and write it as the snapshot (= nothing to restore on
    -- revert).
    State.TransitionToMode(modeName, actualTarget, current)

    notify(L.CHAT_APPLIED:format(L[MODE_CHAT_KEY[modeName]] or modeName, tracked, untracked))

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then
        ns.ZoneFilter.UI.OnStateChanged()
    end
end

-- Apply.Filter — sugar over Apply.Mode("zoneFilter", ...). Adds the
-- map-id guard (specific to the zone-filter use case) and translates
-- the addFromLog shift-flag into opts.narrowOnly.
function Apply.Filter(addFromLog)
    local Relevance = ns.ZoneFilter.Relevance
    if not Relevance or not Relevance.GetCurrentMapID() then
        notify(L.CHAT_NO_ZONE)
        return
    end
    Apply.Mode("zoneFilter", { narrowOnly = not addFromLog })
end
