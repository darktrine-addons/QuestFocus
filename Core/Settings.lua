-- Core/Settings.lua — native AddOn settings panel.
--
-- One QuestFocus category under Settings → AddOns, with sections for
-- Global (module toggles + Reload UI) and PartySync (visual settings +
-- on-tracker preview). Module enable checkboxes are bound directly to
-- QuestFocusDB.modules.<name> tables so slash commands and the panel
-- write the same SV keys.
--
-- PartySync's enable checkbox hot-toggles via ns.PartySync.SetActive
-- on ValueChanged, mirroring `/qf module disable|enable PartySync`.
-- ZoneFilter still requires /reload (its frame-attached buttons can't
-- cleanly tear themselves down without one) and the checkbox tooltip
-- says so.

local addonName, ns = ...
local L = ns.L

ns.Settings = ns.Settings or {}

local registered     = false
local categoryRef    = nil   -- the category object, kept for OpenToCategory

-- Effective values snapshot — what the running session is using. Filled
-- at Register() time and re-snapshotted on /reload. A panel checkbox
-- is "dirty" when its current SV value differs from the effective
-- snapshot for the same key. The Reload button uses HasReloadDirty()
-- to gate its enabled state.
local effective      = {}

-- ============================================================
-- Style preview surfaces
-- ============================================================
--
-- Two complementary views into "what will my indicator dots look
-- like?":
--
-- 1. Inline permanent preview — a small static row inside the
--    QuestFocus settings page (top-right of the right pane). Always
--    visible while the page is open. Updates the moment any visual
--    setting changes.
--
-- 2. On-tracker preview ("Preview indicators" button) — temporarily
--    attaches up to 4 demo dots to actual tracker rows for in-context
--    review. Truncates to N if fewer than 4 quests are watched. No-op
--    (with chat message) when nothing is watched. 30 s timer; re-click
--    extends.

local PREVIEW_STATES     = { "aligned", "mixed", "ready_turn_in", "alone_shareable" }
local PREVIEW_LABEL_TEXT = { L.PREVIEW_ALIGNED, L.PREVIEW_MIXED, L.PREVIEW_READY, L.PREVIEW_SHAREABLE }
local PREVIEW_TOOLTIPS   = {
    L.PREVIEW_TIP_ALIGNED,
    L.PREVIEW_TIP_MIXED,
    L.PREVIEW_TIP_READY,
    L.PREVIEW_TIP_SHAREABLE,
}
local PREVIEW_DURATION   = 30

-- ------------------------------------------------------------
-- Inline permanent preview: a layout-flow row containing 4 demo dots
-- with labels and hover tooltips. Built as a custom initializer wrapping
-- SettingsListSectionHeaderTemplate so the framework handles category-
-- visibility for us automatically.
-- ------------------------------------------------------------

local inlinePreviewDots = {}       -- addon-owned demo dots, built once
local inlinePreviewContainer       -- addon-owned frame holding bg + dots
local hookedHeaderFrames = setmetatable({}, { __mode = "k" })

