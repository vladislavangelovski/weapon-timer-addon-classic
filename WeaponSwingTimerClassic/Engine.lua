local _, ns = ...

local Engine = {}
ns.Engine = Engine

LibStub("AceEvent-3.0"):Embed(Engine)
Engine.callbacks = LibStub("CallbackHandler-1.0"):New(Engine)

Engine.state = {
    mainHand = { speed = 0, startedAt = 0, firesAt = 0, active = false },
    offHand  = { speed = 0, startedAt = 0, firesAt = 0, active = false },
    ranged   = { speed = 0, startedAt = 0, firesAt = 0, active = false,
                 aiming = false, aimEndsAt = 0 },
}

-- [spellID] = { endTime, spellName, spellID } for casts currently in flight.
-- Keyed by spellID rather than castGUID because you can't cast the same spell
-- twice concurrently and spellID is always available on Classic Era.
Engine.activeCasts = {}

-- [slot] = clip delta currently advertised to the UI (nil = no clip).
-- Used to debounce ClipPredicted/ClipCleared so we only fire on state change.
Engine.clipped = {}

Engine.isAutoRepeating = false

-- Auto-attack spells trigger UNIT_SPELLCAST_START but shouldn't generate clip
-- warnings because they ARE the swing, not something delaying it.
Engine.NO_CLIP_SPELLS = {
    [75]   = true,  -- Auto Shot (Hunter)
    [5019] = true,  -- Shoot (wand)
}

-- ============================================================================
-- Speed helpers
-- ============================================================================

function Engine:CurrentSpeedFor(slot)
    if slot == "mainHand" then
        return (UnitAttackSpeed("player")) or 0
    elseif slot == "offHand" then
        local _, off = UnitAttackSpeed("player")
        return off or 0
    elseif slot == "ranged" then
        return (UnitRangedDamage("player")) or 0
    end
    return 0
end

function Engine:RefreshSpeeds()
    local main, off = UnitAttackSpeed("player")
    self.state.mainHand.speed = main or 0
    self.state.offHand.speed  = off or 0
    self.state.ranged.speed   = (UnitRangedDamage("player")) or 0
end

-- When haste changes mid-swing, preserve the proportion already elapsed so the
-- visual bar stays continuous instead of jumping.
function Engine:UpdateSlotSpeed(slot, newSpeed)
    local s = self.state[slot]
    newSpeed = newSpeed or 0
    if s.active and s.speed > 0 and newSpeed > 0 and newSpeed ~= s.speed then
        local now = GetTime()
        local remaining = math.max(s.firesAt - now, 0)
        local proportion = remaining / s.speed
        s.speed = newSpeed
        s.firesAt = now + newSpeed * proportion
        s.startedAt = s.firesAt - newSpeed
        self.callbacks:Fire("SwingStart", slot, newSpeed)
        self:RefreshClipPrediction(slot)
    else
        s.speed = newSpeed
    end
end

-- ============================================================================
-- Public API used by ClassResets and Core
-- ============================================================================

function Engine:FireSwing(slot)
    local s = self.state[slot]
    local now = GetTime()
    s.speed     = self:CurrentSpeedFor(slot)
    s.startedAt = now
    s.firesAt   = now + s.speed
    s.active    = s.speed > 0
    if s.active then
        self.callbacks:Fire("SwingFired", slot)
        self.callbacks:Fire("SwingStart", slot, s.speed)
        self:RefreshClipPrediction(slot)
    end
end

function Engine:Reset(slot, reason)
    self:FireSwing(slot)
    self.callbacks:Fire("SwingReset", slot, reason or "manual")
end

function Engine:Stop(slot, reason)
    local s = self.state[slot]
    if s.active then
        s.active = false
        self.callbacks:Fire("SwingStop", slot, reason or "manual")
        self:RefreshClipPrediction(slot)
    end
end

function Engine:PauseRanged(reason)
    self:Stop("ranged", reason or "cast")
