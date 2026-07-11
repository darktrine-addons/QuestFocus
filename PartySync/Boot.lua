-- PartySync/Boot.lua — module entry point.
--
-- Called by QuestFocus.lua's bootstrap dispatcher on PLAYER_ENTERING_WORLD.
-- Early-returns when the module is disabled in Config; otherwise wires
-- the tracker indicator and sets the `booted = true` flag so /qf module
-- list can confirm.
--
-- SetActive(false/true) is the runtime hot-toggle path: releases all
-- indicators on disable, refreshes them on re-enable. (An already-open
-- row tooltip keeps its appended party section until it next hides —
-- the OnShow hook checks the active flag, so no new sections appear.)
-- Used by /qf module disable|enable PartySync so the user doesn't have
-- to /reload to apply the toggle.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}

function ns.PartySync.Boot()
    if not ns.Config or not ns.Config.IsModuleEnabled("PartySync") then return end
    ns.PartySync.active = true
    ns.PartySync.booted = true
    if ns.PartySync.UI and ns.PartySync.UI.MountTracker then
        ns.PartySync.UI.MountTracker.Mount()
    end
end

function ns.PartySync.SetActive(enabled)
    enabled = enabled and true or false
    if ns.PartySync.active == enabled then return end
    ns.PartySync.active = enabled

    local MountTracker = ns.PartySync.UI and ns.PartySync.UI.MountTracker

    if not enabled then
        if MountTracker and MountTracker.ReleaseAllIndicators then
            MountTracker.ReleaseAllIndicators()
        end
    else
        -- Mount if it never wired up before (e.g. user re-enables a module
        -- that started disabled). Otherwise Refresh re-populates from
        -- the live tracker.
        if MountTracker then
            if MountTracker.Mount then MountTracker.Mount() end
            if MountTracker.Refresh then MountTracker.Refresh() end
        end
    end
end
