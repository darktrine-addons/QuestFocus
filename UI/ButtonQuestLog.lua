-- ButtonQuestLog.lua — host module: mounts the filter/revert pair on the
-- quest log side panel of the world map (`QuestMapFrame`).
--
-- Parent is QuestMapFrame so visibility inherits — buttons hide when the
-- world map is closed or when the side panel is collapsed.
--
-- Anchor: top-right corner of QuestMapFrame, inset to clear the panel border
-- and any session-management widgets that occasionally appear at the top.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

local function Mount()
    if mounted then return true end
    if not QuestMapFrame then return false end

    -- ANCHOR_BOTTOMLEFT for the tooltip: places it below-and-left of the
    -- button, which is into the quest list area — visible without clipping
    -- the world-map edge regardless of which side the map is docked.
    local inst = ns.UI.MakePair(QuestMapFrame, { tooltipAnchor = "ANCHOR_BOTTOMLEFT" })
    inst.filterBtn:SetPoint("TOPRIGHT", QuestMapFrame, "TOPRIGHT", -8, -8)

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
