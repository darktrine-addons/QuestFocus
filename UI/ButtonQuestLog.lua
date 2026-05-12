-- ButtonQuestLog.lua — host module: mounts the filter/revert pair on the
-- quest log side panel of the world map (`QuestMapFrame`).
--
-- Anchor: bottom-right of QuestMapFrame, in the typically-empty footer area.
--   - The v0.1.0-beta TOPRIGHT anchor overlapped with campaign-header text
--     when a campaign was active (see in-game screenshot 2026-05-11).
--   - The earlier WorldMapFrame.SidePanelToggle probe in b571a4c placed the
--     buttons off-screen — the toggle frame existed but wasn't the
--     right-side quest-log tab the user described.
--   - BOTTOMRIGHT is consistently clean across builds.
--
-- See umbrella issue #1 polish item: long-term we still want the right-side
-- tab strip anchor (above the topmost "!" tab), but we couldn't reliably
-- identify that frame's Blizzard-stable path. Footer is the safe interim.
--
-- Parent is QuestMapFrame, so visibility inherits: buttons hide when the
-- world map is closed or when the quest log panel is collapsed.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

local function Mount()
    if mounted then return true end
    if not QuestMapFrame then return false end

    -- ANCHOR_TOPLEFT: tooltip appears above-and-to-the-left of the button.
    -- Since the buttons sit at bottom-right of the panel, tooltip extends
    -- up-and-left into the quest list area — visible without clipping.
    local inst = ns.UI.MakePair(QuestMapFrame, { tooltipAnchor = "ANCHOR_TOPLEFT" })
    inst.filterBtn:SetPoint("BOTTOMRIGHT", QuestMapFrame, "BOTTOMRIGHT", -8, 8)

    mounted = true
    return true
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