-- Taint / pool posture: the section-header frame the initializer hands
-- us is a Blizzard-owned POOLED frame — it gets recycled for other
-- rows (including other addons' categories) when the settings list
-- rebuilds. We therefore never write fields or create children on it.
-- Everything lives on our own container frame, which is re-parented
-- onto the current header frame at InitFrame time and detached again
-- when that frame hides (release back to the pool / panel close).
local function EnsureInlinePreviewContainer()
    if inlinePreviewContainer then return inlinePreviewContainer end

    local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
    if not Indicator or not Indicator.Acquire then return nil end

    local c = CreateFrame("Frame", nil, UIParent)
    c:Hide()

    -- Background rectangle making the row feel like its own panel.
    local bg = c:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.25)
    bg:SetAllPoints()

    local prevDot
    for i, state in ipairs(PREVIEW_STATES) do
        local d = Indicator.Acquire()
        d:SetParent(c)
        d:ClearAllPoints()
        if prevDot then
            d:SetPoint("LEFT", prevDot, "RIGHT", 70, 0)
        else
            -- Dot row sits ~16 px inside the background.
            d:SetPoint("TOPLEFT", c, "TOPLEFT", 32, -12)
        end
        Indicator.SetState(d, state)
        inlinePreviewDots[i] = d
        prevDot = d

        -- One-word legend under each dot.
        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOP", d, "BOTTOM", 0, -3)
        lbl:SetText(PREVIEW_LABEL_TEXT[i])

        -- Hover tooltip with longer explanation. Enable mouse on the
        -- dot so it can fire OnEnter — Indicator.Acquire disables it
        -- for tracker use, so we re-enable for the preview row.
        d:EnableMouse(true)
        local tooltipTitle = PREVIEW_LABEL_TEXT[i]
        local tooltipBody  = PREVIEW_TOOLTIPS[i]
        d:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipTitle, 1, 0.82, 0)
            GameTooltip:AddLine(tooltipBody, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        d:SetScript("OnLeave", GameTooltip_Hide)
    end

    inlinePreviewContainer = c
    return c
end

local function DetachInlinePreview()
    local c = inlinePreviewContainer
    if not c then return end
    c:Hide()
    c:ClearAllPoints()
    c:SetParent(UIParent)
end

local function AttachInlinePreview(frame)
    local c = EnsureInlinePreviewContainer()
    if not c then return end
    c:SetParent(frame)
    c:ClearAllPoints()
    -- Starts ~36 px below the title to leave space between section
    -- heading and the dot row.
    c:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -36)
    c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)
    c:Show()

    -- Detach when this pooled frame hides (released back to the pool or
    -- the panel closes) so the preview can never bleed into whatever
    -- row the frame is recycled for next. HookScript only; weak-keyed
    -- side-table prevents double-hooking a frame we've seen before.
    if not hookedHeaderFrames[frame] then
        hookedHeaderFrames[frame] = true
        frame:HookScript("OnHide", function(self)
            if inlinePreviewContainer and inlinePreviewContainer:GetParent() == self then
                DetachInlinePreview()
            end
        end)
    end
end

local function RefreshInlinePreview()
    local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
    if not Indicator or not Indicator.SetState then return end
    for i, dot in ipairs(inlinePreviewDots) do
        Indicator.SetState(dot, PREVIEW_STATES[i])
    end
end

