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
         (Repair, added 2026-09-02, is the one deliberate exception: it may also
         restore files the RELEASE'S OWN FILE TABLE lists — Config, sample content,
         the tools — and nothing else. Never a creator's Community folder. See the
         Verify + Repair section.)
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
# LOOK: the window copies vr-realms.com's live dark theme (style-v3.css) - same greys, the same
# green, the site's outline buttons and tags, its nav-bar logo mark and its blurred page background -
# so the tool reads as part of VR Realms rather than a generic utility. Everything visual is in this
# one block plus the embedded artwork at the bottom; the logic in between never depends on colours.
# ⚠ It is a DOUBLE-QUOTED here-string: no "$" anywhere in the XAML, PowerShell would expand it.
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VRR Updater" Height="620" Width="840" MinHeight="500" MinWidth="720"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" Background="#FF101010"
        TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">

  <!-- Straight from vr-realms.com's dark theme (style-v3.css): bg #101010, surface #2d2d2d,
       surface2 #252525, line #383838, text #f4f4f4, muted #8a8a8a, ok #34d399, wip #eab308.
       Buttons are the site's .b-line (outline) and .b-fill (green). Tags are the site's outline
       tag (SUPPORTER-style). No glows, no gradients, no dots - the site does not use them. -->
  <Window.Resources>
    <SolidColorBrush x:Key="Surface"  Color="#FF2D2D2D"/>
    <SolidColorBrush x:Key="Surface2" Color="#FF252525"/>
    <SolidColorBrush x:Key="Line"     Color="#FF383838"/>
    <SolidColorBrush x:Key="Line2"    Color="#FF2A2A2A"/>
    <SolidColorBrush x:Key="Text"     Color="#FFF4F4F4"/>
    <SolidColorBrush x:Key="Text2"    Color="#FFC9C9C9"/>
    <SolidColorBrush x:Key="Muted"    Color="#FF8A8A8A"/>
    <SolidColorBrush x:Key="Ok"       Color="#FF34D399"/>

    <!-- .b-line -->
    <Style x:Key="BtnLine" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="{StaticResource Line}"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="Medium"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Padding" Value="15,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource Muted}"/>
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource Surface}"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Opacity" Value="0.85"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- .b-fill: the site's green Wishlist button -->
    <Style x:Key="BtnFill" TargetType="Button" BasedOn="{StaticResource BtnLine}">
      <Setter Property="Foreground" Value="#FF0A0F0C"/>
      <Setter Property="Background" Value="{StaticResource Ok}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Ok}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Opacity" Value="0.92"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter Property="Opacity" Value="0.82"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Background" Value="{StaticResource Surface}"/>
                <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource Line}"/>
                <Setter Property="Foreground" Value="{StaticResource Muted}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Scrollbar: thin, line-coloured thumb, no arrows. -->
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Border CornerRadius="4" Background="#FF3D3D3D" Margin="1,0"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <!-- .site-bg: the site's blurred screenshot behind every page, with its veil gradient -->
    <Image x:Name="ImgBg" Stretch="UniformToFill" Opacity="0.35" IsHitTestVisible="False"
           RenderOptions.BitmapScalingMode="HighQuality">
      <Image.Effect>
        <BlurEffect Radius="40"/>
      </Image.Effect>
    </Image>
    <Rectangle IsHitTestVisible="False">
      <Rectangle.Fill>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
          <GradientStop Color="#B8101010" Offset="0"/>
          <GradientStop Color="#E0101010" Offset="0.4"/>
          <GradientStop Color="#F0101010" Offset="1"/>
        </LinearGradientBrush>
      </Rectangle.Fill>
    </Rectangle>

    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <!-- .top: the site's nav bar - logo mark + name on the left, a .pill on the right -->
      <Border Grid.Row="0" Background="#C7101010" BorderBrush="{StaticResource Line2}" BorderThickness="0,0,0,1" Padding="20,10">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
            <Border x:Name="LogoBox" Width="30" Height="30" CornerRadius="6" Background="{StaticResource Surface2}" Margin="0,0,10,0"/>
            <TextBlock Text="VR Realms" FontSize="14.5" FontWeight="SemiBold" Foreground="{StaticResource Text}" VerticalAlignment="Center"/>
            <TextBlock Text="Creator Kit" FontSize="13" FontWeight="Medium" Foreground="{StaticResource Muted}" VerticalAlignment="Center" Margin="14,0,0,0"/>
          </StackPanel>
          <!-- ⚠ Pill radii are HALF THE HEIGHT, not the CSS-style 100px: WPF does not clamp an
               oversized CornerRadius and draws a lens shape instead of a pill. -->
          <Border Grid.Column="2" VerticalAlignment="Center" CornerRadius="13" Background="{StaticResource Surface}"
                  BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="11,4">
            <TextBlock Text="build 2026-09-02.2" FontSize="12" FontWeight="Medium" Foreground="{StaticResource Muted}"/>
          </Border>
        </Grid>
      </Border>

      <Grid Grid.Row="1" Margin="24,20,24,20">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- page title, like the site's page-hero -->
        <StackPanel Grid.Row="0" Margin="0,0,0,16">
          <TextBlock Text="VRR Updater" FontSize="26" FontWeight="SemiBold" Foreground="{StaticResource Text}"/>
          <TextBlock Text="Install a release, or verify the kit's own files and repair any that changed. Your maps and avatars are never touched." FontSize="13"
                     Foreground="{StaticResource Muted}" Margin="0,2,0,0"/>
        </StackPanel>

        <!-- installed card -->
        <Border Grid.Row="1" Background="{StaticResource Surface2}" BorderBrush="{StaticResource Line}" BorderThickness="1"
                CornerRadius="10" Padding="16,13" Margin="0,0,0,14">
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock x:Name="TxtInstalledLabel" Text="INSTALLED TOOLS" FontSize="11" FontWeight="SemiBold" Foreground="{StaticResource Muted}"/>
              <TextBlock x:Name="TxtInstalled" FontSize="24" FontWeight="SemiBold" Foreground="{StaticResource Text}" TextWrapping="Wrap" Margin="0,2,0,0"/>
              <TextBlock x:Name="TxtPath" FontSize="12" Foreground="{StaticResource Muted}" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
            </StackPanel>
            <Border x:Name="BdgState" Grid.Column="1" VerticalAlignment="Center" CornerRadius="12" BorderThickness="1"
                    Padding="10,4" Margin="16,0,0,0" Visibility="Collapsed">
              <TextBlock x:Name="TxtBadge" FontSize="11" FontWeight="SemiBold"/>
            </Border>
          </Grid>
        </Border>

        <!-- releases card -->
        <Border Grid.Row="2" Background="{StaticResource Surface2}" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="10" Padding="6,4">
          <ListView x:Name="LstReleases" Background="Transparent" BorderThickness="0" Foreground="{StaticResource Text}" FontSize="13"
                    ScrollViewer.HorizontalScrollBarVisibility="Disabled">
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
                <Setter Property="Foreground" Value="{StaticResource Text}"/>
                <Setter Property="Padding" Value="8,7"/>
                <Setter Property="Margin" Value="0,1"/>
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="ListViewItem">
                      <Border x:Name="Bd" Background="Transparent" BorderBrush="Transparent" BorderThickness="1" CornerRadius="6"
                              Padding="{TemplateBinding Padding}" SnapsToDevicePixels="True">
                        <GridViewRowPresenter Content="{TemplateBinding Content}"
                                              Columns="{TemplateBinding GridView.ColumnCollection}"/>
                      </Border>
                      <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="{StaticResource Line2}"/>
                        </Trigger>
                        <!-- Selected wins over hover, so it is declared last. Same shape as the site's
                             selected sidebar link: surface fill + 1px line border. -->
                        <Trigger Property="IsSelected" Value="True">
                          <Setter TargetName="Bd" Property="Background" Value="{StaticResource Surface}"/>
                          <Setter TargetName="Bd" Property="BorderBrush" Value="{StaticResource Line}"/>
                        </Trigger>
                      </ControlTemplate.Triggers>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ListView.ItemContainerStyle>
            <!-- Own header template: the stock one is a light Windows-grey bar with its own hover
                 painting, so styling its Background alone still flashed light on mouse-over. -->
            <ListView.Resources>
              <Style TargetType="GridViewColumnHeader">
                <Setter Property="Foreground" Value="{StaticResource Muted}"/>
                <Setter Property="FontSize" Value="11"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
                <Setter Property="Template">
                  <Setter.Value>
                    <ControlTemplate TargetType="GridViewColumnHeader">
                      <Border BorderBrush="{StaticResource Line2}" BorderThickness="0,0,0,1" Padding="10,7" Background="Transparent">
                        <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
                      </Border>
                    </ControlTemplate>
                  </Setter.Value>
                </Setter>
              </Style>
            </ListView.Resources>
            <ListView.View>
              <GridView>
                <GridViewColumn Header="VERSION" Width="100">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Version}" FontSize="13.5" FontWeight="SemiBold" Margin="2,0,0,0"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="PUBLISHED" Width="110">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Published}" Foreground="#FFC9C9C9"/>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="STATUS" Width="160">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <!-- The site's outline tag: 11px semibold uppercase, tinted fill, tinted 1px border.
                           Only states that mean something get a tag; OLDER is plain muted text. -->
                      <Border CornerRadius="10" Padding="9,2" BorderThickness="1" HorizontalAlignment="Left" VerticalAlignment="Center">
                        <Border.Style>
                          <Style TargetType="Border">
                            <Setter Property="Background" Value="Transparent"/>
                            <Setter Property="BorderBrush" Value="Transparent"/>
                            <Style.Triggers>
                              <DataTrigger Binding="{Binding Status}" Value="INSTALLED">
                                <Setter Property="Background" Value="#2434D399"/>
                                <Setter Property="BorderBrush" Value="#5934D399"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding Status}" Value="AVAILABLE">
                                <Setter Property="Background" Value="#FF2D2D2D"/>
                                <Setter Property="BorderBrush" Value="#FF383838"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding Status}" Value="FULL DOWNLOAD ONLY">
                                <Setter Property="Background" Value="#24EAB308"/>
                                <Setter Property="BorderBrush" Value="#59EAB308"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding Status}" Value="SEARCHED">
                                <Setter Property="Background" Value="#FF2D2D2D"/>
                                <Setter Property="BorderBrush" Value="#FF383838"/>
                              </DataTrigger>
                              <!-- Verify results -->
                              <DataTrigger Binding="{Binding Status}" Value="OK">
                                <Setter Property="Background" Value="#2434D399"/>
                                <Setter Property="BorderBrush" Value="#5934D399"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding Status}" Value="MODIFIED">
                                <Setter Property="Background" Value="#24EAB308"/>
                                <Setter Property="BorderBrush" Value="#59EAB308"/>
                              </DataTrigger>
                              <DataTrigger Binding="{Binding Status}" Value="MISSING">
                                <Setter Property="Background" Value="#24F87171"/>
                                <Setter Property="BorderBrush" Value="#59F87171"/>
                              </DataTrigger>
                            </Style.Triggers>
                          </Style>
                        </Border.Style>
                        <TextBlock Text="{Binding Status}" FontSize="11" FontWeight="SemiBold">
                          <TextBlock.Style>
                            <Style TargetType="TextBlock">
                              <Setter Property="Foreground" Value="#FF8A8A8A"/>
                              <Style.Triggers>
                                <DataTrigger Binding="{Binding Status}" Value="INSTALLED">
                                  <Setter Property="Foreground" Value="#FF34D399"/>
                                </DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="AVAILABLE">
                                  <Setter Property="Foreground" Value="#FFF4F4F4"/>
                                </DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="FULL DOWNLOAD ONLY">
                                  <Setter Property="Foreground" Value="#FFEAB308"/>
                                </DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="OK">
                                  <Setter Property="Foreground" Value="#FF34D399"/>
                                </DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="MODIFIED">
                                  <Setter Property="Foreground" Value="#FFEAB308"/>
                                </DataTrigger>
                                <DataTrigger Binding="{Binding Status}" Value="MISSING">
                                  <Setter Property="Foreground" Value="#FFF87171"/>
                                </DataTrigger>
                              </Style.Triggers>
                            </Style>
                          </TextBlock.Style>
                        </TextBlock>
                      </Border>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
                <GridViewColumn Header="WHAT CHANGED" Width="400">
                  <GridViewColumn.CellTemplate>
                    <DataTemplate>
                      <TextBlock Text="{Binding Summary}" ToolTip="{Binding Summary}" Foreground="#FFC9C9C9">
                        <TextBlock.Style>
                          <Style TargetType="TextBlock">
                            <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                            <Style.Triggers>
                              <!-- Kit-not-found rows are folder paths that a creator screenshots for
                                   support. An ellipsis there hides the one thing we need to see. -->
                              <DataTrigger Binding="{Binding Status}" Value="SEARCHED">
                                <Setter Property="TextTrimming" Value="None"/>
                                <Setter Property="TextWrapping" Value="Wrap"/>
                              </DataTrigger>
                            </Style.Triggers>
                          </Style>
                        </TextBlock.Style>
                      </TextBlock>
                    </DataTemplate>
                  </GridViewColumn.CellTemplate>
                </GridViewColumn>
              </GridView>
            </ListView.View>
          </ListView>
        </Border>

        <!-- footer: status line above, actions below (five buttons left no room beside the text) -->
        <Grid Grid.Row="3" Margin="0,12,0,0">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <TextBlock x:Name="TxtStatus" Grid.Row="0" FontSize="12.5" Foreground="{StaticResource Muted}" TextWrapping="Wrap"
                     MinHeight="18" Margin="0,0,0,10"/>
          <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnVerify"  Content="Verify files" Style="{StaticResource BtnLine}" Margin="0,0,8,0"/>
            <Button x:Name="BtnRefresh" Content="Refresh" Style="{StaticResource BtnLine}" Margin="0,0,8,0"/>
            <Button x:Name="BtnPage"    Content="Open releases page" Style="{StaticResource BtnLine}" Margin="0,0,8,0"/>
            <Button x:Name="BtnRepair"  Content="Repair" Style="{StaticResource BtnFill}" MinWidth="110" Margin="0,0,8,0" Visibility="Collapsed"/>
            <Button x:Name="BtnInstall" Content="Install selected" Style="{StaticResource BtnFill}" IsEnabled="False" MinWidth="150"/>
          </StackPanel>
        </Grid>
      </Grid>
    </Grid>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win    = [Windows.Markup.XamlReader]::Load($reader)

