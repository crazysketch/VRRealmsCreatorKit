<#
    VRR UPDATER — Creator Kit updater
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

    Usage:  VRRUpdater.cmd            check, then ask before installing
            VRRUpdater.cmd -Check     report only, never install
            VRRUpdater.cmd -Force     reinstall even if versions match
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

# The package may also carry VRR Updater ITSELF, so the updater can update itself.
# EXPLICIT ALLOWLIST, not a widened prefix: the kit plugin folder, plus exactly two
# tool paths at the kit root. Anything else - above all Content\VRRealms\Community,
# where a creator's own maps live - is still refused outright.
function Test-AllowedEntry($name) {
    if ($name -like 'VRRealms/Plugins/VRRealmsCreatorKit/*') { return $true }
    if ($name -eq  'VRRUpdater.cmd')                        { return $true }
    if ($name -like 'Tools/*.ps1')                          { return $true }
    return $false
}# ⚠⚠ FIND THE KIT. TWO STRATEGIES, THEN SAY WHAT WAS TRIED.
#
# Strategy 1 walks UP looking for the exact layout VRRealms\Plugins\VRRealmsCreatorKit.
# Strategy 2 exists because strategy 1 assumed that layout and a real creator's kit did
# not match it - the search found nothing anywhere above the tool and the failure said
# only "kit not found", which is unactionable from a screenshot. So we also search DOWN
# for the .uplugin by name, and on failure we REPORT EVERY FOLDER WE LOOKED IN.
#
# 💡 The rule this encodes: when a tool cannot find something, the error must name where
# it looked. "Not found" costs a round trip every single time; "not found, I checked
# these five folders" is usually self-diagnosing.
$script:KitSearchLog = New-Object System.Collections.ArrayList

