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

local function FormatModeLabel(label, count)
    local WARN_ICON = ns.ZoneFilter.UI.WARN_ICON
    if count == 0 then
        return string.format("%s |cffaaaaaa(0)|r %s", label, WARN_ICON)
    end
    return string.format("%s |cffaaaaaa(%d)|r", label, count)
end

function Menu.Show(button)
    if not MenuUtil or not MenuUtil.CreateContextMenu then
        print("|cffffcc00QuestFocus|r menu API unavailable on this client.")
        return
    end
    local Apply     = ns.ZoneFilter.Apply
    local WARN_ICON = ns.ZoneFilter.UI.WARN_ICON

    MenuUtil.CreateContextMenu(button, function(owner, root)
        root:CreateTitle("Tracker modes")

        local function addModeItem(label, modeName)
            local count = Apply.CountForMode and Apply.CountForMode(modeName) or 0
            root:CreateButton(FormatModeLabel(label, count), function()
                ns.ZoneFilter.Apply.Mode(modeName)
            end)
        end
        local function addFilterItem(label, addFromLog)
            local count = Apply.CountForFilter and Apply.CountForFilter(addFromLog) or 0
            root:CreateButton(FormatModeLabel(label, count), function()
                ns.ZoneFilter.Apply.Filter(addFromLog)
            end)
        end

        -- Broadest first.
        addModeItem("Track all quests in log", "trackAll")

        root:CreateDivider()

        -- Zone filter (also accessible via the button's left/shift-left).
        addFilterItem("Track current zone (Focus)",                  false)
        addFilterItem("Track current zone + promote from log",       true)

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
