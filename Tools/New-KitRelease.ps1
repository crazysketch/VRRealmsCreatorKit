<#
    VRR UPDATER — build a release package  (MAINTAINER SIDE, not for creators)
    ---------------------------------------------------------------------------
    Produces the two files VRR Updater needs on a GitHub release:

      VRRealmsCreatorKit-plugin-<version>.zip   the ~1 MB tools payload
      manifest.json                             version + hash + content channel

    Run it, then upload both with `gh release create`. The command is printed at
    the end with the version already filled in.

    THE ZIP LAYOUT IS A CONTRACT. Every entry must begin with
    VRRealms/Plugins/VRRealmsCreatorKit/ because VRR Updater refuses to extract
    anything that does not (that guard is what keeps a bad package from writing
    into a creator's own project). Entries are added by hand below rather than
    with Compress-Archive precisely so those paths are exact and visible.
#>

[CmdletBinding()]
param(
    # Bump this ONLY when the sample Content changes. Creators cannot patch
    # 1.2 GB, so a bump tells VRR Updater to send them for a full re-download instead
    # of silently leaving them on mismatched assets.
    [int] $ContentVersion = 1
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$KitRoot   = Split-Path -Parent $PSScriptRoot
$PluginRel = 'VRRealms/Plugins/VRRealmsCreatorKit'
$PluginDir = Join-Path $KitRoot ($PluginRel -replace '/', '\')
$UPlugin   = Join-Path $PluginDir 'VRRealmsCreatorKit.uplugin'

$version = (Get-Content $UPlugin -Raw | ConvertFrom-Json).VersionName
if ($version -eq '1.0') {
    throw "VersionName is still the '1.0' placeholder. Set the real version in the .uplugin first — VRR Updater compares against it."
}

$outDir = Join-Path $KitRoot '_release'
if (Test-Path $outDir) { Remove-Item $outDir -Recurse -Force }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$zipPath = Join-Path $outDir "VRRealmsCreatorKit-plugin-$version.zip"

# Ship the tools, never build intermediates or debug symbols. A .pdb here would
# be ~75 MB and defeat the entire point of a 1 MB patch.
$files = Get-ChildItem $PluginDir -Recurse -File | Where-Object {
    $_.Extension -ne '.pdb' -and
    $_.FullName -notmatch '\\Intermediate\\' -and
    $_.FullName -notmatch '\\obj\\'
}

$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($PluginDir.Length).TrimStart('\') -replace '\\', '/'
        $entryName = "$PluginRel/$rel"
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entryName)
        Write-Host "  + $entryName"
    }
    # VRR Updater ITSELF travels in the package, so a creator who updates once
    # keeps getting updater fixes too. Without this, every improvement to the
    # tool would have to be hand-delivered to every creator - which is the exact
    # problem the tool exists to solve. The updater's allowlist accepts precisely
    # these two paths and nothing else at the kit root.
    foreach ($extra in @('VRRUpdater.cmd')) {
        $src = Join-Path $KitRoot $extra
        if (Test-Path $src) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $src, $extra)
            Write-Host "  + $extra"
        }
    }
    foreach ($ps in (Get-ChildItem (Join-Path $KitRoot 'Tools') -Filter *.ps1 -File)) {
        if ($ps.Name -eq 'New-KitRelease.ps1') { continue }   # maintainer-only, creators do not need it
        $entry = "Tools/$($ps.Name)"
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $ps.FullName, $entry)
        Write-Host "  + $entry"
    }
} finally { $zip.Dispose() }

$sha  = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash
$size = (Get-Item $zipPath).Length

$manifest = [ordered]@{
    pluginVersion  = $version
    contentVersion = "$ContentVersion"
    engine         = '5.8'
    pluginZip      = Split-Path $zipPath -Leaf
    pluginSha256   = $sha
    pluginSize     = $size
}
# UTF-8 WITHOUT a BOM: this is JSON read by Invoke-RestMethod, and a BOM breaks
# some parsers. (Note the opposite rule for .ps1 files, which need one.)
[IO.File]::WriteAllText((Join-Path $outDir 'manifest.json'),
    ($manifest | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))

Write-Host ""
Write-Host "  Built $([math]::Round($size/1KB,1)) KB  ->  $zipPath"
Write-Host "  sha256 $sha"
Write-Host ""
Write-Host "  Publish it:" -ForegroundColor Cyan
Write-Host "    gh release create v$version ""$zipPath"" ""$outDir\manifest.json"" --title ""Creator Kit $version"" --notes-file <notes.md>"
Write-Host ""
Write-Host "  VRR Updater shows the release notes to creators, so write them for creators." -ForegroundColor DarkGray
