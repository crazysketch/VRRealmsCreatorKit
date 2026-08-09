<#
    VRR CREATOR — Creator Kit updater
    ---------------------------------------------------------------------------
    Reads the kit's installed version, asks GitHub what the latest release is,
    and swaps in the new TOOLS if they differ.

    WHY THIS EXISTS
      The kit is ~1.2 GB, but only ~1.2 MB of it (the plugin) changes between
      releases. Creators were re-downloading the whole thing to get a new DLL.

    THE THREE RULES THIS SCRIPT WILL NOT BREAK
      1. It only ever writes inside VRRealms\Plugins\VRRealmsCreatorKit\.
         A creator's own maps and avatars are never touched, and every entry in
         the downloaded zip is checked against that prefix BEFORE anything is
         extracted (a zip that reaches outside it is rejected outright).
      2. It contains NO credentials. The repo is public; the GitHub API and the
         release assets are read anonymously. Never add a token or an FTP
         password here — this file ships to every creator.
      3. It refuses to run while Unreal is open, because the plugin DLL is
         locked and a half-written plugin folder is worse than an old one.

    Usage:  VRRCreator.cmd            check, then ask before installing
            VRRCreator.cmd -Check     report only, never install
            VRRCreator.cmd -Force     reinstall even if versions match
#>

