-- PartySync/UI/Tooltip.lua — Alt-hover detail tooltip on indicator dots.
--
-- Layout (per design §4.3):
--
--   Quest Title
--   ──────────────────────────────────
--   Party state:
--     You                In progress (2/3)
--     PlayerTwo          Ready to turn in
--     PlayerThree        Not on quest
--     PlayerFour         In progress (1/3)
--   Hidden / not-on-quest rows depend on BNet visibility.   (footer; conditional)
--
-- Member names in class colour, state text in state colour. "You" is
-- always first; other members sorted complete → in_progress → not_on_quest.
--
-- Trigger: holding Alt while hovering an indicator. Dismissed by
-- releasing Alt OR moving off the indicator.

local addonName, ns = ...
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local Tooltip = {}
ns.PartySync.UI.Tooltip = Tooltip

-- Track the currently-hovered indicator so the MODIFIER_STATE_CHANGED
-- handler can resolve "the user just pressed Alt while hovering" → show.
local hovered = nil

local STATE_RANK = {
    complete     = 1,
    in_progress  = 2,
    not_on_quest = 3,
    no_data      = 4,
}

local function ClassColor(class)
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

local function StateColor(state)
    if state == "complete"     then return 0.40, 1.00, 0.40 end  -- green
    if state == "in_progress"  then return 1.00, 1.00, 1.00 end  -- white
    if state == "not_on_quest" then return 0.55, 0.55, 0.55 end  -- grey
    return 0.55, 0.55, 0.55
end

local function FormatState(state, player)
    if state == "complete"    then return "Ready to turn in" end
    if state == "not_on_quest" then return "Not on quest"     end
    if state == "in_progress" then
        local done, total = 0, 0
        if player and player.objectives then
            for _, obj in ipairs(player.objectives) do
                total = total + 1
                if obj.completed then done = done + 1 end
            end
        end
        if total > 0 then
            return string.format("In progress (%d/%d)", done, total)
        end
        return "In progress"
    end
    return "—"
end

-- Find a class string for a GUID by walking the group roster. Cheap
-- enough at hover time (we don't do this on every tracker update).
local function ClassForGUID(targetGUID)
    if not targetGUID then return nil end
    if UnitGUID("player") == targetGUID then
        return select(2, UnitClass("player"))
    end
    if not IsInGroup() then return nil end
    local n = GetNumGroupMembers() or 0
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, n do
        local unit = prefix .. i
        if UnitGUID(unit) == targetGUID then
            return select(2, UnitClass(unit))
        end
    end
end

local function AppendMemberRow(name, class, state, player)
    local cr, cg, cb = ClassColor(class)
    local sr, sg, sb = StateColor(state)
    GameTooltip:AddDoubleLine(
        name or "?",
        FormatState(state, player),
        cr, cg, cb,
        sr, sg, sb)
end

function Tooltip.Show(owner, questID)
    if not questID then return end
    local Fetch = ns.PartySync.Fetch
    if not Fetch then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local title = (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)) or "?"
    GameTooltip:SetText(title, 1, 0.82, 0, 1)

    GameTooltip:AddLine("Party state:", 0.82, 0.82, 0.82)

    -- "You" row first
    local selfData = Fetch.GetSelfProgress(questID)
    local anyNotOnQuest = false
    if selfData then
        local state = Fetch.GetPlayerStateForQuest(selfData)
        AppendMemberRow("You", select(2, UnitClass("player")), state, selfData)
    end

    -- Partymate rows, sorted by state then name
    local progress = Fetch.GetPartyProgress(questID)
    local rows = {}
    for guid, player in pairs(progress) do
        local state = Fetch.GetPlayerStateForQuest(player)
        if state == "not_on_quest" then anyNotOnQuest = true end
        rows[#rows+1] = {
            guid   = guid,
            name   = player.name,
            state  = state,
            player = player,
        }
    end
    table.sort(rows, function(a, b)
        local ra, rb = STATE_RANK[a.state] or 99, STATE_RANK[b.state] or 99
        if ra ~= rb then return ra < rb end
        return (a.name or "") < (b.name or "")
    end)
    for _, row in ipairs(rows) do
        AppendMemberRow(row.name, ClassForGUID(row.guid), row.state, row.player)
    end

    -- BNet visibility footer (only when relevant — keeps clean rows clean)
    if anyNotOnQuest then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hidden / not-on-quest rows depend on BNet visibility.",
            0.55, 0.55, 0.55, true)
    end

    GameTooltip:Show()
