<#
.SYNOPSIS
	Assembles the deployable addon folder and the CurseForge zip into <repo>\build\.

.DESCRIPTION
	Copies <repo>\src\ (the addon folder: one .toc for every game flavor)
	into <repo>\build\ClassicUIRestoration\, stamps the version into it and
	zips that folder as <repo>\build\ClassicUIRestoration-<version>.zip, the
	layout CurseForge expects (the addon folder is the zip's root entry).

	The same build runs on every flavor: the .toc lists each flavor's
	Interface version and the Forever-only files return early on retail
	(ns.IS_FOREVER in Core.lua). Upload the one zip to CurseForge tagged with
	every game version it supports.

	The build folder is git-ignored; it is what deploy.ps1 copies into the
	game(s) and what gets uploaded to CurseForge. It is recreated from scratch
	on every run.

	The addon name and version come from <repo>\addon.json.

.EXAMPLE
	.\build.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RepoRoot  = $PSScriptRoot
$SrcRoot   = Join-Path $RepoRoot "src"
$BuildRoot = Join-Path $RepoRoot "build"

# addon.json is the single place for the addon name and version (deploy.ps1
# reads it too for the flavor -> game folder mapping).
$Addon = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
foreach ($key in "name", "version") {
	if (-not $Addon.$key) {
		throw "addon.json is missing '$key'."
	}
}
$AddonName = $Addon.name
$Version   = $Addon.version
if ($Version -notmatch '^\d+\.\d+\.\d+(\S*)$') {
	throw "addon.json version must look like 1.2.3 (optionally with a suffix), got '$Version'."
}

if (-not (Test-Path (Join-Path $SrcRoot "$AddonName.toc"))) {
	throw "src\$AddonName.toc does not exist."
}

# The .toc (and any other .toc/.lua/.md file) carries the
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

$output = Join-Path $BuildRoot $AddonName

if (Test-Path $output) {
	Remove-Item $output -Recurse -Force
}
New-Item -ItemType Directory -Force $output | Out-Null

# src\ is the addon folder as it lands in the game (Core.lua, Modules\, ...).
Copy-Item (Join-Path $SrcRoot "*") $output -Recurse -Force
Set-BuildVersion $output

$count = (Get-ChildItem $output -Recurse -File).Count
Write-Host "Built $AddonName $Version -> $output ($count files)"

# CurseForge upload: a zip whose root is the addon folder itself
# (ClassicUIRestoration/ClassicUIRestoration.toc, ...). Old zips of other
# versions are removed so the folder holds only the current one.
Get-ChildItem $BuildRoot -File -Filter "$AddonName-*.zip" | Remove-Item -Force
$zip = Join-Path $BuildRoot "$AddonName-$Version.zip"
New-AddonZip -Folder $output -Zip $zip
Write-Host "Zipped -> $zip"

exit 0
