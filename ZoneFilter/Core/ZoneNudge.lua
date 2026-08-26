-- ZoneFilter/Core/ZoneNudge.lua — soft reminder when the zone filter
-- goes stale.
--
-- Full auto-apply on zone change is a stated non-goal (it silently
-- un-tracks quests the user may still want). This is the middle path:
-- when the ACTIVE mode is zoneFilter and the player enters a new zone
-- where the watch list no longer matches, pulse the lens and print one
-- chat line with a clickable [Re-focus] link. The user keeps agency;
-- the addon stops feeling stale.
--
-- The link uses the `addon:` hyperlink type (no default client
-- behaviour) dispatched through the standard SetItemRef hook.
-- Clicking runs the shift-click equivalent (narrow + add from log) —
-- in a NEW zone, "show me this zone's quests" is the intent, and the
-- link label says what it does.
--
-- Guards: per-char setting (default on), zoneFilter mode only, 10 s
-- cooldown against portal chains / rapid sub-zone hops, skipped in
-- combat, skipped when the watch list already matches the new zone.

local addonName, ns = ...
local L = ns.L
ns.ZoneFilter = ns.ZoneFilter or {}
local ZoneNudge = {}
ns.ZoneFilter.ZoneNudge = ZoneNudge

local COOLDOWN   = 10   -- seconds between nudges
local SETTLE     = 1.5  -- seconds after zone-in before map/POI data is trustworthy
local LINK       = "addon:QuestFocus:refocus"

local lastNudgeAt = 0

local function NudgeEnabled()
    return QuestFocusCharDB
       and QuestFocusCharDB.zoneFilter
       and QuestFocusCharDB.zoneFilter.zoneChangeNudge ~= false  -- default ON
end

local function TryNudge()
    if not (ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")) then return end
    if not NudgeEnabled() then return end
    if InCombatLockdown() then return end

    local State     = ns.ZoneFilter.State
    local Relevance = ns.ZoneFilter.Relevance
    if not State or not State.GetFilterActive() then return end
    if State.GetLastMode() ~= "zoneFilter" then return end
    if not Relevance or not Relevance.GetCurrentMapID() then return end

    if GetTime() - lastNudgeAt < COOLDOWN then return end

    -- Delta vs the new zone: anything to un-track, anything to add?
    -- If the watch list already matches, the filter isn't stale — stay
    -- quiet.
    local relevant = Relevance.GetRelevantQuests()
    local current  = State.GetCurrentWatches()
    local stale, here = 0, 0
    for qid in pairs(current) do
        if not relevant[qid] then stale = stale + 1 end
    end
    for qid in pairs(relevant) do here = here + 1 end
    local addable = 0
    for qid in pairs(relevant) do
        if not current[qid] then addable = addable + 1 end
    end
    if stale == 0 and addable == 0 then return end

    lastNudgeAt = GetTime()

    if ns.ZoneFilter.UI and ns.ZoneFilter.UI.PulseLens then
        ns.ZoneFilter.UI.PulseLens()
    end

    local zone = GetZoneText() or L.CHAT_THIS_ZONE
    print(string.format(
        "|cffffcc00QuestFocus|r " .. L.CHAT_ZONE_CHANGED .. " |H%s|h|cff44ff44%s|r|h",
        zone, here, LINK, L.CHAT_REFOCUS_LINK))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function()
    -- Map/POI relevance data settles asynchronously after a zone-in;
    -- checking immediately under-counts the new zone's quests.
    C_Timer.After(SETTLE, TryNudge)
end)

-- Route clicks on our chat link. `addon:` links have no default client
-- behaviour; hooksecurefunc keeps us taint-clean.
hooksecurefunc("SetItemRef", function(link)
    if link ~= LINK then return end
    if not (ns.Config and ns.Config.IsModuleEnabled("ZoneFilter")) then return end
    if ns.ZoneFilter.Apply and ns.ZoneFilter.Apply.Filter then
        -- Narrow + add from log: in a fresh zone the intent is "show me
        -- this zone's quests", not just "drop the old ones".
        ns.ZoneFilter.Apply.Filter(true)
    end
end)
