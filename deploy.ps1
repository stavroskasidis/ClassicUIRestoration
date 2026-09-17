<#
.SYNOPSIS
	Deploys the addon into the World of Warcraft AddOns folder(s).

.DESCRIPTION
	Runs build.ps1 for each flavor being deployed (src\Shared + src\<Flavor>
	merged into <repo>\build\<Flavor>\ClassicUIRestoration\) and mirrors that
	build output into <WoW>\<gameDir>\Interface\AddOns\ClassicUIRestoration\.

	Without -Flavor, every flavor declared in addon.json whose game folder
	exists in the WoW install is deployed; flavors whose client is not
	installed are skipped with a note. With -Flavor, that one flavor is
	deployed and a missing game folder is an error.

	The WoW install location (the folder that contains _retail_, _classic_, ...)
	is asked for on the first run and stored in deploy.config.json next to this
	script. That file is git-ignored because it is machine specific.

.PARAMETER Flavor
	Deploy only this flavor. Flavors and the game sub-folder each one deploys
	to ("gameDir") are declared in addon.json.

.PARAMETER Reset
	Forget the stored WoW location and ask for it again.

.EXAMPLE
	.\deploy.ps1                  # every flavor whose client is installed
	.\deploy.ps1 -Flavor Forever  # just one
	.\deploy.ps1 -Reset
#>
[CmdletBinding()]
param(
	[string]$Flavor,
	[switch]$Reset
)

$ErrorActionPreference = "Stop"

$RepoRoot    = $PSScriptRoot
$ConfigPath  = Join-Path $RepoRoot "deploy.config.json"
$BuildScript = Join-Path $RepoRoot "build.ps1"

# Addon name and flavor -> game folder mapping ("gameDir") come from addon.json.
# (Forever currently ships as the "wow_classic_beta" product, _classic_beta_;
# update its gameDir there once it gets its own product folder.)
$Addon     = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
$AddonName = $Addon.name
$FlavorDirs = [ordered]@{}
foreach ($property in $Addon.flavors.PSObject.Properties) {
	if (-not $property.Value.gameDir) {
		throw "Flavor '$($property.Name)' in addon.json has no 'gameDir'."
	}
	$FlavorDirs[$property.Name] = $property.Value.gameDir
}

if ($Flavor -and -not $FlavorDirs.Contains($Flavor)) {
	throw "Unknown flavor '$Flavor'. Known flavors: $($FlavorDirs.Keys -join ', ')"
}

# --- WoW location -----------------------------------------------------------

function Read-WowPath {
	while ($true) {
		$path = Read-Host "Path to your World of Warcraft install (the folder containing _retail_, e.g. D:\Games\World of Warcraft)"
		$path = $path.Trim().Trim('"')
		if (-not $path) { continue }
		if (-not (Test-Path $path)) {
			Write-Warning "'$path' does not exist."
			continue
		}
		# Accept a flavor folder too and step up to the install root.
		$leaf = Split-Path $path -Leaf
		if ($FlavorDirs.Values -contains $leaf) {
			$path = Split-Path $path -Parent
		}
		return (Resolve-Path $path).Path
	}
}

$config = $null
if (-not $Reset -and (Test-Path $ConfigPath)) {
	try {
		$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
	} catch {
		Write-Warning "deploy.config.json is unreadable; asking for the path again."
	}
}

if (-not $config -or -not $config.wowPath -or -not (Test-Path $config.wowPath)) {
	if ($config -and $config.wowPath) {
		Write-Warning "Stored WoW location '$($config.wowPath)' no longer exists."
	}
	$wowPath = Read-WowPath
	$config = [pscustomobject]@{ wowPath = $wowPath }
	$config | ConvertTo-Json | Set-Content $ConfigPath -Encoding UTF8
	Write-Host "Stored WoW location in $ConfigPath"
}

$WowPath = $config.wowPath

# --- Which flavors -----------------------------------------------------------

# Flavor name -> its addon folder inside the game, for every flavor to deploy.
$targets = [ordered]@{}
if ($Flavor) {
	$gameDir = Join-Path $WowPath $FlavorDirs[$Flavor]
	if (-not (Test-Path $gameDir)) {
		throw "Game folder '$gameDir' for flavor '$Flavor' does not exist in the WoW install. Run with -Reset to change the location."
	}
	$targets[$Flavor] = Join-Path $gameDir "Interface\AddOns\$AddonName"
} else {
	foreach ($name in $FlavorDirs.Keys) {
		$gameDir = Join-Path $WowPath $FlavorDirs[$name]
		if (Test-Path $gameDir) {
			$targets[$name] = Join-Path $gameDir "Interface\AddOns\$AddonName"
		} else {
			Write-Host "Skipping $name`: '$gameDir' is not installed."
		}
	}
	if ($targets.Count -eq 0) {
		throw "None of the game folders ($($FlavorDirs.Values -join ', ')) exist under '$WowPath'. Run with -Reset to change the location."
	}
}

# --- Build + deploy ---------------------------------------------------------

foreach ($name in $targets.Keys) {
	$buildOutput = Join-Path $RepoRoot "build\$name\$AddonName"
	$target      = $targets[$name]

	& $BuildScript -Flavor $name
	if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $buildOutput "$AddonName.toc"))) {
		throw "build.ps1 did not produce '$buildOutput'."
	}

	Write-Host "Deploying $buildOutput -> $target"
	New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null

	# /MIR keeps the target an exact copy of the build output (removes deleted files).
	$robocopyArgs = @($buildOutput, $target, "/MIR", "/NJH", "/NJS", "/NDL", "/NP", "/R:2", "/W:1")
	& robocopy @robocopyArgs
	$code = $LASTEXITCODE

	# Robocopy exit codes below 8 mean success (bits 1/2/4 = copied/extra/mismatched).
	if ($code -ge 8) {
		throw "robocopy failed with exit code $code while deploying $name"
	}
}

Write-Host "Done ($($targets.Keys -join ', ')). Type /reload in game to pick up the changes."

exit 0
