-- ZoneFilter/UI/Buttons/Factory.lua — button construction + live-state
-- registry. Builds the filter/revert/re-apply trio and keeps an
-- instance list refreshed in lock-step on state changes.
--
-- Public API:
--   ns.ZoneFilter.UI.MakePair(parent, opts)
--       Returns { filterBtn, revertBtn, reapplyBtn, countBadge }. The
--       host module is responsible for SetPoint-ing filterBtn.
--   ns.ZoneFilter.UI.OnStateChanged()
--       Refreshes every registered instance. Called by Apply / Revert
--       after they mutate state.

local addonName, ns = ...
ns.ZoneFilter    = ns.ZoneFilter    or {}
ns.ZoneFilter.UI = ns.ZoneFilter.UI or {}

-- Registered instances: { filterBtn, revertBtn, countBadge, reapplyBtn }.
-- Two entries in normal play (tracker pair + quest-log pair).
local instances = {}

-- ============================================================
-- D3: clean → dirty pulse
-- ============================================================

-- Two-stage alpha animation on the lens icon. Plays once when the
-- filter transitions from clean to dirty, drawing attention without
-- being persistent. AnimationGroup is built lazily per icon.
local function PulseLensIcon(icon)
    if not icon then return end
    if not icon.qfPulseAG then
        local ag = icon:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(1); a1:SetToAlpha(0.3)
        a1:SetDuration(0.25); a1:SetSmoothing("OUT"); a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(0.3); a2:SetToAlpha(1)
        a2:SetDuration(0.25); a2:SetSmoothing("IN"); a2:SetOrder(2)
        ag:SetScript("OnFinished", function() icon:SetAlpha(1) end)
        icon.qfPulseAG = ag
    end
    if icon.qfPulseAG:IsPlaying() then return end
    icon.qfPulseAG:Play()
end

-- ============================================================
-- Visual state refresh
-- ============================================================

local function UpdateOne(inst)
    if not inst.filterBtn then return end
    local State    = ns.ZoneFilter.State
    local active   = State.GetFilterActive()
    local dirty    = State.IsDirty()
    local count    = State.GetRevertAddCount()
    local lastMode = State.GetLastMode and State.GetLastMode()

    -- D3: detect transitions from clean (or inactive) into dirty so we
    -- can pulse the lens icon once. _wasDirty lives on the inst table
    -- (addon-owned, taint-safe).
    local nowDirty = active and dirty
    if nowDirty and not inst._wasDirty and not InCombatLockdown() then
        PulseLensIcon(inst.filterBtn.icon)
    end
    inst._wasDirty = nowDirty

    -- Filter button colour. Combat handler greys all icons on
    -- PLAYER_REGEN_DISABLED; we restore colour only out of combat.
    if not InCombatLockdown() and inst.filterBtn.icon then
        if active and dirty then
            inst.filterBtn.icon:SetVertexColor(1.0, 0.55, 0.15)  -- orange: drift
        elseif active then
            inst.filterBtn.icon:SetVertexColor(0.4, 1.0, 0.4)    -- green: clean
        else
            inst.filterBtn.icon:SetVertexColor(1, 1, 1)          -- white: inactive
        end
    end

    -- Restorable-count badge.
    if count > 0 then
        inst.countBadge:SetText(tostring(count))
        inst.countBadge:Show()
    else
        inst.countBadge:Hide()
    end

    -- Re-apply button: only when a non-zone mode is active AND there's
    -- drift to re-clear. Left-click on the lens already handles the
    -- zoneFilter case, so the re-apply button stays hidden then.
    if inst.reapplyBtn then
        local shouldShow = active and dirty
            and lastMode and lastMode ~= "zoneFilter"
        if shouldShow then inst.reapplyBtn:Show() else inst.reapplyBtn:Hide() end
        -- Restore the green tint — PLAYER_REGEN_DISABLED greys it and
        -- the post-combat UpdateAll path doesn't otherwise re-tint it.
        if not InCombatLockdown() and inst.reapplyBtn.icon then
            inst.reapplyBtn.icon:SetVertexColor(0.4, 1.0, 0.4)
        end
    end
end

local function UpdateAll()
    for _, inst in ipairs(instances) do UpdateOne(inst) end
end

-- Exposed so Apply / Revert can notify the UI after a state change.
ns.ZoneFilter.UI.OnStateChanged = UpdateAll

-- ============================================================
-- Button factory
-- ============================================================

local function MakeButton(parent, atlas, onClick, tooltipFn, tooltipAnchor, onRightClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas(atlas)
    b.icon = icon

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Shift-Right-click → Settings; plain Right-click → optional
            -- onRightClick (mode menu on the filter button only).
            if IsShiftKeyDown() then
                if ns.Settings and ns.Settings.Open then ns.Settings.Open() end
            elseif onRightClick then
                onRightClick(self)
            end
            return
        end
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
-- Public: create a filter / revert / re-apply trio parented to `parent`.
-- Caller is responsible for SetPoint-ing the returned filterBtn.
-- Other buttons anchor leftwards off it automatically.
-- ============================================================

function ns.ZoneFilter.UI.MakePair(parent, opts)
    opts = opts or {}
    local tooltipAnchor = opts.tooltipAnchor   -- defaults to ANCHOR_LEFT inside MakeButton
    local gap           = opts.gap or 2

    local T = ns.ZoneFilter.UI.Tooltips
    local M = ns.ZoneFilter.UI.Menu

    local filterBtn = MakeButton(parent, "common-icon-zoomin",
        function(addFromLog) ns.ZoneFilter.Apply.Filter(addFromLog) end,
        T.Filter,
        tooltipAnchor,
        M.Show)

    local revertBtn = MakeButton(parent, "common-icon-undo",
        function() ns.ZoneFilter.Revert.Revert() end,
        T.Revert,
        tooltipAnchor)
    revertBtn:SetPoint("RIGHT", filterBtn, "LEFT", -gap, 0)

    local countBadge = revertBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countBadge:SetPoint("BOTTOMRIGHT", revertBtn, "BOTTOMRIGHT", 2, -2)
    countBadge:SetTextColor(1, 1, 0.4)
    countBadge:Hide()

    -- Re-apply button. Atlas: common-icon-undo (same as revert) but
    -- tinted green in UpdateOne to distinguish — common-icon-redo
    -- isn't reliable on all TWW clients. Visual differentiation via
    -- colour, identity via tooltip + position.
    local reapplyBtn = MakeButton(parent, "common-icon-undo",
        function()
            local lastMode = ns.ZoneFilter.State.GetLastMode and ns.ZoneFilter.State.GetLastMode()
            if lastMode and lastMode ~= "zoneFilter" then
                ns.ZoneFilter.Apply.Mode(lastMode)
            end
        end,
        T.Reapply,
        tooltipAnchor)
    -- Triangular layout: re-apply sits ABOVE, centered over the gap
    -- between revert (left) and filter (right). Extending leftward made
    -- the trio overflow the quest log frame edge; going up uses the
    -- empty area above the pair.
    reapplyBtn:SetPoint("BOTTOM", revertBtn, "TOPRIGHT", 1, gap)
    if reapplyBtn.icon then
        reapplyBtn.icon:SetVertexColor(0.4, 1.0, 0.4)
    end
    reapplyBtn:Hide()

    local inst = {
        filterBtn  = filterBtn,
        revertBtn  = revertBtn,
        countBadge = countBadge,
        reapplyBtn = reapplyBtn,
    }
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
