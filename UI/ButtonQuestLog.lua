-- ButtonQuestLog.lua — host module: mounts the filter/revert pair on the
-- quest log side panel of the world map (`QuestMapFrame`).
--
-- Anchor: outside QuestMapFrame's TOPRIGHT corner — just above the panel's
-- top edge, near its right side. Sits in the horizontal strip between
-- WorldMapFrame's title bar and QuestMapFrame's content area. This area
-- is typically clean and doesn't compete with any panel widgets.
--
-- Iteration history (so future-me knows why we're here):
--   v0.1.0-beta: anchored INSIDE QuestMapFrame at TOPRIGHT — overlapped
--     with campaign header and the panel's section-collapse "−" button.
--   b571a4c: probed WorldMapFrame.SidePanelToggle — that frame exists in
--     TWW but isn't the right-side "!" quest-log tab; anchoring there
--     placed buttons off-screen.
--   812db98: BOTTOMRIGHT inside QuestMapFrame — visible but the footer
--     was also crowded.
--   Current: outside the panel's top edge.
--
-- Parent is QuestMapFrame, so visibility inherits: buttons hide when the
-- world map is closed or when the quest log panel is collapsed.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

local function Mount()
    if mounted then return true end
    if not QuestMapFrame then return false end

    -- ANCHOR_BOTTOMLEFT: tooltip appears below-and-to-the-left of the button.
    -- Since the buttons sit just above the panel's top-right, tooltip extends
    -- down-and-left into the quest list area — visible without clipping the
    -- world-map title bar above.
    local inst = ns.UI.MakePair(QuestMapFrame, { tooltipAnchor = "ANCHOR_BOTTOMLEFT" })
    -- BOTTOMRIGHT of the pair anchored 4px above QuestMapFrame's TOPRIGHT corner.
    inst.filterBtn:SetPoint("BOTTOMRIGHT", QuestMapFrame, "TOPRIGHT", 0, 4)

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
