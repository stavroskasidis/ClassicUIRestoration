# Renders the logos in logo-src\ to PNG with headless Chrome (or Edge):
#   logo.png       800x800   CurseForge project logo (split W medallion, stacked wordmark)
#   logo_alt.png   800x800   the same with "Forever & Retail" and no Modern / Classic switch
#   logo_large.png 1600x640  horizontal lockup for page headers
#   ..\src\Icon.png 128x128  the medallion alone: the .toc's IconTexture, also shown by the setup wizard and options page
# The sources load Cinzel, Cinzel Decorative and Marcellus from Google Fonts, so this needs a network connection.
$ErrorActionPreference = 'Stop'

$browser = @(
	"$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
	"${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
	"${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw 'Chrome or Edge not found' }

$logos = @(
	@{ Name = 'logo';       Width = 800;  Height = 800 },
	@{ Name = 'logo_alt';   Width = 800;  Height = 800 },
	@{ Name = 'logo_large'; Width = 1600; Height = 640 },
	@{ Name = 'icon';       Width = 128;  Height = 128; Target = '..\src\Icon.png' }
)
foreach ($logo in $logos) {
	$source = Join-Path $PSScriptRoot "logo-src\$($logo.Name).html"
	$target = Join-Path $PSScriptRoot $(if ($logo.Target) { $logo.Target } else { "$($logo.Name).png" })
	$target = [System.IO.Path]::GetFullPath($target)
	Remove-Item $target -ErrorAction SilentlyContinue
	$url = ([System.Uri]$source).AbsoluteUri
	# A throwaway profile, so a running browser does not swallow the call; the time budget lets the web fonts load.
	$profileDir = Join-Path ([System.IO.Path]::GetTempPath()) "fmcui-logo-$([guid]::NewGuid())"
	& $browser --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$profileDir" `
		--default-background-color=00000000 --window-size="$($logo.Width),$($logo.Height)" `
		--virtual-time-budget=10000 --screenshot="$target" $url 2>$null | Out-Null
	Remove-Item -Recurse -Force $profileDir -ErrorAction SilentlyContinue
	if (-not (Test-Path $target)) { throw "Rendering $($logo.Name) failed" }
	Write-Host $target
}
