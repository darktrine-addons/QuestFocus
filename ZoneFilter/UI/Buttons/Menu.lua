-- ZoneFilter/UI/Buttons/Menu.lua — right-click context menu on the
-- focus (lens) button. Surfaces every Track-X / Untrack action plus
-- the two zone-filter operations and a Settings entry. Each entry
-- previews the resulting watch count and flags 0-result actions with
-- the shared WARN_ICON.

local addonName, ns = ...
ns.ZoneFilter    = ns.ZoneFilter    or {}
ns.ZoneFilter.UI = ns.ZoneFilter.UI or {}

local Menu = {}
ns.ZoneFilter.UI.Menu = Menu

-- opts:
--   binding     — string like "Left-click" / "Shift+Left-click" shown as
--                 a grey prefix in front of the label (zoneFilter rows only)
--   activeState — nil (not active) | "clean" (green marker) | "drift"
--                 (orange marker) — appended after the count
local function FormatModeLabel(label, count, opts)
    opts = opts or {}
    local WARN_ICON = ns.ZoneFilter.UI.WARN_ICON
    local prefix = ""
    if opts.binding and opts.binding ~= "" then
        prefix = string.format("|cffaaaaaa[%s]|r ", opts.binding)
    end
    local suffix = ""
    if opts.activeState == "clean" then
        suffix = " |cff44ff44(active)|r"
    elseif opts.activeState == "drift" then
        suffix = " |cffff8c26(drifted)|r"
    end
    if count == 0 then
        return string.format("%s%s |cffaaaaaa(0)|r %s%s", prefix, label, WARN_ICON, suffix)
    end
    return string.format("%s%s |cffaaaaaa(%d)|r%s", prefix, label, count, suffix)
end

function Menu.Show(button)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        print("|cffffcc00QuestFocus|r menu API unavailable on this client.")
        return
    end
    local Apply     = ns.ZoneFilter.Apply
    local State     = ns.ZoneFilter.State
    local WARN_ICON = ns.ZoneFilter.UI.WARN_ICON

    -- Active-state lookup: returns "clean" / "drift" / nil for a mode
    -- so the row can show its current marker.
    local activeMode = State and State.GetLastMode and State.GetLastMode()
    local active     = State and State.GetFilterActive and State.GetFilterActive()
    local dirty      = State and State.IsDirty and State.IsDirty()
    local function activeStateFor(modeName)
        if not active or activeMode ~= modeName then return nil end
        return dirty and "drift" or "clean"
    end

    MenuUtil.CreateContextMenu(button, function(owner, root)
        root:CreateTitle("Tracker modes")

        local function addModeItem(label, modeName, opts)
            opts = opts or {}
            opts.activeState = activeStateFor(modeName)
            local count = Apply.CountForMode and Apply.CountForMode(modeName) or 0
            root:CreateButton(FormatModeLabel(label, count, opts), function()
                ns.ZoneFilter.Apply.Mode(modeName)
            end)
        end
        local function addFilterItem(label, addFromLog, opts)
            opts = opts or {}
            opts.activeState = activeStateFor("zoneFilter")
            local count = Apply.CountForFilter and Apply.CountForFilter(addFromLog) or 0
            root:CreateButton(FormatModeLabel(label, count, opts), function()
                ns.ZoneFilter.Apply.Filter(addFromLog)
            end)
        end

        -- Broadest first.
        addModeItem("Track all quests in log", "trackAll")

        root:CreateDivider()

        -- Zone filter — also bound to the button's left/shift-left clicks.
        addFilterItem("Track current zone (Focus)",         false, { binding = "Left-click" })
        addFilterItem("Track current zone + add from log",  true,  { binding = "Shift+Left-click" })

        root:CreateDivider()

        -- By quest type.
        addModeItem("Track campaign quests only",  "campaignOnly")
        addModeItem("Track daily quests only",     "dailyOnly")
        addModeItem("Track weeklies only",         "weekliesOnly")
        addModeItem("Track Important quests only", "importantOnly")

        root:CreateDivider()

        -- By quest state.
        addModeItem("Track ready-to-turn-in only", "readyOnly")
        addModeItem("Track in-progress only",      "inProgressOnly")

        root:CreateDivider()

        -- Destructive.
        addModeItem("Untrack everything", "untrackAll")

        root:CreateDivider()

        root:CreateButton("Open settings…", function()
            if ns.Settings and ns.Settings.Open then ns.Settings.Open() end
        end)

        -- Footer: explain the warning glyph.
        root:CreateDivider()
        root:CreateTitle(WARN_ICON .. " action would clear the tracker (it hides).")
        root:CreateTitle("|cffaaaaaa/qf revert restores the previous state.|r")
    end)
end
