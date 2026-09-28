# CurseForge project text

Copy-paste material for the CurseForge project page. `logo.png` (400x400) is
the project avatar; `logo-1024.png` is the same at a larger size if a bigger
image is ever needed. Regenerate both with `python curseforge\make_logo.py`.

## Project name

Forevermore Classic UI - Forever & Retail

(The in-game title, `## Title:` in the `.toc`, is the short "Forevermore Classic
UI"; the addon folder is `ForevermoreClassicUI`.)

## Summary (short field, under 250 characters)

The best Classic UI addon. Every UI feature and Edit Mode keeps working. Classic unit frames, action bars, minimap, bags, nameplates and more, each switchable. Make the UI as Classic as you want. For Forever & Retail.

## Categories

- Unit Frames (primary)
- Miscellaneous

## Game versions

One file for both: upload `build\ForevermoreClassicUI-<version>.zip` and tick
every supported version in the file's Game Version field:

- WoW Retail: 12.1.x
- WoW Forever: 1.60.x

# Description

**Forevermore Classic UI** brings the classic look to the modern UI of
WoW Forever and Retail, without breaking it.

It is a **reskin, not a replacement**. Instead of rebuilding the old frames
from scratch, Forevermore keeps Blizzard's own frames and only changes how
they look, so **no functionality is lost**: Edit Mode, heal prediction, absorbs,
auras, vehicles, the search boxes, the sort buttons, the auction house
commodity market, staged talent changes, casting from the spellbook in combat,
all of it keeps working, now wearing the vanilla art.

Each element is its own option, so restore only the parts you miss and keep
the rest modern. On the first login (after installing or updating) a **setup wizard** asks how you want it:
one-click presets (everything classic, or a classic HUD with modern windows
or the reverse), or going through the elements one by one
with a picture of the modern and the classic look side by side.

## What it restores

- **Unit Frames**
- **Combo Points** (WoW Forever)
- **Cast Bars**
- **Breath & Fatigue Bars**
- **Nameplates**
- **Minimap**
- **Group Finder Eye**
- **Loot Window**
- **Trainer Windows**
- **Auction House**
- **Action Bar Gryphons**
- **XP & Reputation Bars**
- **Vendor Window**
- **Action Bar Art**
- **Bags**
- **Micro Menu**
- **Game Menu**
- **Spellbook** (WoW Forever)
- **Talents** (WoW Forever)
- **Character Window** (WoW Forever)
- **Professions Window** (WoW Forever)

## How it works

Blizzard's frames are reskinned in place, not replaced: only textures,
positions and colours change. The buttons you click, the bars you watch and
the windows you open are still Blizzard's own, driven by Blizzard's own code,
so Edit Mode, heal prediction, absorbs, vehicles, role icons, threat, auras,
tooltips and keybinds all keep working, and new features Blizzard adds keep
showing up. The classic look follows the modern UI, not the other way
around. No libraries, nothing to configure or position; turn an element off
and it goes back to the modern look.

## Known limitations

- **Friendly nameplates in dungeons and raids** keep the modern look: Blizzard
  locks them so no addon can change them. Enemy nameplates there are classic.

## Options

`/fmcui` (or `/forevermore`, `/cuir`, `/classicui`), or **Game Menu > Options > AddOns > Forevermore
Classic UI**: every element with a picture of its current look and a
Modern / Classic switch, plus All Classic / All Modern. `/fmcui setup` (or the
Setup Wizard button there) opens the setup wizard again.

## Upgrading from Classic UI Restoration

This addon used to be called **Classic UI Restoration**. If its old
`ClassicUIRestoration` folder is still in `Interface\AddOns`, the first login
copies its settings over and disables it; delete that folder afterwards.
Without the old folder the options start from their defaults.

## Feedback

Leave a comment for bugs and request.