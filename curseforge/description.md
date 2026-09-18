# CurseForge project text

Copy-paste material for the CurseForge project page. `logo.png` (400x400) is
the project avatar; `logo-1024.png` is the same at a larger size if a bigger
image is ever needed. Regenerate both with `python curseforge\make_logo.py`.

## Project name

Classic UI Restoration

## Summary (short field, under 250 characters)

Brings back the classic (pre-Dragonflight) unit frames, cast bars, nameplates, minimap and loot window on the modern UI. Each element can be switched back to the modern look individually. For Retail and  Forever.

## Categories

- Unit Frames (primary)
- Miscellaneous

## Game versions

- World of Warcraft (retail): 12.1.x  -> upload `build\Retail\ClassicUIRestoration-<version>-retail.zip`
- WoW Forever: 1.60.x               -> upload `build\Forever\ClassicUIRestoration-<version>-forever.zip`

## Description (long field; Markdown)

Miss the old unit frames? **Classic UI Restoration** restores the look of the
pre-Dragonflight interface on top of the modern UI, one element at a time.
Every element is a separate option, so you can bring back only the parts you
miss and keep the rest modern.

### What it restores

- **Unit Frames** – the classic frame artwork and layout for the player,
  target, focus, target-of-target, pet, party and boss frames: elite / rare /
  minus dragons, the level circle, the black backdrop behind the bars, the
  classic icon positions and the circular portraits with the "Zzz" resting
  bubble and crossed-swords combat indicator. Health bars are the flat classic
  green (heal prediction and absorbs included) and power bars use the solid
  classic colours without the modern end-cap spark. Raid-style frames get the
  classic bar textures too.
- **Cast Bars** – the classic cast bar art (border, spark, finish flash,
  yellow / green / red fill colours) for the player, pet, target, focus and
  boss cast bars. Works with Edit Mode's "lock to player frame" option.
- **Nameplates** – the classic nameplate style (classic border, flat health
  bar, level in the border's bubble, flat classic cast bar).
- **Minimap** – the classic minimap: the round gold border with the zone
  text bar on top, the round tracking button, the always-visible zoom
  buttons, the calendar page with the day printed on it, the clock on its
  plate under the map, the square world map button, the letter icon for new
  mail and the compass ring / north tag. Edit Mode's size slider still
  works, and the addon compartment button gets the classic round look.
- **Loot Window** – the vanilla loot panel: the classic panel artwork with
  the skull in its ring, the classic item rows and the Prev / Next page
  arrows.

### How it works

The addon does not replace Blizzard's frames – it re-skins them in place.
Everything the modern frames do (Edit Mode, heal prediction, absorbs, vehicle
swapping, role icons, threat, auras) keeps working; only textures, positions
and colours change. No libraries, no configuration to import, nothing to
position manually.

### Options

`/cuir` (or `/classicui`), or **Game Menu > Options > AddOns > Classic UI
Restoration**. One checkbox per element.

### WoW Forever

Forever runs the modern UI, so this addon works there as well; the Forever
build additionally tidies up the few things the Forever UI adds (the level and
PvP circles on the frames, the level box next to nameplates, the day/night
indicator and coordinates on the minimap) so the classic look is complete.
Download the file matching your game version.

### Feedback

Bugs and requests: use the Issues tab. A screenshot and the output of `/cuir`
help a lot.
