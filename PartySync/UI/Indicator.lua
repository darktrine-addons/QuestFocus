-- PartySync/UI/Indicator.lua — addon-owned indicator-dot frame pool.
--
-- De-risks the tracker integration (slice 6) by separating "draw a
-- coloured dot somewhere" from "find the right place to draw it." This
-- file owns nothing on Blizzard frames — it just gives slice 6 a clean
-- Acquire/Release pool of indicator widgets keyed on questID.
--
-- Colour palette from design/QuestFocusParty.md §4.2:
--   blue   (ready_turn_in)   = (0.35, 0.70, 1.00)
--   orange (alone_shareable) = (1.00, 0.55, 0.15)
--   yellow (mixed)           = (1.00, 0.85, 0.20)
--   green  (aligned)         = (0.40, 1.00, 0.40)
--
-- `nil` / unknown state → frame hidden (no-op render).

local addonName, ns = ...
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local Indicator = {}
ns.PartySync.UI.Indicator = Indicator

local SIZE = 8

local COLOURS = {
    ready_turn_in   = { 0.35, 0.70, 1.00 },
    alone_shareable = { 1.00, 0.55, 0.15 },
    mixed           = { 1.00, 0.85, 0.20 },
    aligned         = { 0.40, 1.00, 0.40 },
}

local pool = {}  -- free list of recycled frames

local function NewFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(SIZE, SIZE)
    f:SetFrameStrata("MEDIUM")
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    f.tex = tex
    f:Hide()
    return f
end

function Indicator.Acquire()
    local f = table.remove(pool)
    if not f then f = NewFrame() end
    f:Show()
    return f
end

function Indicator.Release(f)
    if not f then return end
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    table.insert(pool, f)
end

function Indicator.SetState(f, state)
    if not f then return end
    local c = COLOURS[state]
    if not c then
        f:Hide()
        return
    end
    f.tex:SetColorTexture(c[1], c[2], c[3], 1.0)
    f:Show()
end

function Indicator.PoolSize()
    return #pool
end

-- ============================================================
-- Test slash commands — removed in slice 10 alongside Test/.
-- ============================================================

local testInstances = {}

local function ReleaseAllTest()
    for _, f in ipairs(testInstances) do
        Indicator.Release(f)
    end
    wipe(testInstances)
end

SLASH_QFWIDGETTEST1 = "/qfwidgettest"
SlashCmdList.QFWIDGETTEST = function()
    ReleaseAllTest()
    local states = { "aligned", "mixed", "ready_turn_in", "alone_shareable" }
    for i, state in ipairs(states) do
        local f = Indicator.Acquire()
        f:SetPoint("CENTER", UIParent, "CENTER", -45 + (i - 1) * 30, 0)
        Indicator.SetState(f, state)
        testInstances[#testInstances+1] = f
    end
    print(string.format("|cffffcc00QF widget test|r placed %d indicators (G/Y/B/O); pool free=%d after acquire.",
        #testInstances, Indicator.PoolSize()))
end

SLASH_QFWIDGETCLEAR1 = "/qfwidgetclear"
SlashCmdList.QFWIDGETCLEAR = function()
    ReleaseAllTest()
    print(string.format("|cffffcc00QF widget test|r cleared; pool free=%d.", Indicator.PoolSize()))
end
