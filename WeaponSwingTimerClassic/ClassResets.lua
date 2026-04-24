local _, ns = ...

local ClassResets = {}
ns.ClassResets = ClassResets

LibStub("AceEvent-3.0"):Embed(ClassResets)

-- ============================================================================
-- Reset helpers
-- ============================================================================

local function rangedPause(engine)   engine:PauseRanged("cast") end
local function rangedResume(engine)  engine:ResumeRanged() end
local function resetMainHand(engine) engine:Reset("mainHand", "slam") end

-- ============================================================================
-- Registry
--
-- Keyed by spellID at edit time; we resolve to localized spell names via
-- GetSpellInfo at load time so every rank of an ability collapses onto a
-- single name key. This works because all ranks of e.g. "Slam" return the same
-- localized name from GetSpellInfo.
-- ============================================================================

local SPELL_REGISTRY = {
    WARRIOR = {
        onCastSucceeded   = { [1464] = resetMainHand },          -- Slam
        onNextSwingSpells = { [78]  = "mainHand",                -- Heroic Strike
                              [845] = "mainHand" },              -- Cleave
    },
    HUNTER = {
        onCastStart       = { [19434] = rangedPause,  [2643] = rangedPause },
        onCastSucceeded   = { [19434] = rangedResume, [2643] = rangedResume },
        onCastInterrupted = { [19434] = rangedResume, [2643] = rangedResume },
        onCastFailed      = { [19434] = rangedResume, [2643] = rangedResume },
    },
    MAGE    = { onCastStart       = { [5019] = rangedPause },    -- Shoot (wand)
                onCastSucceeded   = { [5019] = rangedResume },
                onCastInterrupted = { [5019] = rangedResume },
                onCastFailed      = { [5019] = rangedResume } },
    PRIEST  = { onCastStart       = { [5019] = rangedPause },
                onCastSucceeded   = { [5019] = rangedResume },
                onCastInterrupted = { [5019] = rangedResume },
                onCastFailed      = { [5019] = rangedResume } },
    WARLOCK = { onCastStart       = { [5019] = rangedPause },
                onCastSucceeded   = { [5019] = rangedResume },
                onCastInterrupted = { [5019] = rangedResume },
                onCastFailed      = { [5019] = rangedResume } },
    ROGUE   = {},
    DRUID   = {},
    PALADIN = {},
    SHAMAN  = {},
}

ClassResets.SPELL_REGISTRY = SPELL_REGISTRY

-- ============================================================================
-- Name resolution
-- ============================================================================

local function resolveByName(spellIDTable)
    local byName = {}
    for spellID, value in pairs(spellIDTable or {}) do
        local name = GetSpellInfo(spellID)
        if name then
            byName[name] = value
        end
    end
    return byName
end

function ClassResets:Initialize(engine, classToken)
    self.engine = engine
    self.classToken = classToken
    local src = SPELL_REGISTRY[classToken] or {}
    self.byName = {
        onCastStart       = resolveByName(src.onCastStart),
        onCastSucceeded   = resolveByName(src.onCastSucceeded),
        onCastInterrupted = resolveByName(src.onCastInterrupted),
        onCastFailed      = resolveByName(src.onCastFailed),
        onNextSwingSpells = resolveByName(src.onNextSwingSpells),
    }
end

-- ============================================================================
-- Event dispatch
-- ============================================================================

local function dispatch(map, engine, name)
    if not map or not name then return end
    local fn = map[name]
    if fn then fn(engine) end
end

function ClassResets:HandleSpellCastStart(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    dispatch(self.byName.onCastStart, self.engine, GetSpellInfo(spellID))
end

function ClassResets:HandleSpellCastSucceeded(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    dispatch(self.byName.onCastSucceeded, self.engine, GetSpellInfo(spellID))
end

function ClassResets:HandleSpellCastInterrupted(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    dispatch(self.byName.onCastInterrupted, self.engine, GetSpellInfo(spellID))
end

function ClassResets:HandleSpellCastFailed(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    dispatch(self.byName.onCastFailed, self.engine, GetSpellInfo(spellID))
end

-- Heroic Strike / Cleave replace the next MH swing and are logged as
-- SPELL_DAMAGE rather than SWING_DAMAGE, so Engine's combat-log handler can't
-- detect the swing on its own. We listen separately and fire the swing here.
--
-- Spell prefix (spellID, spellName, spellSchool) lives at base-offset 12, or at
-- offset 29 when Advanced Combat Logging is enabled. Detect by arg count.
function ClassResets:HandleCombatLog()
    local map = self.byName.onNextSwingSpells
    if not map or not next(map) then return end

    local info = { CombatLogGetCurrentEventInfo() }
    local argc       = #info
    local subEvent   = info[2]
    local sourceGUID = info[4]

    if sourceGUID ~= self.engine.playerGUID then return end
    if subEvent ~= "SPELL_DAMAGE" and subEvent ~= "SPELL_MISSED" then return end

    local prefixStart = (argc >= 25) and 29 or 12
    local spellName   = info[prefixStart + 1]

    local slot = spellName and map[spellName]
    if slot then
        self.engine:FireSwing(slot)
    end
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function ClassResets:Enable()
    self:RegisterEvent("UNIT_SPELLCAST_START",          "HandleSpellCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",      "HandleSpellCastSucceeded")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",    "HandleSpellCastInterrupted")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED",         "HandleSpellCastFailed")
    self:RegisterEvent("UNIT_SPELLCAST_STOP",           "HandleSpellCastFailed")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START",  "HandleSpellCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "HandleSpellCastFailed")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED",   "HandleCombatLog")
end

function ClassResets:Disable()
    self:UnregisterAllEvents()
end
