-- ButtonTracker.lua — two minimalistic symbolic buttons anchored to the tracker.
--
-- Visibility, position, and Edit Mode movement are inherited from the tracker's
-- Header (parent + anchor), so when the tracker hides itself (nothing tracked)
-- or is repositioned, the buttons follow without us managing it.
--
-- Combat behaviour: on PLAYER_REGEN_DISABLED each button :Disable()s itself and
-- calls :EnableMouse(false) so clicks pass through to whatever is behind. The
-- OnClick handler also guards with InCombatLockdown() as a belt-and-braces
-- defense in case any path leaves the button mouse-enabled in combat — neither
-- the Apply nor Revert API call paths are reachable during combat.

local addonName, ns = ...
ns.UI = ns.UI or {}

local filterBtn, revertBtn, countBadge
local mounted = false

-- ============================================================
-- Anchor probe — modern retail uses Header, fall back to older paths.
-- ============================================================

local function FindAnchor()
    local OT = ObjectiveTrackerFrame
    if not OT then return nil, nil end
    if OT.Header and OT.Header.MinimizeButton then
        return OT.Header, OT.Header.MinimizeButton
    end
    if OT.HeaderMenu and OT.HeaderMenu.MinimizeButton then
        return OT.HeaderMenu, OT.HeaderMenu.MinimizeButton
    end
    if OT.MinimizeButton then
        return OT, OT.MinimizeButton
    end
    return nil, nil
end

-- ============================================================
-- Visual state — green tint on filter button when active, count badge on revert.
-- ============================================================

local function UpdateState()
    if not filterBtn then return end
    local State = ns.Core.State
    local active = State.GetFilterActive()
    local dirty  = State.IsDirty()
    local count  = State.GetRevertAddCount()

    -- Don't override the gray-during-combat color set by the OnEvent handler.
    if not InCombatLockdown() and filterBtn.icon then
        if active and dirty then
            filterBtn.icon:SetVertexColor(1.0, 0.85, 0.2)   -- yellow / amber: filter applied, drift detected
        elseif active then
            filterBtn.icon:SetVertexColor(0.4, 1.0, 0.4)    -- green: filter applied and clean
        else
            filterBtn.icon:SetVertexColor(1, 1, 1)          -- white: no filter
        end
    end

    if count > 0 then
        countBadge:SetText(tostring(count))
        countBadge:Show()
    else
        countBadge:Hide()
    end
end

ns.UI.OnStateChanged = UpdateState

-- ============================================================
-- Button factory — minimalistic symbolic button with hover highlight,
-- tooltip, combat lockdown, click-through during combat.
-- ============================================================

local function MakeButton(parent, atlas, onClick, tooltipFn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)

    -- Icon texture region — atlas-driven so we don't ship art assets.
    -- common-icon-* atlases have been stable since Dragonflight (10.0).
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetAtlas(atlas)
    b.icon = icon

    -- Hover highlight (subtle white overlay)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)

    b:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        onClick()
    end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        tooltipFn(self)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)

    -- Combat handling
    b:RegisterEvent("PLAYER_REGEN_DISABLED")
    b:RegisterEvent("PLAYER_REGEN_ENABLED")
    b:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:Disable()
            self:EnableMouse(false)              -- click-through; clicks reach whatever is behind
            icon:SetVertexColor(0.5, 0.5, 0.5)   -- visually dimmed
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:Enable()
            self:EnableMouse(true)
            UpdateState()                         -- restore active/inactive color
        end
    end)

    return b
end

-- ============================================================
-- Mount: place the buttons. Idempotent; retries on first call if tracker
-- frame doesn't exist yet at PLAYER_ENTERING_WORLD.
-- ============================================================

local function Mount()
    if mounted then return true end
    local parent, anchor = FindAnchor()
    if not parent or not anchor then return false end

    filterBtn = MakeButton(parent, "common-icon-zoomin",
        function() ns.Core.Apply.Filter() end,
        function(self)
            local State  = ns.Core.State
            local active = State.GetFilterActive()
            local dirty  = State.IsDirty()

            GameTooltip:SetText("Focus on this zone", 1, 0.82, 0)
            if not active then
                GameTooltip:AddLine("Click to narrow your watch list to quests with objectives in this zone.", 1, 1, 1, true)
            elseif dirty then
                local driftAdds = State.GetDriftAddCount()
                GameTooltip:AddLine(string.format("|cffffd62aFilter is applied, %d quest%s added since.|r",
                    driftAdds, driftAdds == 1 and "" or "s"), 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to re-narrow for current zone. Your interim quests will be remembered for revert.", 1, 1, 1, true)
            else
                GameTooltip:AddLine("|cff44ff44Filter is applied and clean.|r", 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to re-narrow (e.g. after a zone change).", 1, 1, 1, true)
            end
        end)
    filterBtn:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    revertBtn = MakeButton(parent, "common-icon-undo",
        function() ns.Core.Revert.Revert() end,
        function(self)
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
        end)
    revertBtn:SetPoint("RIGHT", filterBtn, "LEFT", -2, 0)

    -- Count badge on revert button (bottom-right corner)
    countBadge = revertBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countBadge:SetPoint("BOTTOMRIGHT", revertBtn, "BOTTOMRIGHT", 2, -2)
    countBadge:SetTextColor(1, 1, 0.4)
    countBadge:Hide()

    mounted = true
    UpdateState()
    return true
end

function ns.UI.MountTrackerButtons()
    if Mount() then return end
    local attempts = 0
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        attempts = attempts + 1
        if Mount() or attempts > 30 then ticker:Cancel() end
    end)
end

-- ============================================================
-- Refresh badge / color when watch list changes externally
-- ============================================================

local watch = CreateFrame("Frame")
watch:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
watch:SetScript("OnEvent", function() UpdateState() end)
