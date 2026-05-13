-- PartySync/Boot.lua — module entry point (placeholder).
--
-- Called by QuestFocus.lua's bootstrap dispatcher on PLAYER_ENTERING_WORLD.
-- Early-returns when the module is disabled in Config; otherwise sets the
-- `booted = true` flag so /qf module list can confirm the module wired up.
-- Future slices add Fetch / Aggregate / UI registration past the gate.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}

function ns.PartySync.Boot()
    if not ns.Config or not ns.Config.IsModuleEnabled("PartySync") then return end
    ns.PartySync.booted = true
end
