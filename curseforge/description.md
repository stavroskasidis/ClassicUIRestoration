# CurseForge project text

Copy-paste material for the CurseForge project page. `logo.png` (400x400) is
the project avatar; `logo-1024.png` is the same at a larger size if a bigger
image is ever needed. Regenerate both with `python curseforge\make_logo.py`.

## Project name

Forevermore Classic UI - Forever & Retail

(The in-game title, `## Title:` in the `.toc`, is the short "Forevermore Classic
UI"; the addon folder is `ForevermoreClassicUI`.)

## Summary (short field, under 250 characters)

The vanilla look on the modern UI, nothing lost: Blizzard's own frames are reskinned in place, so every feature and Edit Mode keep working. Classic unit frames, action bars, minimap, bags, nameplates and more, each switchable. Forever & Retail.

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
the rest modern.

## What it restores

- **Unit Frames**
- **Combo Points** (WoW Forever: the classic layout down the side of the target's portrait)
- **Cast Bars**
- **Breath & Fatigue Bars**
- **Nameplates**
- **Minimap**
- **Group Finder Eye** (the animated classic eye in a minimap button ring)
- **Loot Window**
- **Trainer Windows**
- **Auction House**
- **Action Bar Gryphons**
- **Vendor Window** icons (repair buttons, buyback slot)
- **Action Bar Art** (square classic button borders, vanilla slot art, page arrows)
- **Bags** (square vanilla bag slots on the bags bar, vanilla bag and backpack windows, also for the combined backpack)
- **Micro Menu** (the classic micro buttons on the vanilla stone bar panel, with your portrait on the character button)
- **Game Menu** (the vanilla Esc menu: classic dialog box and header, small red classic buttons)
- **Spellbook** (WoW Forever: the vanilla book, twelve spells per page, skill line tabs on the side)
- **Talents** (WoW Forever: the vanilla talent frame, one tree at a time with the classic branches and tabs)
- **Character Window** (WoW Forever: the vanilla paperdoll with the classic tabs, resistances and stat boxes, and the vanilla reputation and skills pages; the details pane docks to its side)

## How it works

Blizzard's frames are reskinned in place, not replaced: only textures,
positions and colours change. The buttons you click, the bars you watch and
the windows you open are still Blizzard's own, driven by Blizzard's own code,
so Edit Mode, heal prediction, absorbs, vehicles, role icons, threat, auras,
tooltips and keybinds all keep working, and new features Blizzard adds keep
showing up. The classic look follows the modern UI, not the other way
around. No libraries, nothing to configure or position; turn an element off
and it goes back to the modern look.

## Options

`/fmcui` (or `/forevermore`, `/cuir`, `/classicui`), or **Game Menu > Options > AddOns > Forevermore
Classic UI**. One checkbox per element.

## Upgrading from Classic UI Restoration

This addon used to be called **Classic UI Restoration**. If its old
`ClassicUIRestoration` folder is still in `Interface\AddOns`, the first login
copies its settings over and disables it; delete that folder afterwards.
Without the old folder the options start from their defaults.

## Feedback

Leave a comment for bugs and request.