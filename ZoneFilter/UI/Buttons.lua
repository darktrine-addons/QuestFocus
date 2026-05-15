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
ns.ZoneFilter    = ns.ZoneFilter    or {}
ns.ZoneFilter.UI = ns.ZoneFilter.UI or {}

-- Each registered instance: { filterBtn = , revertBtn = , countBadge = }
local instances = {}

-- ============================================================
-- Visual state refresh
-- ============================================================

local function UpdateOne(inst)
    if not inst.filterBtn then return end
    local State  = ns.ZoneFilter.State
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
ns.ZoneFilter.UI.OnStateChanged = UpdateAll

-- ============================================================
-- Tooltip copy (identical for every host — state is global)
-- ============================================================

-- Cheap on hover: one quest-log walk (via GetRelevantQuests) + one watch-list
-- intersection. Returns (untrackCount, promoteCount, mapKnown).
local function PredictFilterDelta()
    local Relevance = ns.ZoneFilter.Relevance
    if not Relevance.GetCurrentMapID() then
        return 0, 0, false
    end
    local relevant = Relevance.GetRelevantQuests()
    local current  = ns.ZoneFilter.State.GetCurrentWatches()

    local untrack, promote = 0, 0
    for qid in pairs(current) do
        if not relevant[qid] then untrack = untrack + 1 end
    end
    for qid in pairs(relevant) do
        if not current[qid] then promote = promote + 1 end
    end
    return untrack, promote, true
end

local function FilterTooltip()
    local State  = ns.ZoneFilter.State
    local active = State.GetFilterActive()
    local dirty  = State.IsDirty()

    GameTooltip:SetText("Focus on this zone", 1, 0.82, 0)
    if not active then
        GameTooltip:AddLine("Narrows your watch list to quests with objectives in this zone.", 1, 1, 1, true)
    elseif dirty then
        local n = State.GetDriftAddCount()
        GameTooltip:AddLine(string.format("|cffff8c26Filter is applied, %d quest%s added since.|r",
            n, n == 1 and "" or "s"), 1, 1, 1, true)
    else
        GameTooltip:AddLine("|cff44ff44Filter is applied and clean.|r", 1, 1, 1, true)
    end

    local untrack, promote, mapKnown = PredictFilterDelta()
    GameTooltip:AddLine(" ")
    if not mapKnown then
        GameTooltip:AddLine("|cffaaaaaaCurrent zone unknown — open the world map once.|r", 1, 1, 1, true)
    else
        if untrack == 0 then
            GameTooltip:AddLine("Click: |cffaaaaaano changes|r", 1, 1, 1, true)
        else
            GameTooltip:AddLine(string.format("Click: untrack |cffff7777%d|r quest%s",
                untrack, untrack == 1 and "" or "s"), 1, 1, 1, true)
        end
        if untrack == 0 and promote == 0 then
            GameTooltip:AddLine("Shift-click: |cffaaaaaano changes|r", 1, 1, 1, true)
        elseif promote == 0 then
            GameTooltip:AddLine(string.format("Shift-click: untrack |cffff7777%d|r (no zone quests to add)",
                untrack), 1, 1, 1, true)
        elseif untrack == 0 then
            GameTooltip:AddLine(string.format("Shift-click: track |cff77ff77%d|r from quest log",
                promote), 1, 1, 1, true)
        else
            GameTooltip:AddLine(string.format("Shift-click: untrack |cffff7777%d|r, track |cff77ff77%d|r from quest log",
                untrack, promote), 1, 1, 1, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaaRight-click: more tracker modes|r", 1, 1, 1, true)
    GameTooltip:AddLine("|cffaaaaaaShift-Right-click: open settings|r", 1, 1, 1, true)
end

local function RevertTooltip()
    local State = ns.ZoneFilter.State
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
            -- Shift-Right-click → Settings panel (always available).
            -- Plain Right-click → optional onRightClick (mode menu on
            -- the filter button; no-op on revert).
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
-- Right-click context menu on the filter button — surfaces the
-- alternate tracker modes from Apply.Mode plus a Settings entry.
-- ============================================================

local function ShowModeMenu(button)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        print("|cffffcc00QuestFocus|r menu API unavailable on this client.")
        return
    end
    MenuUtil.CreateContextMenu(button, function(owner, root)
        root:CreateTitle("Tracker modes")

        -- Broadest first.
        root:CreateButton("Track all quests in log", function()
            ns.ZoneFilter.Apply.Mode("trackAll")
        end)

        root:CreateDivider()

        -- Zone filter (also accessible via the button's left/shift-left).
        root:CreateButton("Track current zone (Focus)", function()
            ns.ZoneFilter.Apply.Filter(false)
        end)
        root:CreateButton("Track current zone + promote from log", function()
            ns.ZoneFilter.Apply.Filter(true)
        end)

        root:CreateDivider()

        -- By quest type.
        root:CreateButton("Track campaign quests only", function()
            ns.ZoneFilter.Apply.Mode("campaignOnly")
        end)
        root:CreateButton("Track daily quests only", function()
            ns.ZoneFilter.Apply.Mode("dailyOnly")
        end)
        root:CreateButton("Track weeklies only", function()
            ns.ZoneFilter.Apply.Mode("weekliesOnly")
        end)
        root:CreateButton("Track Important quests only", function()
            ns.ZoneFilter.Apply.Mode("importantOnly")
        end)

        root:CreateDivider()

        -- By quest state.
        root:CreateButton("Track ready-to-turn-in only", function()
            ns.ZoneFilter.Apply.Mode("readyOnly")
        end)
        root:CreateButton("Track in-progress only", function()
            ns.ZoneFilter.Apply.Mode("inProgressOnly")
        end)

        root:CreateDivider()

        -- Destructive.
        root:CreateButton("Untrack everything", function()
            ns.ZoneFilter.Apply.Mode("untrackAll")
        end)

        root:CreateDivider()

        root:CreateButton("Open settings…", function()
            if ns.Settings and ns.Settings.Open then ns.Settings.Open() end
        end)
    end)
end

-- ============================================================
-- Public: create a filter/revert pair parented to `parent`.
-- Caller is responsible for SetPoint-ing the returned filterBtn.
-- The revertBtn is anchored to the filterBtn's LEFT automatically.
-- ============================================================

function ns.ZoneFilter.UI.MakePair(parent, opts)
    opts = opts or {}
    local tooltipAnchor = opts.tooltipAnchor   -- defaults to ANCHOR_LEFT inside MakeButton
    local gap           = opts.gap or 2

    local filterBtn = MakeButton(parent, "common-icon-zoomin",
        function(addFromLog) ns.ZoneFilter.Apply.Filter(addFromLog) end,
        FilterTooltip,
        tooltipAnchor,
        ShowModeMenu)

    local revertBtn = MakeButton(parent, "common-icon-undo",
        function() ns.ZoneFilter.Revert.Revert() end,  -- shift state ignored on revert
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