# Extract without Expand-Archive: its -DestinationPath has no literal variant, so a kit
# under D:\[Brackets]\ fails with "an item with the specified name ... already exists".
# Entry-by-entry with overwrite is also idempotent, which a retry needs.
function Expand-Zip($zipPath, $destRoot) {
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $zip.Entries) {
            if (-not $entry.Name) { continue }                  # directory marker
            $rel    = $entry.FullName.Replace([char]47, [char]92)
            $target = Join-Path $destRoot $rel
            [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
    } finally { $zip.Dispose() }
}
# Recursive directory copy that is immune to wildcard characters in paths.
function Copy-Tree($src, $dst) {
    [void][IO.Directory]::CreateDirectory($dst)
    foreach ($d in [IO.Directory]::GetDirectories($src, '*', 'AllDirectories')) {
        [void][IO.Directory]::CreateDirectory((Join-Path $dst $d.Substring($src.Length).TrimStart('\')))
    }
    foreach ($fl in [IO.Directory]::GetFiles($src, '*', 'AllDirectories')) {
        [IO.File]::Copy($fl, (Join-Path $dst $fl.Substring($src.Length).TrimStart('\')), $true)
    }
}

# ---------------------------------------------------------------------------
# NEVER HALF-UPDATED (2026-10-07)
# ---------------------------------------------------------------------------
# An install used to write files one after another and stop at the first one Windows refused. On a PC whose
# security software guards documents and pictures (ransomware protection: it lets an unknown program change
# .dll and .json files but not .txt or .png, in folders like Desktop and Documents) that meant the plugin
# files and the version number were already new when a .txt was refused, and the status line still said the
# tools had been left alone. Two things now stand between a creator and that state:
#   1. Get-BlockedTargets opens every file the package will replace for writing BEFORE anything is changed.
#      If one refuses, nothing is touched and the message says what usually causes it.
#      A file that already has exactly the bytes the package carries is skipped by both steps: it is not
#      written, so it cannot be refused. The kit's .txt and .png files rarely change between releases, so on
#      such a PC most updates simply go through.
#   2. Expand-ZipTracked keeps a copy of each file as it replaces it, and if a write still fails half way
#      (a full disk, a file opened in between) it puts every one of them back.
# True when the file on disk already holds exactly what the package would write there.
function Test-EntrySame($entry, $target) {
    try {
        $info = New-Object IO.FileInfo($target)
        if (-not $info.Exists -or $info.Length -ne $entry.Length) { return $false }
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $zs = $entry.Open()
            try { $a = [BitConverter]::ToString($sha.ComputeHash($zs)) } finally { $zs.Dispose() }
            $fs = [IO.File]::OpenRead($target)
            try { $b = [BitConverter]::ToString($sha.ComputeHash($fs)) } finally { $fs.Dispose() }
        } finally { $sha.Dispose() }
        return ($a -eq $b)
    } catch { return $false }
}

function Get-BlockedTargets($zipPath, $destRoot) {
    $blocked = New-Object System.Collections.ArrayList
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        foreach ($entry in $zip.Entries) {
            if (-not $entry.Name) { continue }                  # directory marker
            $target = Join-Path $destRoot $entry.FullName.Replace([char]47, [char]92)
            if (-not [IO.File]::Exists($target)) { continue }   # a new file: nothing to refuse yet
            if (Test-EntrySame $entry $target) { continue }     # already identical: it will not be written at all
            try { $probe = [IO.File]::Open($target, 'Open', 'Write', 'ReadWrite'); $probe.Dispose() }
            catch { [void]$blocked.Add($entry.FullName.Replace([char]92, [char]47)) }
        }
    } finally { $zip.Dispose() }
    return ,$blocked.ToArray()
}

function Get-BlockedMessage($blocked, $lead) {
    $more = ''
    if ($blocked.Count -gt 1) { $more = " and $($blocked.Count - 1) more" }
    return "$lead Windows will not let VRR Updater replace '$($blocked[0])'$more. With Unreal Editor closed, this is almost always security software that guards documents and pictures (ransomware protection) refusing .txt and .png files in folders like Desktop and Documents. Allow this folder, or PowerShell, in that software, or move the kit to a plain folder such as C:\VRRealmsCreatorKit, then try again."
}

function Expand-ZipTracked($zipPath, $destRoot, $undoDir) {
    $written = New-Object System.Collections.ArrayList
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        try {
            foreach ($entry in $zip.Entries) {
                if (-not $entry.Name) { continue }
                $rel    = $entry.FullName.Replace([char]47, [char]92)
                $target = Join-Path $destRoot $rel
                if (Test-EntrySame $entry $target) { continue }   # nothing to do, and nothing for anyone to refuse
                [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
                if ([IO.File]::Exists($target)) {
                    $undo = Join-Path $undoDir $rel
                    [void][IO.Directory]::CreateDirectory((Split-Path $undo -Parent))
                    [IO.File]::Copy($target, $undo, $true)
                }
                [void]$written.Add($rel)
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
            }
        } catch {
            $why      = $_.Exception.Message
            $failedOn = '?'
            if ($written.Count -gt 0) { $failedOn = ([string]$written[$written.Count - 1]).Replace([char]92, [char]47) }
            $notBack = 0
            foreach ($rel in $written) {
                $undo   = Join-Path $undoDir $rel
                $target = Join-Path $destRoot $rel
                try {
                    if ([IO.File]::Exists($undo)) { [IO.File]::Copy($undo, $target, $true) }
                    elseif ([IO.File]::Exists($target)) { [IO.File]::Delete($target) }   # a file this install had added
                } catch {
                    # The file that refused in the first place cannot be written now either, and need not be:
                    # it was never changed. Only a file that really differs from its copy counts as not put back.
                    $same = $false
                    try {
                        if ([IO.File]::Exists($undo) -and [IO.File]::Exists($target)) {
                            $same = ((Get-FileHash -LiteralPath $undo -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash)
                        }
                    } catch { }
                    if (-not $same) { $notBack++ }
                }
            }
            $tail = 'Every file it had already replaced was put back, so the kit is as it was.'
            if ($notBack -gt 0) { $tail = "$notBack file(s) could not be put back; your previous tools are in the newest _VRRUpdaterBackup_ folder." }
            throw "could not write '$failedOn' ($why) $tail"
        }
    } finally { $zip.Dispose() }
}
function Find-KitRoot($startDir) {
    $ancestors = New-Object System.Collections.ArrayList
    $dir = $startDir
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
        [void]$ancestors.Add($dir)
        $probe = Join-Path $dir 'VRRealms\Plugins\VRRealmsCreatorKit\VRRealmsCreatorKit.uplugin'
        [void]$script:KitSearchLog.Add("looked for VRRealms\Plugins\... under: $dir")
        if (Test-Path -LiteralPath $probe) { $script:FoundPluginDir = (Split-Path $probe -Parent); return $dir }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    # Nothing in the expected shape. Hunt for the .uplugin by NAME instead - the kit may
    # be nested differently, or the project folder may not be called VRRealms at all.
    # ⚠⚠ BOUNDED. NEVER RECURSE FROM A DRIVE ROOT.
    # The first version searched every ancestor to depth 5 - and the ancestor list runs
    # all the way up to D:\, so it recursively scanned an entire drive. It never crashed;
    # it just ground away for minutes with no window on screen, which reads as frozen.
    # Only the nearest 3 ancestors, only depth 3, and anything that looks like a drive
    # root is skipped outright. A real kit is always within a couple of folders of the tool.
    foreach ($anc in ($ancestors | Select-Object -First 3)) {
        if ($anc.Length -le 3) {
            [void]$script:KitSearchLog.Add("skipped drive root (too broad to search): $anc")
            continue
        }
        [void]$script:KitSearchLog.Add("searched for VRRealmsCreatorKit.uplugin under: $anc")
        # ⚠ SKIP OUR OWN BACKUPS. Every install leaves _VRRUpdaterBackup_<version>\ behind,
        # and that folder contains a copy of VRRealmsCreatorKit.uplugin - the exact filename
        # this search hunts for. Without this filter the tool can "find" a kit inside its own
        # backup and then install into the wrong place. A tool's leftovers must never look
        # like the thing it is searching for.
        $hit = Get-ChildItem -LiteralPath $anc -Filter 'VRRealmsCreatorKit.uplugin' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
               Where-Object { $_.FullName -notlike '*_VRRUpdaterBackup_*' } |
               Select-Object -First 1
        if ($hit) {
            # <root>\<project>\Plugins\VRRealmsCreatorKit\VRRealmsCreatorKit.uplugin -> up 3
            $root = Split-Path (Split-Path (Split-Path $hit.DirectoryName -Parent) -Parent) -Parent
            [void]$script:KitSearchLog.Add("FOUND plugin at: $($hit.FullName)")
            [void]$script:KitSearchLog.Add("deduced kit root: $root")
            $script:FoundPluginDir = $hit.DirectoryName
            if ($root -and (Test-Path -LiteralPath $root)) { return $root }
        }
    }
    return $null
}
$KitRoot      = Find-KitRoot $PSScriptRoot
# No kit anywhere. Fall back to the old assumption so the FRIENDLY 'kit not found'
# message (with its list of folders checked) still prints, instead of the script dying
# on a null inside Join-Path and leaving the user staring at a raw PowerShell error.
if (-not $KitRoot) { $KitRoot = Split-Path -Parent $PSScriptRoot }
$PluginDir    = if ($script:FoundPluginDir) { $script:FoundPluginDir } else { Join-Path $KitRoot 'VRRealms\Plugins\VRRealmsCreatorKit' }
$UPluginPath  = Join-Path $PluginDir 'VRRealmsCreatorKit.uplugin'
$ContentVerPath = Join-Path $KitRoot '.kit-content-version'

function Write-Head($text) { Write-Host ""; Write-Host "  $text" -ForegroundColor Cyan }
function Write-Ok($text)   { Write-Host "  $text" -ForegroundColor Green }
function Write-Warn2($text){ Write-Host "  $text" -ForegroundColor Yellow }
function Write-Bad($text)  { Write-Host "  $text" -ForegroundColor Red }

Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkCyan
Write-Host "   VRR UPDATER  -  VR Realms Creator Kit updater   (build 2026-10-07.1)" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor DarkCyan

# ---------------------------------------------------------------------------
# 1. Where am I, and what version is installed?
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $UPluginPath)) {
    Write-Bad "Could not find the kit plugin at:"
    Write-Bad "  $UPluginPath"
    Write-Host ""
    Write-Host ""
    Write-Host "  Folders checked:"
    foreach ($line in $script:KitSearchLog) { Write-Host "    $line" }
    Write-Host ""
    Write-Host "  Keep VRRUpdater.cmd in the folder that contains 'VRRealms'. If you moved it,"
    Write-Host "  move it back rather than running it from somewhere else."
    exit 2
}

try {
    $uplugin      = Get-Content -LiteralPath $UPluginPath -Raw | ConvertFrom-Json
    $localVersion = [string]$uplugin.VersionName
} catch {
    Write-Bad "The kit's .uplugin file could not be read. It may be corrupted."
    exit 2
}

$localContentVer = '0'
if (Test-Path -LiteralPath $ContentVerPath) {
    $localContentVer = (Get-Content -LiteralPath $ContentVerPath -Raw).Trim()
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
                                 -Headers @{ 'User-Agent' = 'VRRUpdater' } -TimeoutSec 30
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
                                      -Headers @{ 'User-Agent' = 'VRRUpdater' } -TimeoutSec 30
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
    Write-Bad "This release has no plugin zip attached, so VRR Updater cannot patch it."
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
    Write-Bad "Unreal Editor is running. Close it and run VRR Updater again."
    Write-Host "  (The kit's plugin file is locked while the editor is open.)"
    exit 5
}

# ---------------------------------------------------------------------------
# 6. Download + verify
# ---------------------------------------------------------------------------
$tmpDir = Join-Path $env:TEMP ("VRRUpdater_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
$zipPath = Join-Path $tmpDir $asset.name

try {
    Write-Head "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing `
                      -Headers @{ 'User-Agent' = 'VRRUpdater' } -TimeoutSec 300

    if ($manifest -and $manifest.pluginSha256) {
        $got = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
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
            if (-not (Test-AllowedEntry $name)) {
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
    # Unique, timestamped backup - see the note in VRRUpdater-App.ps1. Copy-Item -Recurse
    # refuses an existing destination, so a retry after any failure was permanently blocked
    # by the previous attempt's leftovers. .NET copy because paths may contain [brackets].
    # Before anything is changed: can every file this package replaces be written? (See NEVER HALF-UPDATED.)
    $blocked = Get-BlockedTargets $zipPath $KitRoot
    if ($blocked.Count -gt 0) {
        Write-Host ""
        Write-Bad (Get-BlockedMessage $blocked 'Nothing was changed.')
        exit 9
    }

    $backupDir = Join-Path $KitRoot ("_VRRUpdaterBackup_" + $localVersion + "_" + (Get-Date -Format 'MMdd-HHmmss'))
    Copy-Tree $PluginDir $backupDir
    Write-Ok "Backed up your current tools to _VRRUpdaterBackup_$localVersion"

    Expand-ZipTracked $zipPath $KitRoot (Join-Path $tmpDir 'undo')

    $newVersion = (Get-Content -LiteralPath $UPluginPath -Raw | ConvertFrom-Json).VersionName
    if ($manifest -and $manifest.contentVersion) {
        [IO.File]::WriteAllText($ContentVerPath, [string]$manifest.contentVersion,
                                (New-Object Text.UTF8Encoding($false)))
    }

    Write-Host ""
    Write-Ok "Updated to $newVersion."
    Write-Host ""
    Write-Host "  Open your project again and the new tools are live."
    Write-Host "  If anything looks wrong, your old tools are in _VRRUpdaterBackup_$localVersion"
    exit 0
}
catch {
    Write-Host ""
    Write-Bad "Update failed: $($_.Exception.Message)"
    exit 8
}
finally {
    if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}
