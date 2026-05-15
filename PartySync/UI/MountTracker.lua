-- PartySync/UI/MountTracker.lua — anchor indicator dots to live quest
-- tracker rows, keyed on questID.
--
-- Covers Blizzard's quest-like tracker modules: QuestObjectiveTracker
-- (regular quests) and CampaignQuestObjectiveTracker (campaign quests).
-- Both share the same usedBlocks shape and the same Update mixin method,
-- so the implementation walks a list of module names and treats them
-- uniformly.
--
-- Approach:
--   1. hooksecurefunc(<module>, "Update", refresh) on each tracker module
--      that's currently loaded — passive observer runs after Blizzard
--      finishes rebuilding usedBlocks.
--   2. Event registrations as a safety net (events sometimes fire before
--      the tracker's own Update; we use C_Timer.After(0, refresh) to wait
--      one frame so usedBlocks is current when we walk it).
--   3. 3-second ticker (only while in a party) as the ultimate safety net.
--   4. Retry loop for ~30s in case a tracker module loads late.
--
-- Taint posture (per memory `wow_blizzard_frame_field_write_taint`):
--   - We never write a custom field onto a tracker block.
--   - Indicator frames are addon-owned (`CreateFrame` parented to the block
--     for visibility-inheritance only); release re-parents to UIParent.
--   - The side-table `indicators[questID] = frame` lives in this file's
--     upvalues, not on Blizzard objects.

local addonName, ns = ...
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local MountTracker = {}
ns.PartySync.UI.MountTracker = MountTracker

local indicators     = {}     -- { [questID] = indicatorFrame }
local hookedModules  = {}     -- { [moduleName] = true }
local eventsWired    = false

-- Tracker modules we attach to. World quests, scenarios, achievements,
-- bonus objectives etc. are excluded — they don't have the party-progress
-- semantics the indicator is conveying.
local TRACKER_MODULES = {
    "QuestObjectiveTracker",
    "CampaignQuestObjectiveTracker",
}

-- Walks the live trackers. Returns { [questID] = block } flattened across
-- every available tracker module.
--
-- Schema (TWW Midnight, Interface 120005, confirmed by in-game probe
-- 2026-05-14): `usedBlocks` is two-level:
--
--   usedBlocks = {
--       [templateName] = {       -- e.g. "ObjectiveTrackerQuestPOIBlockTemplate"
--           [questID] = block,
--           ...
--       },
--       ...
--   }
--
-- The questID is the inner key directly. The CampaignQuestObjectiveTracker
-- uses the same shape, just keyed by campaign quest IDs.
local function VisibleQuestBlocks()
    local result = {}
    for _, name in ipairs(TRACKER_MODULES) do
        local module = _G[name]
        if module and module.usedBlocks then
            for _, inner in pairs(module.usedBlocks) do
                if type(inner) == "table" then
                    for qid, block in pairs(inner) do
                        if type(qid) == "number" and block then
                            result[qid] = block
                        end
                    end
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

-- Per-quest cache of the last computed aggregate state. Used to emit
-- /qf party debug diffs without printing on every Refresh tick.
local lastState = {}

local function Refresh()
    if ns.PartySync.active == false then return end
    local Indicator = ns.PartySync.UI.Indicator
    local Aggregate = ns.PartySync.Aggregate
    if not Indicator or not Aggregate then return end

    -- Solo → release everything and bail.
    if not IsInGroup() then
        ReleaseAll()
        wipe(lastState)
        return
    end

    local visible = VisibleQuestBlocks()

    -- Release indicators for quests that have left the tracker.
    for qid, f in pairs(indicators) do
        if not visible[qid] then
            Indicator.Release(f)
            indicators[qid] = nil
            if ns.PartySync.debug and lastState[qid] ~= nil then
                print(string.format("|cffaaaaaaQF debug|r qid=%d released (was %s)",
                    qid, tostring(lastState[qid])))
            end
            lastState[qid] = nil
        end
    end

    -- Mount or refresh indicators for currently visible quests.
    for qid, block in pairs(visible) do
        local f = indicators[qid]
        if not f then
            f = Indicator.Acquire()
            indicators[qid] = f
        end
        f:SetParent(block)
        MountTracker.ApplyAnchorToBlock(f, block)
        local state = Aggregate.Compute(qid)
        if ns.PartySync.debug and lastState[qid] ~= state then
            local title = (C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(qid)) or "?"
            print(string.format("|cffaaaaaaQF debug|r qid=%d (%s): %s -> %s",
                qid, title, tostring(lastState[qid]), tostring(state)))
        end
        lastState[qid] = state
        Indicator.SetState(f, state)
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

