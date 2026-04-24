local ADDON_NAME, ns = ...

local Config = {}
ns.Config = Config

local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")
local LSM             = LibStub("LibSharedMedia-3.0")

-- ============================================================================
-- LSM values helper
--
-- AceConfig `select` expects `values` to be { key = display } pairs. LSM's
-- HashTable returns { name = path } so we can't pass it directly; we build a
-- name->name map from LSM:List so the stored db key is the same string the
-- user sees.
-- ============================================================================

local function lsmValues(mediaType)
    local out = {}
    for _, name in ipairs(LSM:List(mediaType) or {}) do
        out[name] = name
    end
    out.None = "None"
    return out
end

-- ============================================================================
-- Options tree
-- ============================================================================

local function buildOptions(dbRoot)
    -- Always dereference dbRoot.profile fresh so profile switches work without
    -- rebuilding the options tree.
    local function get(info) return dbRoot.profile[info[#info]] end
    local function set(info, value)
        dbRoot.profile[info[#info]] = value
        ns.UI:ApplyTheme()
    end
    local function setRelayout(info, value)
        dbRoot.profile[info[#info]] = value
        ns.UI:Relayout()
    end
    local function getColor(info)
        local c = dbRoot.profile.colors[info[#info]]
        return c.r, c.g, c.b, 1
    end
    local function setColor(info, r, g, b)
        local c = dbRoot.profile.colors[info[#info]]
        c.r, c.g, c.b = r, g, b
        ns.UI:ApplyTheme()
    end

    return {
        type = "group",
        name = "Weapon Swing Timer",
        args = {
            general = {
                type = "group", order = 1, name = "General",
                args = {
                    locked = {
                        type = "toggle", order = 1, name = "Lock bars",
                        desc = "Prevent the bars from being dragged.",
                        get = get, set = set,
                    },
                    clipWarning = {
                        type = "toggle", order = 2, name = "Show clip warning",
                        desc = "Tint a bar red when a cast will delay it past the next swing.",
                        get = get, set = set,
                    },
                    rangedAlwaysVisible = {
                        type = "toggle", order = 3, name = "Ranged bar always visible",
                        desc = "Show the ranged bar even when auto-repeat is off (ranged weapon still required).",
                        get = get, set = setRelayout,
                    },
                },
            },

            appearance = {
                type = "group", order = 2, name = "Appearance",
                args = {
                    width = {
                        type = "range", order = 1, name = "Bar width",
                        min = 80, max = 400, step = 1, get = get, set = set,
                    },
                    height = {
                        type = "range", order = 2, name = "Bar height",
                        min = 8, max = 40, step = 1, get = get, set = set,
                    },
                    spacing = {
                        type = "range", order = 3, name = "Spacing between bars",
                        min = 0, max = 20, step = 1, get = get, set = set,
                    },
                    alpha = {
                        type = "range", order = 4, name = "Alpha",
                        min = 0.1, max = 1.0, step = 0.05, isPercent = false,
                        get = get, set = set,
                    },
                    texture = {
                        type = "select", order = 5, name = "Bar texture",
                        values = function() return lsmValues("statusbar") end,
                        get = get, set = set,
                    },
                    font = {
                        type = "select", order = 6, name = "Font",
                        values = function() return lsmValues("font") end,
                        get = get, set = set,
                    },
                    fontSize = {
                        type = "range", order = 7, name = "Font size",
                        min = 6, max = 24, step = 1, get = get, set = set,
                    },
                    showTimeText = {
                        type = "toggle", order = 8, name = "Show time text",
                        get = get, set = set,
                    },
                    showSpark = {
                        type = "toggle", order = 9, name = "Show spark",
                        get = get, set = set,
                    },
                    showIcon = {
                        type = "toggle", order = 10, name = "Show weapon icon",
                        get = get, set = set,
                    },
                    iconPosition = {
                        type = "select", order = 11, name = "Icon position",
                        values = { LEFT = "Left", RIGHT = "Right" },
                        get = get, set = set,
                    },
                    iconSize = {
                        type = "range", order = 12, name = "Icon size",
                        min = 8, max = 40, step = 1, get = get, set = set,
                    },
                },
            },

            colors = {
                type = "group", order = 3, name = "Colors",
                args = {
                    mainHand = { type = "color", order = 1, name = "Main hand", hasAlpha = false,
                                 get = getColor, set = setColor },
                    offHand  = { type = "color", order = 2, name = "Off hand",  hasAlpha = false,
                                 get = getColor, set = setColor },
                    ranged   = { type = "color", order = 3, name = "Ranged",    hasAlpha = false,
                                 get = getColor, set = setColor },
                    clipping = { type = "color", order = 4, name = "Clip warning", hasAlpha = false,
                                 get = getColor, set = setColor },
                },
            },

            sounds = {
                type = "group", order = 4, name = "Sounds",
                args = {
                    soundOnSwing = {
                        type = "toggle", order = 1, name = "Sound when swing fires",
                        get = get, set = set,
                    },
                    soundOnSwingKey = {
                        type = "select", order = 2, name = "Swing sound",
                        values = function() return lsmValues("sound") end,
                        get = get, set = set,
                    },
                    soundOnClip = {
                        type = "toggle", order = 3, name = "Sound on clip warning",
                        get = get, set = set,
                    },
                    soundOnClipKey = {
                        type = "select", order = 4, name = "Clip sound",
                        values = function() return lsmValues("sound") end,
                        get = get, set = set,
                    },
                },
            },

            profiles = AceDBOptions:GetOptionsTable(dbRoot),
        },
    }
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function Config:Initialize(addon)
    self.addon  = addon
    self.dbRoot = addon.db
    self.options = buildOptions(self.dbRoot)

    AceConfig:RegisterOptionsTable(ADDON_NAME, self.options)
    self.blizFrame = AceConfigDialog:AddToBlizOptions(ADDON_NAME, "Weapon Swing Timer")
end

function Config:Open()
    AceConfigDialog:Open(ADDON_NAME)
end
