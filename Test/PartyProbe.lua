-- PartyProbe.lua — throwaway test module.
-- Captures `C_TooltipInfo.GetQuestPartyProgress(questID)` output for every
-- watched quest into `QuestFocusDB.partyProbe`, so the structure can be
-- inspected off-disk after a /reload.
--
-- Remove this file and its TOC entry once the API behaviour is understood.

local addonName, ns = ...

local function CaptureParty()
    local n = GetNumGroupMembers() or 0
    local list = {}
    for i = 1, n do
        local unit = (IsInRaid() and "raid"..i) or (i == n and "player" or "party"..i)
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        local guid = UnitGUID(unit)
        list[#list+1] = { unit = unit, name = name, class = class, guid = guid }
    end
    return { count = n, inGroup = IsInGroup(), inRaid = IsInRaid(), members = list }
end

-- Count the player headers (type 18) and objective rows (type 8) for a given
-- TooltipData payload — used both to populate the per-entry summary and to
-- compute the global overlap count for the chat print.
local function CountLines(data)
    local players, objs = 0, 0
    if data and data.lines then
        for _, ln in ipairs(data.lines) do
            if ln.type == 18 then players = players + 1
            elseif ln.type == 8 then objs = objs + 1 end
        end
    end
    return players, objs
end

local function CaptureQuestEntry(questID, source)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or nil
    local entry = {
        questID = questID,
        title = title,
        source = source,            -- "watch" or "log"
        isOnMap = nil,
        isComplete = C_QuestLog.IsComplete and C_QuestLog.IsComplete(questID) or nil,
    }
    -- isOnMap from log info
    local logIdx = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    if logIdx then
        local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(logIdx)
        if info then
            entry.isOnMap = info.isOnMap
            entry.hasLocalPOI = info.hasLocalPOI
            entry.isHeader = info.isHeader
        end
    end

    -- Three variants of GetQuestPartyProgress so we can see what the flags do
    local ok1, data1 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID)
    local ok2, data2 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID, true)        -- omitTitle
    local ok3, data3 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID, false, true) -- ignoreActivePlayer

    entry.default               = { ok = ok1, data = data1 }
    entry.omitTitle             = { ok = ok2, data = data2 }
    entry.ignoreActivePlayer    = { ok = ok3, data = data3 }

    -- Compact summary derived from ignoreActivePlayer — this is the "real
    -- party overlap" signal, since active-player rows are suppressed.
    local players, objs = CountLines(data3)
    entry.summary = {
        otherPlayersWithObjectives = players,
        otherObjectiveRows = objs,
        hasOverlap = players > 0,
    }
    return entry
end

local function Probe(silent)
    QuestFocusDB = QuestFocusDB or {}
    local snapshot = {
        timestamp = time(),
        timestampISO = date("%Y-%m-%dT%H:%M:%S"),
        realm = GetRealmName(),
        playerName = UnitName("player"),
        zone = GetZoneText(),
        party = CaptureParty(),
        entries = {},
    }

    -- Capture both watched quests and the full quest log so we can see whether
    -- the API also returns data for accepted-but-unwatched quests.
    local seen = {}

    local numWatches = C_QuestLog.GetNumQuestWatches() or 0
    for i = 1, numWatches do
        local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if qid and not seen[qid] then
            seen[qid] = true
            snapshot.entries[#snapshot.entries+1] = CaptureQuestEntry(qid, "watch")
        end
    end

    local numLog = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, numLog do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader and not seen[info.questID] then
            seen[info.questID] = true
            snapshot.entries[#snapshot.entries+1] = CaptureQuestEntry(info.questID, "log")
        end
    end

    -- Roll up counts for the print summary.
    local nWatched, nLogOnly, nOverlap = 0, 0, 0
    for _, e in ipairs(snapshot.entries) do
        if e.source == "watch" then nWatched = nWatched + 1
        else nLogOnly = nLogOnly + 1 end
        if e.summary and e.summary.hasOverlap then nOverlap = nOverlap + 1 end
    end
    snapshot.summary = {
        watchedCount = nWatched,
        logOnlyCount = nLogOnly,
        partyOverlapCount = nOverlap,
        partyMemberCount = snapshot.party.count,
    }

    QuestFocusDB.partyProbe = snapshot
    QuestFocusDB.partyProbe._silent = silent
    if not silent then
        print(string.format("|cffffcc00QuestFocus probe|r: %d watched + %d log-only quests; %d/%d show party overlap; group=%d members. /reload to flush.",
            nWatched, nLogOnly, nOverlap, nWatched + nLogOnly, snapshot.party.count))
    end
end

SLASH_QUESTFOCUSPROBE1 = "/qfprobe"
SlashCmdList.QUESTFOCUSPROBE = function() Probe(false) end

-- ============================================================
-- Passive in-session harvesting.
-- ============================================================
--
-- Quest IDs aren't useful across sessions (the player may have turned
-- them in by next login), so we keep the SV snapshot perpetually fresh:
--
--   * Re-probe ~30s after PLAYER_ENTERING_WORLD if in a party.
--   * Re-probe on UNIT_QUEST_LOG_CHANGED for a partymate (their state
--     changed → fresh data worth capturing). Throttled to 1/min.
--   * Background ticker every 5 min while in a party.
--
-- All silent (no chat print) so we don't spam the user during play.
-- Manual /qfprobe still prints normally.

local last = 0
local THROTTLE_SECS = 60

local function MaybeProbe(reason)
    if not IsInGroup() then return end
    local now = GetTime()
    if now - last < THROTTLE_SECS then return end
    last = now
    Probe(true)  -- silent
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
boot:RegisterEvent("GROUP_ROSTER_UPDATE")
boot:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, function()
            if IsInGroup() then
                last = GetTime()
                Probe(true)
            else
                print("|cffffcc00QuestFocus probe|r: solo on load — skipping auto-probe. /qfprobe to force.")
            end
        end)
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        if type(unit) == "string" and unit:match("^party") then
            MaybeProbe("party-quest-update")
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        MaybeProbe("roster-update")
    end
end)

-- 5-minute background ticker as ultimate safety net.
C_Timer.NewTicker(300, function() MaybeProbe("ticker") end)