-- Build a layout initializer for the preview row. Uses the section-
-- header template as a base so we get free category-visibility +
-- styling, then extends it with our dots / labels / tooltips. Returns
-- nil if the framework can't satisfy the request — caller skips the
-- row gracefully (preview just doesn't appear).
local function MakeInlinePreviewInitializer()
    if not Settings or not Settings.CreateElementInitializer then return nil end
    local data = { name = L.SETTING_STYLE_PREVIEW }
    local init = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", data)
    if not init then return nil end
    init.GetExtent = function() return 90 end
    local origInitFrame = init.InitFrame
    init.InitFrame = function(self, frame)
        if origInitFrame then origInitFrame(self, frame) end
        AttachInlinePreview(frame)
    end
    return init
end

-- ------------------------------------------------------------
-- On-tracker preview button
-- ------------------------------------------------------------

local trackerPreviewDots = {}
local trackerPreviewExpiresAt
local trackerPreviewTicker
local trackerPanelHideHooked = false

local function ReleaseTrackerPreview()
    local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
    if Indicator and Indicator.Release then
        for _, d in ipairs(trackerPreviewDots) do Indicator.Release(d) end
    end
    wipe(trackerPreviewDots)
    if trackerPreviewTicker then trackerPreviewTicker:Cancel() end
    trackerPreviewTicker    = nil
    trackerPreviewExpiresAt = nil
end

local function PickVisibleBlocks(maxN)
    local MT = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.MountTracker
    if not MT or not MT.GetVisibleBlocks then return {}, 0 end
    local visible = MT.GetVisibleBlocks()
    local qids = {}
    for qid in pairs(visible) do qids[#qids+1] = qid end
    table.sort(qids)
    local result = {}
    for i = 1, math.min(maxN, #qids) do
        result[i] = visible[qids[i]]
    end
    return result, #qids
end

local function ShowOrExtendPreview()
    local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
    local MT        = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.MountTracker
    if not Indicator or not MT then return end

    -- Re-click while running: just extend the timer.
    if trackerPreviewExpiresAt then
        trackerPreviewExpiresAt = GetTime() + PREVIEW_DURATION
        return
    end

    local blocks, total = PickVisibleBlocks(#PREVIEW_STATES)
    if total == 0 then
        print("|cffffcc00QuestFocus|r " .. L.CHAT_NOTHING_TO_PREVIEW)
        return
    end

    for i, block in ipairs(blocks) do
        local f = Indicator.Acquire()
        f:SetParent(block)
        if MT.ApplyAnchorToBlock then MT.ApplyAnchorToBlock(f, block) end
        Indicator.SetState(f, PREVIEW_STATES[i])
        trackerPreviewDots[i] = f
    end

    trackerPreviewExpiresAt = GetTime() + PREVIEW_DURATION
    trackerPreviewTicker = C_Timer.NewTicker(1, function()
        if not trackerPreviewExpiresAt then return end
        if GetTime() >= trackerPreviewExpiresAt then
            ReleaseTrackerPreview()
        end
    end)

    if not trackerPanelHideHooked and SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", ReleaseTrackerPreview)
        trackerPanelHideHooked = true
    end
end

local function HasReloadDirty()
    return effective.zoneFilter ~= nil
       and effective.zoneFilter ~= (QuestFocusDB
            and QuestFocusDB.modules
            and QuestFocusDB.modules.ZoneFilter
            and QuestFocusDB.modules.ZoneFilter.enabled)
end

local function HasModernSettingsAPI()
    return Settings
        and Settings.RegisterVerticalLayoutCategory
        and Settings.RegisterAddOnSetting
        and Settings.CreateCheckbox
        and Settings.RegisterAddOnCategory
end

function ns.Settings.Register()
    if registered then return end
    if not HasModernSettingsAPI() then return end

    -- Config.EnsureDB has already run by ADDON_LOADED; the tables
    -- exist. Defensive check anyway.
    QuestFocusDB         = QuestFocusDB or {}
    QuestFocusDB.modules = QuestFocusDB.modules or {}
    QuestFocusDB.modules.ZoneFilter = QuestFocusDB.modules.ZoneFilter or { enabled = true }
    QuestFocusDB.modules.PartySync  = QuestFocusDB.modules.PartySync  or { enabled = true }

    local category, layout = Settings.RegisterVerticalLayoutCategory("QuestFocus")
    categoryRef = category

    -- Snapshot effective values so the Reload button can detect when
    -- a setting that needs /reload has been changed during this session.
    effective.zoneFilter = QuestFocusDB.modules.ZoneFilter.enabled

    local function AddSectionHeader(text)
        if CreateSettingsListSectionHeaderInitializer and layout and layout.AddInitializer then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
        end
    end

    -- ===========================================================
    -- Section: Global
    -- ===========================================================
    AddSectionHeader(L.SECTION_GLOBAL)

    -- ZoneFilter toggle (requires /reload)
    local zfSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_Module_ZoneFilter",
        "enabled",
        QuestFocusDB.modules.ZoneFilter,
        Settings.VarType.Boolean,
        L.SETTING_ZF_ENABLE,
        true)
    Settings.CreateCheckbox(
        category,
        zfSetting,
        L.SETTING_ZF_ENABLE_TIP)

    -- PartySync toggle (hot-toggle)
    local psSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_Module_PartySync",
        "enabled",
        QuestFocusDB.modules.PartySync,
        Settings.VarType.Boolean,
        L.SETTING_PS_ENABLE,
        true)
    Settings.CreateCheckbox(
        category,
        psSetting,
        L.SETTING_PS_ENABLE_TIP)

    psSetting:SetValueChangedCallback(function(setting, value)
        if ns.PartySync and ns.PartySync.SetActive then
            ns.PartySync.SetActive(value)
        end
    end)

    -- Reload UI button — lives in the Global section because the only
    -- needs-/reload setting today is the global ZoneFilter toggle. The
    -- Settings button-initializer API doesn't surface a re-evaluating
    -- enabled-state hook for arbitrary predicates, so we gate the click
    -- instead of greying the button.
    if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
        local reloadInit = CreateSettingsButtonInitializer(
            "",                  -- no left label
            L.SETTING_RELOAD_UI,     -- button text
            function()
                if HasReloadDirty() then
                    ReloadUI()
                else
                    print("|cffffcc00QuestFocus|r " .. L.CHAT_NO_RELOAD_PENDING)
                end
            end,
            L.SETTING_RELOAD_UI_TIP,
            true)
        layout:AddInitializer(reloadInit)
    end

    -- ===========================================================
    -- Section: ZoneFilter (behaviour preferences, per-character)
    -- ===========================================================
    AddSectionHeader(L.SECTION_ZONEFILTER)

    -- D1: per-character "untrack also clears the snapshot".
    QuestFocusCharDB.zoneFilter = QuestFocusCharDB.zoneFilter or {}
    if QuestFocusCharDB.zoneFilter.untrackClearsSnapshot == nil then
        QuestFocusCharDB.zoneFilter.untrackClearsSnapshot = false
    end
    local untrackClearsSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_ZF_UntrackClears",
        "untrackClearsSnapshot",
        QuestFocusCharDB.zoneFilter,
        Settings.VarType.Boolean,
        L.SETTING_ZF_UNTACK_CLEARS,
        false)
    Settings.CreateCheckbox(
        category,
        untrackClearsSetting,
        L.SETTING_ZF_UNTACK_CLEARS_TIP)

    -- Zone-change reminder (nudge, not auto-apply — see ZoneNudge.lua).
    if QuestFocusCharDB.zoneFilter.zoneChangeNudge == nil then
        QuestFocusCharDB.zoneFilter.zoneChangeNudge = true
    end
    local nudgeSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_ZF_ZoneNudge",
        "zoneChangeNudge",
        QuestFocusCharDB.zoneFilter,
        Settings.VarType.Boolean,
        L.SETTING_ZF_ZONE_NUDGE,
        true)
    Settings.CreateCheckbox(
        category,
        nudgeSetting,
        L.SETTING_ZF_ZONE_NUDGE_TIP)

    -- ===========================================================
    -- Section: PartySync (visual settings)
    -- ===========================================================
    AddSectionHeader(L.SECTION_PARTYSYNC)

    local function RefreshIndicators()
        local MT = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.MountTracker
        if MT and MT.Refresh then MT.Refresh() end
        local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
        if not Indicator or not Indicator.SetState then return end

        -- Inline permanent style preview (always-on row in the page).
        RefreshInlinePreview()

        -- On-tracker preview (button-triggered, temporary).
        for i, dot in ipairs(trackerPreviewDots) do
            Indicator.SetState(dot, PREVIEW_STATES[i])
        end
        -- Re-apply anchor for tracker preview when position changes.
        if MT and MT.ApplyAnchorToBlock then
            for _, dot in ipairs(trackerPreviewDots) do
                local block = dot:GetParent()
                if block then MT.ApplyAnchorToBlock(dot, block) end
            end
        end
    end

    -- B1: size
    local sizeSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Size", "indicatorSize",
        QuestFocusDB.partySync, Settings.VarType.Number, L.SETTING_PS_SIZE, 10)
    Settings.CreateDropdown(category, sizeSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add(6,  L.SIZE_TINY)
            c:Add(8,  L.SIZE_SMALL)
            c:Add(10, L.SIZE_MEDIUM)
            c:Add(12, L.SIZE_LARGE)
            return c:GetData()
        end,
        L.SETTING_PS_SIZE_TIP)
    sizeSetting:SetValueChangedCallback(RefreshIndicators)

    -- B2: shape
    local shapeSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Shape", "indicatorShape",
        QuestFocusDB.partySync, Settings.VarType.String, L.SETTING_PS_SHAPE, "circle")
    Settings.CreateDropdown(category, shapeSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("square",  L.SHAPE_SQUARE)
            c:Add("circle",  L.SHAPE_CIRCLE)
            c:Add("diamond", L.SHAPE_DIAMOND)
            return c:GetData()
        end,
        L.SETTING_PS_SHAPE_TIP)
    shapeSetting:SetValueChangedCallback(RefreshIndicators)

    -- B3: anchor position
    local anchorSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Anchor", "indicatorAnchor",
        QuestFocusDB.partySync, Settings.VarType.String, L.SETTING_PS_ANCHOR, "leftOfTitle")
    Settings.CreateDropdown(category, anchorSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("topRight",       L.ANCHOR_TOP_RIGHT)
            c:Add("rightOfTitle",   L.ANCHOR_RIGHT_OF_TITLE)
            c:Add("leftOfTitle",    L.ANCHOR_LEFT_OF_TITLE)
            return c:GetData()
        end,
        L.SETTING_PS_ANCHOR_TIP)
    anchorSetting:SetValueChangedCallback(RefreshIndicators)

    -- B4: palette (colour-vision options)
    local paletteSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Palette", "palette",
        QuestFocusDB.partySync, Settings.VarType.String, L.SETTING_PS_PALETTE, "default")
    Settings.CreateDropdown(category, paletteSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("default",      L.PALETTE_DEFAULT)
            c:Add("deuteranopia", L.PALETTE_DEUTERANOPIA)
            c:Add("tritanopia",   L.PALETTE_TRITANOPIA)
            return c:GetData()
        end,
        L.SETTING_PS_PALETTE_TIP)
    paletteSetting:SetValueChangedCallback(RefreshIndicators)

    -- B5: opacity
    local opacitySetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Opacity", "indicatorOpacity",
        QuestFocusDB.partySync, Settings.VarType.Number, L.SETTING_PS_OPACITY, 1.0)
    local opacityOptions = Settings.CreateSliderOptions(0.4, 1.0, 0.1)
    if opacityOptions.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        opacityOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    end
    Settings.CreateSlider(category, opacitySetting, opacityOptions,
        L.SETTING_PS_OPACITY_TIP)
    opacitySetting:SetValueChangedCallback(RefreshIndicators)

    -- D5: raid threshold — summarize per-member tooltip in large groups.
    local raidThresholdSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_RaidThreshold", "raidThreshold",
        QuestFocusDB.partySync, Settings.VarType.Number, L.SETTING_PS_RAID_THRESHOLD, 10)
    Settings.CreateDropdown(category, raidThresholdSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add(0,  L.RAID_ALWAYS)
            c:Add(10, L.RAID_AT_10)
            c:Add(20, L.RAID_AT_20)
            return c:GetData()
        end,
        L.SETTING_PS_RAID_THRESHOLD_TIP)

    -- Inline permanent style preview — a layout-flow row between the
    -- visual settings and the Preview-on-tracker button.
    if layout and layout.AddInitializer then
        local previewInit = MakeInlinePreviewInitializer()
        if previewInit then layout:AddInitializer(previewInit) end
    end

    -- Solo preview button — sits at the bottom of the PartySync section.
    -- Surfaces a row of 4 demo indicators either on the first 4 tracker
    -- rows (WYSIWYG) or free-floating above the panel as a fallback.
    -- 30 s timer; re-click extends.
    if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
        local previewInit = CreateSettingsButtonInitializer(
            "",
            L.SETTING_PREVIEW_TRACKER,
            ShowOrExtendPreview,
            L.SETTING_PREVIEW_TRACKER_TIP,
            true)
        layout:AddInitializer(previewInit)
    end

    Settings.RegisterAddOnCategory(category)
    registered = true
end

function ns.Settings.Open()
    if not categoryRef then return end
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(categoryRef:GetID())
    end
end
