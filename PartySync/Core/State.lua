-- PartySync/Core/State.lua — placeholder for future per-session state
-- (party action history, accept-recency cache, etc.). Currently just
-- declares the namespace so the module structure is consistent with
-- ZoneFilter.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}
ns.PartySync.State = {}
