-- State.lua — SavedVars accessors and the central state machine for
-- the tracker filter.
--
-- One nullable SV struct holds the entire applied-filter state:
--
--   QuestFocusCharDB.currentApplication = nil
--     — no filter active
--
--   QuestFocusCharDB.currentApplication = {
--       mode     = "campaignOnly",       -- which Apply produced this
--       target   = { [qid] = true, ... }, -- the post-apply watch list
--       snapshot = { [qid] = true, ... }, -- pre-filter watch list, accumulates drift_adds
--   }
--
-- Derived (computed from currentApplication on demand):
--   filterActive       = currentApplication ~= nil
--   driftAdds          = current ∖ target    -- quests added since the apply
--   driftRemoves       = target ∖ current    -- quests removed since the apply
--   dirty              = driftAdds ≠ ∅ or driftRemoves ≠ ∅
--   revertAddCount     = |snapshot ∖ current|   -- how many quests revert would re-track
--   revertTarget       = snapshot ∪ driftAdds   -- merge-revert semantics
--
-- Four functions mutate currentApplication:
--   TransitionToMode(modeName, target)  — first-apply or re-apply
--   ExtendTarget(qid)                   — add one quest to the active target
--   PruneQuest(qid)                     — remove one quest from snapshot + target
--   ClearFilter()                       — discard everything

local addonName, ns = ...
ns.ZoneFilter = ns.ZoneFilter or {}
local State = {}
ns.ZoneFilter.State = State

-- ============================================================
-- Bootstrap & migration
-- ============================================================

local function MigrateLegacyShape()
    -- The four-flat-fields layout shipped before this refactor. If we
    -- find filterActive (with the post-v0.1.0-beta lastApplied), fold
    -- the four fields into the new currentApplication struct.
    if QuestFocusCharDB.currentApplication then return end
    if not QuestFocusCharDB.filterActive then
        -- Old "inactive" state — just clear leftovers.
        QuestFocusCharDB.filterActive = nil
        QuestFocusCharDB.snapshot     = nil
        QuestFocusCharDB.lastApplied  = nil
        QuestFocusCharDB.lastMode     = nil
        return
    end
    if not QuestFocusCharDB.lastApplied then
        -- Legacy v0.1.0-beta state — can't migrate cleanly; drop.
        QuestFocusCharDB.filterActive = nil
        QuestFocusCharDB.snapshot     = nil
        QuestFocusCharDB.lastApplied  = nil
        QuestFocusCharDB.lastMode     = nil
        return
    end
    QuestFocusCharDB.currentApplication = {
        mode     = QuestFocusCharDB.lastMode or "zoneFilter",
        target   = QuestFocusCharDB.lastApplied,
        snapshot = QuestFocusCharDB.snapshot or {},
    }
    QuestFocusCharDB.filterActive = nil
    QuestFocusCharDB.snapshot     = nil
    QuestFocusCharDB.lastApplied  = nil
    QuestFocusCharDB.lastMode     = nil
end

function State.EnsureDB()
    QuestFocusDB     = QuestFocusDB     or {}
    QuestFocusCharDB = QuestFocusCharDB or {}
    MigrateLegacyShape()
end

-- ============================================================
-- The three mutators — only these touch currentApplication
-- ============================================================

-- First-apply or re-apply. Caller MUST pass `priorWatches` — the
-- watch-list snapshot taken before any RemoveQuestWatch / AddQuestWatch
-- calls happen — because by the time we set state, the live watch list
-- has already moved. On first apply: snapshot = priorWatches. On
-- re-apply: accumulates drift_adds (priorWatches ∖ existing target)
-- into the existing snapshot so they survive a future revert.
function State.TransitionToMode(modeName, target, priorWatches)
    local existing = QuestFocusCharDB.currentApplication

    local newSnapshot
    if existing and existing.snapshot then
        -- Re-apply: accumulate drift_adds.
        newSnapshot = existing.snapshot
        local oldTarget = existing.target or {}
        for qid in pairs(priorWatches) do
            if not oldTarget[qid] then newSnapshot[qid] = true end
        end
    else
        -- First apply: snapshot = pre-apply watch list.
        newSnapshot = {}
        for qid in pairs(priorWatches) do newSnapshot[qid] = true end
    end

    QuestFocusCharDB.currentApplication = {
        mode     = modeName,
        target   = target,
        snapshot = newSnapshot,
    }
end

-- Append a single questID to the currently-active target. Used by
-- AutoPromote so that a zone-relevant quest entering the log doesn't
-- register as drift. No-op when no filter is active.
function State.ExtendTarget(questID)
    local app = QuestFocusCharDB.currentApplication
    if not app or not app.target then return end
    app.target[questID] = true
end

function State.ClearFilter()
    QuestFocusCharDB.currentApplication = nil
end

-- Remove a single questID from snapshot AND target. Used by quest-log
-- hygiene (QUEST_TURNED_IN / QUEST_REMOVED) so abandoned/completed
-- quests don't linger in SV indefinitely, and by the optional
-- untrackClearsSnapshot setting so manual un-tracks become permanent.
-- No-op when no filter is active.
function State.PruneQuest(questID)
    if not questID then return end
    local app = QuestFocusCharDB and QuestFocusCharDB.currentApplication
    if not app then return end
    if app.snapshot then app.snapshot[questID] = nil end
    if app.target   then app.target[questID]   = nil end
end

-- ============================================================
-- Read-only accessors (computed from currentApplication)
-- ============================================================

function State.GetFilterActive()
    return QuestFocusCharDB and QuestFocusCharDB.currentApplication ~= nil
end

function State.GetSnapshot()
    local app = QuestFocusCharDB and QuestFocusCharDB.currentApplication
    return app and app.snapshot
end

function State.GetLastApplied()
    local app = QuestFocusCharDB and QuestFocusCharDB.currentApplication
    return app and app.target
end

function State.GetLastMode()
    local app = QuestFocusCharDB and QuestFocusCharDB.currentApplication
    return app and app.mode
end

-- Live read of the player's watch list. Returns { [qID] = true }.
function State.GetCurrentWatches()
    local set = {}
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local qid = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if qid then set[qid] = true end
    end
    return set
end

-- ============================================================
-- Drift detection (pure derivations)
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

function State.GetDriftRemoveCount()
    local last = State.GetLastApplied()
    if not last then return 0 end
    local current = State.GetCurrentWatches()
    local count = 0
    for qid in pairs(last) do
        if not current[qid] then count = count + 1 end
    end
    return count
end

function State.IsDirty()
    if not State.GetFilterActive() then return false end
    return State.GetDriftAddCount() > 0 or State.GetDriftRemoveCount() > 0
end

-- Quests in snapshot but not in current watches — how many revert
-- would re-track. Used by the count badge on the revert button.
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
