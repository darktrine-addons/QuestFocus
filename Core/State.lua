-- State.lua — SavedVars accessors and snapshot/flag bookkeeping.

local addonName, ns = ...
ns.Core = ns.Core or {}
local State = {}
ns.Core.State = State

-- ============================================================
-- Bootstrap
-- ============================================================

function State.EnsureDB()
    QuestFocusDB     = QuestFocusDB     or {}
    QuestFocusCharDB = QuestFocusCharDB or {}
    if QuestFocusCharDB.filterActive == nil then
        QuestFocusCharDB.filterActive = false
    end
    -- snapshot stays nil until first filter
end

-- ============================================================
-- Filter-active flag
-- ============================================================

function State.GetFilterActive()
    return QuestFocusCharDB and QuestFocusCharDB.filterActive == true
end

function State.SetFilterActive(active)
    QuestFocusCharDB.filterActive = active and true or false
end

-- ============================================================
-- Snapshot of the watch list at the moment Filter was first applied.
-- Stored as { [questID] = true, ... }
-- ============================================================

function State.GetSnapshot()
    return QuestFocusCharDB and QuestFocusCharDB.snapshot
end

function State.SetSnapshot(snap)
    QuestFocusCharDB.snapshot = snap
end

function State.ClearSnapshot()
    QuestFocusCharDB.snapshot = nil
end

-- ============================================================
-- Live read of the current quest watch list (not stored — derived from game state).
-- Returns set { [questID] = true, ... }
-- ============================================================

function State.GetCurrentWatches()
    local set = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if qid then set[qid] = true end
    end
    return set
end

-- ============================================================
-- Count of quests in the snapshot that are NOT currently watched —
-- i.e. how many quests a Revert would re-track. Used for the badge.
-- ============================================================

function State.GetRevertAddCount()
    local snap = State.GetSnapshot()
    if not snap then return 0 end
    local current = State.GetCurrentWatches()
    local count = 0
    for qid in pairs(snap) do
        if not current[qid] then count = count + 1 end
    end
    return count
end
