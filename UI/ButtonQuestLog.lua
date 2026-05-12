-- ButtonQuestLog.lua — host module: mounts the filter/revert pair near the
-- right-side quest log tab on the world map.
--
-- The world map has a vertical strip of tabs on the right edge (yellow "!"
-- toggle for the quest log, plus map-pin filter buttons below it). The
-- topmost tab is the quest-log toggle; we anchor the pair just above it.
--
-- Parent is the tab's parent (typically WorldMapFrame) rather than
-- QuestMapFrame, so the buttons remain visible when the user collapses the
-- quest log panel — they can re-filter without expanding first.
--
-- Anchor frame discovery is defensive: the precise Blizzard path for this
-- tab varies by patch. Probe a couple of known names; if none resolves,
-- fall back to anchoring inside QuestMapFrame's top-right (the v0.1.x
-- behavior) so the pair still appears, just less ideally placed.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

-- Probe for the right-side quest-log toggle tab.
-- Returns the tab frame, or nil if no known path resolves.
local function FindQuestLogTab()
    if not WorldMapFrame then return nil end

    -- Modern retail (TWW / Midnight): side-panel toggle. Most likely match.
    if WorldMapFrame.SidePanelToggle then
        return WorldMapFrame.SidePanelToggle
    end

    -- Older retail variants
    if QuestMapFrame and QuestMapFrame.HideShowButton then
        return QuestMapFrame.HideShowButton
    end
    if WorldMapFrame.BorderFrame and WorldMapFrame.BorderFrame.QuestLogToggleButton then
        return WorldMapFrame.BorderFrame.QuestLogToggleButton
    end

    return nil
end

local function Mount()
    if mounted then return true end

    local tab = FindQuestLogTab()
    if tab then
        -- Best path: anchor above the topmost tab in the right-side strip.
        -- Parent to the tab's host so visibility follows the map (not the
        -- quest-log panel, which may be collapsed).
        local parent = tab:GetParent() or WorldMapFrame
        local inst = ns.UI.MakePair(parent, { tooltipAnchor = "ANCHOR_LEFT" })
        inst.filterBtn:SetPoint("BOTTOM", tab, "TOP", 0, 4)
        mounted = true
        return true
    end

    -- Fallback: if we can't find the tab, anchor inside QuestMapFrame's
    -- top-right corner — visible, but may overlap the campaign header.
    -- Acceptable fallback so users still get the second pair.
    if QuestMapFrame then
        local inst = ns.UI.MakePair(QuestMapFrame, { tooltipAnchor = "ANCHOR_BOTTOMLEFT" })
        inst.filterBtn:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -8, -8)
        mounted = true
        return true
    end

    return false
end

function ns.UI.MountQuestLogButtons()
    if Mount() then return end
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        attempts = attempts + 1
        if Mount() or attempts > 30 then ticker:Cancel() end
    end)
end
