-- ZoneFilter/Core/AutoPromote.lua — keep the ACTIVE filter true over time.
--
-- Problem: while a filter is active, a quest matching that filter may
-- appear in the quest log via paths that don't reliably trigger
-- Blizzard's autoQuestWatch — most visibly Void-Assault-style event
-- quests, which the game pushes into the log on first progress without
-- auto-tracking them. And even for normally-accepted quests, a filter
-- like weeklies-only shouldn't flag a freshly-accepted weekly as
-- "drift" the user has to clean up.
--
-- Behaviour: on QUEST_ACCEPTED (which fires for both NPC-accepted and
-- game-pushed quests), if a filter is active and the new quest matches
-- the ACTIVE MODE's predicate (zone-relevance for zoneFilter, weekly
-- frequency for weekliesOnly, etc.), we AddQuestWatch and record it in
-- the target so it counts as filter-intended rather than as drift.
--
-- Idempotency: we only auto-promote when the quest is NOT already
-- watched. So a quest the user manually untracks after acceptance stays
-- untracked — no infinite re-tracking loop.
--
-- We do not modify the snapshot here: a filter re-apply later will fold
-- this quest into the snapshot via the existing drift mechanism if the
-- user manually accepts a new quest that does NOT match the mode
-- (which we ignore here).

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local AutoPromote = {}
ns.ZoneFilter.AutoPromote = AutoPromote

local function TryPromote(questID)
    if not questID then return end
    -- Module gate: this handler is wired at file load, before the
    -- enable flag is known. A disabled ZoneFilter can still have a
    -- stale currentApplication in the per-char SV, so without this
    -- check it would keep auto-promoting.
    if not (ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")) then return end
    local State = ns.ZoneFilter.State
    local Apply = ns.ZoneFilter.Apply
    if not State or not State.GetFilterActive() then return end
    if not Apply or not Apply.QuestMatchesMode then return end

    local mode = State.GetLastMode()
    if not mode then return end

    -- Already in watch list (either by autoQuestWatch firing, or because
    -- the user manually started tracking it before this handler ran).
    -- Nothing to do.
    local current = State.GetCurrentWatches()
    if current[questID] then return end

    local logIdx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIdx then return end
    local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIdx)
    if not info or not Apply.QuestMatchesMode(mode, info) then return end

    C_QuestLog.AddQuestWatch(questID)

    -- Mark as filter-intended so it doesn't register as drift.
    State.ExtendTarget(questID)

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.OnStateChanged then
        ns.ZoneFilter.UI.OnStateChanged()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:SetScript("OnEvent", function(self, event, questID)
    -- Modern retail QUEST_ACCEPTED signature: (questID).
    -- Defer 0.5 s: the quest log info (isOnMap / hasLocalPOI /
    -- classification fields) is populated asynchronously by the client,
    -- so an immediate check can miss a quest that's about to match.
    C_Timer.After(0.5, function() TryPromote(questID) end)
end)
