# Classic UI Restoration

Restores the classic (pre-Dragonflight) look of the default UI, one element at
a time. Every element has its own option and can be switched back to the
modern look.

Ships for retail 12.1 (`## Interface: 120100`) and for World of Warcraft:
Forever 1.60 (`## Interface: 16001`). No external libraries.

## Options

Open with `/cuir` (or `/classicui`), or via **Game Menu > Options > AddOns >
Classic UI Restoration**.

| Option | What it does | Toggle |
| --- | --- | --- |
| **Unit Frames** | Classic frame artwork and layout for the player, target, focus, target-of-target, pet, party and boss frames (elite/rare/minus dragons, level background, classic icon positions, black backdrop behind the bars), the classic circular portraits with the "Zzz" resting bubble and crossed-swords combat indicator on the player portrait, and the flat classic health bars (green, incl. heal prediction / absorb overlays) and power bars (solid classic colours, no end-cap spark). The raid-style frame bars get the classic textures as well. | UI reload |
| **Cast Bars** | Classic cast bar art (border, spark, flash, yellow/green/red fill colours) for the player, pet, target, focus and boss cast bars. Works with the "lock to player frame" Edit Mode option. | Immediate |
| **Breath & Fatigue Bars** | Classic look for the mirror timers (breath, fatigue, feign death): the flat bar on a black backdrop with the label on the bar, the large classic cast bar border and the classic colours (blue breath, yellow fatigue, orange death / feign death). Edit Mode's position and size settings keep working. | Immediate |
| **Nameplates** | Switches nameplates to the client's built-in classic style (classic border, flat health bar, level text in the border's bubble, flat cast bar without spark) and remembers the previous style so it can be restored. | Immediate |
| **Minimap** | Classic minimap: the 140px map in the round `UI-Minimap-Border` ring with the zone text bar on top, the round tracking button on the left, always-visible classic zoom buttons, the calendar page with the day printed on it, the clock on its plate at the bottom of the map, the square world map button, the letter icon (in a ring) for new mail and crafting orders, the compass ring while "rotate minimap" is on and the north tag otherwise. The addon compartment button gets the same round classic button look, below the tracking button. Edit Mode's size slider and the icon scale still work; its "header underneath" option has no classic equivalent and is ignored. | UI reload |
| **Loot Window** | The vanilla loot panel: the classic `UI-LootPanel` artwork with the skull (fishing bobber for fishing loot) in its ring, the round close button, one classic name plate per item and the Prev / Next arrows; four items fit, with more the panel shows three per page like the original (the mouse wheel steps one row). Blizzard's looting, tooltips, quest markers and the "open loot window at mouse" option keep working. | UI reload |
| **Action Bar Gryphons** | The vanilla stone gryphons (`UI-MainMenuBar-EndCap-Dwarf`) at both ends of the main action bar instead of the modern gryphon/wyvern art. Classic showed the gryphon to both factions, so Horde characters get it too. Edit Mode's "hide bar art" option and the bar's scale keep working. | Immediate |

The "UI reload" options are applied while the interface loads because
Blizzard's frames cannot be safely un-skinned at runtime; changing them
prompts for a reload (there is also a Reload button on the options page and
`/cuir reload`).

## How it works

The 12.x client still ships the legacy textures
(`Interface\TargetingFrame\UI-TargetingFrame`, `UI-StatusBar`,
`Interface\CastingBar\UI-CastingBar-*`, ...), so the addon re-skins Blizzard's
own frames in place: the retail bars, texts and icons are kept and only
re-textured and re-anchored. Blizzard's layout functions are hooked with
`hooksecurefunc` so the classic layout survives target changes, vehicle
swapping, party roster updates and Edit Mode.

Cast bars are re-textured from script hooks on the bars themselves (their
cast methods must not be hooked on 12.x, see `Modules\CastBars.lua`), the
breath/fatigue timers are Blizzard's own timer frames re-textured in place,
and nameplates use the `nameplateStyle` CVar's Classic value. The minimap keeps
Blizzard's cluster (so Edit Mode, the tracking menu and the notifications keep
working) and re-parents its pieces into the scaled map container at the
classic positions.
The loot window keeps Blizzard's scroll-box list of items and only re-skins
the panel and the rows; the classic page arrows scroll that list a page at
a time. The action bar gryphons are Blizzard's own end cap textures with the
vanilla file (cropped to its art and scaled to the modern 45px buttons) in
place of the modern atlas; on Forever, where each end cap is a movable Edit
Mode frame, only the texture inside it is swapped.

## WoW Forever

Forever's UI is the retail 12.x UI with a small "camelot" game-type overlay
(`Blizzard_UnitFrame\Camelot\*`, `Blizzard_NamePlates\Camelot\*` in Blizzard's
UI source, branch `forever`), so the Forever build is the same code plus one
extra module, `Modules/Forever.lua`, which handles what the overlay adds:

- the level is shown in a small circle in the bottom corner of the
  player/target/focus/boss frames (`LevelBackgroundCircle`, large white font):
  hidden, and the classic level font/colour is restored in the frame art's
  own circle,
- PvP status is a small faction circle (`PvpBackgroundCircle` +
  `PvpBackgroundIcon`): the circle is hidden and the icon is placed where
  classic had its PvP banner (using the legacy
  `Interface\TargetingFrame\UI-PVP-*` art when the client has it, otherwise
  Blizzard's small icon),
- nameplates get a level indicator box (`PlayerLevelDiffFrame`) to the right
  of every health bar: hidden while the classic nameplate style is on, and the
  bar takes the full width again,
- the hunter pet happiness indicator next to the pet frame is left as is,
- the minimap frame is re-skinned by the overlay on every "rotate minimap"
  change (`Blizzard_Minimap\Camelot\Skin.lua`); the classic art is put back
  afterwards, and the overlay's day/night indicator (`MinimapCluster.DielFrame`),
  which sits where classic has the calendar, is moved to the bottom left of
  the ring and its player coordinates are moved below the classic clock.

## Files

```
ClassicUIRestoration.toc per flavor (Interface version, file list)
Core.lua                 saved variables, module registry, helpers
Options.lua              Settings panel + slash commands
Modules/UnitFrames.lua   frame art & layout
Modules/Portraits.lua    portrait masks, rest/combat indicators
Modules/HealthBars.lua   health bar textures/colours
Modules/PowerBars.lua    power bar textures/colours
Modules/CastBars.lua     classic cast bars (live toggle)
Modules/MirrorTimers.lua classic breath/fatigue timer bars (live toggle)
Modules/Nameplates.lua   classic nameplate style (live toggle)
Modules/Minimap.lua      classic minimap cluster
Modules/LootFrame.lua    classic loot window
Modules/EndCaps.lua      vanilla action bar gryphons (live toggle)
Modules/Forever.lua      Forever only: adjustments for the "camelot" overlay
```
