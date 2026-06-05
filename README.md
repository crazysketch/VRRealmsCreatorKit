# VR Realms Creator Kit

Build maps and avatars for **VR Realms** and publish them to the Steam Workshop.
You do **not** need Visual Studio, C++, or the VR Realms source — just Unreal
Engine 5.7 and a Steam account that has VR Realms in its library.

## 1. Install

1. Install **Unreal Engine 5.7** from the Epic Games Launcher (free).
2. Install **SteamCMD** (https://developer.valvesoftware.com/wiki/SteamCMD) and note
   where `steamcmd.exe` lives.
3. Unzip this kit anywhere (avoid very deep folder paths).

## 2. One-time Steam login (do this first, or uploads will hang)

Open a Command Prompt and run, replacing with your Steam login name:

    "C:\path\to\steamcmd.exe" +login YOUR_STEAM_NAME +quit

Enter your password and Steam Guard code when asked. This caches your credentials
so the Workshop Tool can upload without prompting. You only do this once.

## 3. Make content

1. Open `VRRealms/VRRealms.uproject` in UE 5.7.
2. **Map:** build your level under
   `Content/VRRealms/Community/Maps/<YourMapName>/Maps/<YourMapName>.umap`.
   Duplicate the template map to start.
3. **Avatar:** import your FBX under
   `Content/VRRealms/Community/Avatars/<YourAvatarName>/Meshes/`. In the import
   dialog, set **Skeleton** to the bundled VR Realms mannequin skeleton — do not
   leave it empty.

Keep the `Community/Maps` and `Community/Avatars` folder names exactly as-is.

## 4. Build + upload

1. Launch `Tools/VRRealmsWorkshopTool.exe`.
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
- Pak size limit: **700 MB**. Reduce texture sizes if you exceed it.
- New Workshop items are rate-limited by Steam (~10–15 per account per 24h).
