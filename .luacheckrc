std = "lua51"
max_line_length = 140
codes = true

exclude_files = {
    "WeaponSwingTimerClassic/Libs/**",
}

globals = {
    "WeaponSwingTimerClassic",
    "WeaponSwingTimerClassicDB",
}

read_globals = {
    "LibStub",

    "UIParent",
    "CreateFrame",
    "PlaySoundFile",
    "GetTime",
    "GetBuildInfo",
    "GetLocale",

    "UnitGUID",
    "UnitClass",
    "UnitName",
    "UnitExists",
    "UnitAttackSpeed",
    "UnitRangedDamage",
    "UnitIsUnit",

    "GetInventoryItemID",
    "GetInventoryItemLink",
    "GetInventoryItemTexture",

    "GetSpellInfo",

    "CombatLogGetCurrentEventInfo",

    "INVSLOT_MAINHAND",
    "INVSLOT_OFFHAND",
    "INVSLOT_RANGED",

    "GameFontNormal",
    "GameFontNormalSmall",

    "Settings",

    table = { fields = { "wipe" } },
    string = { fields = { "format", "lower", "upper", "match", "find", "gsub" } },
    math = { fields = { "max", "min", "floor", "ceil", "abs" } },
}

ignore = {
    "212/self",
    "212/_.*",
    "213",
    "542",
}
