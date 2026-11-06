<#
    VRRUploader.ps1 - uploads one Workshop item THROUGH THE STEAM APP, in a process of its own.

    One Steam submit carries everything: the files, title, description, preview, visibility AND the
    tags. SteamCMD (the old way) cannot send tags, and it signs your account in a second time, which
    knocks the Steam app offline, so the tags set afterwards often failed. This talks to the Steam
    app that is already running and signed in: nothing gets signed out.

    WHY A SEPARATE PROCESS: the same reason as VRRTagger.ps1. SteamAPI_Init() registers the calling
    process as *playing* the game; inside the editor, Steam's Stop button would kill the editor. Here
    Steam sees a PowerShell process for as long as the upload takes, and Stop can only end this.

    No compiler and no SDK install: it P/Invokes the flat C API of the steam_api64.dll that ships
    inside UE 5.8.

    INPUT: -Job <path to a UTF-8 JSON file> with
      itemId (string, "" or "0" = make a new item), contentFolder, previewFile (may be ""),
      title, description, changeNote, tags (array), visibility (0 = Public; optional, default 0)

    OUTPUT CONTRACT - the kit parses these, do not rename them:
      VRRUP_STEAMID=<id>          who the Steam app is signed in as
      VRRUP_ITEMID=<id>           the item's id (printed as soon as a NEW item exists, before its files go up)
      VRRUP_PROGRESS=<pct>        whole percent of the files sent, now and then
      VRRUP_RESULT=<n>            Steam EResult of the final submit. 1 = OK. 0 = never got that far
      VRRUP_EULA=<0|1>            1 = the account has not accepted the Workshop legal agreement
      VRRUP_ERROR=<text>          single-line reason, present only on failure
    Everything else printed here is for people and is echoed into the kit's log.
#>

param(
    [Parameter(Mandatory = $true)] [string] $Job,
    [uint32] $AppId = 2964550,
    [string] $EngineDir
)

$ErrorActionPreference = 'Stop'

function Fail($msg, $result = 0) {
    Write-Output "VRRUP_RESULT=$result"
    Write-Output "VRRUP_EULA=0"
    Write-Output ("VRRUP_ERROR=" + ($msg -replace '\r?\n', ' '))
    exit 1
}

if (-not (Test-Path -LiteralPath $Job)) { Fail "The upload job file is missing: $Job" }
$j = Get-Content -LiteralPath $Job -Raw -Encoding UTF8 | ConvertFrom-Json
[uint64]$itemId = 0
if ($j.itemId) { [void][uint64]::TryParse([string]$j.itemId, [ref]$itemId) }
$tags = @($j.tags | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -ne '' })
$visibility = 0
if ($null -ne $j.visibility) { $visibility = [int]$j.visibility }
if (-not (Test-Path -LiteralPath $j.contentFolder)) { Fail "The folder to upload is missing: $($j.contentFolder)" }

# ---- locate steam_api64.dll inside the engine (same search as VRRTagger.ps1) ------------------
if (-not $EngineDir) { $EngineDir = "C:\Program Files\Epic Games\UE_5.8\Engine" }
$dll = $null
foreach ($v in @('Steamv164','Steamv162','Steamv157','Steamv153')) {
    $c = Join-Path $EngineDir "Binaries\ThirdParty\Steamworks\$v\Win64\steam_api64.dll"
    if (Test-Path -LiteralPath $c) { $dll = $c; break }   # -LiteralPath: [ ] in a folder name are wildcards otherwise
}
if (-not $dll) { Fail "steam_api64.dll not found under $EngineDir" }

