-- ZoneFilter/Core/AutoPromote.lua — keep the filter coherent over time.
--
-- Problem: while filter is active, a zone-relevant quest may appear in
-- the quest log via paths that don't reliably trigger Blizzard's
-- autoQuestWatch — most visibly Void-Assault-style event quests, which
-- the game pushes into the log on first progress without auto-tracking
-- them. Result: a quest the filter would have promoted is silently
-- absent from the watch list.
--
-- Behaviour: on QUEST_ACCEPTED (which fires for both NPC-accepted and
-- game-pushed quests), if the filter is active and the new quest is
-- zone-relevant, we AddQuestWatch and record it in lastApplied so it
-- counts as filter-intended rather than as drift.
--
-- Idempotency: we only auto-promote when the quest is NOT already
-- watched. So a quest the user manually untracks after acceptance stays
-- untracked — no infinite re-tracking loop.
--
-- We do not modify the snapshot here: a filter re-apply later will fold
-- this quest into the snapshot via the existing drift mechanism if the
-- user manually accepts a new quest that's NOT zone-relevant (which we
-- ignore here).

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local AutoPromote = {}
ns.ZoneFilter.AutoPromote = AutoPromote

local function TryPromote(questID)
    if not questID then return end
    local State     = ns.ZoneFilter.State
    local Relevance = ns.ZoneFilter.Relevance
    if not State or not State.GetFilterActive() then return end
    if not Relevance or not Relevance.IsQuestInCurrentZone then return end

    -- Already in watch list (either by autoQuestWatch firing, or because
    -- the user manually started tracking it before this handler ran).
    -- Nothing to do.
    local current = State.GetCurrentWatches()
    if current[questID] then return end

    local logIdx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIdx then return end
    local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIdx)
    if not info or not Relevance.IsQuestInCurrentZone(info) then return end

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
    -- Defer one frame: the quest log info (isOnMap / hasLocalPOI) is
    -- populated asynchronously by the client, so an immediate check can
    -- miss a quest that's about to be flagged zone-relevant.
    C_Timer.After(0.5, function() TryPromote(questID) end)
end)
