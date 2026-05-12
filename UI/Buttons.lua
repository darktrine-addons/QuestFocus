-- UI/Buttons.lua — shared button factory, tooltip definitions, and live-state
-- registry for filter/revert button pairs. Each host module (ButtonTracker,
-- ButtonQuestLog, …) calls MakePair to create a fresh pair parented into its
-- own UI region; this file handles the rest (visual states, combat lockdown,
-- tooltip copy, watch-list-change refresh).
--
-- All pairs share the same underlying State.  When state changes, every
-- registered pair gets refreshed together so the tracker icon and the
-- quest-log icon stay in lock-step.

local addonName, ns = ...
ns.UI = ns.UI or {}

-- Each registered instance: { filterBtn = , revertBtn = , countBadge = }
local instances = {}

-- ============================================================
-- Visual state refresh
-- ============================================================

local function UpdateOne(inst)
    if not inst.filterBtn then return end
    local State  = ns.Core.State
    local active = State.GetFilterActive()
    local dirty  = State.IsDirty()
    local count  = State.GetRevertAddCount()

    -- Don't override the gray-during-combat color set by the OnEvent handler.
    if not InCombatLockdown() and inst.filterBtn.icon then
        if active and dirty then
            inst.filterBtn.icon:SetVertexColor(1.0, 0.55, 0.15)  -- orange: drift detected
        elseif active then
            inst.filterBtn.icon:SetVertexColor(0.4, 1.0, 0.4)    -- green: clean
        else
            inst.filterBtn.icon:SetVertexColor(1, 1, 1)          -- white: inactive
        end
    end

    if count > 0 then
        inst.countBadge:SetText(tostring(count))
        inst.countBadge:Show()
    else
        inst.countBadge:Hide()
    end
end

local function UpdateAll()
    for _, inst in ipairs(instances) do UpdateOne(inst) end
end

-- Exposed so Apply/Revert can notify the UI after a state change.
ns.UI.OnStateChanged = UpdateAll

-- ============================================================
-- Tooltip copy (identical for every host — state is global)
-- ============================================================

local function FilterTooltip()
    local State  = ns.Core.State
    local active = State.GetFilterActive()
    local dirty  = State.IsDirty()

    GameTooltip:SetText("Focus on this zone", 1, 0.82, 0)
    if not active then
        GameTooltip:AddLine("Click to narrow your watch list — untrack quests with no objectives in this zone.", 1, 1, 1, true)
    elseif dirty then
        local n = State.GetDriftAddCount()
        GameTooltip:AddLine(string.format("|cffff8c26Filter is applied, %d quest%s added since.|r",
            n, n == 1 and "" or "s"), 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to re-narrow for current zone. Your interim quests will be remembered for revert.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("|cff44ff44Filter is applied and clean.|r", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to re-narrow (e.g. after a zone change).", 1, 1, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaaShift-click also adds untracked zone quests from your quest log.|r", 1, 1, 1, true)
end

local function RevertTooltip()
    local State = ns.Core.State
    GameTooltip:SetText("Restore tracking", 1, 0.82, 0)
    if not State.GetFilterActive() then
        GameTooltip:AddLine("Nothing to restore.", 1, 1, 1, true)
        return
    end
    local restoreCount = State.GetRevertAddCount()
    local keepCount    = State.GetDriftAddCount()
    if restoreCount > 0 then
        GameTooltip:AddLine(string.format("Restores %d quest%s from before the filter.",
            restoreCount, restoreCount == 1 and "" or "s"), 1, 1, 1, true)
    end
    if keepCount > 0 then
        GameTooltip:AddLine(string.format("Keeps %d quest%s you've added since.",
            keepCount, keepCount == 1 and "" or "s"), 1, 1, 1, true)
    end
    if restoreCount == 0 and keepCount == 0 then
        GameTooltip:AddLine("Clears filter state — no changes to tracking.", 1, 1, 1, true)
    end
end

-- ============================================================
-- Button factory
-- ============================================================

local function MakeButton(parent, atlas, onClick, tooltipFn, tooltipAnchor)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas(atlas)
    b.icon = icon

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)

    b:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        onClick(IsShiftKeyDown() and true or false)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, tooltipAnchor or "ANCHOR_LEFT")
        tooltipFn()
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)

    b:RegisterEvent("PLAYER_REGEN_DISABLED")
    b:RegisterEvent("PLAYER_REGEN_ENABLED")
    b:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:Disable()
            self:EnableMouse(false)
            icon:SetVertexColor(0.5, 0.5, 0.5)
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:Enable()
            self:EnableMouse(true)
            UpdateAll()
        end
    end)

    return b
end

-- ============================================================
-- Public: create a filter/revert pair parented to `parent`.
-- Caller is responsible for SetPoint-ing the returned filterBtn.
-- The revertBtn is anchored to the filterBtn's LEFT automatically.
-- ============================================================

function ns.UI.MakePair(parent, opts)
    opts = opts or {}
    local tooltipAnchor = opts.tooltipAnchor   -- defaults to ANCHOR_LEFT inside MakeButton
    local gap           = opts.gap or 2

    local filterBtn = MakeButton(parent, "common-icon-zoomin",
        function(addFromLog) ns.Core.Apply.Filter(addFromLog) end,
        FilterTooltip,
        tooltipAnchor)

    local revertBtn = MakeButton(parent, "common-icon-undo",
        function() ns.Core.Revert.Revert() end,  -- shift state ignored on revert
        RevertTooltip,
        tooltipAnchor)
    revertBtn:SetPoint("RIGHT", filterBtn, "LEFT", -gap, 0)

    local countBadge = revertBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countBadge:SetPoint("BOTTOMRIGHT", revertBtn, "BOTTOMRIGHT", 2, -2)
    countBadge:SetTextColor(1, 1, 0.4)
    countBadge:Hide()

    local inst = { filterBtn = filterBtn, revertBtn = revertBtn, countBadge = countBadge }
    table.insert(instances, inst)
    UpdateOne(inst)
    return inst
end

-- ============================================================
-- Refresh every pair when the watch list changes externally
-- (manual track/untrack via Blizzard UI, quest accept/complete, etc.)
-- ============================================================

local watch = CreateFrame("Frame")
watch:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
watch:SetScript("OnEvent", UpdateAll)
