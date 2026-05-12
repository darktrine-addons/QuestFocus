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

local function CaptureQuestEntry(questID)
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or nil
    local entry = {
        questID = questID,
        title = title,
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
        end
    end

    -- Three variants of GetQuestPartyProgress so we can see what the flags do
    local ok1, data1 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID)
    local ok2, data2 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID, true)        -- omitTitle
    local ok3, data3 = pcall(C_TooltipInfo.GetQuestPartyProgress, questID, false, true) -- ignoreActivePlayer

    entry.default               = { ok = ok1, data = data1 }
    entry.omitTitle             = { ok = ok2, data = data2 }
    entry.ignoreActivePlayer    = { ok = ok3, data = data3 }
    return entry
end

local function Probe()
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
    local numWatches = C_QuestLog.GetNumQuestWatches() or 0
    for i = 1, numWatches do
        local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if qid then
            snapshot.entries[#snapshot.entries+1] = CaptureQuestEntry(qid)
        end
    end
    QuestFocusDB.partyProbe = snapshot
    print(string.format("|cffffcc00QuestFocus probe|r: dumped %d watched quest(s), party=%d. /reload to flush SV to disk.",
        #snapshot.entries, snapshot.party.count))
end

SLASH_QUESTFOCUSPROBE1 = "/qfprobe"
SlashCmdList.QUESTFOCUSPROBE = function() Probe() end

-- Auto-probe shortly after entering world, so a /reload-then-paste workflow
-- captures something even if the user forgets to type /qfprobe.
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function(self)
    C_Timer.After(5, Probe)
end)
