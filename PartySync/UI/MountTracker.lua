-- PartySync/UI/MountTracker.lua — anchor indicator dots to live quest
-- tracker rows, keyed on questID.
--
-- Approach (per slice plan, option "hook + walk"):
--   1. hooksecurefunc(QuestObjectiveTracker, "Update", refresh) — passive
--      observer that runs after Blizzard finishes rebuilding usedBlocks.
--   2. Event registrations as a safety net (events sometimes fire before
--      the tracker's own Update; we use C_Timer.After(0, refresh) to wait
--      one frame so usedBlocks is current when we walk it).
--   3. 3-second ticker (only while in a party) as the ultimate safety net.
--
-- Taint posture (per memory `wow_blizzard_frame_field_write_taint`):
--   - We never write a custom field onto a tracker block.
--   - Indicator frames are addon-owned (`CreateFrame` parented to the block
--     for visibility-inheritance only); release re-parents to UIParent.
--   - `block.id` / `block.HeaderText` are READ, never written.
--   - The side-table `indicators[questID] = frame` lives in this file's
--     upvalues, not on Blizzard objects.

local addonName, ns = ...
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local MountTracker = {}
ns.PartySync.UI.MountTracker = MountTracker

local indicators = {}   -- { [questID] = indicatorFrame }
local mounted    = false

local function GetQuestModule()
    return QuestObjectiveTracker
end

-- Walks the live tracker. Returns { [questID] = block }.
--
-- Schema (TWW Midnight, Interface 120005, confirmed by in-game probe
-- 2026-05-14): QuestObjectiveTracker.usedBlocks is two-level:
--
--   usedBlocks = {
--       [templateName] = {       -- e.g. "ObjectiveTrackerQuestPOIBlockTemplate"
--           [questID] = block,
--           ...
--       },
--       ...
--   }
--
-- We flatten across all templates. The questID is the inner key directly,
-- so no block.id heuristic is needed.
local function VisibleQuestBlocks()
    local result = {}
    local module = GetQuestModule()
    if not module or not module.usedBlocks then return result end
    for _, inner in pairs(module.usedBlocks) do
        if type(inner) == "table" then
            for qid, block in pairs(inner) do
                if type(qid) == "number" and block then
                    result[qid] = block
                end
            end
        end
    end
    return result
end

local function ReleaseAll()
    local Indicator = ns.PartySync.UI.Indicator
    for qid, f in pairs(indicators) do
        Indicator.Release(f)
        indicators[qid] = nil
    end
end

local function Refresh()
    local Indicator = ns.PartySync.UI.Indicator
    local Aggregate = ns.PartySync.Aggregate
    if not Indicator or not Aggregate then return end

    -- Solo → release everything and bail.
    if not IsInGroup() then
        ReleaseAll()
        return
    end

    local visible = VisibleQuestBlocks()

    -- Release indicators for quests that have left the tracker.
    for qid, f in pairs(indicators) do
        if not visible[qid] then
            Indicator.Release(f)
            indicators[qid] = nil
        end
    end

    -- Mount or refresh indicators for currently visible quests.
    local Tooltip = ns.PartySync.UI and ns.PartySync.UI.Tooltip
    for qid, block in pairs(visible) do
        local f = indicators[qid]
        if not f then
            f = Indicator.Acquire()
            indicators[qid] = f
        end
        f:SetParent(block)
        f:ClearAllPoints()
        -- Slice-6 anchor: top-right corner of the block, slight inset.
        -- Visual polish (anchor to title text's right edge) deferred to
        -- slice 8 once we've validated positioning in practice.
        f:SetPoint("TOPRIGHT", block, "TOPRIGHT", -4, -4)
        Indicator.SetState(f, Aggregate.Compute(qid))
        if Tooltip then Tooltip.Attach(f, qid) end
    end
end

-- One-frame debounce: events fire BEFORE the tracker rebuilds its
-- usedBlocks, so we wait one tick before walking it. Also coalesces
-- bursts of events into a single Refresh call.
local pending = false
local function DeferredRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        Refresh()
    end)
end

