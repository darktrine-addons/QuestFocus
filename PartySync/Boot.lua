-- PartySync/Boot.lua — module entry point.
--
-- Called by QuestFocus.lua's bootstrap dispatcher on PLAYER_ENTERING_WORLD.
-- Early-returns when the module is disabled in Config; otherwise wires
-- the tracker indicator and sets the `booted = true` flag so /qf module
-- list can confirm.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}

function ns.PartySync.Boot()
    if not ns.Config or not ns.Config.IsModuleEnabled("PartySync") then return end
    ns.PartySync.booted = true
    if ns.PartySync.UI and ns.PartySync.UI.MountTracker then
        ns.PartySync.UI.MountTracker.Mount()
    end
end
