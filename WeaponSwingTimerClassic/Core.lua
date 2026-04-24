local ADDON_NAME, ns = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")
ns.addon = addon

-- ============================================================================
-- Lifecycle
-- ============================================================================

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("WeaponSwingTimerClassicDB", ns.defaults, true)

    ns.UI:Initialize(ns.Engine, self.db.profile)
    ns.Config:Initialize(self)

    self:RegisterChatCommand("wst",  "HandleSlash")
    self:RegisterChatCommand("wstc", "HandleSlash")

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied",  "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",   "OnProfileChanged")
end

-- AceAddon's OnEnable fires at ADDON_LOADED, where UnitGUID may still be nil
-- on cold login (before PLAYER_LOGIN). Defer player-specific init to whichever
-- of the two points the GUID becomes valid.
function addon:OnEnable()
    if UnitGUID("player") then
        self:FinishInit()
    else
        self:RegisterEvent("PLAYER_LOGIN", "FinishInit")
    end
end

function addon:FinishInit()
    self:UnregisterEvent("PLAYER_LOGIN")
    local _, classToken = UnitClass("player")
    ns.Engine:Initialize(UnitGUID("player"))
    ns.ClassResets:Initialize(ns.Engine, classToken)
    ns.Engine:Enable()
    ns.ClassResets:Enable()
    ns.UI:Relayout()
end

function addon:OnDisable()
    if ns.Engine.UnregisterAllEvents then ns.Engine:Disable() end
    if ns.ClassResets.UnregisterAllEvents then ns.ClassResets:Disable() end
end

function addon:OnProfileChanged()
    ns.UI.db = self.db.profile
    ns.UI:ApplyTheme()
end

-- ============================================================================
-- Slash command
-- ============================================================================

function addon:HandleSlash(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$") or ""

    if input == "lock" then
        self.db.profile.locked = true
        self:Print("Bars locked.")
    elseif input == "unlock" then
        self.db.profile.locked = false
        self:Print("Bars unlocked. Click and drag the bars to reposition.")
    elseif input == "reset" then
        self.db.profile.position.point    = "CENTER"
        self.db.profile.position.relPoint = "CENTER"
        self.db.profile.position.x        = 0
        self.db.profile.position.y        = -150
        ns.UI:ApplyTheme()
        self:Print("Position reset to screen center.")
    elseif input == "help" or input == "?" then
        self:Print("/wst           - open options")
        self:Print("/wst lock      - lock bars")
        self:Print("/wst unlock    - unlock bars for dragging")
        self:Print("/wst reset     - reset position to screen center")
    else
        ns.Config:Open()
    end
end
