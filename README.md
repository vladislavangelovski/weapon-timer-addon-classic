# Weapon Swing Timer (Classic)

A World of Warcraft **Classic Era** addon that tracks your main-hand, off-hand, and ranged swing timers with class-aware reset detection and a clipping-prediction warning.

Built from scratch as a learning project; architecture and rationale are documented in [`docs/superpowers/specs/2026-04-24-weapon-swing-timer-classic-design.md`](docs/superpowers/specs/2026-04-24-weapon-swing-timer-classic-design.md).

## Features

- Horizontal status-bar timer per weapon slot (MH / OH / ranged), stacked dynamically
- Class-aware swing-reset detection
    - Warrior: Slam resets the MH timer; Heroic Strike and Cleave are handled as on-next-swing abilities
    - Hunter: Aimed Shot and Multi-Shot correctly pause and resume the ranged timer
    - Caster classes (Mage / Priest / Warlock): wand `Shoot` channel handled
- Parry-haste shortening of the MH timer when the player parries an incoming swing (Vanilla rule: up to 40% of base speed, floor at 20%)
- Clipping-prediction warning: a cast that would delay the next swing tints the affected bar red
- Haste-change scaling that preserves visual progress during weapon-proc haste events
- Per-character AceDB profiles with a full in-game options panel (texture, font, colors, sounds, icon, spark)
- Slash commands: `/wst` to open options, `/wst lock`, `/wst unlock`, `/wst reset`, `/wst help`

## Install

### From a release zip

1. Grab the latest zip from the [Releases page](../../releases).
2. Unzip into `<WoW>\_classic_era_\Interface\AddOns\` so you end up with `...\_classic_era_\Interface\AddOns\WeaponSwingTimerClassic\WeaponSwingTimerClassic.toc`.
3. Start the game, make sure the addon is enabled on the character-select screen's AddOns list.

### From source (development)

Dev iteration is easiest with a junction (Windows) or symlink:

```
mklink /J "C:\Program Files (x86)\World of Warcraft\_classic_era_\Interface\AddOns\WeaponSwingTimerClassic" "C:\path\to\weapon-timer-addon-classic\WeaponSwingTimerClassic"
```

Then fetch libraries once with the [BigWigs Packager](https://github.com/BigWigsMods/packager) (required the first time because `Libs/` is not committed):

```
# in WSL or git bash:
curl -s https://raw.githubusercontent.com/BigWigsMods/packager/master/release.sh | bash -s -- -z -d
```

Or copy the required Ace3 / LibStub / CallbackHandler / LibSharedMedia libraries manually into `WeaponSwingTimerClassic/Libs/`.

Then in-game, `/reload` after each Lua change.

## Usage

- `/wst` — open the options panel (also accessible via Esc → Interface → AddOns)
- `/wst lock` / `/wst unlock` — toggle drag-to-move
- `/wst reset` — re-center the bars if you've lost them off-screen
- `/wst help` — list commands

Drag the bars while unlocked to position them. Lock when happy.

## Project layout

```
weapon-timer-addon-classic/
├── .github/workflows/              # CI: luacheck on pushes, BigWigs Packager on tags
├── .pkgmeta                        # BigWigs Packager manifest (library sources)
├── .luacheckrc                     # luacheck config (WoW API globals declared)
├── docs/superpowers/specs/         # design spec (source of truth)
├── WeaponSwingTimerClassic/        # the addon folder — what gets zipped
│   ├── WeaponSwingTimerClassic.toc
│   ├── embeds.xml
│   ├── Defaults.lua                # saved-variables schema
│   ├── Engine.lua                  # swing state machine
│   ├── ClassResets.lua             # per-class spell-event handlers
│   ├── UI.lua                      # StatusBar frames + OnUpdate
│   ├── Config.lua                  # AceConfig options tree
│   └── Core.lua                    # AceAddon root (wires everything)
└── TESTING.md                      # manual in-game test plan
```

## License

See [LICENSE](LICENSE).
