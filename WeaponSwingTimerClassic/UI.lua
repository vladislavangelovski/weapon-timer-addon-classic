local _, ns = ...

local UI = {}
ns.UI = UI

local LSM = LibStub("LibSharedMedia-3.0")

UI.bars     = {}
UI.anchor   = nil
UI.onUpdateRegistered = false

-- ============================================================================
-- Frame construction
-- ============================================================================

local function createBar(name, parent)
    local bar = CreateFrame("StatusBar", name, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.bg:SetColorTexture(0, 0, 0, 0.6)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")

    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.time  = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bar.time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetSize(16, 32)
    bar.spark:Hide()

    bar.clip = bar:CreateTexture(nil, "OVERLAY")
    bar.clip:SetAllPoints(bar)
    bar.clip:SetColorTexture(1, 0, 0, 0.35)
    bar.clip:Hide()

    bar:Hide()
    return bar
end

-- ============================================================================
-- OnUpdate (single hot path for all three bars)
-- ============================================================================

local function onUpdateFn(_)
    local now = GetTime()
    local state = ns.Engine.state
    for slot, bar in pairs(UI.bars) do
        local s = state[slot]
        if s.active and bar:IsShown() then
            local speed = s.speed > 0 and s.speed or 1
            local remaining = math.max(s.firesAt - now, 0)
            local progress = 1 - remaining / speed
            bar:SetValue(progress)
            if bar.showTime then
                bar.time:SetFormattedText("%.2f", remaining)
            end
            if bar.showSpark then
                bar.spark:SetPoint("CENTER", bar, "LEFT", progress * bar:GetWidth(), 0)
            end
        end
    end
end

function UI:StartOnUpdate()
    if not self.onUpdateRegistered and self.anchor then
        self.anchor:SetScript("OnUpdate", onUpdateFn)
        self.onUpdateRegistered = true
    end
end

function UI:StopOnUpdate()
    if self.onUpdateRegistered and self.anchor then
        self.anchor:SetScript("OnUpdate", nil)
        self.onUpdateRegistered = false
    end
end

function UI:CheckOnUpdate()
    local anyActive = false
    for _, s in pairs(ns.Engine.state) do
        if s.active then
            anyActive = true
            break
        end
    end
    if anyActive then self:StartOnUpdate() else self:StopOnUpdate() end
end

-- ============================================================================
-- Dynamic layout
-- ============================================================================

function UI:IsSlotVisible(slot)
    local invSlot = ns.SLOT_TO_INVSLOT[slot]
    local equipped = GetInventoryItemID("player", invSlot) ~= nil
    if slot == "ranged" and not self.db.rangedAlwaysVisible then
        return equipped and ns.Engine.isAutoRepeating
    end
    return equipped
end

function UI:Relayout()
    local spacing = self.db.spacing
    local prev = nil
    local visibleCount = 0
    for _, slot in ipairs(ns.SLOT_ORDER) do
        local bar = self.bars[slot]
        if self:IsSlotVisible(slot) then
            bar:ClearAllPoints()
            if prev then
                bar:SetPoint("TOPLEFT",  prev, "BOTTOMLEFT",  0, -spacing)
                bar:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -spacing)
            else
                bar:SetPoint("TOPLEFT",  self.anchor, "TOPLEFT",  0, 0)
                bar:SetPoint("TOPRIGHT", self.anchor, "TOPRIGHT", 0, 0)
            end
            bar:Show()
            prev = bar
            visibleCount = visibleCount + 1
        else
            bar:Hide()
        end
    end

    local totalHeight = visibleCount > 0
        and (visibleCount * self.db.height + math.max(0, visibleCount - 1) * spacing)
        or 1
    self.anchor:SetHeight(totalHeight)
end

-- ============================================================================
-- Drag
-- ============================================================================

local function onDragStart(self)
    if not UI.db.locked then self:StartMoving() end
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    UI.db.position.point    = p
    UI.db.position.relPoint = rp
    UI.db.position.x        = x
    UI.db.position.y        = y
end

-- ============================================================================
-- Icons
-- ============================================================================

function UI:UpdateIcons()
    for slot, bar in pairs(self.bars) do
        local invSlot = ns.SLOT_TO_INVSLOT[slot]
        local tex = GetInventoryItemTexture("player", invSlot)
        if tex then
            bar.icon:SetTexture(tex)
            bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            bar.icon:SetTexture(nil)
        end
    end
end

-- ============================================================================
-- Theme application (reads db, pushes to frames)
-- ============================================================================