end

function Engine:ResumeRanged()
    -- The actual RANGE_DAMAGE / RANGE_MISSED event will re-activate the timer
    -- when the shot fires. We just clear any clip-prediction state here.
    self:RefreshClipPrediction("ranged")
end

-- Parry haste (Vanilla): when the player parries an incoming swing, the MH
-- timer is shortened by up to 40% of base speed but can't drop below 20% of
-- base speed remaining from startedAt. Source: vanilla combat mechanics docs.
function Engine:ApplyParryHaste(slot)
    local s = self.state[slot]
    if not s.active or s.speed <= 0 then return end
    local newFiresAt = math.max(s.firesAt - 0.4 * s.speed,
                                s.startedAt + 0.2 * s.speed)
    s.firesAt = newFiresAt
    self.callbacks:Fire("SwingParryHasted", slot, newFiresAt)
    self:RefreshClipPrediction(slot)
end

-- ============================================================================
-- Combat log
-- ============================================================================

-- Field layout per Wowpedia (Classic Era, no Advanced Combat Logging):
--   Base (1..11):   timestamp, subEvent, hideCaster,
--                   sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
--                   destGUID,   destName,   destFlags,   destRaidFlags
--   SWING_DAMAGE  suffix at 12..21 -> last arg (index #info) is isOffHand.
--   SWING_MISSED  suffix at 12..13 -> missType, isOffHand.
--   RANGE_DAMAGE  prefix at 12..14 (spellID, spellName, spellSchool), suffix follows.
--
-- When Advanced Combat Logging is enabled, 17 extra unit-info args are inserted
-- between the base and the suffix, shifting the suffix start to index 29. We
-- auto-detect by arg count (Adv-on SWING_DAMAGE >= 38 args, Adv-off <= 21).
function Engine:HandleCombatLog()
    local info = { CombatLogGetCurrentEventInfo() }
    local argc       = #info
    local subEvent   = info[2]
    local sourceGUID = info[4]
    local destGUID   = info[8]

    local suffixStart = (argc >= 25) and 29 or 12

    if sourceGUID == self.playerGUID then
        if subEvent == "SWING_DAMAGE" then
            local isOffHand = info[argc]
            self:FireSwing(isOffHand and "offHand" or "mainHand")
        elseif subEvent == "SWING_MISSED" then
            local isOffHand = info[suffixStart + 1]
            self:FireSwing(isOffHand and "offHand" or "mainHand")
        elseif subEvent == "RANGE_DAMAGE" or subEvent == "RANGE_MISSED" then
            self:FireSwing("ranged")
        end
    end

    if destGUID == self.playerGUID and subEvent == "SWING_MISSED" then
        local missType = info[suffixStart]
        if missType == "PARRY" then
            self:ApplyParryHaste("mainHand")
        end
    end
end

-- ============================================================================
-- Attack-speed / equipment / auto-repeat handlers
-- ============================================================================

function Engine:HandleAttackSpeedChange(_, unit)
    if unit and unit ~= "player" then return end
    local main, off = UnitAttackSpeed("player")
    self:UpdateSlotSpeed("mainHand", main)
    self:UpdateSlotSpeed("offHand",  off)
end

function Engine:HandleRangedDamageChange(_, unit)
    if unit and unit ~= "player" then return end
    self:UpdateSlotSpeed("ranged", (UnitRangedDamage("player")))
end

-- PLAYER_EQUIPMENT_CHANGED fires with (slot, hasCurrent); slot is the inventory
-- slot id. We only care about MH/OH/ranged.
function Engine:HandleEquipmentChange(_, invSlot, hasCurrent)
    local slotMap = {
        [ns.SLOT_TO_INVSLOT.mainHand] = "mainHand",
        [ns.SLOT_TO_INVSLOT.offHand]  = "offHand",
        [ns.SLOT_TO_INVSLOT.ranged]   = "ranged",
    }
    local engineSlot = slotMap[invSlot]
    if not engineSlot then return end

    self.state[engineSlot].active = false
    self:RefreshSpeeds()
    self.callbacks:Fire("SwingReset", engineSlot, "weaponSwap")
    self.callbacks:Fire("EquipmentChanged", engineSlot, hasCurrent)
    self:RefreshClipPrediction(engineSlot)
end

function Engine:HandleAutoRepeatStart()
    self.isAutoRepeating = true
    self.callbacks:Fire("AutoRepeatStart")
end

function Engine:HandleAutoRepeatStop()
    self.isAutoRepeating = false
    self.callbacks:Fire("AutoRepeatStop")
    local s = self.state.ranged
    if s.active then
        s.active = false
        self.callbacks:Fire("SwingReset", "ranged", "autoRepeatStop")
    end
    self:RefreshClipPrediction("ranged")
end

-- ============================================================================
-- Spell-cast tracking for clip prediction
-- ============================================================================

function Engine:HandleSpellCastStart(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    if self.NO_CLIP_SPELLS[spellID] then return end
    local name, _, _, castTime = GetSpellInfo(spellID)
    if not name or not castTime or castTime <= 0 then return end
    self.activeCasts[spellID] = {
        endTime   = GetTime() + castTime / 1000,
        spellName = name,
        spellID   = spellID,
    }
    self:RefreshClipPrediction()
end

function Engine:HandleSpellCastEnded(_, unitTarget, _, spellID)
    if unitTarget ~= "player" or not spellID then return end
    if self.activeCasts[spellID] then
        self.activeCasts[spellID] = nil
        self:RefreshClipPrediction()
    end
end

function Engine:RefreshClipPrediction(optionalSlot)
    local latestEnd, hasCast = 0, false
    for _, cast in pairs(self.activeCasts) do
        if cast.endTime > latestEnd then
            latestEnd = cast.endTime
            hasCast = true
        end
    end

    local slots = optionalSlot and { optionalSlot } or ns.SLOT_ORDER
    for _, slot in ipairs(slots) do
        local s = self.state[slot]
        local nowClipped = s.active and hasCast and latestEnd > s.firesAt
        local delta      = nowClipped and (latestEnd - s.firesAt) or nil

        if nowClipped then
            if delta ~= self.clipped[slot] then
                self.clipped[slot] = delta
                self.callbacks:Fire("ClipPredicted", slot, delta)
            end
        elseif self.clipped[slot] ~= nil then
            self.clipped[slot] = nil
            self.callbacks:Fire("ClipCleared", slot)
        end
    end
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function Engine:Initialize(playerGUID)
    self.playerGUID = playerGUID
    self:RefreshSpeeds()
end

function Engine:Enable()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED",  "HandleCombatLog")
    self:RegisterEvent("UNIT_ATTACK_SPEED",            "HandleAttackSpeedChange")
    self:RegisterEvent("UNIT_RANGEDDAMAGE",            "HandleRangedDamageChange")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED",     "HandleEquipmentChange")
    self:RegisterEvent("START_AUTOREPEAT_SPELL",       "HandleAutoRepeatStart")
    self:RegisterEvent("STOP_AUTOREPEAT_SPELL",        "HandleAutoRepeatStop")
    self:RegisterEvent("UNIT_SPELLCAST_START",          "HandleSpellCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",      "HandleSpellCastEnded")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",    "HandleSpellCastEnded")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED",         "HandleSpellCastEnded")
    self:RegisterEvent("UNIT_SPELLCAST_STOP",           "HandleSpellCastEnded")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START",  "HandleSpellCastStart")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",   "HandleSpellCastEnded")
end

function Engine:Disable()
    self:UnregisterAllEvents()
    for slot in pairs(self.state) do
        self.state[slot].active = false
    end
    self.activeCasts = {}
    self.clipped = {}
end
