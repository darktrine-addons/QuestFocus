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

    -- Reload button. The Settings button-initializer API doesn't surface
    -- a re-evaluating enabled-state hook for arbitrary predicates, so we
    -- gate the click instead of greying the button: if no needs-/reload
    -- setting has changed since this session loaded, the click is a no-op
    -- with a chat message. Same end-state for the user (no unnecessary
    -- reload), just without the visual cue.
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

    Settings.RegisterAddOnCategory(category)
    registered = true
end

function ns.Settings.Open()
    if not categoryRef then return end
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(categoryRef:GetID())
    end
end
