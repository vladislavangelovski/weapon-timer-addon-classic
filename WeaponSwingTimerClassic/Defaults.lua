local _, ns = ...

ns.defaults = {
    profile = {
        locked = false,

        position = {
            point    = "CENTER",
            relPoint = "CENTER",
            x        = 0,
            y        = -150,
        },

        width    = 200,
        height   = 16,
        spacing  = 4,
        alpha    = 1.0,

        texture  = "Blizzard",
        font     = "Friz Quadrata TT",
        fontSize = 11,

        showTimeText = true,
        showSpark    = true,
        showIcon     = true,
        iconPosition = "LEFT",
        iconSize     = 16,

        rangedAlwaysVisible = false,
        clipWarning         = true,

        soundOnSwing    = false,
        soundOnSwingKey = "None",
        soundOnClip     = false,
        soundOnClipKey  = "None",

        colors = {
            mainHand = { r = 0.2, g = 0.6, b = 1.0 },
            offHand  = { r = 0.4, g = 0.4, b = 1.0 },
            ranged   = { r = 0.9, g = 0.6, b = 0.1 },
            clipping = { r = 1.0, g = 0.0, b = 0.0 },
        },
    },
}

ns.SLOT_ORDER = { "mainHand", "offHand", "ranged" }

ns.SLOT_TO_INVSLOT = {
    mainHand = INVSLOT_MAINHAND or 16,
    offHand  = INVSLOT_OFFHAND  or 17,
    ranged   = INVSLOT_RANGED   or 18,
}

ns.SLOT_LABEL = {
    mainHand = "MH",
    offHand  = "OH",
    ranged   = "Ranged",
}
