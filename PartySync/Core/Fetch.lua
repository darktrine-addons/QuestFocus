-- PartySync/Core/Fetch.lua — query Blizzard's native party-progress tooltip
-- data and parse it into a structured table.
--
-- Single load-bearing primitive for the module. Everything downstream
-- (Aggregate.Compute, the tracker indicator, the Alt-tooltip) consumes
-- the output of `Fetch.GetPartyProgress(questID)`.
--
-- Empirical TooltipData schema (confirmed by Test/PartyProbe.lua dump,
-- 2026-05-13; see design/QuestFocusParty.md §0.1):
--
--   data.lines is a flat array. Each line has a `type`:
--     17  quest title row
--     18  per-player header (leftText = name, guid populated)
--     8   objective row (leftText, completed, numFulfilled, numRequired)
--
--   Lines are ordered as: [title] [player1-header] [player1-obj×N]
--                         [player2-header] [player2-obj×N] ...
--
--   When the caller has a quest a partymate doesn't, the partymate still
--   gets a type-18 header followed by a single type-8 row whose leftText
--   begins with `|cff7f7f7f` (grey) — typically "|cff7f7f7fNot on quest|r".
--
-- BNet visibility gate (see design §0.2): the API returns the same
-- "Not on quest" row when the partymate is BNet-hidden from the caller,
-- even when they actually have the quest. We can't distinguish the two
-- cases from the data — both are reported as `state = "not_on_quest"`.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}
local Fetch = {}
ns.PartySync.Fetch = Fetch

local LINE_TITLE      = 17
local LINE_PLAYER     = 18
local LINE_OBJECTIVE  = 8

local GREY_COLOUR_PREFIX = "|cff7f7f7f"

local function isNotOnQuest(text)
    if not text then return false end
    return text:sub(1, #GREY_COLOUR_PREFIX) == GREY_COLOUR_PREFIX
end

-- Returns: { [guid] = { name, guid, objectives = { {text, completed,
--                       numFulfilled, numRequired, notOnQuest}, ... } }, ... }
--
-- Returns an empty table for: solo player, nil questID, unsupported
-- quest types, or any case where the API returns nothing.
function Fetch.GetPartyProgress(questID)
    local result = {}
    if not questID then return result end
    if not C_TooltipInfo or not C_TooltipInfo.GetQuestPartyProgress then return result end

    -- omitTitle=true: caller knows the title, no point parsing it again.
    -- ignoreActivePlayer=true: drop caller's own rows — we only want partymates.
    local data = C_TooltipInfo.GetQuestPartyProgress(questID, true, true)
    if not data or not data.lines then return result end

    local current
    for _, line in ipairs(data.lines) do
        if line.type == LINE_PLAYER then
            current = {
                name       = line.leftText,
                guid       = line.guid,
                objectives = {},
            }
            -- guid is the stable key; fall back to name if absent (shouldn't
            -- happen on retail, but defensive against future schema drift).
            result[line.guid or line.leftText] = current
        elseif line.type == LINE_OBJECTIVE and current then
            current.objectives[#current.objectives+1] = {
                text         = line.leftText,
                completed    = line.completed,
                numFulfilled = line.numFulfilled,
                numRequired  = line.numRequired,
                notOnQuest   = isNotOnQuest(line.leftText),
            }
        end
        -- type 17 (title) suppressed by omitTitle; ignored if present.
    end
    return result
end

-- Per-player state derivation: roll up that player's objectives into one of
--   "complete"     — all objectives done (ready-to-turn-in for them)
--   "in_progress"  — has the quest, some progress / no progress
--   "not_on_quest" — has the marker indicating they don't have it
--   "no_data"      — empty objectives table (degenerate)
function Fetch.GetPlayerStateForQuest(player)
    if not player or not player.objectives or #player.objectives == 0 then
        return "no_data"
    end
    local allNotOnQuest = true
    local allComplete   = true
    for _, obj in ipairs(player.objectives) do
        if not obj.notOnQuest then allNotOnQuest = false end
        if not obj.completed  then allComplete   = false end
    end
    if allNotOnQuest then return "not_on_quest" end
    if allComplete   then return "complete"     end
    return "in_progress"
end

-- ============================================================
-- Test slash command: /qfprobe2 [questID]
-- Prints the parsed Fetch result for the given questID (or the first
-- watched quest if omitted). Removed in slice 10 alongside Test/.
-- ============================================================

SLASH_QFPROBE21 = "/qfprobe2"
SlashCmdList.QFPROBE2 = function(msg)
    if ns.Config and not ns.Config.IsModuleEnabled("PartySync") then
        print("|cffffcc00QF probe|r PartySync is disabled — /qf module enable PartySync")
        return
    end

    local arg = (msg or ""):match("^%s*(%S+)%s*$")
    local qid = tonumber(arg)
    if not qid then
        if (C_QuestLog.GetNumQuestWatches() or 0) == 0 then
            print("|cffffcc00QF probe|r no watched quests; pass /qfprobe2 <questID>")
            return
        end
        qid = C_QuestLog.GetQuestIDForQuestWatchIndex(1)
    end
    if not qid then
        print("|cffffcc00QF probe|r could not resolve quest ID")
        return
    end

    local title = (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or "?"
    local result = Fetch.GetPartyProgress(qid)
    print(string.format("|cffffcc00QF probe|r qid=%d |cffaaaaaa(%s)|r", qid, title))

    local Aggregate = ns.PartySync.Aggregate
    if Aggregate and Aggregate.Compute then
        local agg = Aggregate.Compute(qid)
        print(string.format("  |cffaaaaaaaggregate:|r %s |cffaaaaaa(%s)|r",
            tostring(agg), Aggregate.Describe(agg)))
    end

    local count = 0
    for _, player in pairs(result) do
        count = count + 1
        local state = Fetch.GetPlayerStateForQuest(player)
        print(string.format("  %s  |cffaaaaaastate=|r%s, |cffaaaaaaobjs=|r%d",
            tostring(player.name), state, #player.objectives))
        for i, obj in ipairs(player.objectives) do
            local check = obj.completed and "|cff44ff44[x]|r" or "|cffaaaaaa[ ]|r"
            local notOn = obj.notOnQuest and " |cffff7777(NOT ON QUEST)|r" or ""
            print(string.format("    %s %s%s", check, tostring(obj.text), notOn))
        end
    end
    if count == 0 then
        print("  |cffaaaaaa(no party data — solo, or unsupported quest)|r")
    end
end
