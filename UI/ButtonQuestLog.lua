-- ButtonQuestLog.lua — host module: mounts the filter/revert pair on the
-- quest log side panel of the world map (`QuestMapFrame`).
--
-- Anchor: directly above `QuestMapFrame.QuestsTab`. That's the small tab
-- on the panel's upper-left (where the user can switch between Quests
-- and other tabs of the quest log). Identified via /framestack on the
-- user's TWW client:
--   ANCHORS:   TOPLEFT QuestMapFrame TOPLEFT 3.00 -28.00
--   SOURCE:    Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.xml:397
-- The strip immediately above this tab is clean of other widgets.
--
-- Parent is QuestMapFrame (not the tab itself) so visibility inherits from
-- the panel — buttons stay visible even if the user switches to another
-- quest-log tab. Anchor is relative to the tab so the pair tracks it.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

local function Mount()
    if mounted then return true end
    if not QuestMapFrame or not QuestMapFrame.QuestsTab then return false end

    -- ANCHOR_LEFT for the tooltip: extends to the left of the button, into
    -- the map area (clean). Other directions would overlap the panel.
    local inst = ns.UI.MakePair(QuestMapFrame, { tooltipAnchor = "ANCHOR_LEFT" })
    inst.filterBtn:SetPoint("BOTTOMLEFT", QuestMapFrame.QuestsTab, "TOPLEFT", 0, 2)

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
