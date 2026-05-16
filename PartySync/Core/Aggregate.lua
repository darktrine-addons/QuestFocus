-- PartySync/Core/Aggregate.lua — per-quest state derivation.
--
-- Implements the four-state ladder from design/QuestFocusParty.md §5.3:
--
--   "ready_turn_in"   — at least one partymate has the quest complete
--                       and not yet turned in (priority 1, blue dot)
--   "alone_shareable" — caller has it, no partymate does, and at least
--                       one partymate is in the same zone (priority 2,
--                       orange dot)
--   "mixed"           — some partymates have it, some don't (priority 3,
--                       yellow dot)
--   "aligned"         — every partymate is on the quest, no one ready
--                       (priority 4, green dot)
--   nil               — caller doesn't have the quest, or none of the
--                       priorities apply (hidden / no indicator)
--
-- Pure function: no events, no side effects. Callers (the indicator
-- mount in slice 6, the Alt-tooltip in slice 7) invoke this on
-- recompute triggers and react to the returned enum.
--
-- BNet visibility caveat (design §0.2): partymates hidden from the
-- caller via BNet "appear offline" register as state=not_on_quest in
-- Fetch's output. Aggregate treats them as `members_without`, which
-- means the `alone_shareable` state can fire when a hidden partymate
-- actually has the quest. We surface this in the README + tooltips —
-- accepted UX cost.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}
local Aggregate = {}
ns.PartySync.Aggregate = Aggregate

-- Returns { [guid] = unit, ... } for every party member except the caller.
-- Empty when solo.
local function GetPartymateUnits()
    local units = {}
    if not IsInGroup() then return units end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() or 0 do
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            if guid and not UnitIsUnit(unit, "player") then
                units[guid] = unit
            end
        end
    else
        -- party1..party(N-1) for a non-raid group of N (player is implicit).
        for i = 1, (GetNumGroupMembers() or 0) - 1 do
            local unit = "party" .. i
            local guid = UnitGUID(unit)
            if guid then units[guid] = unit end
        end
    end
    return units
end

-- Quest types where party-state has no meaningful semantics — account-
-- wide warband quests and bonus-objective tasks. Extend this list as
-- additional non-shareable types surface in real play. Permissive by
-- default: only DECLINE for known-non-shareable types.
local function IsShareableQuestType(info)
    if not info then return true end
    if info.isAccountQuest then return false end
    if info.isTask         then return false end
    return true
end

-- Main entry point. Returns one of the five values listed at the top
-- of this file. See §5.3 of the design doc for the priority logic.
function Aggregate.Compute(questID)
    if not questID then return nil end

    -- Caller must have the quest in their log; nothing to aggregate otherwise.
    local logIdx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if not logIdx then return nil end

    -- D4: non-shareable quest types get no indicator at all.
    local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIdx)
    if not IsShareableQuestType(info) then return nil end

    -- Solo → no aggregation.
    if not IsInGroup() then return nil end

    local Fetch = ns.PartySync.Fetch
    if not Fetch or not Fetch.GetPartyProgress then return nil end

    local partymateUnits = GetPartymateUnits()
    local progress       = Fetch.GetPartyProgress(questID)
    local callerMap      = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")

    local membersWith, membersWithout, readyToTurnIn = 0, 0, 0
    local anyWithoutInZone = false

    -- Iterate all partymates we can name (not just those Fetch returned
    -- a player block for — though in practice the API returns a block
    -- for every named partymate, with grey "Not on quest" rows for ones
    -- it can't see into).
    for guid, unit in pairs(partymateUnits) do
        local player = progress[guid]
        local state  = player and Fetch.GetPlayerStateForQuest(player) or "no_data"

        if state == "complete" then
            membersWith   = membersWith + 1
            readyToTurnIn = readyToTurnIn + 1
        elseif state == "in_progress" then
            membersWith = membersWith + 1
        else
            -- not_on_quest, no_data → counted as "without"
            membersWithout = membersWithout + 1
            if not anyWithoutInZone and callerMap then
                local theirMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit(unit)
                if theirMap and theirMap == callerMap then
                    anyWithoutInZone = true
                end
            end
        end
    end

    -- Priority ladder.
    if readyToTurnIn > 0                            then return "ready_turn_in"   end
    if membersWith == 0 and anyWithoutInZone        then return "alone_shareable" end
    if membersWith > 0 and membersWithout > 0       then return "mixed"           end
    if membersWith > 0 and membersWithout == 0      then return "aligned"         end
    return nil
end

-- Convenience for debug output / tooltip rendering.
function Aggregate.Describe(state)
    if state == "ready_turn_in"   then return "blue: a partymate is ready to turn in"     end
    if state == "alone_shareable" then return "orange: only you have it, a partymate is nearby" end
    if state == "mixed"           then return "yellow: some partymates on the quest, some not" end
    if state == "aligned"         then return "green: every partymate is on the quest"        end
    return "hidden"
end
