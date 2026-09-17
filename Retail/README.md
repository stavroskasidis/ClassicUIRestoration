# Classic UI Restoration

Restores the classic (pre-Dragonflight) look of the default retail UI, one
element at a time. Every element has its own option and can be switched back to
the retail look.

Targets retail 12.1 (`## Interface: 120100`). No external libraries.

## Options

Open with `/cuir` (or `/classicui`), or via **Game Menu > Options > AddOns >
Classic UI Restoration**.

| Option | What it does | Toggle |
| --- | --- | --- |
| **Unit Frames** | Classic frame artwork and layout for the player, target, focus, target-of-target, pet, party and boss frames (elite/rare/minus dragons, level background, classic icon positions, black backdrop behind the bars), the classic circular portraits with the "Zzz" resting bubble and crossed-swords combat indicator on the player portrait, and the flat classic health bars (green, incl. heal prediction / absorb overlays) and power bars (solid classic colours, no end-cap spark). The raid-style frame bars get the classic textures as well. | UI reload |
| **Cast Bars** | Classic cast bar art (border, spark, flash, yellow/green/red fill colours) for the player, pet, target, focus and boss cast bars. Works with the "lock to player frame" Edit Mode option. | Immediate |
| **Nameplates** | Switches nameplates to the client's built-in classic style (classic border, flat health bar, level text, small classic cast bar) and remembers the previous style so it can be restored. | Immediate |

The "UI reload" option is applied while the interface loads because
Blizzard's frames cannot be safely un-skinned at runtime; changing it
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

Cast bars use the `classicStyleCastBar` mode that Blizzard's `CastingBarMixin`
already supports, and nameplates use the `nameplateStyle` CVar's Classic value.

## Files

```
ClassicUIRestoration.toc
Core.lua                 saved variables, module registry, helpers
Options.lua              Settings panel + slash commands
Modules/UnitFrames.lua   frame art & layout
Modules/Portraits.lua    portrait masks, rest/combat indicators
Modules/HealthBars.lua   health bar textures/colours
Modules/PowerBars.lua    power bar textures/colours
Modules/CastBars.lua     classic cast bars (live toggle)
Modules/Nameplates.lua   classic nameplate style (live toggle)
```