end

local function ShowFor(indicator)
    if not indicator or not indicator.qfQuestID then return end
    Tooltip.Show(indicator, indicator.qfQuestID)
end

local function HideIfOwn(indicator)
    if GameTooltip:GetOwner() == indicator then GameTooltip:Hide() end
end

local function OnEnter(self)
    hovered = self
    if IsAltKeyDown() then ShowFor(self) end
end

local function OnLeave(self)
    if hovered == self then hovered = nil end
    HideIfOwn(self)
end

-- Attach (or update) the OnEnter/OnLeave handlers to an indicator and
-- record the questID it currently represents. Idempotent: only sets
-- handlers once per frame; updates the questID every call.
function Tooltip.Attach(indicator, questID)
    if not indicator then return end
    indicator.qfQuestID = questID
    if indicator.qfTooltipAttached then return end
    indicator.qfTooltipAttached = true
    indicator:EnableMouse(true)
    indicator:SetScript("OnEnter", OnEnter)
    indicator:SetScript("OnLeave", OnLeave)
end

-- Module-level: show/hide based on Alt-key transitions while hovered.
local modWatch = CreateFrame("Frame")
modWatch:RegisterEvent("MODIFIER_STATE_CHANGED")
modWatch:SetScript("OnEvent", function(self, event, key, state)
    if key ~= "LALT" and key ~= "RALT" then return end
    if not hovered then return end
    if state == 1 then
        ShowFor(hovered)
    else
        HideIfOwn(hovered)
    end
end)

-- ============================================================
-- Test slash command (removed in slice 10).
-- /qftooltiptest [questID] — places a free-standing green dot at
-- screen-centre and attaches the tooltip with the given (or first
-- watched) questID. Works solo — the "You" row renders from local
-- C_QuestLog data; partymate rows only appear if you're actually in a
-- party. Use to validate the self-row layout / colours / formatting.
-- ============================================================

local testFrame
SLASH_QFTOOLTIPTEST1 = "/qftooltiptest"
SlashCmdList.QFTOOLTIPTEST = function(msg)
    local arg = (msg or ""):match("^%s*(%S+)%s*$")
    local qid = tonumber(arg)
    if not qid then
        if (C_QuestLog.GetNumQuestWatches() or 0) == 0 then
            print("|cffffcc00QF tooltip test|r no watched quests; pass /qftooltiptest <questID>")
            return
        end
        qid = C_QuestLog.GetQuestIDForQuestWatchIndex(1)
    end
    if not qid then
        print("|cffffcc00QF tooltip test|r could not resolve quest ID")
        return
    end

    local Indicator = ns.PartySync.UI.Indicator
    if testFrame then
        Indicator.Release(testFrame)
        testFrame = nil
    end
    testFrame = Indicator.Acquire()
    testFrame:SetSize(14, 14)  -- larger than production so it's easy to hover
    testFrame:ClearAllPoints()
    testFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    Indicator.SetState(testFrame, "aligned")  -- green
    Tooltip.Attach(testFrame, qid)
    print(string.format("|cffffcc00QF tooltip test|r dot placed above screen-centre, qid=%d. Hold |cffffff88Alt|r and hover it.",
        qid))
end

SLASH_QFTOOLTIPCLEAR1 = "/qftooltipclear"
SlashCmdList.QFTOOLTIPCLEAR = function()
    if testFrame then
        ns.PartySync.UI.Indicator.Release(testFrame)
        testFrame = nil
        print("|cffffcc00QF tooltip test|r cleared")
    end
end
