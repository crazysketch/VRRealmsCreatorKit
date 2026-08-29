<#
    VRR UPDATER — Creator Kit manager (window)
    ---------------------------------------------------------------------------
    Lists every published kit release, shows which one you have, and installs
    the one you pick — the usual "creator companion" job, scoped to the
    VR Realms kit.

    WHY WPF-FROM-POWERSHELL AND NOT A C# .EXE
      An unsigned .exe downloaded from GitHub trips SmartScreen ("Windows
      protected your PC"), which is a terrible first impression for a tool whose
      whole job is to be trusted with a creator's project folder. Code signing
      costs money and needs renewing. This gets a real window with zero build
      step, zero dependencies, and no scary dialog. If it ever outgrows that,
      the install logic below ports to C# unchanged.

    THE THREE RULES (identical to VRRUpdater-Console.ps1 — keep them in sync)
      1. Only ever writes inside VRRealms\Plugins\VRRealmsCreatorKit\. Every zip
         entry is checked against that prefix BEFORE extracting anything.
      2. NO credentials, ever. Public repo, anonymous reads. This ships to
         creators — a token or FTP password here would be handed to everyone.
      3. Refuses to install while Unreal is open (the plugin DLL is locked).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Repo           = 'crazysketch/VRRealmsCreatorKit'
$SafePrefix     = 'VRRealms/Plugins/VRRealmsCreatorKit/'

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
    foreach ($f in [IO.Directory]::GetFiles($src, '*', 'AllDirectories')) {
        [IO.File]::Copy($f, (Join-Path $dst $f.Substring($src.Length).TrimStart('\')), $true)
    }
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
$KitRoot        = Find-KitRoot $PSScriptRoot
# No kit anywhere. Fall back to the old assumption so the FRIENDLY 'kit not found'
# message (with its list of folders checked) still prints, instead of the script dying
# on a null inside Join-Path and leaving the user staring at a raw PowerShell error.
if (-not $KitRoot) { $KitRoot = Split-Path -Parent $PSScriptRoot }
$PluginDir      = if ($script:FoundPluginDir) { $script:FoundPluginDir } else { Join-Path $KitRoot 'VRRealms\Plugins\VRRealmsCreatorKit' }
$UPluginPath    = Join-Path $PluginDir 'VRRealmsCreatorKit.uplugin'
$ContentVerPath = Join-Path $KitRoot '.kit-content-version'
$Headers        = @{ 'User-Agent' = 'VRRUpdater' }

# ---------------------------------------------------------------------------
# Window
# ---------------------------------------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VRR Updater" Height="560" Width="760"
        WindowStartupLocation="CenterScreen" Background="#FF15181D">
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,12">
      <TextBlock Text="VRR UPDATER" FontSize="24" FontWeight="Bold" Foreground="#FF35D0E8"/>
      <TextBlock Text="VR Realms Creator Kit manager  |  build 2026-08-08.9" FontSize="12" Foreground="#FF8A96A6"/>
    </StackPanel>

    <Border Grid.Row="1" Background="#FF1E232B" CornerRadius="6" Padding="12" Margin="0,0,0,12">
      <StackPanel>
        <TextBlock x:Name="TxtInstalled" Foreground="#FFE6EAF0" FontSize="14"/>
        <TextBlock x:Name="TxtPath" Foreground="#FF6E7A8A" FontSize="11" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
    </Border>

    <ListView Grid.Row="2" x:Name="LstReleases" Background="#FF1E232B" Foreground="#FFE6EAF0"
              BorderBrush="#FF2C333D" FontSize="13">
      <!-- The selected row used to be unreadable: a PALE highlight under this list's light text.
           The fix is a dark highlight, NOT dark text - the row is only pale while it is selected,
           so darkening the text would break every OTHER row.
           ⚠ DO NOT "simplify" this back to overriding SystemColors.HighlightBrushKey. That is the
           advice you will find everywhere and it does NOTHING here: the Aero2 theme (Win8+) that
           WPF actually uses hard-codes the selection colours inside the ListBoxItem template
           (#3D26A0DA focused / #3DDADADA unfocused) instead of looking up those resource keys.
           Verified by rendering the control offscreen - the override changed nothing. Restyling
           the container is the only thing that reliably wins. -->
      <ListView.ItemContainerStyle>
        <Style TargetType="ListViewItem">
          <Setter Property="Foreground" Value="#FFE6EAF0"/>
          <Setter Property="Padding" Value="2,3"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="ListViewItem">
                <Border x:Name="Bd" Background="{TemplateBinding Background}"
                        Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
                  <GridViewRowPresenter Content="{TemplateBinding Content}"
                                        Columns="{TemplateBinding GridView.ColumnCollection}"/>
                </Border>
                <ControlTemplate.Triggers>
                  <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#FF262E38"/>
                  </Trigger>
                  <!-- Selected wins over hover, so it is declared last. -->
                  <Trigger Property="IsSelected" Value="True">
                    <Setter TargetName="Bd" Property="Background" Value="#FF17505C"/>
                    <Setter Property="Foreground" Value="#FFFFFFFF"/>
                  </Trigger>
                </ControlTemplate.Triggers>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Style>
      </ListView.ItemContainerStyle>
      <!-- The stock header is a light Windows-grey bar, so this list's light text was washed out
           there too. Make it part of the dark theme instead. -->
      <ListView.Resources>
        <Style TargetType="GridViewColumnHeader">
          <Setter Property="Background" Value="#FF262E38"/>
          <Setter Property="Foreground" Value="#FFB6C0CC"/>
          <Setter Property="BorderBrush" Value="#FF2C333D"/>
          <Setter Property="BorderThickness" Value="0,0,1,1"/>
          <Setter Property="Padding" Value="8,5"/>
          <Setter Property="HorizontalContentAlignment" Value="Left"/>
        </Style>
      </ListView.Resources>
      <ListView.View>
        <GridView>
          <GridViewColumn Header="Version"   Width="110" DisplayMemberBinding="{Binding Version}"/>
          <GridViewColumn Header="Published" Width="120" DisplayMemberBinding="{Binding Published}"/>
          <GridViewColumn Header="Status"    Width="120" DisplayMemberBinding="{Binding Status}"/>
          <GridViewColumn Header="What changed" Width="330" DisplayMemberBinding="{Binding Summary}"/>
        </GridView>
      </ListView.View>
    </ListView>

    <TextBlock Grid.Row="3" x:Name="TxtStatus" Margin="0,12,0,0" Foreground="#FF8A96A6"
               TextWrapping="Wrap" MinHeight="34"/>

    <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,12,0,0">
      <Button x:Name="BtnRefresh" Content="Refresh" Width="100" Height="32" Margin="0,0,8,0"/>
      <Button x:Name="BtnPage"    Content="Open releases page" Width="150" Height="32" Margin="0,0,8,0"/>
      <Button x:Name="BtnInstall" Content="Install selected" Width="150" Height="32" IsEnabled="False"/>
    </StackPanel>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win    = [Windows.Markup.XamlReader]::Load($reader)

$TxtInstalled = $win.FindName('TxtInstalled')
$TxtPath      = $win.FindName('TxtPath')
$LstReleases  = $win.FindName('LstReleases')
$TxtStatus    = $win.FindName('TxtStatus')
$BtnRefresh   = $win.FindName('BtnRefresh')
$BtnPage      = $win.FindName('BtnPage')
$BtnInstall   = $win.FindName('BtnInstall')

function Set-Status($text, $colour = '#FF8A96A6') {
    $TxtStatus.Text = $text
    $TxtStatus.Foreground = $colour
    # The download is small and synchronous; this keeps the window painted.
    $win.Dispatcher.Invoke([action]{}, 'Render')
}

function Get-LocalVersion {
    if (-not (Test-Path -LiteralPath $UPluginPath)) { return $null }
    try {
        $v = (Get-Content -LiteralPath $UPluginPath -Raw | ConvertFrom-Json).VersionName
        # Kits published before version tracking all claim "1.0", which parses as
        # NEWER than 0.4.6 and would mark everyone permanently up to date.
        if ($v -eq '1.0') { return '0.0.0' }
        return [string]$v
    } catch { return $null }
}

function Compare-Version($a, $b) {
    try { return ([version]$a).CompareTo([version]$b) }
    catch { if ($a -eq $b) { return 0 } else { return -1 } }
}

# ---------------------------------------------------------------------------
# Load the release list
# ---------------------------------------------------------------------------
$script:Releases = @()

function Refresh-Releases {
    $local = Get-LocalVersion
    if (-not $local) {
        $TxtInstalled.Text = "Kit not found (build 2026-08-08.9). Put VRRUpdater.cmd anywhere inside your Creator Kit."
        $TxtPath.Text = $UPluginPath
        # Show EVERY folder we looked in. "Not found" alone costs a support round trip;
        # the list is usually enough for the creator to spot the problem themselves.
        $rows = New-Object System.Collections.ArrayList
        foreach ($line in $script:KitSearchLog) {
            [void]$rows.Add([pscustomobject]@{ Version=''; Published=''; Status='searched'; Summary=$line })
        }
        $LstReleases.ItemsSource = $rows
        Set-Status "Cannot continue until the kit is found. The rows above list every folder checked - send this screenshot." '#FFE8615F'
        return
    }
    $TxtInstalled.Text = "Installed tools: $local"
    $TxtPath.Text      = $KitRoot

    Set-Status "Checking GitHub for releases..."
    try {
        $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers $Headers -TimeoutSec 30
    } catch {
        Set-Status "Could not reach GitHub: $($_.Exception.Message)" '#FFE8615F'
        return
    }

    $rows = New-Object System.Collections.ArrayList
    $script:Releases = @()

    foreach ($r in $all) {
        $ver = ([string]$r.tag_name) -replace '^[vV]', ''
        if ([string]::IsNullOrWhiteSpace($ver)) { continue }

        $asset = $r.assets | Where-Object { $_.name -like '*plugin*.zip' } | Select-Object -First 1
        $cmp    = Compare-Version $ver $local
        $status = 'Available'
        if ($cmp -eq 0)      { $status = 'INSTALLED' }
        elseif ($cmp -lt 0)  { $status = 'Older' }
        if (-not $asset)     { $status = 'Full download only' }

        $summary = ''
        if ($r.body) {
            $firstLine = (($r.body -split "`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
            if ($firstLine) { $summary = $firstLine.Trim() }
        }

        $script:Releases += [pscustomobject]@{ Version = $ver; Asset = $asset; Release = $r }
        [void]$rows.Add([pscustomobject]@{
            Version   = $ver
            Published = ([datetime]$r.published_at).ToString('yyyy-MM-dd')
            Status    = $status
            Summary   = $summary
        })
    }

    $LstReleases.ItemsSource = $rows
    if ($rows.Count -eq 0) {
        Set-Status "No releases published yet." '#FFD9A441'
    } else {
        $newest = $script:Releases[0].Version
        if ((Compare-Version $newest $local) -gt 0) {
            Set-Status "Update available: $local  ->  $newest. Select it and press Install." '#FF6FD07A'
        } else {
            Set-Status "You are up to date ($local)." '#FF6FD07A'
        }
    }
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
function Install-Release($entry) {
    if (-not $entry.Asset) {
        Set-Status "That release has no patchable tools package — use 'Open releases page' for the full kit." '#FFD9A441'
        return
    }

    if (Get-Process -Name 'UnrealEditor' -ErrorAction SilentlyContinue) {
        Set-Status "Close Unreal Editor first — the kit's plugin file is locked while it is open." '#FFE8615F'
        return
    }

    $local  = Get-LocalVersion
    $tmpDir = Join-Path $env:TEMP ("VRRUpdater_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zipPath = Join-Path $tmpDir $entry.Asset.name

    try {
        Set-Status "Downloading $($entry.Asset.name) ($([math]::Round($entry.Asset.size / 1MB, 2)) MB)..."
        Invoke-WebRequest -Uri $entry.Asset.browser_download_url -OutFile $zipPath `
                          -UseBasicParsing -Headers $Headers -TimeoutSec 300

        # ⚠ ZIP-SLIP GUARD — check every entry BEFORE extracting a single byte.
        #   An entry like "../../Content/..." would otherwise land in the
        #   creator's own project. This is the guard that makes the tool safe to
        #   point at a folder full of somebody's unbacked-up work.
        Set-Status "Verifying package contents..."
        $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            foreach ($e in $archive.Entries) {
                $name = $e.FullName -replace '\\', '/'
                if (-not (Test-AllowedEntry $name)) {
                    Set-Status "REFUSED: package tries to write outside the kit plugin folder ($name). Nothing changed." '#FFE8615F'
                    return
                }
            }
        } finally { $archive.Dispose() }
        # ⚠ UNIQUE BACKUP FOLDER, AND A .NET COPY.
        # Copy-Item -Recurse REFUSES when the destination already exists ("an item with the
        # specified name ... already exists"), which is exactly what happens on a second
        # attempt after any earlier failure - the install then blocks forever on the debris
        # of the run before it. A timestamped name cannot collide, so no delete is needed,
        # and the old backup stays around as extra safety rather than being destroyed.
        # .NET rather than Copy-Item because these paths may contain [square brackets].
        $backupDir = Join-Path $KitRoot ("_VRRUpdaterBackup_" + $local + "_" + (Get-Date -Format 'MMdd-HHmmss'))
        Copy-Tree $PluginDir $backupDir

        Set-Status "Installing..."
        Expand-Zip $zipPath $KitRoot

        $now = Get-LocalVersion
        Set-Status "Installed $now. Your previous tools are in _VRRUpdaterBackup_$local. Reopen your project to use them." '#FF6FD07A'
        Refresh-Releases
    }
    catch {
        Set-Status "Install failed: $($_.Exception.Message). Your existing tools were left alone." '#FFE8615F'
    }
    finally {
        if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------
$LstReleases.Add_SelectionChanged({ $BtnInstall.IsEnabled = ($LstReleases.SelectedIndex -ge 0) })
$BtnRefresh.Add_Click({ Refresh-Releases })
$BtnPage.Add_Click({ Start-Process "https://github.com/$Repo/releases" })
$BtnInstall.Add_Click({
    $i = $LstReleases.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:Releases.Count) { Install-Release $script:Releases[$i] }
})

Refresh-Releases
$win.ShowDialog() | Out-Null
