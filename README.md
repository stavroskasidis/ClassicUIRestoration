# Classic UI Restoration

Repository for the *Classic UI Restoration* World of Warcraft addon. Each game
flavor has its own addon folder:

```
Retail/          addon for retail WoW  ->  <WoW>\_retail_\Interface\AddOns\ClassicUIRestoration
deploy.ps1       copies a flavor into the game's AddOns folder
```

See [Retail/README.md](Retail/README.md) for what the addon does.

## Deploying to the game

```powershell
.\deploy.ps1                 # deploy Retail (default)
.\deploy.ps1 -Flavor Retail  # explicit flavor
.\deploy.ps1 -Reset          # forget the stored WoW location and ask again
```

The first run asks for the WoW install folder (the one that contains
`_retail_`) and stores it in `deploy.config.json`, which is git-ignored. The
script mirrors the flavor folder into the game (files removed here are removed
there too) and never touches anything outside the addon folder. Type `/reload`
in game afterwards.

Adding a flavor: create its source folder (e.g. for WoW Forever) and add the
matching game sub-folder to `$FlavorDirs` in `deploy.ps1`.