$TxtInstalled      = $win.FindName('TxtInstalled')
$TxtInstalledLabel = $win.FindName('TxtInstalledLabel')
$TxtPath           = $win.FindName('TxtPath')
$LstReleases       = $win.FindName('LstReleases')
$TxtStatus         = $win.FindName('TxtStatus')
$BdgState          = $win.FindName('BdgState')
$TxtBadge          = $win.FindName('TxtBadge')
$LogoBox           = $win.FindName('LogoBox')
$ImgBg             = $win.FindName('ImgBg')
$BtnRefresh        = $win.FindName('BtnRefresh')
$BtnPage           = $win.FindName('BtnPage')
$BtnInstall        = $win.FindName('BtnInstall')
$BtnVerify         = $win.FindName('BtnVerify')
$BtnRepair         = $win.FindName('BtnRepair')

function Set-Status($text, $colour = '#FF8A8A8A') {
    $TxtStatus.Text = $text
    $TxtStatus.Foreground = $colour
    # The download is small and synchronous; this keeps the window painted.
    $win.Dispatcher.Invoke([action]{}, 'Render')
}

# The outline tag on the installed card (same shape as the site's SUPPORTER tag). Empty text hides it.
function Set-Badge($text, $colour = '#FF8A8A8A', $background = '#FF2D2D2D', $border = '#FF383838') {
    if (-not $text) { $BdgState.Visibility = 'Collapsed'; return }
    $TxtBadge.Text        = $text
    $TxtBadge.Foreground  = $colour
    $BdgState.Background  = $background
    $BdgState.BorderBrush = $border
    $BdgState.Visibility  = 'Visible'
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
        $TxtInstalledLabel.Text = "KIT NOT FOUND"
        $TxtInstalled.FontSize  = 14
        $TxtInstalled.Text = "Put VRRUpdater.cmd anywhere inside your Creator Kit (build 2026-09-02.2)."
        $TxtPath.Text = $UPluginPath
        Set-Badge ''
        # Show EVERY folder we looked in. "Not found" alone costs a support round trip;
        # the list is usually enough for the creator to spot the problem themselves.
        $rows = New-Object System.Collections.ArrayList
        foreach ($line in $script:KitSearchLog) {
            [void]$rows.Add([pscustomobject]@{ Version=''; Published=''; Status='SEARCHED'; Summary=$line })
        }
        $LstReleases.ItemsSource = $rows
        Set-Status "Cannot continue until the kit is found. The rows above list every folder checked - send this screenshot." '#FFF87171'
        return
    }
    $TxtInstalledLabel.Text = "INSTALLED TOOLS"
    $TxtInstalled.FontSize  = 24
    $TxtInstalled.Text      = $local
    $TxtPath.Text           = $KitRoot
    Set-Badge ''

    Set-Status "Checking GitHub for releases..."
    try {
        $all = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers $Headers -TimeoutSec 30
    } catch {
        Set-Status "Could not reach GitHub: $($_.Exception.Message)" '#FFF87171'
        return
    }

    $rows = New-Object System.Collections.ArrayList
    $script:Releases = @()

    foreach ($r in $all) {
        $ver = ([string]$r.tag_name) -replace '^[vV]', ''
        if ([string]::IsNullOrWhiteSpace($ver)) { continue }

        $asset = $r.assets | Where-Object { $_.name -like '*plugin*.zip' } | Select-Object -First 1
        $cmp    = Compare-Version $ver $local
        # These exact strings are matched by the STATUS column's tag triggers in the XAML above.
        $status = 'AVAILABLE'
        if ($cmp -eq 0)      { $status = 'INSTALLED' }
        elseif ($cmp -lt 0)  { $status = 'OLDER' }
        if (-not $asset)     { $status = 'FULL DOWNLOAD ONLY' }

        $summary = ''
        if ($r.body) {
            $firstLine = (($r.body -split "`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
            # Release notes are Markdown. Strip the heading marks and bold so the row reads as a
            # sentence instead of "## **Grey faces**".
            if ($firstLine) { $summary = ($firstLine.Trim() -replace '^#+\s*', '' -replace '\*\*', '').Trim() }
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
    Set-ListMode 'releases'
    if ($rows.Count -eq 0) {
        Set-Status "No releases published yet." '#FFEAB308'
        Set-Badge 'NO RELEASES'
    } else {
        $newest = $script:Releases[0].Version
        if ((Compare-Version $newest $local) -gt 0) {
            Set-Status "Update available: $local  ->  $newest. Select it and press Install." '#FF34D399'
            Set-Badge "UPDATE $newest" '#FFEAB308' '#24EAB308' '#59EAB308'
        } else {
            Set-Status "You are up to date ($local)." '#FF34D399'
            Set-Badge 'UP TO DATE' '#FF34D399' '#2434D399' '#5934D399'
        }
    }
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
function Install-Release($entry) {
    if (-not $entry.Asset) {
        Set-Status "That release has no patchable tools package — use 'Open releases page' for the full kit." '#FFEAB308'
        return
    }

    if (Get-Process -Name 'UnrealEditor' -ErrorAction SilentlyContinue) {
        Set-Status "Close Unreal Editor first — the kit's plugin file is locked while it is open." '#FFF87171'
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
                    Set-Status "REFUSED: package tries to write outside the kit plugin folder ($name). Nothing changed." '#FFF87171'
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
        Set-Status "Installed $now. Your previous tools are in _VRRUpdaterBackup_$local. Reopen your project to use them." '#FF34D399'
        Refresh-Releases
    }
    catch {
        Set-Status "Install failed: $($_.Exception.Message). Your existing tools were left alone." '#FFF87171'
    }
    finally {
        if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# Verify + Repair (added 2026-09-02, needs a release with a file table: 0.4.11+)
# ---------------------------------------------------------------------------
# WHY: a creator can overwrite or delete any shipped kit file and nothing tells them. The case that
# actually happened: a project whose Config/DefaultEngine.ini was not the kit's cooked without
# instanced stereo, and every VR player saw that content black in the right eye. Steam has "verify
# integrity of game files"; this is the same idea for the kit.
#
# The source of truth is the FILE TABLE in the release's manifest.json — `files`: path -> sha256 +
# size for every file in the full kit zip, written by Tools\New-FullKitZip.ps1. Verify hashes the
# local copies against it and lists OK / MODIFIED / MISSING. Repair downloads the full kit zip named
# in that same manifest, checks the zip's own sha256, and re-extracts ONLY the differing entries:
#   - nothing that is not in the table is ever written (a creator's own content is never touched),
#   - nothing is ever deleted (extra files are theirs),
#   - every replaced file is backed up first, same folder pattern as Install.
# Verify is pinned to the manifest of the release you have INSTALLED, so it compares against what
# this kit shipped as, not against whatever is newest.
$script:ListMode       = 'releases'   # 'releases' | 'verify' — what the list is showing
$script:VerifyBad      = @()          # rel paths needing repair, from the last Verify
$script:VerifyManifest = $null

function Set-ListMode($mode) {
    $script:ListMode = $mode
    $cols = $LstReleases.View.Columns
    if ($cols.Count -ge 4) { $cols[3].Header = $(if ($mode -eq 'verify') { 'FILE' } else { 'WHAT CHANGED' }) }
    $BtnRepair.Visibility = $(if ($mode -eq 'verify' -and $script:VerifyBad.Count -gt 0) { 'Visible' } else { 'Collapsed' })
    $BtnInstall.IsEnabled = ($mode -eq 'releases' -and $LstReleases.SelectedIndex -ge 0)
}

function Get-InstalledManifest {
    $local = Get-LocalVersion
    if (-not $local) { return $null }
    $entry = $script:Releases | Where-Object { $_.Version -eq $local } | Select-Object -First 1
    if (-not $entry) {
        Set-Status "Verify compares against the release you have installed ($local), and that release is no longer on GitHub. Install the latest first, then Verify." '#FFEAB308'
        return $null
    }
    $asset = $entry.Release.assets | Where-Object { $_.name -eq 'manifest.json' } | Select-Object -First 1
    if (-not $asset) {
        Set-Status "Release $local has no manifest.json - nothing to verify against." '#FFEAB308'
        return $null
    }
    $tmp = Join-Path $env:TEMP ("VRRUpdater_manifest_" + [guid]::NewGuid().ToString('N') + ".json")
    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -Headers $Headers -TimeoutSec 30
        $m = Get-Content -LiteralPath $tmp -Raw | ConvertFrom-Json
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    if (-not $m.files) {
        Set-Status "Release $local was published before the kit carried a file table. Install the latest, then Verify." '#FFEAB308'
        return $null
    }
    return $m
}

# Pure: file table + kit root -> one row per shipped file. No UI in here so it can be tested alone.
function Compare-KitFiles($manifest, $root) {
    $rows = New-Object System.Collections.ArrayList
    foreach ($p in $manifest.files.PSObject.Properties) {
        $rel  = [string]$p.Name
        $path = Join-Path $root ($rel -replace '/', '\')
        $status = 'OK'
        if (-not (Test-Path -LiteralPath $path)) {
            $status = 'MISSING'
        } elseif ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $p.Value.sha256) {
            $status = 'MODIFIED'
        }
        [void]$rows.Add([pscustomobject]@{ Rel = $rel; Status = $status })
    }
    return ,$rows
}

function Invoke-Verify {
    if (-not $script:Releases -or $script:Releases.Count -eq 0) { Refresh-Releases }
    $local = Get-LocalVersion
    if (-not $local) { return }
    Set-Status "Checking the installed files against release $local..."
    $m = Get-InstalledManifest
    if (-not $m) { return }

    $result = Compare-KitFiles $m $KitRoot
    $bad    = @($result | Where-Object { $_.Status -ne 'OK' })
    $script:VerifyBad      = @($bad | ForEach-Object { $_.Rel })
    $script:VerifyManifest = $m

    # Problems first, then the OK rows, so nothing needs scrolling to be seen.
    $rows = New-Object System.Collections.ArrayList
    foreach ($r in ($bad + @($result | Where-Object { $_.Status -eq 'OK' }))) {
        [void]$rows.Add([pscustomobject]@{ Version=''; Published=''; Status=$r.Status; Summary=$r.Rel })
    }
    $LstReleases.ItemsSource = $rows
    Set-ListMode 'verify'

    if ($bad.Count -eq 0) {
        Set-Status "All $($result.Count) shipped files match release $local." '#FF34D399'
    } else {
        $mod = @($bad | Where-Object { $_.Status -eq 'MODIFIED' }).Count
        $mis = @($bad | Where-Object { $_.Status -eq 'MISSING' }).Count
        Set-Status "$($bad.Count) of $($result.Count) shipped files differ ($mod modified, $mis missing). Press Repair to restore them from release $local - your copies are backed up first." '#FFEAB308'
    }
}

function Invoke-Repair {
    $m = $script:VerifyManifest
    if (-not $m -or $script:VerifyBad.Count -eq 0) { return }

    if (Get-Process -Name 'UnrealEditor' -ErrorAction SilentlyContinue) {
        Set-Status "Close Unreal Editor first - the kit's files are locked while it is open." '#FFF87171'
        return
    }
    $local = Get-LocalVersion
    $entry = $script:Releases | Where-Object { $_.Version -eq $local } | Select-Object -First 1
    $asset = $null
    if ($entry -and $m.fullKitZip) { $asset = $entry.Release.assets | Where-Object { $_.name -eq $m.fullKitZip } | Select-Object -First 1 }
    if (-not $asset) {
        Set-Status "Release $local does not carry '$($m.fullKitZip)' to repair from." '#FFF87171'
        return
    }

    $tmpDir  = Join-Path $env:TEMP ("VRRUpdater_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zipPath = Join-Path $tmpDir $asset.name
    try {
        Set-Status "Downloading $($asset.name) ($([math]::Round($asset.size / 1MB, 2)) MB) to repair $($script:VerifyBad.Count) file(s)..."
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing -Headers $Headers -TimeoutSec 300

        # The manifest names the zip's own hash. A download that does not match it is not used, full stop.
        $sha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
        if ($sha -ne $m.fullKitSha256) {
            Set-Status "REFUSED: the downloaded kit does not match the release's checksum. Nothing changed." '#FFF87171'
            return
        }

        $backupDir = Join-Path $KitRoot ("_VRRUpdaterBackup_" + $local + "_repair_" + (Get-Date -Format 'MMdd-HHmmss'))
        $restored  = 0
        $skipped   = New-Object System.Collections.ArrayList
        $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            foreach ($rel in $script:VerifyBad) {
                # ⚠ THE GUARDS. Only a path the release's own table lists, and never a creator's
                # Community folder (the two _PUT_YOUR_ markers are the only shipped files there).
                if (-not $m.files.PSObject.Properties[$rel]) { [void]$skipped.Add($rel); continue }
                if ($rel -like 'VRRealms/Content/VRRealms/Community/*' -and $rel -notlike '*/_PUT_YOUR_*') { [void]$skipped.Add($rel); continue }
                $e = $zip.GetEntry("VRRealmsCreatorKit/$rel")
                if (-not $e) { [void]$skipped.Add($rel); continue }

                $target = Join-Path $KitRoot ($rel -replace '/', '\')
                if (Test-Path -LiteralPath $target) {
                    $bak = Join-Path $backupDir ($rel -replace '/', '\')
                    [void][IO.Directory]::CreateDirectory((Split-Path $bak -Parent))
                    [IO.File]::Copy($target, $bak, $true)
                }
                [void][IO.Directory]::CreateDirectory((Split-Path $target -Parent))
                [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
                $restored++
            }
        } finally { $zip.Dispose() }

        $msg = "Restored $restored file(s) from release $local."
        if (Test-Path -LiteralPath $backupDir) { $msg += " Your previous copies are in $(Split-Path $backupDir -Leaf)." }
        if ($skipped.Count -gt 0) { $msg += " Skipped $($skipped.Count) not in the release." }
        $msg += " Reopen your project to use them."
        Set-Status $msg '#FF34D399'
        Invoke-Verify
    }
    catch {
        Set-Status "Repair failed: $($_.Exception.Message). Nothing else was changed." '#FFF87171'
    }
    finally {
        if (Test-Path -LiteralPath $tmpDir) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# Wiring
# ---------------------------------------------------------------------------
# Install only makes sense while the list shows releases; in verify mode the rows are files.
$LstReleases.Add_SelectionChanged({ $BtnInstall.IsEnabled = ($script:ListMode -eq 'releases' -and $LstReleases.SelectedIndex -ge 0) })
$BtnRefresh.Add_Click({ Refresh-Releases })
$BtnPage.Add_Click({ Start-Process "https://github.com/$Repo/releases" })
$BtnVerify.Add_Click({ Invoke-Verify })
$BtnRepair.Add_Click({ Invoke-Repair })
$BtnInstall.Add_Click({
    $i = $LstReleases.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:Releases.Count) { Install-Release $script:Releases[$i] }
})

# "What changed" takes whatever width is left, so the notes are not cut off at a fixed 330px
# when the window is wider than the default.
$LstReleases.Add_SizeChanged({
    $cols = $LstReleases.View.Columns
    if ($cols.Count -lt 4) { return }
    $fixed = $cols[0].ActualWidth + $cols[1].ActualWidth + $cols[2].ActualWidth
    $cols[3].Width = [Math]::Max(200, $LstReleases.ActualWidth - $fixed - 28)
})

# Dark title bar (and on Windows 11, a caption painted in the app's own colour) plus our own
# window icon. Both are cosmetic and both are wrapped: on an older Windows 10 the DWM attribute
# does not exist, and if the tiny C# shim fails to compile the window still opens with the stock
# chrome. Nothing here can stop the tool from working.
try {
    Add-Type -Namespace VRR -Name Dwm -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
'@
} catch {}
$win.Add_SourceInitialized({
    try {
        $h  = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
        $on = 1
        # 20 = DWMWA_USE_IMMERSIVE_DARK_MODE; builds before Windows 10 20H1 used 19 for the same thing.
        if ([VRR.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$on, 4) -ne 0) {
            [VRR.Dwm]::DwmSetWindowAttribute($h, 19, [ref]$on, 4) | Out-Null
        }
        # Windows 11 only: caption + border in the site's colours. COLORREF is 0x00BBGGRR (grey, so
        # the byte order does not matter here): caption #101010, border #383838.
        $caption = 0x00101010
        $border  = 0x00383838
        [VRR.Dwm]::DwmSetWindowAttribute($h, 35, [ref]$caption, 4) | Out-Null
        [VRR.Dwm]::DwmSetWindowAttribute($h, 34, [ref]$border,  4) | Out-Null
    } catch {}
})

# ---------------------------------------------------------------------------
# Artwork, embedded so the tool stays a single script with no assets to lose.
#   LogoJpegB64 - the ring-R mark cropped from the site's nav logo (logo-v2.png), 96px JPEG.
#                 Shown rounded-square in the top bar exactly like the site's .mark img, and used
#                 as the window / taskbar icon.
#   BgJpegB64   - the site's blurred page background (screenshots/cta-bg.jpg) at 120px. It is
#                 blurred 40px on screen anyway, so a thumbnail is all the detail that survives.
# Both are cosmetic: if decoding fails the top bar shows a plain square and the background stays
# flat, and the tool works exactly the same.
# ---------------------------------------------------------------------------
$LogoJpegB64 = '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'
$BgJpegB64   = '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'

function ConvertFrom-Base64Image($b64) {
    $bi = New-Object Windows.Media.Imaging.BitmapImage
    $bi.BeginInit()
    $bi.StreamSource = New-Object IO.MemoryStream (,[Convert]::FromBase64String($b64))
    $bi.CacheOption  = 'OnLoad'
    $bi.EndInit()
    $bi.Freeze()
    return $bi
}
try {
    $logo = ConvertFrom-Base64Image $LogoJpegB64
    $brush = New-Object Windows.Media.ImageBrush $logo
    $brush.Stretch = 'UniformToFill'
    $LogoBox.Background = $brush
    $win.Icon = $logo
} catch {}
try { $ImgBg.Source = ConvertFrom-Base64Image $BgJpegB64 } catch {}

Refresh-Releases
$win.ShowDialog() | Out-Null