[CmdletBinding()]
param(
    [switch] $Check,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1 still defaults to TLS 1.0 on some machines, and GitHub
# refuses anything below 1.2 — without this the very first request dies with an
# unhelpful "connection was closed" that looks like a network outage.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo         = 'crazysketch/VRRealmsCreatorKit'
$SafePrefix   = 'VRRealms/Plugins/VRRealmsCreatorKit/'
$KitRoot      = Split-Path -Parent $PSScriptRoot
$PluginDir    = Join-Path $KitRoot 'VRRealms\Plugins\VRRealmsCreatorKit'
$UPluginPath  = Join-Path $PluginDir 'VRRealmsCreatorKit.uplugin'
$ContentVerPath = Join-Path $KitRoot '.kit-content-version'

function Write-Head($text) { Write-Host ""; Write-Host "  $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "  $text" -ForegroundColor Yellow }
function Write-Bad($text)  { Write-Host "  $text" -ForegroundColor Red }

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkCyan
Write-Host "   VRR CREATOR  -  VR Realms Creator Kit updater" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# 1. Where am I, and what version is installed?
# ---------------------------------------------------------------------------
if (-not (Test-Path $UPluginPath)) {
    Write-Bad "Could not find the kit plugin at:"
    Write-Bad "  $UPluginPath"
    Write-Host ""
    Write-Host "  Keep VRRCreator.cmd in the folder that contains 'VRRealms'. If you moved it,"
    Write-Host "  move it back rather than running it from somewhere else."
    exit 2
}

try {
    $uplugin      = Get-Content $UPluginPath -Raw | ConvertFrom-Json
    $localVersion = [string]$uplugin.VersionName
} catch {
    Write-Bad "The kit's .uplugin file could not be read. It may be corrupted."
    exit 2
}

$localContentVer = '0'
if (Test-Path $ContentVerPath) {
    $localContentVer = (Get-Content $ContentVerPath -Raw).Trim()
}

Write-Host ""
Write-Host "  Installed tools : $localVersion"
Write-Host "  Kit folder      : $KitRoot"

# ---------------------------------------------------------------------------
# 2. Ask GitHub what the latest release is
# ---------------------------------------------------------------------------
Write-Head "Checking for updates..."
try {
    # The API rejects requests with no User-Agent. Anonymous is fine: public repo.
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
                                 -Headers @{ 'User-Agent' = 'VRRCreator' } -TimeoutSec 30
} catch {
    Write-Bad "Could not reach GitHub."
    Write-Host "  $($_.Exception.Message)"
    Write-Host ""
    Write-Host "  Check your internet connection and try again. Nothing was changed."
    exit 3
}

$latestVersion = ([string]$release.tag_name) -replace '^[vV]', ''
if ([string]::IsNullOrWhiteSpace($latestVersion)) {
    Write-Bad "The latest release has no version tag. Tell the kit author."
    exit 3
}
Write-Host "  Latest release  : $latestVersion"

# Compare as versions, not strings — "0.4.10" is NEWER than "0.4.9", and a string
# comparison gets that backwards. Fall back to string inequality if either side
# is not a clean Major.Minor.Patch.

# ⚠⚠ LEGACY TRAP: every kit shipped before this updater existed has
#    "VersionName": "1.0" baked into its .uplugin — a placeholder that was never
#    maintained while the kit itself went 0.1 ... 0.4.6. Parsed as a version,
#    1.0 is NEWER than 0.4.6, so without this guard the updater would cheerfully
#    tell every existing creator they are up to date, forever, and the whole
#    feature would look like it worked while doing nothing.
#    Treat that exact placeholder as "pre-versioning, definitely stale".
if ($localVersion -eq '1.0') {
    Write-Warn2 "Your kit predates version tracking (it reports 1.0). Treating it as out of date."
    $localVersion = '0.0.0'
}

$needsUpdate = $false
try {
    $needsUpdate = ([version]$latestVersion) -gt ([version]$localVersion)
} catch {
    $needsUpdate = ($latestVersion -ne $localVersion)
}

# ---------------------------------------------------------------------------
# 3. Does the sample CONTENT need a full re-download?
#    The plugin zip cannot carry 1.2 GB of assets, so when Content genuinely
#    changes we say so plainly instead of shipping a half-matched kit.
# ---------------------------------------------------------------------------
$manifest = $null
$manifestAsset = $release.assets | Where-Object { $_.name -eq 'manifest.json' } | Select-Object -First 1
if ($manifestAsset) {
    try {
        $manifest = Invoke-RestMethod -Uri $manifestAsset.browser_download_url `
                                      -Headers @{ 'User-Agent' = 'VRRCreator' } -TimeoutSec 30
    } catch {
        $manifest = $null   # not fatal: the plugin update can still proceed
    }
}

$contentStale = $false
if ($manifest -and $manifest.contentVersion) {
    $contentStale = ([string]$manifest.contentVersion -ne [string]$localContentVer)
}

if (-not $needsUpdate -and -not $Force) {
    Write-Host ""
    Write-Ok "You are up to date ($localVersion)."
    if ($contentStale) {
        Write-Host ""
        Write-Warn2 "NOTE: the sample Content in this release is newer than yours."
        Write-Warn2 "      That part is too large to patch. Download the full kit when convenient:"
        Write-Host  "      https://github.com/$Repo/releases/latest"
    }
    exit 0
}

Write-Host ""
Write-Warn2 "An update is available: $localVersion  ->  $latestVersion"
if ($release.body) {
    Write-Head "What's new"
    ($release.body -split "`n") | Select-Object -First 25 | ForEach-Object { Write-Host "    $_" }
}
if ($contentStale) {
    Write-Host ""
    Write-Warn2 "This release ALSO changes the sample Content, which is too large to patch here."
    Write-Warn2 "The tools below will still update, but download the full kit when you can:"
    Write-Host  "  https://github.com/$Repo/releases/latest"
}

if ($Check) {
    Write-Host ""
    Write-Host "  (-Check was used, so nothing was installed.)"
    exit 0
}

# ---------------------------------------------------------------------------
# 4. Find the plugin-only asset
# ---------------------------------------------------------------------------
$asset = $release.assets | Where-Object { $_.name -like '*plugin*.zip' } | Select-Object -First 1
if (-not $asset) {
    Write-Host ""
    Write-Bad "This release has no plugin zip attached, so VRR Creator cannot patch it."
    Write-Host "  Download the full kit instead: https://github.com/$Repo/releases/latest"
    exit 4
}

Write-Host ""
$answer = Read-Host "  Install $latestVersion now? [Y/n]"
if ($answer -and $answer.Trim().ToLower() -notin @('y','yes')) {
    Write-Host "  Cancelled. Nothing was changed."
    exit 0
}

# ---------------------------------------------------------------------------
# 5. Unreal must be closed — the DLL is locked while the editor is running,
#    and a partly-replaced plugin folder is worse than an out-of-date one.
# ---------------------------------------------------------------------------
$ue = Get-Process -Name 'UnrealEditor' -ErrorAction SilentlyContinue
if ($ue) {
    Write-Host ""
    Write-Bad "Unreal Editor is running. Close it and run VRR Creator again."
    Write-Host "  (The kit's plugin file is locked while the editor is open.)"
    exit 5
}

# ---------------------------------------------------------------------------
# 6. Download + verify
# ---------------------------------------------------------------------------
$tmpDir = Join-Path $env:TEMP ("VRRCreator_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
$zipPath = Join-Path $tmpDir $asset.name

try {
    Write-Head "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing `
                      -Headers @{ 'User-Agent' = 'VRRCreator' } -TimeoutSec 300

    if ($manifest -and $manifest.pluginSha256) {
        $got = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
        if ($got -ne ([string]$manifest.pluginSha256).ToUpper()) {
            Write-Bad "Download failed its integrity check. Nothing was changed."
            Write-Host "  expected $($manifest.pluginSha256)"
            Write-Host "  got      $got"
            exit 6
        }
        Write-Ok "Integrity check passed."
    }

    # ⚠ ZIP-SLIP GUARD. Verify EVERY entry stays inside the plugin folder before
    #   extracting a single byte. A zip entry like "..\..\Content\..." would
    #   otherwise write straight into a creator's own project.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName -replace '\\', '/'
            if ($name -notlike "$SafePrefix*") {
                Write-Bad "This package tries to write outside the kit plugin folder:"
                Write-Bad "  $name"
                Write-Host "  Refusing to install. Nothing was changed."
                exit 7
            }
        }
    } finally {
        $archive.Dispose()
    }
    Write-Ok "Package contents verified ($SafePrefix only)."

    # -----------------------------------------------------------------------
    # 7. Back up, then install
    # -----------------------------------------------------------------------
    $backupDir = Join-Path $KitRoot ("_VRRCreatorBackup_" + $localVersion)
    if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
    Copy-Item $PluginDir $backupDir -Recurse -Force
    Write-Ok "Backed up your current tools to _VRRCreatorBackup_$localVersion"

    Expand-Archive -Path $zipPath -DestinationPath $KitRoot -Force

    $newVersion = (Get-Content $UPluginPath -Raw | ConvertFrom-Json).VersionName
    if ($manifest -and $manifest.contentVersion) {
        [IO.File]::WriteAllText($ContentVerPath, [string]$manifest.contentVersion,
                                (New-Object Text.UTF8Encoding($false)))
    }

    Write-Host ""
    Write-Ok "Updated to $newVersion."
    Write-Host ""
    Write-Host "  Open your project again and the new tools are live."
    Write-Host "  If anything looks wrong, your old tools are in _VRRCreatorBackup_$localVersion"
    exit 0
}
catch {
    Write-Host ""
    Write-Bad "Update failed: $($_.Exception.Message)"
    Write-Host "  Your existing tools were left alone."
    exit 8
}
finally {
    if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}
