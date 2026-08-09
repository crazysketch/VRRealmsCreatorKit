<#
    VRR CREATOR — Creator Kit manager (window)
    ---------------------------------------------------------------------------
    Lists every published kit release, shows which one you have, and installs
    the one you pick. Same job as VRChat's Creator Companion, scoped to the
    VR Realms kit.

    WHY WPF-FROM-POWERSHELL AND NOT A C# .EXE
      An unsigned .exe downloaded from GitHub trips SmartScreen ("Windows
      protected your PC"), which is a terrible first impression for a tool whose
      whole job is to be trusted with a creator's project folder. Code signing
      costs money and needs renewing. This gets a real window with zero build
      step, zero dependencies, and no scary dialog. If it ever outgrows that,
      the install logic below ports to C# unchanged.

    THE THREE RULES (identical to VRRCreator-Update.ps1 — keep them in sync)
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
$KitRoot        = Split-Path -Parent $PSScriptRoot
$PluginDir      = Join-Path $KitRoot 'VRRealms\Plugins\VRRealmsCreatorKit'
$UPluginPath    = Join-Path $PluginDir 'VRRealmsCreatorKit.uplugin'
$ContentVerPath = Join-Path $KitRoot '.kit-content-version'
$Headers        = @{ 'User-Agent' = 'VRRCreator' }

# ---------------------------------------------------------------------------
# Window
# ---------------------------------------------------------------------------
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VRR Creator" Height="560" Width="760"
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
      <TextBlock Text="VRR CREATOR" FontSize="24" FontWeight="Bold" Foreground="#FF35D0E8"/>
      <TextBlock Text="VR Realms Creator Kit manager" FontSize="12" Foreground="#FF8A96A6"/>
    </StackPanel>

    <Border Grid.Row="1" Background="#FF1E232B" CornerRadius="6" Padding="12" Margin="0,0,0,12">
      <StackPanel>
        <TextBlock x:Name="TxtInstalled" Foreground="#FFE6EAF0" FontSize="14"/>
        <TextBlock x:Name="TxtPath" Foreground="#FF6E7A8A" FontSize="11" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
      </StackPanel>
    </Border>

    <ListView Grid.Row="2" x:Name="LstReleases" Background="#FF1E232B" Foreground="#FFE6EAF0"
              BorderBrush="#FF2C333D" FontSize="13">
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
    if (-not (Test-Path $UPluginPath)) { return $null }
    try {
        $v = (Get-Content $UPluginPath -Raw | ConvertFrom-Json).VersionName
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
        $TxtInstalled.Text = "Kit not found — keep VRR Creator in the folder that contains 'VRRealms'."
        $TxtPath.Text = $UPluginPath
        Set-Status "Cannot continue until the kit is found." '#FFE8615F'
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
    $tmpDir = Join-Path $env:TEMP ("VRRCreator_" + [guid]::NewGuid().ToString('N'))
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
                if ($name -notlike "$SafePrefix*") {
                    Set-Status "REFUSED: package tries to write outside the kit plugin folder ($name). Nothing changed." '#FFE8615F'
                    return
                }
            }
        } finally { $archive.Dispose() }

        $backupDir = Join-Path $KitRoot ("_VRRCreatorBackup_" + $local)
        if (Test-Path $backupDir) { Remove-Item $backupDir -Recurse -Force }
        Copy-Item $PluginDir $backupDir -Recurse -Force

        Set-Status "Installing..."
        Expand-Archive -Path $zipPath -DestinationPath $KitRoot -Force

        $now = Get-LocalVersion
        Set-Status "Installed $now. Your previous tools are in _VRRCreatorBackup_$local. Reopen your project to use them." '#FF6FD07A'
        Refresh-Releases
    }
    catch {
        Set-Status "Install failed: $($_.Exception.Message). Your existing tools were left alone." '#FFE8615F'
    }
    finally {
        if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
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
