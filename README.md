# VR Realms Creator Kit — v0.1.0 (Alpha)

Build maps and avatars for **VR Realms** and publish them to the Steam Workshop.
You do **not** need Visual Studio, C++, or the VR Realms source — just Unreal
Engine 5.7 and a Steam account that has VR Realms in its library.

- Full step-by-step guides: **https://vr-realms.com** (Maps & Avatars)
- Latest version / downloads: **https://github.com/crazysketch/VRRealmsCreatorKit/releases**
- Help & feedback: Discord → `#workshop-support`

> This is an **alpha** kit — expect updates. Grab the newest release before starting a big project.

## 1. Install

1. Install **Unreal Engine 5.7** from the Epic Games Launcher (free).
2. Install **SteamCMD** (https://developer.valvesoftware.com/wiki/SteamCMD) and note
   where `steamcmd.exe` lives.
3. Unzip this kit anywhere (avoid very deep folder paths).

## 2. One-time Steam login (do this first, or uploads will hang)

You only do this once — it caches your Steam credentials so the WorkshopTool can
upload without prompting.

**Easiest:** in `Tools/VRRealmsWorkshopTool.exe`, go to the **Settings** tab and click
**🔑 Log in to Steam (one time)**. A console opens — enter your password and Steam
Guard code when asked, then close it.

**Or manually:** open a Command Prompt and run, replacing with your Steam login name:

    "C:\path\to\steamcmd.exe" +login YOUR_STEAM_NAME +quit

Enter your password and Steam Guard code when asked.

## 3. Make content

1. Open `VRRealms/VRRealms.uproject` in UE 5.7.
2. **Map:** make your own folder and build your level under
   `Content/VRRealms/Community/Maps/<YourMapName>/`. Drop a `PlayerStart` in the
   level so players have somewhere to spawn. Everything the map references must live
   inside that folder.
3. **Avatar:** import your FBX under
   `Content/VRRealms/Community/Avatars/<YourAvatarName>/Meshes/`. In the import
   dialog, set the **Skeleton** field to the bundled skeleton at this exact path —
   do **not** leave it empty:

       /Game/VRRealms/AvatarRig/SK_VRUE5Mannequin

   (Picking a different skeleton, or leaving it empty, makes your avatar load as the
   default body and not animate.)

Keep the `Community/Maps` and `Community/Avatars` folder names exactly as-is.

## 4. Build + upload

1. Launch `Tools/VRRealmsWorkshopTool.exe`.
   *(First run: Windows SmartScreen may say "Windows protected your PC" because the
   tool isn't code-signed yet. Click **More info → Run anyway**.)*
2. **Settings tab:** point it at your UE 5.7 folder, this kit's `VRRealms.uproject`,
   your `steamcmd.exe`, and your Steam login name. Click Save.
3. **Map or Avatar tab:** browse to your `.umap` (or avatar `.uasset`), give it a
   title/description/preview image, and click **Build**, then **Upload**.
4. Your item is uploaded **hidden**. Open its Steam Workshop page to add a
   description/tags and set it public (or wait for review — see the rules below).

## Rules / standards

- Engine: **UE 5.7** only.
- Avatars must use the bundled VR Realms mannequin skeleton (set on FBX import).
- **Do NOT enable Nanite on your meshes.** VR Realms uses the VR forward renderer,
  and Nanite only works with deferred rendering — Nanite-enabled meshes will be
  **invisible in game**. When importing, leave "Build Nanite" OFF; for existing
  assets, right-click the mesh → disable Nanite. Use normal LODs to control poly
  count instead.
- **Maps: bake your lighting** (Build → Lighting Quality → *Production*). VR Realms uses
  the VR forward renderer, so **Lumen does not run** — use Static/Stationary lights and a
  Lightmass Importance Volume. For sky, use SkyAtmosphere + a Directional Light with
  "Atmosphere Sun Light" (avoid HDRI sky-dome meshes — they often render black).
- Pak size limit: **700 MB**. Reduce texture sizes if you exceed it.
- New Workshop items are rate-limited by Steam (~10–15 per account per 24h).
