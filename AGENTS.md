# Agent instructions for Classic UI Restoration

This repository contains *Classic UI Restoration*, a World of Warcraft addon
that restores pre-Dragonflight UI elements (unit frames, cast bars, nameplates,
minimap)
on the modern client, with each element individually switchable back to the
retail look.

## Repository layout

```
src/Shared/             addon code common to every flavor (lands in the addon root when built)
  Core.lua              namespace, textures/colours, module registry, mirror bars, lifecycle, /cuir
  Options.lua           Settings panel (one checkbox per top-level module) + reload prompt
  Modules/UnitFrames.lua   classic frame art & layout (player/target/focus/ToT/pet/party/boss)
  Modules/Portraits.lua    portrait masks, rest/combat indicators   (part of Unit Frames)
  Modules/HealthBars.lua   health bar textures/colours              (part of Unit Frames)
  Modules/PowerBars.lua    power bar textures/colours               (part of Unit Frames)
  Modules/CastBars.lua     classic cast bars (live toggle)
  Modules/Nameplates.lua   classic nameplate style (live toggle)
  Modules/Minimap.lua      classic minimap cluster (reload; keeps Blizzard's cluster, re-parents its pieces into MinimapContainer)
  README.md             user-facing description of every option (both flavors)
src/Retail/             retail WoW flavor (Interface 12.x)
  ClassicUIRestoration.toc
src/Forever/            WoW Forever flavor (Interface 16001, client 1.60.x)
  ClassicUIRestoration.toc
  Modules/Forever.lua   Forever-only adjustments for the "camelot" UI overlay (loaded last)
addon.json              addon name, version (single source; .toc files carry @project-version@)
                        and the flavors with the game folder each deploys to ("gameDir")
build.ps1               assembles src\Shared + each flavor into build\<Flavor>\ClassicUIRestoration\
                        and zips it as build\<Flavor>\ClassicUIRestoration-<version>-<flavor>.zip (CurseForge layout)
build/                  build output (git-ignored); what deploy.ps1 copies into the game
deploy.ps1              builds + mirrors every installed flavor into the game (-Flavor X for one)
deploy.config.json      machine-specific WoW path (git-ignored, never commit)
curseforge/             project page material: logo.png (+ make_logo.py to regenerate it), description.md
```

Flavors: `Retail` -> `_retail_`, `Forever` -> `_classic_beta_` (declared in
`addon.json`; Forever currently ships as the `wow_classic_beta` product and
will need a new `gameDir` once it gets its own). Every flavor in `addon.json`
must have a `src/<Flavor>/ClassicUIRestoration.toc`. The build flattens `src/Shared/`
and `src/<Flavor>/` into one addon folder (flavor files win on equal paths), so the
`.toc` files list shared files by their plain path (`Core.lua`,
`Modules\UnitFrames.lua`); every `.toc` must list the same shared files in
the same order, so add a new shared file to all of them. Flavor-specific code
lives only in the flavor folder (Forever: `Modules/Forever.lua`, which hooks
the same Blizzard functions *after* the shared modules); never add runtime
flavor detection to `src/Shared/`, and never edit anything under `build/`.

## Workflow

- Edit files under `src/` only. `build/` and the copies inside the game
  folders are outputs; never edit them directly and never touch anything else
  in the game install.
- Deploy with `.\deploy.ps1` (PowerShell): it runs `build.ps1` for every
  flavor whose game folder exists (skipping uninstalled clients) and mirrors
  `build\<Flavor>\ClassicUIRestoration\` into
  `<WoW>\<gameDir>\Interface\AddOns\ClassicUIRestoration\`; `-Flavor X`
  deploys one flavor. The user then runs `/reload` in game; the addon cannot
  be tested outside the game client. A change under `src/Shared/` affects
  both flavors: say so, since the user will typically test one of them.
- There is no automated test suite in the repo. Before handing over, at least
  check Lua syntax (e.g. with a Lua parser) and re-read the changed code for
  the taint rules below. In-game verification is done by the user; ask for a
  `/reload` and, when useful, a screenshot or the output of `/cuir`.
- Keep `src/Shared/README.md` in sync with the options and behaviour. For a
  user-visible release bump `"version"` in `addon.json` (`x.y.z`); never write
  a literal version into a `.toc` — they contain `## Version: @project-version@`,
  which `build.ps1` replaces (in `.toc`, `.lua` and `.md` files) and uses for
  the zip name. `ns.VERSION` in `Core.lua` reads it back from the TOC.
- Do not commit unless asked. Never commit `deploy.config.json`.

## Client facts (retail 12.x) that shape the code

- `## Interface: 120100` (12.1.0). Blizzard's UI source is
  https://github.com/Gethe/wow-ui-source (branch `live`); use the 9.2.x tag for
  classic coordinates/texture coords. Read the real source before hooking or
  re-anchoring anything — names and hierarchies change between patches.
