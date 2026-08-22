-- PartySync/UI/Tooltip.lua — append party-state lines to Blizzard's own
-- objective-tracker row tooltips.
--
-- We don't show our own tooltip. Instead we hook GameTooltip:OnShow,
-- detect whether the tooltip's owner is one of our tracked tracker
-- blocks (via MountTracker.GetQuestIDForBlock), and append our party
-- section to the existing tooltip. The indicator dots themselves are
-- click-through (EnableMouse(false)) so hovering them doesn't suppress
-- the row's underlying tooltip.
--
-- Taint posture:
--   - GameTooltip:HookScript("OnShow", ...) is the supported addon hook
--     mechanism. It does NOT write a custom field onto the Blizzard
--     frame; it registers an additional handler.
--   - GameTooltip:AddLine / :AddDoubleLine are public APIs.
--   - No custom field writes on Blizzard frames anywhere in this file.
--
-- Layout (appended after Blizzard's lines, only when in party):
--
--   [Blizzard's quest description + objective lines]
--
--   Party state:
--     You           In progress (2/3)
--     PlayerTwo     Ready to turn in
--     PlayerThree   Not on quest
--   Hidden / not-on-quest rows depend on BNet visibility.   (footer when relevant)

local addonName, ns = ...
local L = ns.L
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local Tooltip = {}
ns.PartySync.UI.Tooltip = Tooltip

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
    if state == "complete"     then return 0.40, 1.00, 0.40 end
    if state == "in_progress"  then return 1.00, 1.00, 1.00 end
    if state == "not_on_quest" then return 0.55, 0.55, 0.55 end
    return 0.55, 0.55, 0.55
end

local function FormatState(state, player)
    if state == "complete"     then return L.PARTY_READY_TO_TURN_IN end
    if state == "not_on_quest" then return L.PARTY_NOT_ON_QUEST     end
    if state == "in_progress"  then
        local done, total = 0, 0
        if player and player.objectives then
            for _, obj in ipairs(player.objectives) do
                total = total + 1
                if obj.completed then done = done + 1 end
            end
        end
        if total > 0 then return string.format(L.PARTY_IN_PROGRESS_COUNT, done, total) end
        return L.PARTY_IN_PROGRESS
    end
    return "—"
end

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

local function AppendMemberRow(tooltip, name, class, state, player)
    local cr, cg, cb = ClassColor(class)
    local sr, sg, sb = StateColor(state)
    tooltip:AddDoubleLine(
        name or "?",
        FormatState(state, player),
        cr, cg, cb,
        sr, sg, sb)
end

-- One-line rollup for large groups: counts instead of the per-member
-- list. The raid organiser's question is "how many still need this?",
-- so suppressing entirely (the old D5 behaviour) threw away the most
-- useful number right when groups get big.
local function AppendSummary(tooltip, questID)
    local Fetch = ns.PartySync.Fetch
    local progress = Fetch.GetPartyProgress(questID)
    local onQuest, ready, notOn = 0, 0, 0
    for _, player in pairs(progress) do
        local state = Fetch.GetPlayerStateForQuest(player)
        if state == "complete" then
            onQuest = onQuest + 1; ready = ready + 1
        elseif state == "in_progress" then
            onQuest = onQuest + 1
        else
            notOn = notOn + 1
        end
    end
    if onQuest + notOn == 0 then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(string.format(L.PARTY_SUMMARY,
        onQuest, ready, notOn), 0.82, 0.82, 0.82)
    tooltip:Show()
end

-- Append our party section to `tooltip` for the given questID. No-op
-- when solo or PartySync inactive. When the group size meets the D5
-- threshold, the per-member list is replaced by a one-line summary.
function Tooltip.AppendForQuest(tooltip, questID)
    if ns.PartySync.active == false then return end
    if not questID or not IsInGroup() then return end
    local Fetch = ns.PartySync.Fetch
    if not Fetch then return end

    -- D5: summarize in large groups (configurable threshold).
    local threshold = (ns.Config and ns.Config.GetPartySyncSetting
                       and ns.Config.GetPartySyncSetting("raidThreshold")) or 0
    if threshold > 0 and (GetNumGroupMembers() or 0) >= threshold then
        AppendSummary(tooltip, questID)
        return
    end

    tooltip:AddLine(" ")
    tooltip:AddLine(L.PARTY_STATE, 0.82, 0.82, 0.82)

    -- "You" row first
    local selfData = Fetch.GetSelfProgress(questID)
    local anyNotOnQuest = false
    if selfData then
        local state = Fetch.GetPlayerStateForQuest(selfData)
        AppendMemberRow(tooltip, L.PARTY_YOU, select(2, UnitClass("player")), state, selfData)
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
        AppendMemberRow(tooltip, row.name, ClassForGUID(row.guid), row.state, row.player)
    end

    -- Dot legend — the one place the colour language is explained at
    -- the moment the user actually meets a dot. Swatches read the live
    -- palette so they stay correct for colour-vision palettes too.
    local Indicator = ns.PartySync.UI and ns.PartySync.UI.Indicator
    if Indicator and Indicator.GetStateColor then
        local function swatch(state, label)
            local c = Indicator.GetStateColor(state)
            if not c then return label end
            return string.format("|cff%02x%02x%02x●|r %s",
                c[1] * 255 + 0.5, c[2] * 255 + 0.5, c[3] * 255 + 0.5, label)
        end
        tooltip:AddLine(string.format(L.PARTY_DOT_LEGEND,
            swatch("ready_turn_in",   L.PARTY_DOT_READY),
            swatch("alone_shareable", L.PARTY_DOT_SHARE),
            swatch("mixed",           L.PARTY_DOT_MIXED),
            swatch("aligned",         L.PARTY_DOT_ALIGNED)), 0.55, 0.55, 0.55)
    end

    -- BNet visibility footer (only when relevant)
    if anyNotOnQuest then
        tooltip:AddLine(" ")
        tooltip:AddLine(L.PARTY_VISIBILITY_FOOTER,
            0.55, 0.55, 0.55, true)
    end

    tooltip:Show()  -- recompute size after the new lines
end

-- Hook: whenever GameTooltip becomes visible, check whether its owner is
-- one of our tracked tracker blocks. If so, append the party section.
-- Early-return for any other tooltip use, so the overhead is one
-- side-table walk per tooltip show.
GameTooltip:HookScript("OnShow", function(self)
    local MountTracker = ns.PartySync.UI and ns.PartySync.UI.MountTracker
    if not MountTracker or not MountTracker.GetQuestIDForBlock then return end
    local owner = self:GetOwner()
    if not owner then return end
    local qid = MountTracker.GetQuestIDForBlock(owner)
    if qid then
        Tooltip.AppendForQuest(self, qid)
    end
end)
