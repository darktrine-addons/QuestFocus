-- Core/Settings.lua — native AddOn settings panel scaffold.
--
-- Slice A1 (Phase 2 roadmap): single QuestFocus category at top level
-- under WoW's Settings → AddOns. Two checkboxes for the module enable
-- flags, bound directly to the QuestFocusDB.modules.<name> tables so
-- the slash commands and the panel write the same SV keys.
--
-- PartySync's checkbox hot-toggles via ns.PartySync.SetActive on
-- ValueChanged, mirroring `/qf module disable|enable PartySync`.
-- ZoneFilter still requires /reload (it has frame-attached buttons
-- that can't cleanly tear themselves down) and the checkbox tooltip
-- says so.
--
-- Future slices (Bundle B / Bundle D) add subcategories or extra
-- settings into this same category; the registration function is
-- idempotent.

local addonName, ns = ...
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
-- Solo preview state (slice B): four demo indicators anchored above
-- the settings panel so the user can eyeball size/shape/palette/opacity
-- changes without being in a party. 30 s timer, refreshes on re-click,
-- stops automatically when the settings panel hides.
-- ============================================================

local PREVIEW_STATES     = { "aligned", "mixed", "ready_turn_in", "alone_shareable" }
local PREVIEW_LABEL_TEXT = { "Aligned", "Mixed",  "Ready",        "Shareable"       }
local PREVIEW_SPACING    = 60
local PREVIEW_DURATION   = 30

local previewDots       = {}
local previewLabels     = {}
local previewCountdown  = nil
local previewExpiresAt  = nil
local previewTicker     = nil
local previewMode       = nil   -- "tracker" or "free" while running
local panelHideHooked   = false

local function HidePreview()
    for _, d in ipairs(previewDots) do
        if ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator and ns.PartySync.UI.Indicator.Release then
            ns.PartySync.UI.Indicator.Release(d)
        end
    end
    wipe(previewDots)
    for _, l in ipairs(previewLabels) do l:Hide() end
    wipe(previewLabels)
    if previewCountdown then previewCountdown:Hide() end
    if previewTicker then previewTicker:Cancel() end
    previewTicker    = nil
    previewExpiresAt = nil
    previewMode      = nil
end

local function StartCountdown(anchor, yOffset)
    if not previewCountdown then
        previewCountdown = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    end
    previewCountdown:SetParent(anchor)
    previewCountdown:ClearAllPoints()
    previewCountdown:SetPoint("BOTTOM", anchor, "TOP", 0, yOffset)
    previewCountdown:SetText(string.format("Preview ends in %ds", PREVIEW_DURATION))
    previewCountdown:Show()

    previewExpiresAt = GetTime() + PREVIEW_DURATION
    previewTicker = C_Timer.NewTicker(0.5, function()
        if not previewExpiresAt then return end
        local remaining = previewExpiresAt - GetTime()
        if remaining <= 0 then
            HidePreview()
        elseif previewCountdown then
            previewCountdown:SetText(string.format("Preview ends in %ds", math.ceil(remaining)))
        end
    end)
end

-- Free-floating preview: 4 dots above the settings panel with state
-- labels below each. Used when there aren't enough tracked quests to
-- run a tracker preview.
local function ShowFreePreview()
    previewMode = "free"
    local anchor = SettingsPanel
    if not anchor or not anchor.IsVisible or not anchor:IsVisible() then
        anchor = UIParent
    end

    for i, state in ipairs(PREVIEW_STATES) do
        local f = ns.PartySync.UI.Indicator.Acquire()
        f:SetParent(anchor)
        f:SetFrameStrata("TOOLTIP")
        f:ClearAllPoints()
        local x = (i - 2.5) * PREVIEW_SPACING
        f:SetPoint("BOTTOM", anchor, "TOP", x, 30)
        ns.PartySync.UI.Indicator.SetState(f, state)
        previewDots[i] = f

        local lbl = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOP", f, "BOTTOM", 0, -3)
        lbl:SetText(PREVIEW_LABEL_TEXT[i])
        previewLabels[i] = lbl
    end

    StartCountdown(anchor, 55)
end

-- Tracker preview: attach one demo dot per state to the first 4 visible
-- tracker rows. WYSIWYG — same anchor logic, same row geometry, B3
-- (anchor position) changes show effect.
local function ShowTrackerPreview(blocks)
    previewMode = "tracker"
    local Indicator = ns.PartySync.UI.Indicator
    local MT        = ns.PartySync.UI.MountTracker
    for i, block in ipairs(blocks) do
        local f = Indicator.Acquire()
        f:SetParent(block)
        if MT.ApplyAnchorToBlock then MT.ApplyAnchorToBlock(f, block) end
        Indicator.SetState(f, PREVIEW_STATES[i])
        previewDots[i] = f
    end

    -- Countdown still lives above the settings panel — it's where the
    -- user is looking while tweaking settings.
    local anchor = SettingsPanel
    if not anchor or not anchor.IsVisible or not anchor:IsVisible() then
        anchor = UIParent
    end
    StartCountdown(anchor, 30)
end

-- Pick the first N visible tracker blocks, sorted by questID for
-- deterministic state assignment. Returns the array of blocks and the
-- total count of visible blocks (count >= N means tracker preview is
-- viable).
local function PickFirstNBlocks(n)
    local MT = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.MountTracker
    if not MT or not MT.GetVisibleBlocks then return {}, 0 end
    local visible = MT.GetVisibleBlocks()
    local qids = {}
    for qid in pairs(visible) do qids[#qids+1] = qid end
    table.sort(qids)
    local result = {}
    for i = 1, math.min(n, #qids) do
        result[i] = visible[qids[i]]
    end
    return result, #qids
end

local function ShowOrExtendPreview()
    if not ns.PartySync or not ns.PartySync.UI or not ns.PartySync.UI.Indicator then return end

    -- Already running: just extend the timer.
    if previewExpiresAt then
        previewExpiresAt = GetTime() + PREVIEW_DURATION
        if previewCountdown then
            previewCountdown:SetText(string.format("Preview ends in %ds", PREVIEW_DURATION))
        end
        return
    end

    -- Try tracker preview first (WYSIWYG); fall back to free-floating
    -- when there aren't enough tracked quests to assign one per state.
    local blocks, totalVisible = PickFirstNBlocks(#PREVIEW_STATES)
    if totalVisible >= #PREVIEW_STATES then
        ShowTrackerPreview(blocks)
    else
        ShowFreePreview()
    end

    -- Hook the settings-panel close once. Closing the panel stops the
    -- preview — keeping demo dots running while the panel is invisible
    -- would be confusing.
    if not panelHideHooked and SettingsPanel and SettingsPanel.HookScript then
        SettingsPanel:HookScript("OnHide", HidePreview)
        panelHideHooked = true
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
    AddSectionHeader("Global")

    -- ZoneFilter toggle (requires /reload)
    local zfSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_Module_ZoneFilter",
        "enabled",
        QuestFocusDB.modules.ZoneFilter,
        Settings.VarType.Boolean,
        "Enable ZoneFilter",
        true)
    Settings.CreateCheckbox(
        category,
        zfSetting,
        "Filter your watch list to quests with objectives in the current zone, "
        .. "with one-click revert. Adds two small buttons to the objective tracker "
        .. "and the world-map quest log.\n\n"
        .. "|cffff8c26Requires /reload to apply changes to this checkbox.|r")

    -- PartySync toggle (hot-toggle)
    local psSetting = Settings.RegisterAddOnSetting(
        category,
        "QuestFocus_Module_PartySync",
        "enabled",
        QuestFocusDB.modules.PartySync,
        Settings.VarType.Boolean,
        "Enable PartySync",
        true)
    Settings.CreateCheckbox(
        category,
        psSetting,
        "Coloured indicator dots on each tracked quest row when you're in a party, "
        .. "plus a 'Party state:' section appended to the row's tooltip showing "
        .. "every member's progress.\n\n"
        .. "|cff44ff44Applied immediately.|r")

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
            "Reload UI",         -- button text
            function()
                if HasReloadDirty() then
                    ReloadUI()
                else
                    print("|cffffcc00QuestFocus|r No pending changes require a UI reload.")
                end
            end,
            "Click to /reload when a setting marked 'Requires /reload' has been changed. "
            .. "No-op when nothing is pending.",
            true)
        layout:AddInitializer(reloadInit)
    end

    -- ===========================================================
    -- Section: PartySync (visual settings)
    -- ===========================================================
    AddSectionHeader("PartySync")

    local function RefreshIndicators()
        local MT = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.MountTracker
        if MT and MT.Refresh then MT.Refresh() end
        local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
        if not Indicator or not Indicator.SetState then return end

        -- Push size/shape/palette/opacity to every preview dot.
        for i, dot in ipairs(previewDots) do
            Indicator.SetState(dot, PREVIEW_STATES[i])
        end

        -- For tracker-mode preview, also re-apply the anchor so B3
        -- changes are visible without restarting the preview.
        if previewMode == "tracker" and MT and MT.ApplyAnchorToBlock then
            for _, dot in ipairs(previewDots) do
                local block = dot:GetParent()
                if block then MT.ApplyAnchorToBlock(dot, block) end
            end
        end
    end

    -- B1: size
    local sizeSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Size", "indicatorSize",
        QuestFocusDB.partySync, Settings.VarType.Number, "Indicator size", 10)
    Settings.CreateDropdown(category, sizeSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add(6,  "Tiny (6px)")
            c:Add(8,  "Small (8px)")
            c:Add(10, "Medium (10px)")
            c:Add(12, "Large (12px)")
            return c:GetData()
        end,
        "Diameter of the indicator dot on each tracked quest row.")
    sizeSetting:SetValueChangedCallback(RefreshIndicators)

    -- B2: shape
    local shapeSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Shape", "indicatorShape",
        QuestFocusDB.partySync, Settings.VarType.String, "Indicator shape", "square")
    Settings.CreateDropdown(category, shapeSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("square",  "Square")
            c:Add("diamond", "Diamond")
            return c:GetData()
        end,
        "Shape of the indicator dot. Diamond is the same texture rotated 45°.")
    shapeSetting:SetValueChangedCallback(RefreshIndicators)

    -- B3: anchor position
    local anchorSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Anchor", "indicatorAnchor",
        QuestFocusDB.partySync, Settings.VarType.String, "Indicator position", "leftOfTitle")
    Settings.CreateDropdown(category, anchorSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("topRight",       "Top-right corner")
            c:Add("rightOfTitle",   "Right of title text")
            c:Add("leftOfTitle",    "Left of title text")
            return c:GetData()
        end,
        "Where to place the indicator on each tracker row. 'Left of title' is "
        .. "offset 30px to clear the quest-type icon. Either 'of title' option "
        .. "falls back to the top-right corner when the row's title text isn't found.")
    anchorSetting:SetValueChangedCallback(RefreshIndicators)

    -- B4: palette (colour-vision options)
    local paletteSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Palette", "palette",
        QuestFocusDB.partySync, Settings.VarType.String, "Colour palette", "default")
    Settings.CreateDropdown(category, paletteSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add("default",      "Default (G/Y/B/O)")
            c:Add("deuteranopia", "Deuteranopia (red-green friendly)")
            c:Add("tritanopia",   "Tritanopia (blue-yellow friendly)")
            return c:GetData()
        end,
        "Alternate colour palettes for users with colour-vision differences. "
        .. "Default = green / yellow / blue / orange.")
    paletteSetting:SetValueChangedCallback(RefreshIndicators)

    -- B5: opacity
    local opacitySetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_Opacity", "indicatorOpacity",
        QuestFocusDB.partySync, Settings.VarType.Number, "Indicator opacity", 1.0)
    local opacityOptions = Settings.CreateSliderOptions(0.4, 1.0, 0.1)
    if opacityOptions.SetLabelFormatter and MinimalSliderWithSteppersMixin then
        opacityOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    end
    Settings.CreateSlider(category, opacitySetting, opacityOptions,
        "Brightness of the indicator dots. 40% blends them into the background; "
        .. "100% is fully opaque.")
    opacitySetting:SetValueChangedCallback(RefreshIndicators)

    -- Solo preview button — sits at the bottom of the PartySync section.
    -- Surfaces a row of 4 demo indicators either on the first 4 tracker
    -- rows (WYSIWYG) or free-floating above the panel as a fallback.
    -- 30 s timer; re-click extends.
    if CreateSettingsButtonInitializer and layout and layout.AddInitializer then
        local previewInit = CreateSettingsButtonInitializer(
            "",
            "Preview indicators (solo, 30s)",
            ShowOrExtendPreview,
            "Show four demo indicator dots — one per aggregate state — on real "
            .. "tracker rows when at least 4 quests are tracked, or above the "
            .. "settings panel as a fallback. Lets you eyeball size, shape, "
            .. "position, palette, and opacity changes without joining a party. "
            .. "Click again to extend the 30s timer.",
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
