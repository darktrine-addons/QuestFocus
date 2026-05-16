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
local PREVIEW_LABEL_TEXT = { "Aligned", "Mixed", "Ready",         "Shareable"       }
local PREVIEW_TOOLTIPS   = {
    "Every party member is on this quest and progressing. No coordination needed.",
    "Some party members are on the quest, some aren't. Worth checking in.",
    "At least one party member has the quest objectives complete and ready to turn in.",
    "Only you have this quest, and at least one partymate is in the same zone — share opportunity.",
}
local PREVIEW_DURATION   = 30

-- ------------------------------------------------------------
-- Inline permanent preview: a layout-flow row containing 4 demo dots
-- with labels and hover tooltips. Built as a custom initializer wrapping
-- SettingsListSectionHeaderTemplate so the framework handles category-
-- visibility for us automatically.
-- ------------------------------------------------------------

local inlinePreviewDots = {}  -- captured at first InitFrame for refresh

local function AttachInlinePreviewDots(frame)
    if frame.qfPreviewAttached then return end
    frame.qfPreviewAttached = true

    local Indicator = ns.PartySync and ns.PartySync.UI and ns.PartySync.UI.Indicator
    if not Indicator or not Indicator.Acquire then return end

    -- Background rectangle making the row feel like its own panel.
    -- Starts ~36 px below the title to leave space between section
    -- heading and the dot row.
    if not frame.qfPreviewBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0, 0, 0, 0.25)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -36)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 4)
        frame.qfPreviewBg = bg
    end

    local prevDot
    for i, state in ipairs(PREVIEW_STATES) do
        local d = Indicator.Acquire()
        d:SetParent(frame)
        d:ClearAllPoints()
        if prevDot then
            d:SetPoint("LEFT", prevDot, "RIGHT", 70, 0)
        else
            -- Dot row sits ~16 px inside the background → ~52 px below
            -- the title. Roughly one section-header-height of breathing.
            d:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, -48)
        end
        Indicator.SetState(d, state)
        inlinePreviewDots[i] = d
        prevDot = d

        -- One-word legend under each dot.
        local lbl = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    local data = { name = "Style preview" }
    local init = Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", data)
    if not init then return nil end
    init.GetExtent = function() return 90 end
    local origInitFrame = init.InitFrame
    init.InitFrame = function(self, frame)
        if origInitFrame then origInitFrame(self, frame) end
        AttachInlinePreviewDots(frame)
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
        print("|cffffcc00QuestFocus|r no quests tracked — nothing to preview.")
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
    -- Section: ZoneFilter (behaviour preferences, per-character)
    -- ===========================================================
    AddSectionHeader("ZoneFilter")

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
        "Manual un-track also clears the snapshot",
        false)
    Settings.CreateCheckbox(
        category,
        untrackClearsSetting,
        "When checked, manually un-tracking a quest while a filter is "
        .. "active also removes it from the snapshot. A later revert "
        .. "will then respect that choice and won't restore the quest. "
        .. "Per-character.\n\n"
        .. "|cffaaaaaaDefault off preserves strict revert: the snapshot is "
        .. "restored exactly as it was taken, regardless of interim "
        .. "manual changes.|r")

    -- ===========================================================
    -- Section: PartySync (visual settings)
    -- ===========================================================
    AddSectionHeader("PartySync")

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

    -- D5: raid threshold — suppress per-member tooltip in large groups.
    local raidThresholdSetting = Settings.RegisterAddOnSetting(
        category, "QuestFocus_PS_RaidThreshold", "raidThreshold",
        QuestFocusDB.partySync, Settings.VarType.Number, "Suppress tooltip in large groups", 10)
    Settings.CreateDropdown(category, raidThresholdSetting,
        function()
            local c = Settings.CreateControlTextContainer()
            c:Add(0,  "Always show")
            c:Add(10, "Hide at 10+ members")
            c:Add(20, "Hide at 20+ members")
            return c:GetData()
        end,
        "In larger groups the per-member 'Party state' tooltip list would "
        .. "be too long. Once the group size meets the threshold, the "
        .. "tooltip's PartySync section is suppressed. Indicator dots "
        .. "still show as usual.")

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
            "Preview on tracker (30s)",
            ShowOrExtendPreview,
            "Temporarily attaches up to 4 demo indicator dots to your "
            .. "tracker rows so you can see how the current style looks "
            .. "in context. Truncates if fewer than 4 quests are tracked; "
            .. "no-op when nothing is tracked. Click again to extend the "
            .. "30s timer; closing the settings panel ends the preview.",
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
