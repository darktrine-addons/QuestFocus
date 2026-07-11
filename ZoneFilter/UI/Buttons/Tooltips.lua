-- ZoneFilter/UI/Buttons/Tooltips.lua — GameTooltip renderers for the
-- filter / revert / re-apply buttons. Pure presentation: each function
-- reads State + Apply, calls GameTooltip:AddLine. Factory wires them
-- as the OnEnter callbacks on the respective buttons.

local addonName, ns = ...
ns.ZoneFilter    = ns.ZoneFilter    or {}
ns.ZoneFilter.UI = ns.ZoneFilter.UI or {}

local Tooltips = {}
ns.ZoneFilter.UI.Tooltips = Tooltips

-- Cheap on hover: one quest-log walk (via GetRelevantQuests) + one
-- watch-list intersection. Returns (untrackCount, promoteCount, mapKnown).
local function PredictFilterDelta()
    local Relevance = ns.ZoneFilter.Relevance
    if not Relevance.GetCurrentMapID() then return 0, 0, false end
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

function Tooltips.Filter()
    local State    = ns.ZoneFilter.State
    local Apply    = ns.ZoneFilter.Apply
    local UI       = ns.ZoneFilter.UI
    local active   = State.GetFilterActive()
    local dirty    = State.IsDirty()
    local lastMode = State.GetLastMode and State.GetLastMode()
    local nonZone  = lastMode and lastMode ~= "zoneFilter"

    -- State-centric headline. The button's identity (it's the lens =
    -- zone-filter action) is implicit from the click-prediction body
    -- below; the headline answers "what's the filter doing right now?".
    -- Colour matches the lens dot state for visual consistency.
    local titleText, tr, tg, tb
    if not active then
        titleText  = "No filter"
        tr, tg, tb = 1, 0.82, 0       -- default tooltip gold
    elseif dirty then
        local modeLabel = (UI.MODE_DISPLAY[lastMode] or lastMode) or "active"
        local addN      = State.GetDriftAddCount()
        local rmN       = State.GetDriftRemoveCount and State.GetDriftRemoveCount() or 0
        local driftStr
        if addN > 0 and rmN > 0 then driftStr = string.format("%d added, %d removed", addN, rmN)
        elseif addN > 0           then driftStr = string.format("%d added",            addN)
        else                            driftStr = string.format("%d removed",          rmN) end
        titleText  = string.format("Filter: %s (%s)", modeLabel, driftStr)
        tr, tg, tb = 1.0, 0.55, 0.15  -- orange (drift)
    else
        local modeLabel = (UI.MODE_DISPLAY[lastMode] or lastMode) or "active"
        titleText  = string.format("Filter: %s", modeLabel)
        tr, tg, tb = 0.40, 1.0, 0.40  -- green (clean)
    end
    GameTooltip:SetText(titleText, tr, tg, tb)
    -- Widen so warning-suffixed lines and the legend don't wrap.
    if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(280) end

    -- Short description below the headline only when inactive — gives
    -- new users orientation. Once a filter is active, this would be
    -- redundant with the click-prediction lines below.
    if not active then
        GameTooltip:AddLine("Narrow your watch list to quests with objectives in this zone.",
            0.75, 0.75, 0.75, true)
    end

    -- 3. Click predictions.
    --
    -- Format (consistent across active/inactive/non-zone):
    --   |cffff9919Left-Click|r: Focus current zone (-N) (T tracked) [WARN]
    --   |cffff9919Shift-Left-Click|r: Focus current zone + add from log (-N / +M) (T tracked) [WARN]
    --
    -- Colours: light orange "hint-keyword" prefix (matches NosyKeys /
    -- Broker_PlayerCoords tooltip convention), red -N, green +M, grey
    -- "(T tracked)". WARN_ICON appended only when T == 0.
    GameTooltip:AddLine(" ")
    local untrack, promote, mapKnown = PredictFilterDelta()
    local anyZeroResult = false

    local KEY_BINDING = "|cffff9919%s|r"

    local function FormatDelta(untrackN, promoteN)
        if untrackN == 0 and promoteN == 0 then
            return "|cffaaaaaa(no changes)|r"
        end
        local parts = {}
        if untrackN > 0 then parts[#parts+1] = string.format("|cffff7777-%d|r", untrackN) end
        if promoteN > 0 then parts[#parts+1] = string.format("|cff77ff77+%d|r", promoteN) end
        return "(" .. table.concat(parts, " / ") .. ")"
    end

    if not mapKnown then
        GameTooltip:AddLine("|cffaaaaaaCurrent zone unknown — open the world map once.|r",
            1, 1, 1, true)
    else
        local clickCount = Apply.CountForFilter and Apply.CountForFilter(false) or 0
        local shiftCount = Apply.CountForFilter and Apply.CountForFilter(true)  or 0
        local clickWarn  = (clickCount == 0) and (" " .. UI.WARN_ICON) or ""
        local shiftWarn  = (shiftCount == 0) and (" " .. UI.WARN_ICON) or ""
        if clickCount == 0 or shiftCount == 0 then anyZeroResult = true end

        -- Plain left-click: narrow only (no promote).
        GameTooltip:AddLine(string.format("%s: Focus current zone %s |cffaaaaaa(%d tracked)|r%s",
            string.format(KEY_BINDING, "Left-Click"),
            FormatDelta(untrack, 0),
            clickCount,
            clickWarn), 1, 1, 1, false)

        -- Shift-left-click: narrow + add zone quests from the log.
        GameTooltip:AddLine(string.format("%s: Focus current zone + add from log %s |cffaaaaaa(%d tracked)|r%s",
            string.format(KEY_BINDING, "Shift-Left-Click"),
            FormatDelta(untrack, promote),
            shiftCount,
            shiftWarn), 1, 1, 1, false)
    end

    -- 4. Re-apply hint.
    if nonZone and dirty then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaaThe |cff44ff44green button|r|cffaaaaaa re-applies the current mode.|r",
            1, 1, 1, false)
    end

    -- 5. Warning legend.
    if anyZeroResult then
        GameTooltip:AddLine(UI.WARN_ICON .. " |cffaaaaaa= tracker would hide|r", 1, 1, 1, false)
    end

    -- 6. Hotkeys.
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaaRight-click: mode menu  |  Shift-Right: settings|r", 1, 1, 1, false)
end

function Tooltips.Revert()
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

function Tooltips.Reapply()
    local State = ns.ZoneFilter.State
    local UI    = ns.ZoneFilter.UI
    local lastMode = State.GetLastMode and State.GetLastMode()
    GameTooltip:SetText("Re-apply tracker mode", 1, 0.82, 0)
    if lastMode then
        GameTooltip:AddLine(string.format("|cffaaaaaaCurrent mode: %s|r",
            UI.MODE_DISPLAY[lastMode] or lastMode), 1, 1, 1, true)
        GameTooltip:AddLine("Clears drift and re-applies the selected mode.", 1, 1, 1, true)
    else
        GameTooltip:AddLine("|cffaaaaaaNo mode active.|r", 1, 1, 1, true)
    end
end