$work = Join-Path $env:TEMP ("vrrup-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    Copy-Item -LiteralPath $dll -Destination (Join-Path $work 'steam_api64.dll') -Force
    Set-Content -Path (Join-Path $work 'steam_appid.txt') -Value "$AppId" -Encoding ascii -NoNewline
    $env:SteamAppId  = "$AppId"
    $env:SteamGameId = "$AppId"
    [Environment]::CurrentDirectory = $work

    Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SteamUp
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetDllDirectory(string lpPathName);

    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int SteamAPI_InitFlat(StringBuilder pOutErrMsg);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void SteamAPI_Shutdown();
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern void SteamAPI_RunCallbacks();
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr SteamAPI_SteamUGC_v021();
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr SteamAPI_SteamUtils_v010();
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr SteamAPI_SteamUser_v023();
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUser_GetSteamID(IntPtr self);

    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUGC_CreateItem(IntPtr self, uint appId, int fileType);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUGC_StartItemUpdate(IntPtr self, uint appId, ulong fileId);
    // Strings go as UTF-8 bytes (IntPtr): a title in another language must arrive as written.
    // C++ bool is ONE byte: I1, or the marshaller reads three bytes of neighbouring stack.
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemTitle(IntPtr self, ulong h, IntPtr text);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemDescription(IntPtr self, ulong h, IntPtr text);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemVisibility(IntPtr self, ulong h, int visibility);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemTags(IntPtr self, ulong h, IntPtr pTags, [MarshalAs(UnmanagedType.I1)] bool allowAdmin);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemContent(IntPtr self, ulong h, IntPtr folder);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemPreview(IntPtr self, ulong h, IntPtr file);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUGC_SubmitItemUpdate(IntPtr self, ulong h, IntPtr note);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern int SteamAPI_ISteamUGC_GetItemUpdateProgress(IntPtr self, ulong h, ref ulong done, ref ulong total);

    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, [MarshalAs(UnmanagedType.I1)] ref bool failed);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, IntPtr cb, int cbSize, int expected, [MarshalAs(UnmanagedType.I1)] ref bool failed);
}
"@

    [void][SteamUp]::SetDllDirectory($work)

    function U8([string]$s) {
        $b = [Text.Encoding]::UTF8.GetBytes($s + [char]0)
        $p = [Runtime.InteropServices.Marshal]::AllocHGlobal($b.Length)
        [Runtime.InteropServices.Marshal]::Copy($b, 0, $p, $b.Length)
        return $p
    }

    # Waits for one Steam call; returns $true and fills $buf, or $false on a lost result.
    function WaitCall($utils, $call, $buf, $size, $callbackId, $seconds) {
        $failed = $false
        $deadline = (Get-Date).AddSeconds($seconds)
        while ((Get-Date) -lt $deadline) {
            [SteamUp]::SteamAPI_RunCallbacks()
            if ([SteamUp]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils, $call, [ref]$failed)) {
                return [SteamUp]::SteamAPI_ISteamUtils_GetAPICallResult($utils, $call, $buf, $size, $callbackId, [ref]$failed)
            }
            Start-Sleep -Milliseconds 150
        }
        return $null   # timed out
    }

    $err = New-Object System.Text.StringBuilder 1024
    if ([SteamUp]::SteamAPI_InitFlat($err) -ne 0) {
        Fail ("The Steam app is not running or not signed in (or signed in as an account that does not own VR Realms). Start Steam, sign in, wait until it is online, then press Upload again. Steam said: " + $err.ToString())
    }

    try {
        $user  = [SteamUp]::SteamAPI_SteamUser_v023()
        $ugc   = [SteamUp]::SteamAPI_SteamUGC_v021()
        $utils = [SteamUp]::SteamAPI_SteamUtils_v010()
        if ($ugc -eq [IntPtr]::Zero -or $utils -eq [IntPtr]::Zero) { Fail "Steam did not return the Workshop interface." }
        $me = [SteamUp]::SteamAPI_ISteamUser_GetSteamID($user)
        Write-Output "VRRUP_STEAMID=$me"
        if ($j.probe) { Write-Output "  The Steam app is signed in as $me and ready."; Write-Output "VRRUP_RESULT=1"; Write-Output "VRRUP_EULA=0"; exit 0 }
        Write-Output "  Uploading through the Steam app, signed in as $me"

        $buf = [Runtime.InteropServices.Marshal]::AllocHGlobal(32)

        # ---- a NEW item: make it first (CreateItemResult_t, callback 3403) ----------------------
        if ($itemId -eq 0) {
            Write-Output "  Making a new Workshop item..."
            $call = [SteamUp]::SteamAPI_ISteamUGC_CreateItem($ugc, $AppId, 0)   # 0 = k_EWorkshopFileTypeCommunity
            if ($call -eq 0) { Fail "Steam refused to make a new item." }
            $ok = WaitCall $utils $call $buf 24 3403 60
            if ($null -eq $ok) { Fail "Timed out waiting for Steam to make the new item." 16 }
            if (-not $ok) { Fail "Steam lost the answer while making the new item." }
            # CreateItemResult_t: EResult(4) + pad(4) | uint64 fileId(8) | bool needsEULA(1) + pad(7)
            $res  = [Runtime.InteropServices.Marshal]::ReadInt32($buf, 0)
            $id   = [uint64][Runtime.InteropServices.Marshal]::ReadInt64($buf, 8)
            $eula = [Runtime.InteropServices.Marshal]::ReadByte($buf, 16)
            if ($res -ne 1) {
                Write-Output "VRRUP_RESULT=$res"
                Write-Output "VRRUP_EULA=$eula"
                Write-Output "VRRUP_ERROR=Steam would not make a new item (EResult $res)."
                exit 1
            }
            $itemId = $id
            Write-Output "VRRUP_ITEMID=$itemId"
            Write-Output "  New item made: $itemId"
        } else {
            Write-Output "VRRUP_ITEMID=$itemId"
        }

        # ---- everything in one update -----------------------------------------------------------
        $h = [SteamUp]::SteamAPI_ISteamUGC_StartItemUpdate($ugc, $AppId, $itemId)
        if ($h -eq 0) { Fail "Steam refused to start an update for item $itemId." }

        if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemTitle($ugc, $h, (U8 ([string]$j.title)))) { Fail "Steam refused the title (too long?)." }
        if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemDescription($ugc, $h, (U8 ([string]$j.description)))) { Fail "Steam refused the description (too long?)." }
        if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemVisibility($ugc, $h, $visibility)) { Fail "Steam refused the visibility." }
        if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemContent($ugc, $h, (U8 ([string]$j.contentFolder)))) { Fail "Steam refused the folder to upload." }
        if ($j.previewFile -and (Test-Path -LiteralPath $j.previewFile)) {
            if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemPreview($ugc, $h, (U8 ([string]$j.previewFile)))) { Fail "Steam refused the preview image." }
        }
        if ($tags.Count -gt 0) {
            # SteamParamStringArray_t { const char **m_ppStrings; int32 m_nNumStrings; }: pointer at 0, count at 8.
            $ptrs = @(); foreach ($t in $tags) { $ptrs += (U8 $t) }
            $arr = [Runtime.InteropServices.Marshal]::AllocHGlobal([IntPtr]::Size * $ptrs.Count)
            for ($i = 0; $i -lt $ptrs.Count; $i++) { [Runtime.InteropServices.Marshal]::WriteIntPtr($arr, $i * [IntPtr]::Size, $ptrs[$i]) }
            $struct = [Runtime.InteropServices.Marshal]::AllocHGlobal(16)
            [Runtime.InteropServices.Marshal]::WriteIntPtr($struct, 0, $arr)
            [Runtime.InteropServices.Marshal]::WriteInt32($struct, 8, $ptrs.Count)
            [Runtime.InteropServices.Marshal]::WriteInt32($struct, 12, 0)
            if (-not [SteamUp]::SteamAPI_ISteamUGC_SetItemTags($ugc, $h, $struct, $false)) {
                Fail "Steam rejected the tag list. Usually one of the tags is not defined for VR Realms on Steamworks."
            }
            Write-Output ("  Tags: " + ($tags -join ', '))
        }

        $call = [SteamUp]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc, $h, (U8 ([string]$j.changeNote)))
        if ($call -eq 0) { Fail "Steam refused to send the update." }

        # ---- send, with progress; no fixed time limit, only a stall limit ------------------------
        $names = @{ 1 = 'getting ready'; 2 = 'preparing the files'; 3 = 'sending the files'; 4 = 'sending the preview'; 5 = 'finishing on Steam' }
        $failed = $false
        $lastPct = -1; $lastStatus = -1; $lastChange = Get-Date; $lastDone = [uint64]0
        while ($true) {
            [SteamUp]::SteamAPI_RunCallbacks()
            if ([SteamUp]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils, $call, [ref]$failed)) { break }
            [uint64]$done = 0; [uint64]$total = 0
            $status = [SteamUp]::SteamAPI_ISteamUGC_GetItemUpdateProgress($ugc, $h, [ref]$done, [ref]$total)
            if ($status -ne $lastStatus -or $done -ne $lastDone) { $lastChange = Get-Date }
            if ($status -ne $lastStatus -and $names.ContainsKey($status)) { Write-Output ("  Steam: " + $names[$status] + "...") ; $lastStatus = $status }
            if ($status -eq 3 -and $total -gt 0) {
                $pct = [int][Math]::Floor(100.0 * $done / $total)
                if ($pct -ge $lastPct + 10 -or ($pct -eq 100 -and $lastPct -ne 100)) {
                    Write-Output "VRRUP_PROGRESS=$pct"
                    Write-Output ("  Sent {0}% ({1:N0} of {2:N0} MB)" -f $pct, ($done / 1MB), ($total / 1MB))
                    $lastPct = $pct
                }
            }
            $lastDone = $done
            if (((Get-Date) - $lastChange).TotalMinutes -gt 10) { Fail "Steam stopped moving for 10 minutes. Check your internet and the Steam app, then press Upload again (it updates the same item)." 16 }
            Start-Sleep -Milliseconds 250
        }
        if (-not [SteamUp]::SteamAPI_ISteamUtils_GetAPICallResult($utils, $call, $buf, 16, 3404, [ref]$failed)) {
            Fail "Steam lost the result of the upload. Look at the item page; if it did not change, press Upload again."
        }
        # SubmitItemUpdateResult_t: EResult(4) | bool needsEULA(1) + pad(3) | uint64 fileId(8)
        $res  = [Runtime.InteropServices.Marshal]::ReadInt32($buf, 0)
        $eula = [Runtime.InteropServices.Marshal]::ReadByte($buf, 4)
        Write-Output "VRRUP_RESULT=$res"
        Write-Output "VRRUP_EULA=$eula"
        if ($res -ne 1) {
            Write-Output "VRRUP_ERROR=Steam did not accept the upload (EResult $res)."
            exit 1
        }
        Write-Output "  Steam accepted the upload."
        exit 0
    }
    finally {
        [SteamUp]::SteamAPI_Shutdown()   # hands the app context back at once; the process ending would too
    }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