local function WireHooksAndEvents()
    local module = GetQuestModule()
    if not module or not module.Update then return false end

    -- Passive observer: runs AFTER Blizzard's Update finishes.
    -- Debounced through DeferredRefresh in case Update fires in bursts.
    hooksecurefunc(module, "Update", DeferredRefresh)

    local watch = CreateFrame("Frame")
    watch:RegisterEvent("QUEST_LOG_UPDATE")          -- own quest log change
    watch:RegisterEvent("QUEST_WATCH_LIST_CHANGED")  -- track/untrack
    watch:RegisterEvent("GROUP_ROSTER_UPDATE")       -- party churn
    watch:RegisterEvent("UNIT_QUEST_LOG_CHANGED")    -- partymate quest update
    watch:SetScript("OnEvent", DeferredRefresh)

    -- 3-second safety net while in party. Cheap when usedBlocks is small.
    C_Timer.NewTicker(3, function()
        if IsInGroup() then DeferredRefresh() end
    end)

    return true
end

-- Public: try to set up the hooks. Retries every second up to ~30s in
-- case the tracker module isn't ready yet at PLAYER_ENTERING_WORLD.
function MountTracker.Mount()
    if mounted then return end
    if WireHooksAndEvents() then
        mounted = true
        Refresh()
        return
    end
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        attempts = attempts + 1
        if WireHooksAndEvents() then
            mounted = true
            ticker:Cancel()
            Refresh()
        elseif attempts > 30 then
            ticker:Cancel()
        end
    end)
end

-- ============================================================
-- Test slash commands (removed in slice 10).
-- ============================================================

SLASH_QFTRACKERDEBUG1 = "/qftrackerdebug"
SlashCmdList.QFTRACKERDEBUG = function()
    local module = GetQuestModule()
    local visible = VisibleQuestBlocks()
    local nVisible, nIndicators = 0, 0
    for _ in pairs(visible)    do nVisible    = nVisible    + 1 end
    for _ in pairs(indicators) do nIndicators = nIndicators + 1 end
    print(string.format("|cffffcc00QF tracker|r mounted=%s visible=%d indicators=%d inGroup=%s module=%s",
        tostring(mounted), nVisible, nIndicators, tostring(IsInGroup()), module and "yes" or "NIL"))
    if nVisible > 0 then
        print("|cffaaaaaa  block enumeration (qid / HeaderText? / WxH / shown):|r")
        local n = 0
        for qid, block in pairs(visible) do
            n = n + 1
            if n > 5 then print("|cffaaaaaa  …more blocks omitted|r"); break end
            local ht = block.HeaderText and "yes" or "no"
            local w  = block.GetWidth  and math.floor(block:GetWidth())  or "?"
            local h  = block.GetHeight and math.floor(block:GetHeight()) or "?"
            local shown = block.IsShown and block:IsShown() or "?"
            print(string.format("    qid=%d / HT=%s / %sx%s / shown=%s",
                qid, ht, tostring(w), tostring(h), tostring(shown)))
        end
    end
end

-- Force-attach a bright debug widget to every tracker block — works
-- regardless of party state. If these aren't visible, the attachment
-- mechanism itself is broken (anchor, parent, size, or strata). If they
-- ARE visible solo but the real dots don't show in party, the bug is in
-- Aggregate.Compute.
local testWidgets = {}
SLASH_QFTRACKERTEST1 = "/qftrackertest"
SlashCmdList.QFTRACKERTEST = function()
    for _, w in ipairs(testWidgets) do w:Hide(); w:SetParent(UIParent) end
    wipe(testWidgets)

    local visible = VisibleQuestBlocks()
    local n = 0
    for _, block in pairs(visible) do
        local w = CreateFrame("Frame", nil, block)
        w:SetSize(12, 12)
        w:SetFrameStrata("DIALOG")  -- well above any tracker artwork
        local t = w:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints()
        t:SetColorTexture(1, 0, 1, 1)  -- magenta — impossible to miss
        w:SetPoint("TOPRIGHT", block, "TOPRIGHT", -4, -4)
        w:Show()
        testWidgets[#testWidgets+1] = w
        n = n + 1
    end
    print(string.format("|cffffcc00QF tracker test|r attached %d magenta widgets. /qftrackertestclear to remove.", n))
end

SLASH_QFTRACKERTESTCLEAR1 = "/qftrackertestclear"
SlashCmdList.QFTRACKERTESTCLEAR = function()
    for _, w in ipairs(testWidgets) do w:Hide(); w:SetParent(UIParent) end
    wipe(testWidgets)
    print("|cffffcc00QF tracker test|r cleared")
end
