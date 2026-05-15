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

    -- 1. Title.
    GameTooltip:SetText("Focus (zone filter)", 1, 0.82, 0)
    -- Widen so warning-suffixed lines and the legend don't wrap.
    if GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(280) end

    -- 2. State: mode + drift in one line.
    if not active then
        GameTooltip:AddLine("Narrow your watch list to quests with objectives in this zone.",
            0.75, 0.75, 0.75, true)
    else
        local modeLabel = (lastMode and (UI.MODE_DISPLAY[lastMode] or lastMode)) or "active"
        if dirty then
            local addN = State.GetDriftAddCount()
            local rmN  = State.GetDriftRemoveCount and State.GetDriftRemoveCount() or 0
            local driftStr
            if addN > 0 and rmN > 0 then
                driftStr = string.format("%d added / %d removed", addN, rmN)
            elseif addN > 0 then
                driftStr = string.format("%d added", addN)
            else
                driftStr = string.format("%d removed", rmN)
            end
            GameTooltip:AddLine(string.format("Mode: |cffffcc00%s|r — |cffff8c26%s since|r",
                modeLabel, driftStr), 1, 1, 1, true)
        else
            GameTooltip:AddLine(string.format("Mode: |cffffcc00%s|r — |cff44ff44clean|r", modeLabel),
                1, 1, 1, true)
        end
    end

    -- 3. Click predictions.
    GameTooltip:AddLine(" ")
    local untrack, promote, mapKnown = PredictFilterDelta()
    local anyZeroResult = false

    if not mapKnown then
        GameTooltip:AddLine("|cffaaaaaaCurrent zone unknown — open the world map once.|r",
            1, 1, 1, true)
    else
        local clickCount = Apply.CountForFilter and Apply.CountForFilter(false) or 0
        local shiftCount = Apply.CountForFilter and Apply.CountForFilter(true)  or 0
        local clickWarn  = (clickCount == 0) and (" " .. UI.WARN_ICON) or ""
        local shiftWarn  = (shiftCount == 0) and (" " .. UI.WARN_ICON) or ""
        if clickCount == 0 or shiftCount == 0 then anyZeroResult = true end

        if nonZone then
            GameTooltip:AddLine(string.format("Click: switch to zone -> |cffaaaaaa%d watched|r%s",
                clickCount, clickWarn), 1, 1, 1, false)
            GameTooltip:AddLine(string.format("Shift: zone + promote log -> |cffaaaaaa%d watched|r%s",
                shiftCount, shiftWarn), 1, 1, 1, false)
        else
            if untrack == 0 then
                GameTooltip:AddLine("Click: |cffaaaaaano changes|r", 1, 1, 1, false)
            else
                GameTooltip:AddLine(string.format("Click: -%d -> |cffaaaaaa%d watched|r%s",
                    untrack, clickCount, clickWarn), 1, 1, 1, false)
            end
            if untrack == 0 and promote == 0 then
                GameTooltip:AddLine("Shift: |cffaaaaaano changes|r", 1, 1, 1, false)
            elseif promote == 0 then
                GameTooltip:AddLine(string.format("Shift: -%d -> |cffaaaaaa%d watched|r%s",
                    untrack, shiftCount, shiftWarn), 1, 1, 1, false)
            elseif untrack == 0 then
                GameTooltip:AddLine(string.format("Shift: +%d -> |cffaaaaaa%d watched|r%s",
                    promote, shiftCount, shiftWarn), 1, 1, 1, false)
            else
                GameTooltip:AddLine(string.format("Shift: -%d / +%d -> |cffaaaaaa%d watched|r%s",
                    untrack, promote, shiftCount, shiftWarn), 1, 1, 1, false)
            end
        end
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
