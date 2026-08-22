-- ZoneFilter/UI/Buttons/Tooltips.lua — GameTooltip renderers for the
-- filter / revert / re-apply buttons. Pure presentation: each function
-- reads State + Apply, calls GameTooltip:AddLine. Factory wires them
-- as the OnEnter callbacks on the respective buttons.

local addonName, ns = ...
local L = ns.L
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
        titleText  = L.TIP_NO_FILTER
        tr, tg, tb = 1, 0.82, 0       -- default tooltip gold
    elseif dirty then
        local modeLabel = (UI.MODE_DISPLAY[lastMode] or lastMode) or L.MODE_ACTIVE
        local addN      = State.GetDriftAddCount()
        local rmN       = State.GetDriftRemoveCount and State.GetDriftRemoveCount() or 0
        local driftStr
        if addN > 0 and rmN > 0 then driftStr = string.format(L.TIP_DRIFT_BOTH, addN, rmN)
        elseif addN > 0           then driftStr = string.format(L.TIP_DRIFT_ADDED,  addN)
        else                            driftStr = string.format(L.TIP_DRIFT_REMOVED, rmN) end
        titleText  = string.format(L.TIP_FILTER_DRIFT, modeLabel, driftStr)
        tr, tg, tb = 1.0, 0.55, 0.15  -- orange (drift)
    else
        local modeLabel = (UI.MODE_DISPLAY[lastMode] or lastMode) or L.MODE_ACTIVE
        titleText  = string.format(L.TIP_FILTER_CLEAN, modeLabel)
        tr, tg, tb = 0.40, 1.0, 0.40  -- green (clean)
    end
    GameTooltip:SetText(titleText, tr, tg, tb)
    -- Widen so warning-suffixed lines and the legend don't wrap.
    if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(280) end

    -- Short description below the headline only when inactive — gives
    -- new users orientation. Once a filter is active, this would be
    -- redundant with the click-prediction lines below.
    if not active then
        GameTooltip:AddLine(L.TIP_NARROW_DESC,
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
            return "|cffaaaaaa" .. L.TIP_NO_CHANGES .. "|r"
        end
        local parts = {}
        if untrackN > 0 then parts[#parts+1] = string.format("|cffff7777-%d|r", untrackN) end
        if promoteN > 0 then parts[#parts+1] = string.format("|cff77ff77+%d|r", promoteN) end
        return "(" .. table.concat(parts, " / ") .. ")"
    end

    if not mapKnown then
        GameTooltip:AddLine("|cffaaaaaa" .. L.TIP_MAP_UNKNOWN .. "|r",
            1, 1, 1, true)
    else
        local clickCount = Apply.CountForFilter and Apply.CountForFilter(false) or 0
        local shiftCount = Apply.CountForFilter and Apply.CountForFilter(true)  or 0
        local clickWarn  = (clickCount == 0) and (" " .. UI.WARN_ICON) or ""
        local shiftWarn  = (shiftCount == 0) and (" " .. UI.WARN_ICON) or ""
        if clickCount == 0 or shiftCount == 0 then anyZeroResult = true end

        -- Plain left-click: narrow only (no promote).
        GameTooltip:AddLine(string.format(L.TIP_FOCUS_LINE,
            string.format(KEY_BINDING, L.TIP_KEY_LEFT_CLICK),
            FormatDelta(untrack, 0),
            clickCount,
            clickWarn), 1, 1, 1, false)

        -- Shift-left-click: narrow + add zone quests from the log.
        GameTooltip:AddLine(string.format(L.TIP_FOCUS_ADD_LINE,
            string.format(KEY_BINDING, L.TIP_KEY_SHIFT_LEFT_CLICK),
            FormatDelta(untrack, promote),
            shiftCount,
            shiftWarn), 1, 1, 1, false)
    end

    -- 4. Re-apply hint.
    if nonZone and dirty then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffaaaaaa" .. L.TIP_REAPPLY_HINT,
            1, 1, 1, false)
    end

    -- 5. Warning legend.
    if anyZeroResult then
        GameTooltip:AddLine(UI.WARN_ICON .. " |cffaaaaaa" .. L.TIP_WARN_LEGEND .. "|r", 1, 1, 1, false)
    end

    -- 6. Hotkeys.
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffaaaaaa" .. L.TIP_HOTKEYS .. "|r", 1, 1, 1, false)
end

function Tooltips.Revert()
    local State = ns.ZoneFilter.State
    GameTooltip:SetText(L.TIP_RESTORE_TITLE, 1, 0.82, 0)
    if not State.GetFilterActive() then
        GameTooltip:AddLine(L.TIP_NOTHING_TO_RESTORE, 1, 1, 1, true)
        return
    end
    local restoreCount = State.GetRevertAddCount()
    local keepCount    = State.GetDriftAddCount()
    if restoreCount > 0 then
        GameTooltip:AddLine(string.format(L.TIP_RESTORES_N, restoreCount), 1, 1, 1, true)
    end
    if keepCount > 0 then
        GameTooltip:AddLine(string.format(L.TIP_KEEPS_N, keepCount), 1, 1, 1, true)
    end
    if restoreCount == 0 and keepCount == 0 then
        GameTooltip:AddLine(L.TIP_CLEARS_FILTER, 1, 1, 1, true)
    end
end

function Tooltips.Reapply()
    local State = ns.ZoneFilter.State
    local UI    = ns.ZoneFilter.UI
    local lastMode = State.GetLastMode and State.GetLastMode()
    GameTooltip:SetText(L.TIP_REAPPLY_TITLE, 1, 0.82, 0)
    if lastMode then
        GameTooltip:AddLine(string.format("|cffaaaaaa" .. L.TIP_CURRENT_MODE .. "|r",
            UI.MODE_DISPLAY[lastMode] or lastMode), 1, 1, 1, true)
        GameTooltip:AddLine(L.TIP_REAPPLY_DESC, 1, 1, 1, true)
    else
        GameTooltip:AddLine("|cffaaaaaa" .. L.TIP_NO_MODE_ACTIVE .. "|r", 1, 1, 1, true)
    end
end
