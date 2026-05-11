-- ButtonTracker.lua — host module: mounts the filter/revert pair next to the
-- objective tracker's minimize button.
--
-- Parent is ObjectiveTrackerFrame.Header (modern retail) so the pair inherits
-- visibility (hidden when nothing is tracked) and follows Edit Mode movement.

local addonName, ns = ...
ns.UI = ns.UI or {}

local mounted = false

local function FindAnchor()
    local OT = ObjectiveTrackerFrame
    if not OT then return nil, nil end
    if OT.Header     and OT.Header.MinimizeButton     then return OT.Header,     OT.Header.MinimizeButton     end
    if OT.HeaderMenu and OT.HeaderMenu.MinimizeButton then return OT.HeaderMenu, OT.HeaderMenu.MinimizeButton end
    if OT.MinimizeButton                              then return OT,            OT.MinimizeButton            end
    return nil, nil
end

local function Mount()
    if mounted then return true end
    local parent, anchor = FindAnchor()
    if not parent or not anchor then return false end

    local inst = ns.UI.MakePair(parent)
    inst.filterBtn:SetPoint("RIGHT", anchor, "LEFT", -4, 0)

    mounted = true
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
