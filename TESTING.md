# Manual test plan

Since WoW addons can't be meaningfully unit-tested outside the client, this document walks through every scenario the spec calls out. Run through the whole list after any substantive change; tick each item off as you go.

## Pre-flight

- [ ] Addon loads without a Lua error (check BugSack / BugGrabber).
- [ ] `/wst` opens the options panel.
- [ ] `/wst help` lists all commands.
- [ ] Type `/etrace` and filter for `UNIT_SPELLCAST_*`, `COMBAT_LOG_EVENT_UNFILTERED`, `PLAYER_EQUIPMENT_CHANGED`, `START_AUTOREPEAT_SPELL`, `STOP_AUTOREPEAT_SPELL` to verify the events fire as expected while you play.

## Melee — main hand

- [ ] Equip a 2H weapon, attack a training dummy.
- [ ] The MH bar appears and fills from 0 to 1 over the weapon's base speed (e.g. 3.70s for a slow 2H).
- [ ] The spark tracks the leading edge of the fill.
- [ ] When the swing lands, the bar snaps back to 0 and starts again.
- [ ] Leave combat; out of combat, the bar stops updating but stays visible.

## Melee — dual wield

- [ ] Equip a 1H + 1H (rogue, fury warrior with dual-wield, shaman with dual-wield).
- [ ] Both MH and OH bars appear, stacked.
- [ ] Each bar tracks its own weapon speed (MH and OH ticker independently at their respective speeds).
- [ ] Remove the off-hand mid-combat — the OH bar disappears, MH stays.
- [ ] Re-equip — OH reappears.

## Ranged — hunter Auto Shot

- [ ] As Hunter, equip a bow/gun/crossbow.
- [ ] Ranged bar is hidden while auto-repeat is off.
- [ ] Target a dummy, press Auto Shot — ranged bar appears and ticks at the ranged weapon speed.
- [ ] Cast Aimed Shot — ranged bar pauses/disappears during the cast (PauseRanged).
- [ ] After Aimed Shot fires, auto-repeat resumes and the ranged bar re-ticks at the next shot.
- [ ] Toggle "Ranged bar always visible" in options — ranged bar stays visible while idle out of combat.

## Ranged — wand Shoot

- [ ] As a caster (Mage/Priest/Warlock), equip a wand and a target.
- [ ] Cast Shoot — ranged bar shows the wand cast timing.
- [ ] Cast Fireball (or any hard cast) — wand Shoot channel breaks; ranged bar behaves sanely.

## Parry haste

- [ ] Fight a mob that parries melee attacks (many humanoids).
- [ ] When you see "parried!" in the log with the player as victim… wait, that's the wrong direction. The rule is: when **you** parry **their** swing, **your** next swing is shortened.
- [ ] Watch the MH bar when you parry — it should jump forward (up to 40% of base speed faster), but not past the 20%-of-base-speed floor.

## Warrior — Slam reset

- [ ] Equip as Warrior, attack a dummy.
- [ ] While a swing is in flight, cast Slam.
- [ ] During the 1.5s Slam cast, the MH bar may tick red (clip warning).
- [ ] When Slam lands, the MH bar resets to 0 and starts over (Slam replaces the swing).

## Warrior — Heroic Strike / Cleave (on-next-swing)

- [ ] Queue Heroic Strike before a swing lands.
- [ ] When the swing lands, the combat log shows `SPELL_DAMAGE: Heroic Strike` instead of `SWING_DAMAGE`.
- [ ] The MH bar still restarts correctly (ClassResets listens for the `SPELL_DAMAGE` fallback).
- [ ] Repeat with Cleave.

## Weapon swap mid-combat

- [ ] While swinging on a dummy, swap to a different MH weapon with a different speed.
- [ ] MH timer resets; the new timer uses the new weapon's speed.
- [ ] Same for OH and ranged (swap bow while auto-shooting).

## Clipping warning

- [ ] As any class with a cast-time ability (e.g. Fireball, Slam, Aimed Shot), start a cast while a melee swing is ticking.
- [ ] If the cast would end *after* the swing would otherwise fire, the MH/OH bar tints red (clip warning overlay).
- [ ] If the cast ends / is interrupted / fails before the swing, the red tint clears.
- [ ] Toggle "Show clip warning" off; verify the tint stops appearing.
- [ ] Enable "Sound on clip warning"; verify the sound plays once on clip start.

## Idle state (no CPU / no errors)

- [ ] Stand in a capital city out of combat for a minute.
- [ ] No Lua errors in BugSack.
- [ ] Framerate is unchanged (OnUpdate should not be registered when nothing is active).
- [ ] Mount up, ride around — no errors.

## Configuration

- [ ] Change bar texture in options — applied immediately.
- [ ] Change font — applied.
- [ ] Change each color — applied.
- [ ] Resize width/height/spacing — applied.
- [ ] Toggle spark, icon, time text — applied.
- [ ] Change icon position LEFT / RIGHT — visuals update.
- [ ] Adjust alpha — entire frame fades.
- [ ] Pick a sound from the Sounds group and toggle on — verify at next swing.

## Profiles

- [ ] Create a new profile named "Raid", modify it.
- [ ] Switch back to "Default" — settings revert.
- [ ] Copy "Raid" into "Default" — settings match.
- [ ] Reset "Default" — defaults restored, UI repositions to center-ish.

## Drag & reset

- [ ] `/wst unlock` — drag the bars to a new location.
- [ ] `/reload` — position persists.
- [ ] `/wst reset` — bars return to screen center.
- [ ] `/wst lock` — drag is disabled.

## Edge cases

- [ ] Enter a vehicle or take control of a pet — no errors (PLAYER_EQUIPMENT_CHANGED may fire).
- [ ] Die and release — no errors.
- [ ] Switch spec / unlearn Slam → verify Slam reset no longer attempts to fire.
- [ ] `/reload` with a bar active — state is lost (that's OK; next swing will re-establish).

## Distribution dry-run (optional)

- [ ] Create a tag `v0.1.0-rc1`, push it.
- [ ] GitHub Action builds a zip and attaches it to the release.
- [ ] Download and install the zip; verify the addon loads and works.
