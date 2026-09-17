# Classic UI Restoration

Repository for the *Classic UI Restoration* World of Warcraft addon. The code
is shared between game flavors; each flavor folder holds only its `.toc` and
flavor-only files:

```
src/Shared/      the addon code (Core, Options, Modules, README) used by every flavor
src/Retail/      retail WoW     ->  <WoW>\_retail_\Interface\AddOns\ClassicUIRestoration
src/Forever/     WoW Forever    ->  <WoW>\_classic_beta_\Interface\AddOns\ClassicUIRestoration
addon.json       addon name, version and flavors (with the game folder each deploys to)
build.ps1        assembles src\Shared + each flavor into build\<Flavor>\ and zips it for CurseForge
deploy.ps1       builds and copies every installed flavor into the game (-Flavor X for one)
build/           build output (git-ignored)
curseforge/      logo and project-page text for CurseForge
```

See [src/Shared/README.md](src/Shared/README.md) for what the addon does
(including the Forever-specific parts).

## Building

```powershell
.\build.ps1                  # build every flavor
.\build.ps1 -Flavor Forever  # one flavor
```

For each flavor this produces

```
build\<Flavor>\ClassicUIRestoration\                               the addon folder
build\<Flavor>\ClassicUIRestoration-<version>-<flavor>.zip         upload this to CurseForge
```

The build flattens `src\Shared\` and the flavor folder into one addon folder
(a flavor file with the same relative path as a shared file wins), which is
why the `.toc` files list shared files by their plain path. The zip has the
addon folder as its root entry (`ClassicUIRestoration/ClassicUIRestoration.toc`,
...), which is the layout CurseForge requires.

## Versioning

The version is defined once, in [addon.json](addon.json). The `.toc` files
say `## Version: @project-version@`, and the build replaces that placeholder
(in any `.toc`, `.lua` or `.md` file) with the version from `addon.json`,
which also names the zip. To release: bump `"version"`, run `.\build.ps1`,
upload the zips.

`addon.json` also holds the addon folder name (`"name"`) and the flavors:

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
.\deploy.ps1                 # build + deploy every flavor whose client is installed
.\deploy.ps1 -Flavor Retail  # just one flavor
.\deploy.ps1 -Flavor Forever # WoW Forever (currently the _classic_beta_ folder)
.\deploy.ps1 -Reset          # forget the stored WoW location and ask again
```

The first run asks for the WoW install folder (the one that contains
`_retail_`) and stores it in `deploy.config.json`, which is git-ignored. The
script runs the build for each flavor and mirrors `build\<Flavor>\ClassicUIRestoration\`
into that flavor's game folder (files removed here are removed there too);
it never touches anything outside the addon folders. Without `-Flavor`, flavors
whose game folder is not installed are skipped with a note. Type `/reload` in
game afterwards.

Adding a flavor: create its folder under `src\` with a `ClassicUIRestoration.toc`
listing the shared files plus its own, and declare it in `addon.json` with
the game sub-folder it deploys to (`"gameDir"`).
