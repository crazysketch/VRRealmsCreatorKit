<#
    VRRTagger.ps1 - sets Workshop tags on one item, in a SHORT-LIVED PROCESS OF ITS OWN.

    WHY A SEPARATE PROCESS, AND NOT C++ INSIDE THE EDITOR

    SteamAPI_Init() registers the calling process as *playing* the app. Done inside the Unreal
    editor that means:
      - Steam shows the creator as "Playing VR Realms" for as long as the editor is open
      - playtime accrues against the editor
      - Steam can refuse to launch the real game, believing it is already running
      - and worst: pressing Stop in Steam KILLS THE EDITOR, losing unsaved work

    All four were observed on 2026-08-27. Running it out here instead means Steam sees a
    PowerShell process for about two seconds, and Stop can only ever kill this script.

    It also sidesteps Valve's "re-initialising the API after shutdown is unsupported" problem,
    because this process only ever does it once and then exits.

    No compiler and no SDK install: it P/Invokes the flat C API out of the steam_api64.dll that
    already ships inside UE 5.8.

    OUTPUT CONTRACT - the kit parses these, do not rename them:
      VRRTAG_STEAMID=<id>     who Steam was signed in as
      VRRTAG_RESULT=<n>       Steam EResult. 1 = OK. 0 = never got far enough to have one
      VRRTAG_EULA=<0|1>       1 = account has not accepted the Workshop legal agreement
      VRRTAG_ERROR=<text>     single-line reason, present only on failure
    Everything else printed here is for humans and is echoed into the kit's log.
#>

param(
    [Parameter(Mandatory = $true)] [uint64]   $ItemId,
    [Parameter(Mandatory = $true)] [string[]] $Tags,
    [uint32] $AppId = 2964550,
    [string] $EngineDir
)

$ErrorActionPreference = 'Stop'

# Through `powershell -File`, "-Tags a,b,c" arrives as ONE string - the comma is not the array
# operator once a command line has been handed over. Without this split Steam is sent a single
# tag literally named "a,b,c" and rejects the lot. Verified, not precautionary.
$Tags = @($Tags | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })

function Fail($msg, $result = 0) {
    Write-Output "VRRTAG_RESULT=$result"
    Write-Output "VRRTAG_EULA=0"
    Write-Output "VRRTAG_ERROR=$msg"
    exit 1
}

# ---- locate steam_api64.dll inside the engine -------------------------------------------------
if (-not $EngineDir) { $EngineDir = "C:\Program Files\Epic Games\UE_5.8\Engine" }
$dll = $null
foreach ($v in @('Steamv164','Steamv162','Steamv157','Steamv153')) {
    $c = Join-Path $EngineDir "Binaries\ThirdParty\Steamworks\$v\Win64\steam_api64.dll"
    # -LiteralPath, ALWAYS. PowerShell treats [ and ] as wildcard character classes, so a creator
    # whose engine sits in a folder like "D:\[VRRealms Projects]\UE_5.8" gets Test-Path = $false for
    # a file that is definitely there, and the only symptom is "steam_api64.dll not found under
    # <the exact path it is sitting in>". Reported by a creator 2026-08-28.
    if (Test-Path -LiteralPath $c) { $dll = $c; break }
}
if (-not $dll) { Fail "steam_api64.dll not found under $EngineDir" }

