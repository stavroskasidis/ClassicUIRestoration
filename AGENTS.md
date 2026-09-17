# Agent instructions for Classic UI Restoration

This repository contains *Classic UI Restoration*, a World of Warcraft addon
that restores pre-Dragonflight UI elements (unit frames, cast bars, nameplates)
on the modern client, with each element individually switchable back to the
retail look.

## Repository layout

```
Retail/                 the addon as shipped for retail WoW (Interface 12.x)
  ClassicUIRestoration.toc
  Core.lua              namespace, textures/colours, module registry, mirror bars, lifecycle, /cuir
  Options.lua           Settings panel (one checkbox per top-level module) + reload prompt
  Modules/UnitFrames.lua   classic frame art & layout (player/target/focus/ToT/pet/party/boss)
  Modules/Portraits.lua    portrait masks, rest/combat indicators   (part of Unit Frames)
  Modules/HealthBars.lua   health bar textures/colours              (part of Unit Frames)
  Modules/PowerBars.lua    power bar textures/colours               (part of Unit Frames)
  Modules/CastBars.lua     classic cast bars (live toggle)
  Modules/Nameplates.lua   classic nameplate style (live toggle)
  README.md             user-facing description of every option
deploy.ps1              copies a flavor folder into the game's AddOns folder
deploy.config.json      machine-specific WoW path (git-ignored, never commit)
```

A second flavor ("WoW Forever": classic WoW with the retail UI) is planned. It
gets its own top-level source folder and an entry in `$FlavorDirs` in
`deploy.ps1`. Keep flavor-specific code inside the flavor folder; do not add
runtime flavor detection to `Retail/`.

## Workflow

- Edit files under `Retail/` only. The copy inside the game folder is a deploy
  target; never edit it directly and never touch anything else in the game
  install.
- Deploy with `.\deploy.ps1` (PowerShell). It mirrors `Retail/` into
  `<WoW>\_retail_\Interface\AddOns\ClassicUIRestoration\`. The user then runs
  `/reload` in game; the addon cannot be tested outside the game client.
- There is no automated test suite in the repo. Before handing over, at least
  check Lua syntax (e.g. with a Lua parser) and re-read the changed code for
  the taint rules below. In-game verification is done by the user; ask for a
  `/reload` and, when useful, a screenshot or the output of `/cuir`.
- Keep `Retail/README.md` in sync with the options and behaviour. Bump
  `## Version` in the `.toc` for user-visible releases.
- Do not commit unless asked. Never commit `deploy.config.json`.

## Client facts (retail 12.x) that shape the code

- `## Interface: 120100` (12.1.0). Blizzard's UI source is
  https://github.com/Gethe/wow-ui-source (branch `live`); use the 9.2.x tag for
  classic coordinates/texture coords. Read the real source before hooking or
  re-anchoring anything — names and hierarchies change between patches.
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
