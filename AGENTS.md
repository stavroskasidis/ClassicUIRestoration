# Agent instructions for Forevermore Classic UI

This repository contains *Forevermore Classic UI* (published as "Forevermore
Classic UI - Forever & Retail"), a World of Warcraft addon that reskins the
modern UI with the pre-Dragonflight look (unit frames, cast bars, nameplates,
minimap, loot window, vendor window, ...) on the modern client, with each
element individually switchable back to the retail look. It is a reskin, not
a replacement: Blizzard's frames keep all their functionality, and the docs
stress that.

The addon was renamed from *Classic UI Restoration* (folder
`ClassicUIRestoration`, saved variables `ClassicUIRestorationDB` /
`ClassicUIRestorationCharDB`) on 2026-09-27. `MigrateFromOldName` in
`Core.lua` copies the old settings over and disables the old addon when the
old folder is still installed; it is temporary (remove it once the beta
testers have moved over). Still named after the old name: the `CUIR_` prefix
of addon-private keys (internal) and the `/cuir` and `/classicui` slash
aliases next to `/fmcui` / `/forevermore` (never `/fcui`: other addons use it).

## Repository layout

```
src/                    the addon folder, one build for every flavor (copied as is into build\ForevermoreClassicUI\)
  ForevermoreClassicUI.toc  the one .toc for every flavor (## Interface: 120100, 16001)
  Core.lua              namespace, textures/colours, module registry, mirror bars, lifecycle, /fmcui
  Options.lua           Settings panel page (canvas: every top-level module by group, with a picture of its set look
                        and a Modern / Classic switch; reload banner)
  Wizard.lua            setup wizard (first login, "/fmcui setup"); ns.UI: widgets, option groups
                        (GROUPS) and short descriptions (SUMMARIES) shared with Options.lua
  Previews.lua          ns.Previews: the modern / classic picture of each option, drawn from the client's art;
                        ns.PreviewImages: screenshots used instead for whole windows
  PreviewsForever.lua   Forever only: its modern pictures (camelot art) and its window screenshots
  Textures/Previews/    the window screenshots (made by tools/make_previews.py)
  Modules/UnitFrames.lua   classic frame art & layout (player/target/focus/ToT/pet/party/boss)
  Modules/Portraits.lua    portrait masks, rest/combat indicators   (part of Unit Frames)
  Modules/HealthBars.lua   health bar textures/colours              (part of Unit Frames)
  Modules/PowerBars.lua    power bar textures/colours               (part of Unit Frames)
  Modules/CastBars.lua     classic cast bars (live toggle)
  Modules/MirrorTimers.lua classic breath/fatigue (mirror timer) bars (live toggle)
  Modules/Nameplates.lua   classic nameplate style (live toggle)
  Modules/Minimap.lua      classic minimap cluster (reload; keeps Blizzard's cluster, re-parents its pieces into MinimapContainer)
                           + the Group Finder Eye option (live; classic eye drawn on a child frame of QueueStatusButton)
  Modules/LootFrame.lua    vanilla loot panel (reload; re-skins the ScrollingFlatPanel loot frame in place, pages its scroll box)
  Modules/TrainerFrame.lua vanilla trainer window (reload; re-skins Blizzard_TrainerUI in place)
  Modules/AuctionHouse.lua vanilla auction house (reload; resizes Blizzard_AuctionHouseUI to 832x447, classic art per tab, sub-frames re-anchored into it)
  Modules/EndCaps.lua      vanilla action bar gryphons (live toggle)
  Modules/ExperienceBar.lua vanilla XP / reputation bars (live toggle; classic frame over Blizzard's status tracking bars, mirror fill)
  Modules/MerchantFrame.lua vanilla vendor window icons: repair/junk buttons, buyback slot (live toggle)
  Modules/ActionBars.lua   vanilla action bar art (reload; button borders, per-button strip cells, page arrows)
  Modules/BagsBar.lua      "Bags" option, bags bar (reload; square equal-size slots, backpack icon, strip cells, Forever key ring)
  Modules/BagFrames.lua    vanilla bag / backpack / combined windows   (part of Bags; slots re-anchored from Blizzard's grid)
  Modules/MicroMenu.lua    classic micro buttons (reload; UI-MicroButton-* files re-applied from hooks on the buttons' Set*Atlas)
  Modules/GameMenu.lua     vanilla game menu / Esc menu (reload; dialog box drawn behind GameMenuFrame, pooled buttons re-skinned and re-stacked after its Layout)
  Textures/                bundled art (UI-Merchant-SellJunk.tga, the vanilla-style Sell All Junk icon;
                           UI-Character-ReputationBar.tga, the 1.12 reputation row art;
                           UI-MicroButton-MainMenu/Quest/Socials-*.tga, the vanilla micro buttons from the
                           Classic Era client, which retail/Forever only ship as Cataclysm redraws)
  Modules/ComboPoints.lua classic combo point layout on the target frame, Forever only (live toggle; retail's combo points are on the player frame)
  Modules/PlayerSpellsPanel.lua PlayerSpellsFrame chrome / close button / mouse for the classic spellbook and talents pages (not a module)
  Modules/SpellBook.lua vanilla spellbook, Forever only (reload; re-skins PlayerSpellsFrame's spellbook page in place, 12 spells per page)
  Modules/TalentFrame.lua vanilla talent frame, Forever only (reload; Blizzard's talent buttons moved onto the 1.12 grid, one tree per tab)
  Modules/CharacterFrame.lua vanilla character window, Forever only (reload; vanilla art on CharacterFrame, left pane moved into it, right pane docked, mode tabs as bottom tabs)
  Modules/CharacterReputation.lua its Reputation tab, Forever only   (part of Character Window; rows re-skinned after Blizzard initializes them)
  Modules/CharacterSkills.lua its Skills tab, Forever only           (part of Character Window; same row skinning, own 1.12 detail pane)
  Modules/ProfessionsFrame.lua vanilla trade skill window, Forever only (reload; crafting page re-skinned in place, Blizzard's recipe list scaled with its row heights overridden, own detail pane / rank bar / "All" tab / proxy create buttons)
  Modules/Forever.lua   Forever-only adjustments for the "camelot" UI overlay (loaded last)
  README.md             user-facing description of every option (both flavors)
addon.json              addon name, version (single source; the .toc carries @project-version@)
                        and the flavors with the game folder each deploys to ("gameDir")
build.ps1               copies src\ into build\ForevermoreClassicUI\ and zips it as
                        build\ForevermoreClassicUI-<version>.zip (CurseForge layout, one file for every flavor)
build/                  build output (git-ignored); what deploy.ps1 copies into the game
deploy.ps1              builds once + mirrors the build into every installed flavor (-Flavor X for one)
deploy.config.json      machine-specific WoW path (git-ignored, never commit)
tools/make_previews.py  crops in-game screenshots into src/Textures/Previews (see its header)
curseforge/             project page material: logo.png (+ make_logo.py to regenerate it), description.md
```

Flavors: `Retail` -> `_retail_`, `Forever` -> `_classic_beta_` (declared in
`addon.json`; Forever currently ships as the `wow_classic_beta` product and
will need a new `gameDir` once it gets its own). One build, one `.toc` and one
CurseForge zip serve every flavor: the `.toc`'s `## Interface:` line lists each
flavor's Interface version, and the zip is uploaded once, tagged with every
game version. Forever-only code lives in its own files (`Modules/Forever.lua`,
which hooks the same Blizzard functions *after* the other modules, and
`Modules/ComboPoints.lua` / `Modules/SpellBook.lua` / `Modules/TalentFrame.lua` /
`Modules/CharacterFrame.lua` / `Modules/CharacterReputation.lua` / `Modules/CharacterSkills.lua` /
`Modules/ProfessionsFrame.lua`, options only Forever has, with
`Modules/PlayerSpellsPanel.lua` shared by the spellbook and talents), each starting with `if not ns.IS_FOREVER then return end` right
after `local _, ns = ...`, so on retail they register nothing.
`ns.IS_FOREVER` (set in `Core.lua` from the Interface version) is the only
flavor check: never branch on it inside the modules both flavors run (they
stay flavor-agnostic by hooking whatever exists), and do not rely on
`[AllowLoadGameType ...]` on `.toc` file lines, which the client ignores for
addons (tested 2026-09-27: retail loaded `camelot`-tagged files). Never edit
anything under `build/`.

## Workflow

- Edit files under `src/` only. `build/` and the copies inside the game
  folders are outputs; never edit them directly and never touch anything else
  in the game install.
- Deploy with `.\deploy.ps1` (PowerShell): it runs `build.ps1` once and
  mirrors `build\ForevermoreClassicUI\` into
  `<WoW>\<gameDir>\Interface\AddOns\ForevermoreClassicUI\` of every flavor
  whose game folder exists (skipping uninstalled clients); `-Flavor X`
  deploys to one flavor. The user then runs `/reload` in game; the addon
  cannot be tested outside the game client. A change outside the
  Forever-only files affects both flavors: say so, since the user will
  typically test one of them.
- There is no automated test suite in the repo. Before handing over, at least
  check Lua syntax (e.g. with a Lua parser) and re-read the changed code for
  the taint rules below. In-game verification is done by the user; ask for a
  `/reload` and, when useful, a screenshot or the output of `/fmcui`.
- Keep every user-facing description in sync with the options and behaviour
  whenever a module is added, removed or renamed: `src/README.md` (the
  option table, "How it works" and the file list), the `## Notes:` line of
  the `.toc`, and `curseforge/description.md` (the "What it restores" list and the summary,
  which must stay under 250 characters). A new top-level module also goes
  into a group of `GROUPS` and gets a line in `SUMMARIES` (`Wizard.lua`; a
  module no group lists lands in "Other") and a picture in `Previews.lua`
  (`classic` / `modern` builders drawing the same files, coordinates and
  atlases the module and Blizzard's frame use).
- For a user-visible release bump `"version"` in `addon.json` (`x.y.z`);
  never write a literal version into the `.toc` — it contains
  `## Version: @project-version@`, which `build.ps1` replaces (in `.toc`,
  `.lua` and `.md` files) and uses for the zip name. `ns.VERSION` in
  `Core.lua` reads it back from the TOC.
- Do not commit unless asked. Never commit `deploy.config.json`.

## Client facts (retail 12.x) that shape the code

- `## Interface: 120100` (12.1.0). Blizzard's UI source is
  https://github.com/Gethe/wow-ui-source (branch `live`); use the 9.2.x tag for
  classic coordinates/texture coords. Read the real source before hooking or
  re-anchoring anything — names and hierarchies change between patches.
- **WoW Forever** (`ns.IS_FOREVER`): `## Interface: 16001` (client 1.60.1, product
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
  An early 1.60.1 beta client wrote SavedVariables but never loaded them back
  (options reset every session); Blizzard fixed it (confirmed 2026-09-28), so
  saved options and `setupDone` persist on Forever like on retail.
  Taint logging is unusable on the 1.60.1 client: with `/console taintLog 2`
  every call of a method this addon hooks with `hooksecurefunc` (micro buttons'
  `SetNormalAtlas`, action buttons' `Update`, ...) fails with "attempt to call
  a nil value" in Blizzard's code (seen 2026-09-27). Test taint questions in
  game instead (e.g. open protected panels in combat) and turn it back off.
- The legacy textures (`Interface\TargetingFrame\UI-TargetingFrame`,
  `UI-StatusBar`, `Interface\CastingBar\*`, `Interface\Tooltips\Nameplate-Border`
  etc.) still ship with the retail client, so the addon references them by path
  and does not bundle copies (exception: files the client only ships redrawn,
  like the three vanilla micro buttons and Forever's redrawn
  `UI-Character-ReputationBar` in `Textures/`). Note the retail `Nameplate-Border` is 256x32 with
  the art in the left 136 px.
- **Secrets:** unit health/power/cast values may be "secret" (12.x). Addon code
  must not compare, do arithmetic on, or format them. They may be passed
  straight through to `StatusBar:SetValue/SetMinMaxValues` (allowed when
  tainted) but not to `SetPoint/SetSize/SetParent` (offset math is not allowed).
  `GetPoint/GetSize` on nameplate regions are restricted; wrap diagnostics in
  `pcall`. Region state that Blizzard set from secret values reads back
  secret too: in instances the unit frames' PvP icons are set with
  `SetShown/SetAtlas(secret)`, so their `IsShown()`/`GetAtlas()` must be
  checked with `issecretvalue` before any test. On Forever the player's stats
  and resistances are secret in combat too: Blizzard's stat functions
  (`PAPERDOLL_STATINFO[...].updateFunc`) fail when addon code calls them
  then, so the character window's stat boxes keep their values through
  combat and refresh after it.
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
- Never call `ShowUIPanel` / `HideUIPanel` from addon code: in combat the
  panel manager refuses tainted calls ("Interface action failed because of
  an AddOn"). A template's script on a button the addon created runs as
  addon code too, so `ns.CreatePanelCloseTextButton` (a `UIPanelCloseButton`
  on the panel) still only closes out of combat. A close button that must
  work in combat is a `SecureActionButtonTemplate` with `type` "click" and
  `clickbutton` the panel's own `CloseButton` (created out of combat; it is
  protected and makes its parent protected): see the professions window.
- A panel with a secure descendant is protected: no `SetSize` / `SetPoint`
  / `EnableMouse` / `SetHitRectInsets` on it in combat, and hooks that run
  when it shows (a keybinding can show it in combat) must defer those with
  `ns:RunOutOfCombat`. Forever's `ProfessionsFrame` is one (its overview
  page's profession spell buttons are secure): setting its hit rect on show
  made the K binding fail in combat ("Interface action failed", 2026-09-27).
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
- Spellbook (Forever only; dropped for retail on 2026-09-26, whose spellbook
  with its Class / General / Pet text tabs and Specialization / Talents bar
  did not fit the vanilla book): the spell buttons of
  `PlayerSpellsFrame.SpellBookFrame` cast
  through the protected `C_SpellBook.CastSpellBookItem`, so the paged list
  must only ever be driven by Blizzard's code: never call its
  `SetViewsPerPage`/`SetDataProvider`/`SetMinimized`/`SetTab` or write its
  fields (the item frames it builds afterwards carry the taint and casting is
  blocked). Items per page are controlled only through the view frame's
  height (see the header of `Modules/SpellBook.lua`); single-page mode comes
  from the `spellBookMinimize` CVar, read when `Blizzard_PlayerSpells` loads.
  Tab clicks reach `PlayerSpellsFrame:SetTab` through a closure taken at load,
  so hooking `SetTab` misses them. The page holds a secure button (the
  assisted combat spell, `UIPanelSpellButtonFrameTemplate`), so the page and
  `PlayerSpellsFrame` are protected: no `SetSize`/`SetPoint`/`EnableMouse`/
  `SetHitRectInsets` on them (or on that button) in combat. The module never
  resizes the panel (the book is drawn at its left edge, lowered to the other
  panels' line, and the panel manager positions the panel by Blizzard's
  compact size); its mouse and that button's anchor are only changed out of
  combat. Forever has no panel tab system and one icon category tab per skill
  line. The panel's chrome, close button and mouse are owned by
  `Modules/PlayerSpellsPanel.lua` (shared with the talents page), which sets
  them from the pages' shown state, never from the page that triggered it.
- Talents (Forever only): `PlayerSpellsFrame.TalentsFrame` is the retail
  trait-tree frame (`Blizzard_SharedTalentUI`) with the camelot overlay: one
  C_Traits tree holding the class's three trees side by side (node groups
  from `C_Traits.GetGroupDisplayInfoByTreeID`), a Primary / Secondary tab per
  spec group, staged changes committed by "Apply Changes". Its panel area is
  "center" (it closes every other panel when opened). The node grid is 600
  node units (60px) in both directions; a few nodes sit far off the grid in
  the data (out of Blizzard's view) and a few edges point upwards. The
  module reparents Blizzard's talent buttons into its own scroll frame:
  `ClassTalentsFrameMixin:UpdateTalentButtonPosition` reparents a button to
  `ButtonsParent` every time it positions it, so the module re-places it in a
  hook on that method; edges (`AcquireEdge` parents them to the start
  button's parent) and gates are reparented to a hidden frame. Button alpha
  is Blizzard's (its "Invisible" state), so trees are hidden by parent, never
  by alpha. The spec tabs reach `SetTab` through a closure taken at load
  (hook the tab buttons' `SetTabSelected`, not `SetTab`).
- Character window (Forever only): `CharacterFrame` is Forever's own
  (`Blizzard_UIPanels_Game\Camelot\CharacterFrame.*`), not retail's: a
  631x484 PortraitFrame (398 wide with the right pane collapsed), six
  `LargeSideTabButtonTemplate` mode tabs (Frames; clicks arrive through
  `OnMouseUp`, selection through the mixin's `SetChecked`), and every page
  (paperdoll, reputation, skills, PvP rank, currency) anchors its content to
  `CharacterFrame.LeftPaneHost`; the stats, gear sets, titles, pet view and
  the pages' detail panes live in `RightPaneHost`. Blizzard re-sizes the
  frame in `UpdateSize` on every refresh and reads the collapsed state from
  the `characterFrameCollapsed` CVar at load only (it never writes it). The
  frame holds no secure widgets, so it can be re-anchored in combat, but
  never change its collapsed state from addon code (the state feeds the
  panel manager's width attribute). Retail's character frame is a different
  frame (`Mainline\CharacterFrame.*`, three bottom tabs).
  The pages' lists are ScrollBoxes: never change their view's extents or
  padding (Lua fields; a row click reaches `SetRightPaneCollapsed`), scale
  the list instead (`ns.CharacterList` in `CharacterFrame.lua`). A ScrollBox's
  acquired-frame callback runs before the row's first Initialize, the
  initialized-frame callback after every one.
- A texture's `SetAlpha` is its vertex alpha: `GetVertexColor()` on a faded
  texture returns alpha 0, so copy only r, g, b from it.
- Minimap: `MinimapCluster` is a `ResizeLayoutFrame` (sizes itself to its shown
  children) and an Edit Mode system; `MinimapContainer` is what the Size slider
  scales, so every classic piece lives inside it. `MinimapCompassTexture` is
  the region the engine rotates with the map ("rotate minimap"), so it carries
  the CompassRing and the static ring border is the addon's own texture.
  `Blizzard_TimeManager` (clock) is load-on-demand: skin it on `ADDON_LOADED`.
  Forever's `Blizzard_Minimap\Camelot\Skin.lua` re-sizes the container/backdrop
  and swaps the compass atlas on every rotate change; `Diel.lua` adds a day/night
  frame (`MinimapCluster.DielFrame`) and replaces `MinimapCluster.SetEditModeScale`.
- XP / reputation bars: `StatusTrackingBarManager` holds two containers
  (`MainStatusTrackingBarContainer`, `SecondaryStatusTrackingBarContainer`,
  Edit Mode systems), each with one bar per kind (`container.bars[barIndex]`,
  created at load) of which it shows one. Retail 12.1 has them in
  `Blizzard_ActionBar`, Forever in its own `Blizzard_StatusTrackingBar`
  (1192px containers with 20 segment dividers; XP has the lowest priority
  there, so reputation takes the main container). Their fill is a
  `GradualAnimatedStatusBar` (animated values, flipbook flares, atlases
  re-applied on every rest / standing change).

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
- Options are changed only through `ns:SetModuleEnabled(key, value)` (Core.lua):
  it saves the value, enables / disables a live module and notifies the
  listeners registered with `ns:OnSettingsChanged` (the options page and the
  wizard refresh from it). The options page is a canvas category
  (`Settings.RegisterCanvasLayoutCategory`, built on its first show); a
  reload-type change shows its reload banner (no popup). The setup wizard
  opens at login until it has been closed once (`db.setupDone`, set when it
  closes), for new installs and existing users alike (not in the session that
  shows the rename migration popup), and is the addon's own frame, never a UI panel:
  it closes on Esc through its own keyboard handler, not `UISpecialFrames`.
- Previews never touch Blizzard's frames: they are drawn with the addon's
  own textures and frames. Only instantiate Blizzard templates without
  `$parent`-named children (they would create globals) and without secure
  or event-registering behaviour.
- Match the existing style: tabs, `local _, ns = ...` header, a doc comment
  block at the top of each file explaining *why*, short comments on non-obvious
  client behaviour, no globals except the saved variables (`ForevermoreClassicUIDB`
  account-wide, mirrored into `ForevermoreClassicUICharDB` per character; both
  globals reference the same table, see `InitializeDB` in `Core.lua`) and the
  slash command tables.
- Diagnostic slash sub-commands are temporary: remove them once the issue they
  were added for is fixed.
