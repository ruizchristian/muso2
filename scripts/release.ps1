# Publishes a release that phones pick up through Muso's in-app updater.
# Usage:  .\scripts\release.ps1            (notes generated from the commits since the last release)
#         .\scripts\release.ps1 -Notes "Fixed the lock-screen buttons"
#
# This only creates the GitHub release. CI (.github/workflows/android.yml) then builds the signed
# APK and attaches it, which takes ~10 minutes; until it is attached, the app does not offer it.

param([string]$Notes)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  $env:Path += ';C:\Program Files\GitHub CLI'
}

$version = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value)
$tag = "v$version"

# The release builds whatever is on GitHub's main, so local commits that were never pushed would
# silently be left out.
git fetch origin main --quiet
if ((git rev-parse HEAD) -ne (git rev-parse origin/main)) {
  throw 'Local main and origin/main differ. Push (or pull) first, then release.'
}

$ErrorActionPreference = 'Continue'
gh release view $tag *> $null
$exists = $LASTEXITCODE -eq 0
$ErrorActionPreference = 'Stop'
if ($exists) {
  throw "Release $tag already exists. Bump 'version:' in pubspec.yaml (e.g. 1.0.1), push, and run this again."
}

$arguments = @('release', 'create', $tag, '--target', 'main', '--title', "Muso $version")
if ($Notes) { $arguments += @('--notes', $Notes) } else { $arguments += '--generate-notes' }
gh @arguments
if ($LASTEXITCODE -ne 0) { throw 'gh release create failed' }

Write-Host "`nReleased $tag. CI is building the APK; phones will see the update once it is attached:" -ForegroundColor Green
gh run list --workflow android.yml --limit 1
