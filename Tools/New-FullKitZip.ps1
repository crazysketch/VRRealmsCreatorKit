<#
    VRR UPDATER — build the FULL kit zip  (MAINTAINER SIDE, not for creators)
    ---------------------------------------------------------------------------
    New-KitRelease.ps1 builds only the ~550 KB patch. The GitHub release also
    needs VRRealmsCreatorKit-v<version>.zip — the whole kit folder under one
    top-level VRRealmsCreatorKit/ entry — because that is what the website's
    download buttons point at. Until 0.4.10 this was hand-built every release.

    Usage (from the kit root, AFTER New-KitRelease.ps1):
      powershell -ExecutionPolicy Bypass -File Tools\New-FullKitZip.ps1
      powershell -ExecutionPolicy Bypass -File Tools\New-FullKitZip.ps1 -PrevList prev.txt
        (prev.txt = `unzip -Z1 <previous full zip> | sort` — prints what was
         added/removed against the last release so nothing sneaks in or drops out)

    Excludes, same list as every release since 0.4.7: .git, _release, CLAUDE.md,
    Intermediate/obj/Saved/DerivedDataCache/Build, .vs, *.pdb, *.py, *.log,
    and Tools\release-notes-*.md (those go on the release page, not in the kit).
#>

[CmdletBinding()]
param(
    [string] $PrevList = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$KitRoot = (Get-Item (Split-Path -Parent $PSScriptRoot)).FullName.TrimEnd('\')
$UPlugin = Join-Path $KitRoot 'VRRealms\Plugins\VRRealmsCreatorKit\VRRealmsCreatorKit.uplugin'
$Version = (Get-Content $UPlugin -Raw | ConvertFrom-Json).VersionName

$outDir  = Join-Path $KitRoot '_release'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$zipPath = Join-Path $outDir "VRRealmsCreatorKit-v$Version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$files = Get-ChildItem $KitRoot -Recurse -File -Force | Where-Object {
    $rel = $_.FullName.Substring($KitRoot.Length).TrimStart('\')
    -not ($rel -match '^(\.git|_release|Intermediate|Saved|DerivedDataCache|Build)(\\|$)') -and
    -not ($rel -match '\\(Intermediate|obj|Saved|DerivedDataCache|Build)\\') -and
    -not ($rel -match '(^|\\)\.vs(\\|$)') -and
    $rel -ne 'CLAUDE.md' -and
    -not ($rel -match '^Tools\\release-notes-.*\.md$') -and
    $_.Extension -notin @('.pdb', '.py', '.log', '.tmp')
}

$entries = New-Object System.Collections.Generic.List[string]
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($KitRoot.Length).TrimStart('\') -replace '\\', '/'
        $entry = "VRRealmsCreatorKit/$rel"
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entry, 'Optimal')
        $entries.Add($entry)
    }
} finally { $zip.Dispose() }

$entries.Sort([StringComparer]::Ordinal)
if ($PrevList -and (Test-Path $PrevList)) {
    $prev    = Get-Content $PrevList | Where-Object { $_ } | Sort-Object
    $added   = $entries | Where-Object { $prev -notcontains $_ }
    $removed = $prev    | Where-Object { $entries -notcontains $_ }
    "vs previous list ({0} entries): +{1} / -{2}" -f $prev.Count, @($added).Count, @($removed).Count
    foreach ($a in $added)   { "  + $a" }
    foreach ($r in $removed) { "  - $r" }
}

$zipSha = (Get-FileHash $zipPath -Algorithm SHA256).Hash
"built {0} ({1:N0} bytes, {2} entries)" -f (Split-Path $zipPath -Leaf), (Get-Item $zipPath).Length, $entries.Count
"sha256 $zipSha"

# ── File table into manifest.json (VRR Updater's Verify / Repair, 0.4.11+) ────────────────────
# One sha256 + size per shipped file, keyed by the path relative to the kit root. Verify hashes the
# creator's copies against this; Repair pulls the differing entries back out of THIS zip, whose own
# sha256 is recorded alongside so a tampered download is refused. New-KitRelease.ps1 writes the
# manifest first (patch fields); this adds to it, so run the two in that order.
$table = [ordered]@{}
foreach ($f in ($files | Sort-Object FullName)) {
    $rel = $f.FullName.Substring($KitRoot.Length).TrimStart('\') -replace '\\', '/'
    $table[$rel] = [ordered]@{ sha256 = (Get-FileHash $f.FullName -Algorithm SHA256).Hash; size = $f.Length }
}
$manifestPath = Join-Path $outDir 'manifest.json'
$m = if (Test-Path $manifestPath) { Get-Content $manifestPath -Raw | ConvertFrom-Json } else { [pscustomobject]@{ pluginVersion = $Version } }
$m | Add-Member -NotePropertyName fullKitZip    -NotePropertyValue (Split-Path $zipPath -Leaf)   -Force
$m | Add-Member -NotePropertyName fullKitSha256 -NotePropertyValue $zipSha                        -Force
$m | Add-Member -NotePropertyName fullKitSize   -NotePropertyValue (Get-Item $zipPath).Length     -Force
$m | Add-Member -NotePropertyName files         -NotePropertyValue ([pscustomobject]$table)       -Force
# UTF-8 without a BOM, same rule as New-KitRelease.ps1 — Invoke-RestMethod chokes on a BOM.
[IO.File]::WriteAllText($manifestPath, ($m | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
"manifest.json: added fullKitZip/fullKitSha256/fullKitSize and a {0}-file table" -f $table.Count
"Attach the zip to the release next to the patch zip and this manifest.json."