# steam_appid.txt goes in a temp dir, never beside the engine binary where it would linger and
# be picked up by unrelated projects. SteamAppId is set too - they fail in different places.
$work = Join-Path $env:TEMP ("vrrtag-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    # Same reason as above: $dll carries the engine path, brackets and all.
    Copy-Item -LiteralPath $dll -Destination (Join-Path $work 'steam_api64.dll') -Force
    Set-Content -Path (Join-Path $work 'steam_appid.txt') -Value "$AppId" -Encoding ascii -NoNewline
    $env:SteamAppId  = "$AppId"
    $env:SteamGameId = "$AppId"
    [Environment]::CurrentDirectory = $work

    Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class SteamFlat
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
    public static extern ulong SteamAPI_ISteamUGC_StartItemUpdate(IntPtr self, uint appId, ulong fileId);

    // C++ bool is ONE byte. Without I1 the marshaller assumes a 4-byte Win32 BOOL and reads
    // three bytes of neighbouring stack as part of the answer.
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUGC_SetItemTags(IntPtr self, ulong h, IntPtr pTags, [MarshalAs(UnmanagedType.I1)] bool allowAdmin);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong SteamAPI_ISteamUGC_SubmitItemUpdate(IntPtr self, ulong h, [MarshalAs(UnmanagedType.LPStr)] string note);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, [MarshalAs(UnmanagedType.I1)] ref bool failed);
    [DllImport("steam_api64.dll", CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, IntPtr cb, int cbSize, int expected, [MarshalAs(UnmanagedType.I1)] ref bool failed);
}
"@

    [void][SteamFlat]::SetDllDirectory($work)

    $err = New-Object System.Text.StringBuilder 1024
    if ([SteamFlat]::SteamAPI_InitFlat($err) -ne 0) {
        Fail ("Steam is not running, or is signed into an account that does not own the game. " + ($err.ToString() -replace '\r?\n',' '))
    }

    try {
        $user  = [SteamFlat]::SteamAPI_SteamUser_v023()
        $ugc   = [SteamFlat]::SteamAPI_SteamUGC_v021()
        $utils = [SteamFlat]::SteamAPI_SteamUtils_v010()
        if ($ugc -eq [IntPtr]::Zero -or $utils -eq [IntPtr]::Zero) { Fail "Steam did not return the UGC interface." }

        $me = [SteamFlat]::SteamAPI_ISteamUser_GetSteamID($user)
        Write-Output "VRRTAG_STEAMID=$me"
        Write-Output "  Signed in to Steam as $me"

        # SteamParamStringArray_t { const char **m_ppStrings; int32 m_nNumStrings; } - 8-byte
        # packed on x64: pointer at 0, count at 8, 4 bytes of tail padding.
        $ptrs = @()
        foreach ($t in $Tags) { $ptrs += [Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($t) }
        $arr = [Runtime.InteropServices.Marshal]::AllocHGlobal([IntPtr]::Size * [Math]::Max($ptrs.Count,1))
        for ($i = 0; $i -lt $ptrs.Count; $i++) {
            [Runtime.InteropServices.Marshal]::WriteIntPtr($arr, $i * [IntPtr]::Size, $ptrs[$i])
        }
        $struct = [Runtime.InteropServices.Marshal]::AllocHGlobal(16)
        [Runtime.InteropServices.Marshal]::WriteIntPtr($struct, 0, $arr)
        [Runtime.InteropServices.Marshal]::WriteInt32($struct, 8, $ptrs.Count)
        [Runtime.InteropServices.Marshal]::WriteInt32($struct, 12, 0)

        $h = [SteamFlat]::SteamAPI_ISteamUGC_StartItemUpdate($ugc, $AppId, $ItemId)
        if ($h -eq 0) { Fail "Steam refused to start an update for item $ItemId." }

        if (-not [SteamFlat]::SteamAPI_ISteamUGC_SetItemTags($ugc, $h, $struct, $false)) {
            Fail "Steam rejected the tag list. Usually one of the tags is not defined for this app on Steamworks."
        }

        $call = [SteamFlat]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc, $h, "tags")
        if ($call -eq 0) { Fail "Steam refused to submit the tag update." }

        $buf = [Runtime.InteropServices.Marshal]::AllocHGlobal(16)
        $failed = $false
        $deadline = (Get-Date).AddSeconds(45)
        while ((Get-Date) -lt $deadline) {
            [SteamFlat]::SteamAPI_RunCallbacks()
            if ([SteamFlat]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils, $call, [ref]$failed)) {
                if (-not [SteamFlat]::SteamAPI_ISteamUtils_GetAPICallResult($utils, $call, $buf, 16, 3404, [ref]$failed)) {
                    Fail "Steam lost the result of the tag update. Nothing was changed."
                }
                # SubmitItemUpdateResult_t: EResult(4) | bool needsEULA(1) + pad(3) | uint64 fileId(8)
                $res  = [Runtime.InteropServices.Marshal]::ReadInt32($buf, 0)
                $eula = [Runtime.InteropServices.Marshal]::ReadByte($buf, 4)
                Write-Output "VRRTAG_RESULT=$res"
                Write-Output "VRRTAG_EULA=$eula"
                if ($res -eq 1) { Write-Output ("  Tags set: " + ($Tags -join ', ')) }
                exit 0
            }
            Start-Sleep -Milliseconds 150
        }
        Fail "Timed out waiting for Steam to confirm the tag update." 16
    }
    finally {
        # ALWAYS. This is what hands the app context back and stops Steam showing the creator
        # as in-game. The process exiting would do it anyway, which is the whole point of
        # being a separate process, but do not rely on that.
        [SteamFlat]::SteamAPI_Shutdown()
    }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
