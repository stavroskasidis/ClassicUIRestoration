<#
.SYNOPSIS
	Assembles the deployable addon folder(s) and CurseForge zips into <repo>\build\.

.DESCRIPTION
	For each flavor, merges <repo>\src\Shared\ (code common to every flavor)
	with <repo>\src\<Flavor>\ (the flavor's .toc and flavor-only files) into
	<repo>\build\<Flavor>\ClassicUIRestoration\ and zips that folder as
	<repo>\build\<Flavor>\ClassicUIRestoration-<version>-<flavor>.zip, the
	layout CurseForge expects (the addon folder is the zip's root entry). A
	flavor file with the same relative path as a shared file wins.

	The build folder is git-ignored; it is what deploy.ps1 copies into the game
	and what gets uploaded to CurseForge. Each flavor's output is recreated
	from scratch on every run.

	The addon name, version and the list of flavors come from <repo>\addon.json.

.PARAMETER Flavor
	Build only this flavor (a folder name such as Retail or Forever). Builds
	every flavor when omitted.

.EXAMPLE
	.\build.ps1
	.\build.ps1 -Flavor Forever
#>
[CmdletBinding()]
param(
	[string]$Flavor
)

$ErrorActionPreference = "Stop"

$RepoRoot     = $PSScriptRoot
$SrcRoot      = Join-Path $RepoRoot "src"
$SharedSource = Join-Path $SrcRoot "Shared"
$BuildRoot    = Join-Path $RepoRoot "build"

# addon.json is the single place for the addon name, version and flavors
# (deploy.ps1 reads it too for the flavor -> game folder mapping).
$Addon = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
foreach ($key in "name", "version", "flavors") {
	if (-not $Addon.$key) {
		throw "addon.json is missing '$key'."
	}
}
$AddonName = $Addon.name
$Version   = $Addon.version
if ($Version -notmatch '^\d+\.\d+\.\d+(\S*)$') {
	throw "addon.json version must look like 1.2.3 (optionally with a suffix), got '$Version'."
}

if (-not (Test-Path $SharedSource)) {
	throw "Shared source folder '$SharedSource' is missing."
}

# The .toc files (and any other .toc/.lua/.md file) carry the
# @project-version@ placeholder, which is replaced in the build output.
$VersionPlaceholder = "@project-version@"

function Set-BuildVersion([string]$Folder) {
	$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
	foreach ($file in Get-ChildItem $Folder -Recurse -File -Include *.toc, *.lua, *.md) {
		$text = [System.IO.File]::ReadAllText($file.FullName)
		if ($text.Contains($VersionPlaceholder)) {
			[System.IO.File]::WriteAllText($file.FullName, $text.Replace($VersionPlaceholder, $Version), $utf8NoBom)
		}
	}
}

# Zips a folder so that the folder itself is the single root entry, with
# forward-slash entry names (Compress-Archive writes backslashes on some
# PowerShell versions, which CurseForge and non-Windows unzips choke on).
function New-AddonZip([string]$Folder, [string]$Zip) {
	Add-Type -AssemblyName System.IO.Compression
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	if (Test-Path $Zip) {
		Remove-Item $Zip -Force
	}
	$root = (Split-Path $Folder -Leaf)
	$archive = [System.IO.Compression.ZipFile]::Open($Zip, [System.IO.Compression.ZipArchiveMode]::Create)
	try {
		foreach ($file in Get-ChildItem $Folder -Recurse -File) {
			$relative = $file.FullName.Substring($Folder.Length).TrimStart('\', '/').Replace('\', '/')
			[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
				$archive, $file.FullName, "$root/$relative",
				[System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
		}
	} finally {
		$archive.Dispose()
	}
}

# Flavors are declared in addon.json; each needs a src\<Flavor>\<name>.toc.
$flavors = @($Addon.flavors.PSObject.Properties.Name)
foreach ($name in $flavors) {
	if (-not (Test-Path (Join-Path $SrcRoot "$name\$AddonName.toc"))) {
		throw "Flavor '$name' is declared in addon.json but src\$name\$AddonName.toc does not exist."
	}
}

if ($Flavor) {
	if ($flavors -notcontains $Flavor) {
		throw "Unknown flavor '$Flavor'. Known flavors: $($flavors -join ', ')"
	}
	$flavors = @($Flavor)
}

foreach ($name in $flavors) {
	$flavorSource = Join-Path $SrcRoot $name
	$output       = Join-Path (Join-Path $BuildRoot $name) $AddonName

	if (Test-Path $output) {
		Remove-Item $output -Recurse -Force
	}
	New-Item -ItemType Directory -Force $output | Out-Null

	# The .toc files list shared files by their path inside the addon folder
	# (Core.lua, Modules\UnitFrames.lua, ...), so both trees are flattened into
	# the same output folder: shared first, then the flavor on top.
	Copy-Item (Join-Path $SharedSource "*") $output -Recurse -Force
	Copy-Item (Join-Path $flavorSource "*") $output -Recurse -Force
	Set-BuildVersion $output

	$count = (Get-ChildItem $output -Recurse -File).Count
	Write-Host "Built $name $Version -> $output ($count files)"

	# CurseForge upload: a zip whose root is the addon folder itself
	# (ClassicUIRestoration/ClassicUIRestoration.toc, ...), one per flavor.
	# Old zips of other versions are removed so the folder holds one per flavor.
	Get-ChildItem (Join-Path $BuildRoot $name) -File -Filter "$AddonName-*.zip" | Remove-Item -Force
	$zip = Join-Path (Join-Path $BuildRoot $name) "$AddonName-$Version-$($name.ToLower()).zip"
	New-AddonZip -Folder $output -Zip $zip
	Write-Host "Zipped $name -> $zip"
}

exit 0