- **WoW Forever** (`src/Forever/`): `## Interface: 16001` (client 1.60.1, product
  `wow_classic_beta`, exe `WowB.exe`; interface version = `%d%02d%02d` of the
  client version, so 1.60.1 -> 16001). Its UI is the *mainline* (12.x) code
  loaded with game type `camelot`: Blizzard's source is the `forever` branch of
  wow-ui-source, where `.toc` lines tagged `[AllowLoadGameType camelot]` and the
  `Camelot\` sub-folders override the Mainline files. Everything in the retail
  rules below (secrets, taint, protected frames, mirror bars) applies to
  Forever unchanged. Known overlay differences: level shown in
  `<ContentMain>.LevelBackgroundCircle`, PvP status in
  `PvpBackgroundCircle/PvpBackgroundIcon` (retail `PVPIcon`/`PrestigePortrait`
  never shown), nameplate `PlayerLevelDiffFrame` level box next to the health
  bar, `PetFrameHappiness`, `ComboFrame_ApplyOverrides`, minimap `DielFrame`
  (day/night) and `MinimapContainer.PlayerCoords`. To find the installed
  client's interface version in game: `/run print((select(4, GetBuildInfo())))`.
- The legacy textures (`Interface\TargetingFrame\UI-TargetingFrame`,
  `UI-StatusBar`, `Interface\CastingBar\*`, `Interface\Tooltips\Nameplate-Border`
  etc.) still ship with the retail client, so the addon references them by path
  and does not bundle copies. Note the retail `Nameplate-Border` is 256x32 with
  the art in the left 136 px.
- **Secrets:** unit health/power/cast values may be "secret" (12.x). Addon code
  must not compare, do arithmetic on, or format them. They may be passed
  straight through to `StatusBar:SetValue/SetMinMaxValues` (allowed when
  tainted) but not to `SetPoint/SetSize/SetParent` (offset math is not allowed).
  `GetPoint/GetSize` on nameplate regions are restricted; wrap diagnostics in
  `pcall`.
- **Taint:** never write a Lua field on a Blizzard frame that Blizzard code
  later reads (e.g. cast bar `barType`, `casting`, `unit`). Writing such a field
  taints Blizzard's execution and produces "action blocked" / secret-value
  errors far from the write. Prefer widget API calls (`SetTexture`, `SetPoint`,
  `SetAlpha`, ...) and keep addon state in the `ns` table or in weak tables keyed
  by frame. Addon-private keys on Blizzard frames use the `CUIR_` prefix and
  must only ever be read by this addon.
- **Protected frames:** Blizzard's unit frame status bars and their containers
  inherit `SecureFrameTemplate`. `SetPoint/SetSize/ClearAllPoints/SetParent` on
  them are blocked in combat (silently) and Blizzard restores the retail
  geometry on every target change. The classic bars are therefore unprotected
  *mirror* StatusBars (`ns.CreateMirrorBar` in `Core.lua`) driven by
  `OnValueChanged/OnMinMaxChanged` hooks on Blizzard's bar; Blizzard's own fill
  is faded to alpha 0. Overlays (heal prediction, absorb, loss bars, glows) are
  re-parented onto the mirror with `ns.AttachToMirror`. Do not add code that
  moves or resizes a protected frame.
- Anything that must touch a protected frame outside combat goes through
  `ns:RunOutOfCombat`.
- Hooks go through `ns.Hook(global, fn)` / `ns.Hook(frame, "Method", fn)`: a
  guarded `hooksecurefunc` whose callback runs in `xpcall`, because an error in
  one hook silently drops every later hook in the chain. Use `HookScript` for
  frame scripts. Never replace Blizzard functions.
- `StatusBar:SetStatusBarTexture(file)` resets the fill's draw layer; use
  `ns.SetBarTexture` for mirrors. Atlases are applied with
  `texture:SetAtlas(name)`, never by passing an atlas name as a file path.
- Nameplates: the built-in `nameplateStyle` CVar value `Enum.NamePlateStyle.Classic`
  is used as the base; the module fixes its texcoords/insets itself and restores
  the previous CVar value on disable.
- Minimap: `MinimapCluster` is a `ResizeLayoutFrame` (sizes itself to its shown
  children) and an Edit Mode system; `MinimapContainer` is what the Size slider
  scales, so every classic piece lives inside it. `MinimapCompassTexture` is
  the region the engine rotates with the map ("rotate minimap"), so it carries
  the CompassRing and the static ring border is the addon's own texture.
  `Blizzard_TimeManager` (clock) is load-on-demand: skin it on `ADDON_LOADED`.
  Forever's `Blizzard_Minimap\Camelot\Skin.lua` re-sizes the container/backdrop
  and swaps the compass atlas on every rotate change; `Diel.lua` adds a day/night
  frame (`MinimapCluster.DielFrame`) and replaces `MinimapCluster.SetEditModeScale`.

## Module conventions

- Every file registers itself with `ns:RegisterModule{ key, name, tooltip, live, parent }`.
  `live = true` modules implement `Enable()`/`Disable()` and can be toggled at
  runtime (cast bars, nameplates). `live = false` modules implement `Apply()`
  once at login and need a `/reload` to switch off, because Blizzard frames
  cannot be safely un-skinned.
- `parent = "unitframes"` marks a module as part of the Unit Frames option: no
  checkbox, no saved variable, follows the parent's state. Portraits, Health
  Bars and Power Bars are such parts — the user wants the unit frames to be
  all-or-nothing. Do not re-introduce separate options for them.
- Options use the modern Settings API (`Settings.RegisterVerticalLayoutCategory`,
  `RegisterProxySetting`, `CreateCheckbox`). Reload-type changes prompt via the
  `CLASSICUIRESTORATION_RELOAD` StaticPopup.
- Match the existing style: tabs, `local _, ns = ...` header, a doc comment
  block at the top of each file explaining *why*, short comments on non-obvious
  client behaviour, no globals except the `ClassicUIRestorationDB` saved variable
  and the slash command tables.
- Diagnostic slash sub-commands are temporary: remove them once the issue they
  were added for is fixed.
