<#
.SYNOPSIS
	Deploys the addon into the World of Warcraft AddOns folder.

.DESCRIPTION
	Mirrors <repo>\<Flavor>\ into <WoW>\<flavor dir>\Interface\AddOns\ClassicUIRestoration\.

	The WoW install location (the folder that contains _retail_, _classic_, ...)
	is asked for on the first run and stored in deploy.config.json next to this
	script. That file is git-ignored because it is machine specific.

.PARAMETER Flavor
	Which game flavor to deploy: the name of a source folder in this repo
	(Retail by default). Each flavor maps to a game sub-folder in $FlavorDirs.

.PARAMETER Reset
	Forget the stored WoW location and ask for it again.

.EXAMPLE
	.\deploy.ps1
	.\deploy.ps1 -Flavor Retail
	.\deploy.ps1 -Reset
#>
[CmdletBinding()]
param(
	[string]$Flavor = "Retail",
	[switch]$Reset
)

$ErrorActionPreference = "Stop"

$AddonName = "ClassicUIRestoration"

# Source folder in this repo -> game flavor folder inside the WoW install.
# Add a line here when a new flavor (e.g. WoW Forever) gets its own folder.
$FlavorDirs = @{
	Retail = "_retail_"
}

$RepoRoot   = $PSScriptRoot
$ConfigPath = Join-Path $RepoRoot "deploy.config.json"

if (-not $FlavorDirs.ContainsKey($Flavor)) {
	throw "Unknown flavor '$Flavor'. Known flavors: $($FlavorDirs.Keys -join ', ')"
}

$Source = Join-Path $RepoRoot $Flavor
if (-not (Test-Path (Join-Path $Source "$AddonName.toc"))) {
	throw "No addon found at '$Source' (expected $AddonName.toc)."
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

$WowPath   = $config.wowPath
$FlavorDir = Join-Path $WowPath $FlavorDirs[$Flavor]
if (-not (Test-Path $FlavorDir)) {
	throw "Flavor folder '$FlavorDir' does not exist in the WoW install. Run with -Reset to change the location."
}

$Target = Join-Path $FlavorDir "Interface\AddOns\$AddonName"

# --- Deploy -----------------------------------------------------------------

Write-Host "Deploying $Flavor -> $Target"
New-Item -ItemType Directory -Force (Split-Path $Target -Parent) | Out-Null

# /MIR keeps the target an exact copy of the source (removes deleted files);
# /XD .git makes sure no repository metadata is copied or purged.
$robocopyArgs = @($Source, $Target, "/MIR", "/XD", ".git", "/NJH", "/NJS", "/NDL", "/NP", "/R:2", "/W:1")
& robocopy @robocopyArgs
$code = $LASTEXITCODE

# Robocopy exit codes below 8 mean success (bits 1/2/4 = copied/extra/mismatched).
if ($code -ge 8) {
	throw "robocopy failed with exit code $code"
}

Write-Host "Done. Type /reload in game to pick up the changes."

exit 0
