<#
.SYNOPSIS
	Builds the addon, writes its changelog and uploads the zip to CurseForge.

.DESCRIPTION
	Runs build.ps1 (build\ForevermoreClassicUI-<version>.zip), writes the
	release notes of this version to build\CHANGELOG.md and uploads the zip to
	the CurseForge project named in addon.json ("curseforge.projectId"),
	tagged with the game version of every flavor the .toc supports. The CI
	release job (.github\workflows\build.yml) runs it when the version in
	addon.json changes on master, then creates the GitHub release (tag
	v<version>) from the same zip and notes.

	Changelog: the "## <version>" section of CHANGELOG.md when there is one,
	otherwise the subjects of the commits since the previous release (the
	previous v* tag; before the first tag, the last commit whose addon.json
	carried another version). Merge commits and bare "version bump" commits
	are left out.

	Game versions: each "## Interface:" entry of the .toc becomes major.minor
	(120100 -> 12.1, 16001 -> 1.60) and is tagged with CurseForge's newest
	patch of it (12.1.5, 1.60.1), so a client patch CurseForge lists is picked
	up without editing anything. "curseforge.gameVersions" in addon.json (a list
	of CurseForge version names, e.g. ["12.1.5", "1.60.1"]) replaces that
	lookup when set.

	Release type: a version with "alpha" or "beta" in its suffix
	(1.22.0-beta1) is uploaded as that type, any other as a release.

	The CurseForge API token (https://authors.curseforge.com/#/settings/api-tokens)
	is read from the CURSEFORGE_API_TOKEN environment variable; in CI it is the
	repository secret of the same name.

.PARAMETER DryRun
	Build and write the changelog, resolve the game versions if a token is
	set, but upload nothing.

.EXAMPLE
	.\publish.ps1 -DryRun                 # check the changelog and the zip
	$env:CURSEFORGE_API_TOKEN = "..."; .\publish.ps1
#>
[CmdletBinding()]
param(
	[switch]$DryRun
)

$ErrorActionPreference = "Stop"

$RepoRoot  = $PSScriptRoot
$BuildRoot = Join-Path $RepoRoot "build"
$CurseForgeApi = "https://wow.curseforge.com/api"

$Addon     = Get-Content (Join-Path $RepoRoot "addon.json") -Raw | ConvertFrom-Json
$AddonName = $Addon.name
$Version   = $Addon.version
$Tag       = "v$Version"
$Toc       = Get-Content (Join-Path (Join-Path $RepoRoot "src") "$AddonName.toc")
$Title     = ($Toc | Where-Object { $_ -match '^##\s*Title:' } | Select-Object -First 1) -replace '^##\s*Title:\s*', ''
if (-not $Title) {
	$Title = $AddonName
}

$ReleaseType = "release"
if ($Version -match '-.*alpha') {
	$ReleaseType = "alpha"
} elseif ($Version -match '-.*beta') {
	$ReleaseType = "beta"
}

# --- Build ------------------------------------------------------------------

& (Join-Path $RepoRoot "build.ps1")
if ($LASTEXITCODE -ne 0) {
	throw "build.ps1 failed."
}
$Zip = Join-Path $BuildRoot "$AddonName-$Version.zip"
if (-not (Test-Path $Zip)) {
	throw "The build did not produce $Zip."
}

# --- Changelog ----------------------------------------------------------------

# The "## <version>" section of CHANGELOG.md ("## 1.2.3", "## v1.2.3",
# "## [1.2.3] - date"), without its heading; $null when there is none.
function Get-CuratedNotes {
	$path = Join-Path $RepoRoot "CHANGELOG.md"
	if (-not (Test-Path $path)) {
		return $null
	}
	$heading = '^##\s+\[?v?' + [regex]::Escape($Version) + '\]?(\s|$)'
	$notes = $null
	foreach ($line in Get-Content $path) {
		if ($null -ne $notes) {
			if ($line -match '^##\s') {
				break
			}
			$notes += $line
		} elseif ($line -match $heading) {
			$notes = @()
		}
	}
	if ($null -eq $notes) {
		return $null
	}
	$text = ($notes -join "`n").Trim()
	if (-not $text) {
		return $null
	}
	return $text
}

function Get-AddonVersionAt([string]$Revision) {
	$json = & git -C $RepoRoot show "${Revision}:addon.json" 2>$null
	if ($LASTEXITCODE -ne 0) {
		return $null
	}
	return (($json -join "`n") | ConvertFrom-Json).version
}

# The commit the previous release was made from: the newest v* tag other than
# this version's, else (before the first tag) the newest commit whose
# addon.json has another version. $null when neither exists.
function Get-PreviousRelease {
	$previous = & git -C $RepoRoot describe --tags --abbrev=0 --match "v[0-9]*" --exclude $Tag HEAD 2>$null
	if ($LASTEXITCODE -eq 0 -and $previous) {
		return @{ Revision = $previous; Tag = $previous }
	}
	$commits = & git -C $RepoRoot log --format=%H '--' addon.json
	if ($LASTEXITCODE -ne 0) {
		throw "git log failed."
	}
	foreach ($commit in $commits) {
		$commitVersion = Get-AddonVersionAt $commit
		if ($commitVersion -and $commitVersion -ne $Version) {
			return @{ Revision = $commit; Tag = $null }
		}
	}
	return $null
}

function Get-CommitNotes {
	$previous = Get-PreviousRelease
	$range = if ($previous) { "$($previous.Revision)..HEAD" } else { "HEAD" }
	$subjects = & git -C $RepoRoot log --no-merges --format=%s $range
	if ($LASTEXITCODE -ne 0) {
		throw "git log $range failed."
	}
	$lines = @()
	foreach ($subject in $subjects) {
		$subject = $subject.Trim()
		if (-not $subject -or $subject -match '^(version bump|bump version|v?\d+\.\d+\.\d+\S*)$') {
			continue
		}
		# Commit subjects start lower or upper case; the list reads better capitalized.
		$lines += "- " + $subject.Substring(0, 1).ToUpper() + $subject.Substring(1)
	}
	if (-not $lines) {
		$lines = @("- Maintenance release.")
	}
	$text = $lines -join "`n"
	if ($previous -and $previous.Tag -and $env:GITHUB_SERVER_URL -and $env:GITHUB_REPOSITORY) {
		$text += "`n`n[All changes since $($previous.Tag)]($env:GITHUB_SERVER_URL/$env:GITHUB_REPOSITORY/compare/$($previous.Tag)...$Tag)"
	}
	return $text
}

$notes = Get-CuratedNotes
$source = "CHANGELOG.md"
if (-not $notes) {
	$notes = Get-CommitNotes
	$source = "commit messages"
}
$Changelog = "## $Title $Version`n`n$notes`n"
$ChangelogPath = Join-Path $BuildRoot "CHANGELOG.md"
[System.IO.File]::WriteAllText($ChangelogPath, $Changelog, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Changelog ($source) -> $ChangelogPath"
Write-Host $Changelog

# The CI job reads these to create the GitHub release.
if ($env:GITHUB_OUTPUT) {
	Add-Content $env:GITHUB_OUTPUT "tag=$Tag"
	Add-Content $env:GITHUB_OUTPUT "zip=$Zip"
	Add-Content $env:GITHUB_OUTPUT "changelog=$ChangelogPath"
	Add-Content $env:GITHUB_OUTPUT "prerelease=$(($ReleaseType -ne 'release').ToString().ToLower())"
}

# --- CurseForge ---------------------------------------------------------------

$ProjectId = $Addon.curseforge.projectId
if (-not $ProjectId) {
	throw "addon.json has no curseforge.projectId."
}
$Token = $env:CURSEFORGE_API_TOKEN
if (-not $Token) {
	if ($DryRun) {
		Write-Host "Dry run without CURSEFORGE_API_TOKEN: game versions not resolved, nothing uploaded."
		exit 0
	}
	throw "Set CURSEFORGE_API_TOKEN to a CurseForge API token (https://authors.curseforge.com/#/settings/api-tokens)."
}
$Headers = @{ "X-Api-Token" = $Token }

$allVersions = Invoke-RestMethod -Uri "$CurseForgeApi/game/versions" -Headers $Headers

function Find-GameVersions([string]$Name) {
	$found = @($allVersions | Where-Object { $_.name -eq $Name })
	if ($found.Count -gt 1) {
		Write-Warning "CurseForge has $($found.Count) game versions named $Name (ids $($found.id -join ', ')); tagging all of them."
	}
	return $found
}

$gameVersions = @()
if ($Addon.curseforge.gameVersions) {
	foreach ($name in $Addon.curseforge.gameVersions) {
		$found = Find-GameVersions $name
		if (-not $found) {
			throw "CurseForge has no game version named '$name' (curseforge.gameVersions in addon.json)."
		}
		$gameVersions += $found
	}
} else {
	$interfaceLine = $Toc | Where-Object { $_ -match '^##\s*Interface:' } | Select-Object -First 1
	if (-not $interfaceLine) {
		throw "src/$AddonName.toc has no '## Interface:' line."
	}
	$interfaces = ($interfaceLine -replace '^##\s*Interface:', '') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
	foreach ($interface in $interfaces) {
		$number = [int]$interface
		$prefix = "{0}.{1}." -f [math]::Floor($number / 10000), ([math]::Floor($number / 100) % 100)
		# Newest patch of that major.minor (12.1.5 over 12.1.0).
		$newest = $allVersions |
			Where-Object { $_.name -match ('^' + [regex]::Escape($prefix) + '(\d+)$') } |
			Sort-Object { [int]($_.name.Substring($prefix.Length)) } |
			Select-Object -Last 1
		if (-not $newest) {
			throw "CurseForge has no game version ${prefix}x for Interface $interface; list the version names in curseforge.gameVersions in addon.json."
		}
		$gameVersions += Find-GameVersions $newest.name
	}
}
$gameVersions = @($gameVersions | Sort-Object id -Unique)
Write-Host "Game versions: $(($gameVersions | ForEach-Object { "$($_.name) (id $($_.id))" }) -join ', ')"

$metadata = [ordered]@{
	changelog     = $Changelog
	changelogType = "markdown"
	gameVersions  = @($gameVersions.id)
	releaseType   = $ReleaseType
} | ConvertTo-Json -Compress

if ($DryRun) {
	Write-Host "Dry run: would upload $Zip to CurseForge project $ProjectId as $ReleaseType."
	exit 0
}

try {
	$response = Invoke-RestMethod -Method Post -Uri "$CurseForgeApi/projects/$ProjectId/upload-file" -Headers $Headers -Form @{
		metadata = $metadata
		file     = Get-Item $Zip
	}
} catch {
	$detail = if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message } else { $_.Exception.Message }
	throw "CurseForge upload failed: $detail"
}
Write-Host "Uploaded $AddonName $Version to CurseForge project $ProjectId as $ReleaseType (file id $($response.id))."

exit 0
