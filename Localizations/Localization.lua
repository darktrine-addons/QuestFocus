-- Localizations/Localization.lua — localization bootstrap.
-- Builds the L table with a fallback chain: L[key] → enUS value → raw key.
-- Localization files (enUS.lua, …) attach to ns.L_EN after this file runs.

local addonName, ns = ...
local EN = {}
local L = setmetatable({}, { __index = function(_, k) return rawget(EN, k) or k end })
ns.L    = L
ns.L_EN = EN