function UI:ApplyTheme()
    local db = self.db
    local texturePath = LSM:Fetch("statusbar", db.texture) or "Interface\\TargetingFrame\\UI-StatusBar"
    local fontPath    = LSM:Fetch("font",      db.font)    or "Fonts\\FRIZQT__.TTF"

    self.anchor:ClearAllPoints()
    self.anchor:SetPoint(db.position.point, UIParent, db.position.relPoint,
                         db.position.x, db.position.y)
    self.anchor:SetWidth(db.width)
    self.anchor:SetAlpha(db.alpha)

    for slot, bar in pairs(self.bars) do
        bar:SetSize(db.width, db.height)
        bar:SetStatusBarTexture(texturePath)
        local c = db.colors[slot]
        bar:SetStatusBarColor(c.r, c.g, c.b, 1)

        bar.label:SetFont(fontPath, db.fontSize, "OUTLINE")
        bar.label:SetText(ns.SLOT_LABEL[slot] or slot)

        bar.time:SetFont(fontPath, db.fontSize, "OUTLINE")
        bar.time:SetShown(db.showTimeText)
        bar.showTime = db.showTimeText

        bar.spark:SetShown(db.showSpark)
        bar.showSpark = db.showSpark

        bar.icon:SetSize(db.iconSize, db.iconSize)
        bar.icon:ClearAllPoints()
        bar.label:ClearAllPoints()
        if db.showIcon and db.iconPosition == "LEFT" then
            bar.icon:SetPoint("LEFT", bar, "LEFT", 1, 0)
            bar.label:SetPoint("LEFT", bar, "LEFT", db.iconSize + 4, 0)
        elseif db.showIcon and db.iconPosition == "RIGHT" then
            bar.icon:SetPoint("RIGHT", bar, "RIGHT", -1, 0)
            bar.label:SetPoint("LEFT", bar, "LEFT", 4, 0)
            bar.time:ClearAllPoints()
            bar.time:SetPoint("RIGHT", bar.icon, "LEFT", -4, 0)
        else
            bar.label:SetPoint("LEFT", bar, "LEFT", 4, 0)
        end
        bar.icon:SetShown(db.showIcon)

        local clipColor = db.colors.clipping
        bar.clip:SetColorTexture(clipColor.r, clipColor.g, clipColor.b, 0.35)
        -- If the user just disabled clipWarning, any currently-showing overlay
        -- would stay visible until the next ClipCleared event fires. Clear it
        -- eagerly here so the toggle takes effect immediately.
        if not db.clipWarning then
            bar.clip:Hide()
        end
    end

    self:UpdateIcons()
    self:Relayout()
end

-- ============================================================================
-- Engine callback handlers
-- ============================================================================

function UI:OnSwingStart(_, slot, _)
    if self.bars[slot] and not self.bars[slot]:IsShown() then
        self:Relayout()
    end
    self:CheckOnUpdate()
end

function UI:OnSwingFired(_, slot)
    if self.db.soundOnSwing then
        local path = LSM:Fetch("sound", self.db.soundOnSwingKey)
        if path then PlaySoundFile(path, "Master") end
    end
    local bar = self.bars[slot]
    if bar then
        bar:SetValue(0)
    end
end

function UI:OnSwingReset(_, _slot, _)
    self:CheckOnUpdate()
end

function UI:OnSwingStop(_, slot, _)
    local bar = self.bars[slot]
    if bar then
        bar:SetValue(0)
        bar.time:SetText("")
    end
    self:CheckOnUpdate()
end

function UI:OnSwingParryHasted(_, _, _)
end

function UI:OnClipPredicted(_, slot, _)
    local bar = self.bars[slot]
    if bar and self.db.clipWarning then
        bar.clip:Show()
    end
    if self.db.soundOnClip then
        local path = LSM:Fetch("sound", self.db.soundOnClipKey)
        if path then PlaySoundFile(path, "Master") end
    end
end

function UI:OnClipCleared(_, slot)
    local bar = self.bars[slot]
    if bar then
        bar.clip:Hide()
    end
end

function UI:OnEquipmentChanged(_, _, _)
    self:UpdateIcons()
    self:Relayout()
end

function UI:OnAutoRepeatStart()
    self:Relayout()
end

function UI:OnAutoRepeatStop()
    self:Relayout()
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function UI:Initialize(engine, db)
    self.db = db

    self.anchor = CreateFrame("Frame", "WSTC_Anchor", UIParent)
    self.anchor:SetMovable(true)
    self.anchor:EnableMouse(true)
    self.anchor:RegisterForDrag("LeftButton")
    self.anchor:SetScript("OnDragStart", onDragStart)
    self.anchor:SetScript("OnDragStop",  onDragStop)
    self.anchor:SetClampedToScreen(true)
    self.anchor:SetFrameStrata("MEDIUM")

    for _, slot in ipairs(ns.SLOT_ORDER) do
        self.bars[slot] = createBar("WSTC_Bar_" .. slot, self.anchor)
    end

    engine.RegisterCallback(self, "SwingStart",       "OnSwingStart")
    engine.RegisterCallback(self, "SwingFired",       "OnSwingFired")
    engine.RegisterCallback(self, "SwingReset",       "OnSwingReset")
    engine.RegisterCallback(self, "SwingStop",        "OnSwingStop")
    engine.RegisterCallback(self, "SwingParryHasted", "OnSwingParryHasted")
    engine.RegisterCallback(self, "ClipPredicted",    "OnClipPredicted")
    engine.RegisterCallback(self, "ClipCleared",      "OnClipCleared")
    engine.RegisterCallback(self, "EquipmentChanged", "OnEquipmentChanged")
    engine.RegisterCallback(self, "AutoRepeatStart",  "OnAutoRepeatStart")
    engine.RegisterCallback(self, "AutoRepeatStop",   "OnAutoRepeatStop")

    self:ApplyTheme()
end

function UI:SetLocked(locked)
    self.db.locked = locked
end
