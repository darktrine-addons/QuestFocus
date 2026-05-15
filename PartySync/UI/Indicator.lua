-- PartySync/UI/Indicator.lua — addon-owned indicator-dot frame pool.
--
-- SetState is the central visual applier — it reads size / shape /
-- palette / opacity from ns.Config and writes them to the frame's
-- texture. Acquire just hands out frames; the caller (MountTracker)
-- decides where to anchor them. Live setting changes are picked up by
-- the next SetState call (per-indicator-per-refresh), so the Settings
-- panel's ValueChanged callbacks just need to trigger MountTracker.Refresh.
--
-- Shapes:
--   square  — solid ColorTexture, no rotation
--   diamond — same texture rotated 45°. Visual extent is the inscribed
--             square (~71% of the frame), no texture-path dependency.
--
-- Palettes:
--   default      — green / yellow / blue / orange per design §4.2
--   deuteranopia — red-green-friendly: green → cyan, orange → magenta
--   tritanopia   — blue-yellow-friendly: blue → purple, yellow → red
--
-- `nil` / unknown state → frame hidden.

local addonName, ns = ...
ns.PartySync    = ns.PartySync    or {}
ns.PartySync.UI = ns.PartySync.UI or {}
local Indicator = {}
ns.PartySync.UI.Indicator = Indicator

local PALETTES = {
    default = {
        ready_turn_in   = { 0.35, 0.70, 1.00 },
        alone_shareable = { 1.00, 0.55, 0.15 },
        mixed           = { 1.00, 0.85, 0.20 },
        aligned         = { 0.40, 1.00, 0.40 },
    },
    deuteranopia = {
        ready_turn_in   = { 0.35, 0.70, 1.00 },  -- blue (kept)
        alone_shareable = { 1.00, 0.20, 0.80 },  -- magenta
        mixed           = { 1.00, 0.85, 0.20 },  -- yellow (kept)
        aligned         = { 0.20, 1.00, 0.85 },  -- cyan
    },
    tritanopia = {
        ready_turn_in   = { 0.65, 0.30, 1.00 },  -- purple
        alone_shareable = { 1.00, 0.55, 0.15 },  -- orange (kept)
        mixed           = { 1.00, 0.30, 0.30 },  -- red
        aligned         = { 0.40, 1.00, 0.40 },  -- green (kept)
    },
}

local pool = {}

local function NewFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("MEDIUM")
    local tex = f:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    f.tex = tex
    f:Hide()
    return f
end

local function Conf(key, fallback)
    if ns.Config and ns.Config.GetPartySyncSetting then
        local v = ns.Config.GetPartySyncSetting(key)
        if v ~= nil then return v end
    end
    return fallback
end

function Indicator.Acquire()
    local f = table.remove(pool) or NewFrame()
    -- Click-through; dots don't intercept hover from the underlying
    -- tracker block.
    f:EnableMouse(false)
    f:Show()
    return f
end

function Indicator.Release(f)
    if not f then return end
    f:Hide()
    f:ClearAllPoints()
    f:SetParent(UIParent)
    f.tex:SetRotation(0)  -- reset for next use
    table.insert(pool, f)
end

function Indicator.SetState(f, state)
    if not f then return end

    local size    = Conf("indicatorSize",    8)
    local shape   = Conf("indicatorShape",   "square")
    local palette = Conf("palette",          "default")
    local opacity = Conf("indicatorOpacity", 1.0)

    local pal   = PALETTES[palette] or PALETTES.default
    local color = pal[state]
    if not color then
        f:Hide()
        return
    end

    f:SetSize(size, size)
    f.tex:SetColorTexture(color[1], color[2], color[3], opacity)
    f.tex:SetRotation(shape == "diamond" and math.rad(45) or 0)
    f:Show()
end

function Indicator.PoolSize()
    return #pool
end
