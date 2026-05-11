-- State.lua — SavedVars accessors and bookkeeping.
--
-- State model:
--   filterActive : bool       — a snapshot exists
--   snapshot     : { [qID]=t } — pre-filter watch list; grows on re-apply to
--                                absorb interim user/auto-track additions
--   lastApplied  : { [qID]=t } — watch list state immediately after the most
--                                recent Filter operation (= zone-relevant set
--                                at that moment). Used to detect drift.
--
-- Derived:
--   drift_adds   = current ∖ lastApplied   (quests appearing since last filter)
--   isDirty      = drift_adds ≠ ∅
--   revertTarget = snapshot ∪ drift_adds   (merge revert: preserve interim adds)

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
    -- Migration: lastApplied was introduced after v0.1.0-beta. If a user's
    -- SavedVars predate it (filterActive=true but no lastApplied), the only
    -- safe move is to clear filter state — we can't distinguish drift adds
    -- from filter additions without lastApplied.
    if QuestFocusCharDB.filterActive and not QuestFocusCharDB.lastApplied then
        QuestFocusCharDB.snapshot = nil
        QuestFocusCharDB.filterActive = false
    end
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
-- Snapshot — pre-filter watch list. Survives re-applies (it grows).
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
-- LastApplied — watch list state right after most recent Filter.
-- Used to detect drift_adds (quests that appeared since).
-- ============================================================

function State.GetLastApplied()
    return QuestFocusCharDB and QuestFocusCharDB.lastApplied
end

function State.SetLastApplied(set)
    QuestFocusCharDB.lastApplied = set
end

function State.ClearLastApplied()
    QuestFocusCharDB.lastApplied = nil
end

-- ============================================================
-- Live read of current watch list. Returns set { [qID]=true }.
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
-- Drift detection — quests in current that weren't in lastApplied.
-- These are interim user adds / auto-track adds since the last filter.
-- ============================================================

function State.GetDriftAddCount()
    local last = State.GetLastApplied()
    if not last then return 0 end
    local current = State.GetCurrentWatches()
    local count = 0
    for qid in pairs(current) do
        if not last[qid] then count = count + 1 end
    end
    return count
end

function State.IsDirty()
    return State.GetFilterActive() and State.GetDriftAddCount() > 0
end

-- ============================================================
-- Revert add count — quests in snapshot that aren't currently watched,
-- i.e. how many quests a Revert would re-track. Used for the badge.
-- (Drift adds, by definition, are in current, so the badge formula
--  |snapshot ∖ current| is the same under merge semantics.)
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
