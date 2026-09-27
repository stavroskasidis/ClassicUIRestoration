# Classic UI Restoration

Repository for the *Classic UI Restoration* World of Warcraft addon. One
build serves every game flavor (retail and WoW Forever): the `.toc` lists
each flavor's Interface version, and the Forever-only modules return early on
retail.

```
src/             the addon folder (ClassicUIRestoration.toc, Core, Options, Modules, Textures, README)
addon.json       addon name, version and flavors (with the game folder each deploys to)
build.ps1        copies src\ into build\ClassicUIRestoration\ and zips it for CurseForge
deploy.ps1       builds and copies the addon into every installed flavor (-Flavor X for one)
build/           build output (git-ignored)
curseforge/      logo and project-page text for CurseForge
```

See [src/README.md](src/README.md) for what the addon does (including the
Forever-specific parts).

## Building

```powershell
.\build.ps1
```

This produces

```
build\ClassicUIRestoration\                    the addon folder
build\ClassicUIRestoration-<version>.zip       upload this to CurseForge
```

The zip has the addon folder as its root entry
(`ClassicUIRestoration/ClassicUIRestoration.toc`, ...), which is the layout
CurseForge requires. Upload it once and tick every supported game version
(WoW Retail and WoW Forever) in the file's Game Version field.

## Versioning

The version is defined once, in [addon.json](addon.json). The `.toc` says
`## Version: @project-version@`, and the build replaces that placeholder
(in any `.toc`, `.lua` or `.md` file) with the version from `addon.json`,
which also names the zip. To release: bump `"version"`, run `.\build.ps1`,
upload the zip.

`addon.json` also holds the addon folder name (`"name"`) and the flavors,
i.e. the game folders `deploy.ps1` copies the build into:

```json
{
	"name": "ClassicUIRestoration",
	"version": "1.0.0",
	"flavors": {
		"Retail":  { "gameDir": "_retail_" },
		"Forever": { "gameDir": "_classic_beta_" }
	}
}
```

## Deploying to the game

```powershell
.\deploy.ps1                 # build + deploy to every flavor whose client is installed
.\deploy.ps1 -Flavor Retail  # just one flavor
.\deploy.ps1 -Flavor Forever # WoW Forever (currently the _classic_beta_ folder)
.\deploy.ps1 -Reset          # forget the stored WoW location and ask again
```

The first run asks for the WoW install folder (the one that contains
`_retail_`) and stores it in `deploy.config.json`, which is git-ignored. The
script runs the build once and mirrors `build\ClassicUIRestoration\` into
each flavor's game folder (files removed here are removed there too); it
never touches anything outside the addon folders. Without `-Flavor`, flavors
whose game folder is not installed are skipped with a note. Type `/reload` in
game afterwards.

Adding a flavor: add its Interface version to the `## Interface:` line of
`src\ClassicUIRestoration.toc`, declare it in `addon.json` with the game
sub-folder it deploys to (`"gameDir"`), and guard any code only it needs the
way the Forever modules check `ns.IS_FOREVER`.
