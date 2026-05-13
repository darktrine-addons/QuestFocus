-- Core/Config.lua — shared module-toggle scaffold.
--
-- Slice 0 stub: provides the `ns.Config` table so future slices (and
-- future modules) can register against a stable entry point. The
-- `IsModuleEnabled` accessor returns true for every name in this stub
-- — actual SavedVars-backed gating lands in slice 1.

local addonName, ns = ...
ns.Config = ns.Config or {}

function ns.Config.IsModuleEnabled(name)
    return true
end
