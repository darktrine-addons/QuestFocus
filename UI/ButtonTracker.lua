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
    local count  = State.GetRevertAddCount()

    local fs = filterBtn:GetFontString()
    if fs then
        if active then
            fs:SetTextColor(0.4, 1.0, 0.4)
        else
            fs:SetTextColor(1, 1, 1)
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

local function MakeButton(parent, symbol, onClick, tooltipFn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER", b, "CENTER", 0, 0)
    fs:SetText(symbol)
    b:SetFontString(fs)

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
            if fs then fs:SetTextColor(0.5, 0.5, 0.5) end
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

    filterBtn = MakeButton(parent, "▼",
        function() ns.Core.Apply.Filter() end,
        function(self)
            GameTooltip:SetText("Focus on this zone", 1, 0.82, 0)
            GameTooltip:AddLine("Narrow your tracked quests to those with an objective in your current zone.", 1, 1, 1, true)
            local active = ns.Core.State.GetFilterActive()
            if active then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff44ff44Filter is active.|r Click to re-apply for current zone.", 1, 1, 1, true)
            else
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Click to apply.", 1, 1, 1, true)
            end
        end)
    filterBtn:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    revertBtn = MakeButton(parent, "↺",
        function() ns.Core.Revert.Revert() end,
        function(self)
            GameTooltip:SetText("Restore tracking", 1, 0.82, 0)
            local count = ns.Core.State.GetRevertAddCount()
            if count > 0 then
                GameTooltip:AddLine(string.format("Restores %d quest%s that %s tracked before the filter was applied.",
                    count, count == 1 and "" or "s", count == 1 and "was" or "were"), 1, 1, 1, true)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cffff8888Any quests you've added since are discarded.|r", 1, 1, 1, true)
            else
                GameTooltip:AddLine("Nothing to restore.", 1, 1, 1, true)
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