local function WireEvents()
    if eventsWired then return end
    eventsWired = true

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
end

-- Hook a single tracker module if it's available and not already hooked.
-- Returns true if (already or newly) hooked.
local function TryHookModule(name)
    if hookedModules[name] then return true end
    local module = _G[name]
    if not module or not module.Update then return false end
    hooksecurefunc(module, "Update", DeferredRefresh)
    hookedModules[name] = true
    return true
end

local function HookAllAvailable()
    local allDone = true
    for _, name in ipairs(TRACKER_MODULES) do
        if not TryHookModule(name) then allDone = false end
    end
    return allDone
end

-- Public: set up events once + hook every tracker module that's available
-- now. Retries every second for ~30s in case any module loads late.
function MountTracker.Mount()
    WireEvents()
    if HookAllAvailable() then
        Refresh()
        return
    end
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        attempts = attempts + 1
        if HookAllAvailable() or attempts > 30 then
            ticker:Cancel()
            Refresh()
        end
    end)
end

-- Exposed for runtime hot-toggle via PartySync.SetActive.
function MountTracker.Refresh() Refresh() end
function MountTracker.ReleaseAllIndicators() ReleaseAll(); wipe(lastState) end

-- Reverse lookup used by the Tooltip hook: given a frame (the
-- GameTooltip's current owner, typically a tracker row block or one of
-- its children), return the questID we've mounted an indicator for on
-- that block. Walks up the parent chain so child-of-block owners work
-- too. nil if no match — caller treats nil as "not our tooltip".
function MountTracker.GetQuestIDForBlock(frame)
    while frame do
        for qid, indicator in pairs(indicators) do
            if indicator:GetParent() == frame then return qid end
        end
        local parent = frame.GetParent and frame:GetParent()
        if parent == frame then return nil end  -- guard against loops
        frame = parent
    end
    return nil
end

-- Public: list of live tracker-row blocks keyed by questID. Used by the
-- Settings panel's solo preview to attach demo dots to real rows.
function MountTracker.GetVisibleBlocks()
    return VisibleQuestBlocks()
end

-- Public: apply the current Config-configured anchor to an indicator
-- attached to a tracker block. Used by Refresh (for live indicators)
-- and by the preview (for demo indicators), so anchor changes flow
-- through one place.
function MountTracker.ApplyAnchorToBlock(f, block)
    local anchor = (ns.Config and ns.Config.GetPartySyncSetting
                    and ns.Config.GetPartySyncSetting("indicatorAnchor")) or "topRight"
    f:ClearAllPoints()
    if anchor == "leftOfTitle" and block.HeaderText then
        -- -30px so the dot clears the row's quest-type icon (campaign
        -- chevron, exclamation, etc.) instead of overlapping it.
        f:SetPoint("RIGHT", block.HeaderText, "LEFT", -30, 0)
    elseif anchor == "rightOfTitle" and block.HeaderText then
        f:SetPoint("LEFT", block.HeaderText, "RIGHT", 4, 0)
    else
        -- topRight (default) — also catches any legacy "topLeft" SV.
        f:SetPoint("TOPRIGHT", block, "TOPRIGHT", -4, -4)
    end
end
