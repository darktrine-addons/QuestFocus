-- PartySync/Core/State.lua — module state holder (placeholder).
--
-- Slice 2 stub: declares the namespace so future slices have a stable
-- place to land `local_state` / `party_state` accessors against. Filled
-- in slice 3 with the parsed-party-progress cache.

local addonName, ns = ...
ns.PartySync = ns.PartySync or {}
ns.PartySync.State = {}
