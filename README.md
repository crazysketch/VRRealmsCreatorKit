# VR Realms Creator Kit — v0.3.4 (Alpha, UE 5.8)

Build maps and avatars for **VR Realms** and publish them to the Steam Workshop.
You do **not** need Visual Studio, C++, or the VR Realms source — just Unreal
Engine 5.8 and a Steam account that has VR Realms in its library.

**New in v0.3.4:** your builds are now **compressed** (Oodle Kraken, distribution
grade) — the same map typically packs **25–40% smaller**, so players download your
world faster and you're far less likely to hit the 700 MB size cap. Nothing to
configure: just Build as usual (the log shows a `Compression:` line). Existing
uploads keep working; rebuild + update your item to get the smaller size. If
you're near the cap even after this, the real lever is texture size — select your
textures → right-click → Asset Actions → Bulk Edit → set **Maximum Texture Size**
to 1024 (4K textures can't be resolved in VR anyway).

**New in v0.3.3:** drop a shared **TV screen** or **jukebox / radio** into any map with a
single tag — `VRItem.TV` (video) or `VRItem.Jukebox` (audio). Players set what it plays from
a **URL** live in VR (a live HLS `.m3u8`, a hosted `.mp4`, internet radio, or an `.mp3`), and
it's synced for everyone in the session — perfect for a club dance floor or a movie room. See
*Interactables → Media* below. Direct media links only (no YouTube pages), and broadcast only
content you have the rights to.

**New in v0.3.2:** turn an Epic **MetaHuman** into a Workshop avatar in one click —
now **with hair**. Hair, eyebrows, mustache and beard come across as game-ready hair
cards, colored from the dye you picked in the MetaHuman editor and tuned to stay sharp
at a distance; the eyes get a lifelike catchlight. It's **zero-setup** — the avatar
materials ship inside the kit, no scripts to run. Custom clothing from Fab / the
marketplace brings its colors across too. And the uploader now catches an **oversized
preview image** up front (Steam rejects previews of 1 MB or larger) with a clear message
instead of a cryptic failure after a long upload. Full walkthrough: the **Build an
Avatar** guide → *MetaHuman avatars*.

**New in v0.3.1:** no more surprise **"DataTable Options" import popup** after every
upload. The kit's per-item save file changed format so the editor no longer tries to
import it — your saved Workshop IDs carry over automatically, nothing to redo. If you
ever clicked "Apply" on that old popup, delete the stray `_VRRWorkshop` DataTable asset
from your item's folder so it doesn't ship inside your pak.

**New in v0.3.0:** the kit moved to **Unreal Engine 5.8** to match the game. Content
built with this kit requires the UE 5.8 version of VR Realms (and older 5.7 kit
uploads will need a re-publish with this kit once the 5.8 game ships).

**New in v0.2.1:** the in-editor validator now also warns about content that hurts
players in multiplayer — avatars with **wrist-twist skinning** problems (the "bow-tie"
wrist) and **memory-heavy avatars** (oversized textures / dense meshes that can crash
low-RAM players) — plus a **Documentation** button that opens the guides.

**New in v0.2:** the old external WorkshopTool .exe is gone. Everything now runs
**inside the Unreal editor** — one button validates your content, fixes common
problems automatically, builds the pak, and uploads it to Steam.

- Full step-by-step guides: **https://vr-realms.com** (Maps & Avatars)
- Latest version / downloads: **https://github.com/crazysketch/VRRealmsCreatorKit/releases**
- Help & feedback: Discord → `#workshop-support`

> This is an **alpha** kit — expect updates. Grab the newest release before starting a big project.

## 1. Install

1. Install **Unreal Engine 5.8** from the Epic Games Launcher (free).
2. Install **SteamCMD** (https://developer.valvesoftware.com/wiki/SteamCMD) and note
   where `steamcmd.exe` lives (the uploader uses it behind the scenes).
3. Unzip this kit anywhere (avoid very deep folder paths).
4. Open `VRRealms/VRRealms.uproject` in UE 5.8. The Workshop tool is already
   installed as a plugin — open it from the top menu bar: **Tools → VR Realms Workshop**.

## 2. One-time Steam login (do this first, or uploads will fail)

In **Tools → VR Realms Workshop → Settings**: check the SteamCMD path, enter your
Steam login name, and click **Steam Login (one time)**. A console window opens —
type your password and Steam Guard code there. Steam remembers you afterwards, so
every later upload runs silently.

## 3. Avatars

### The skeleton rules (read this once, it saves you a re-upload)

- Your character **must be rigged to the standard Epic mannequin skeleton** —
  either the **UE4** or the **UE5** version. Most marketplace/Fab characters
  advertised as "rigged to the Epic skeleton" work as-is.
- The core humanoid bones are **required**: pelvis, spine, neck, head, clavicles,
  arms, hands, thighs, calves, feet (standard mannequin names). If your rig renamed
  or removed these, no tool can fix it — re-rig in Blender/Maya first.
- **Extra bones are totally fine** — eyes, jaw, hair, ears, tails, wings, whatever.
  You don't have to do anything: the tool detects them and **automatically adds them**
  (it builds a private copy of the mannequin skeleton for your avatar and merges the
  extra bones in). *(Currently supported for UE4-skeleton rigs; UE5 rigs with extra
  bones are not supported yet — the tool will tell you.)*
- Don't worry about which skeleton asset you pick in the FBX import dialog — even if
  you leave it empty or your pack ships its own skeleton, the tool detects the right
  mannequin (UE4 vs UE5) and re-assigns your mesh automatically.

### Upload an avatar

1. Import your FBX (or install your Fab/marketplace pack) anywhere in the project.
2. **Tools → VR Realms Workshop → Avatar** → pick your skeletal mesh in the dropdown.
3. The tool checks it instantly and shows a colored verdict:
   - 🟢 **READY — all checks passed.** Go ahead.
   - 🟠 **FIXABLE — issues found, Build will fix them automatically.** Also go ahead —
     this is normal for fresh imports and store packs (wrong folder, own skeleton,
     extra bones…). The details are listed under the verdict if you're curious.
   - 🔴 **INCOMPATIBLE — this avatar can NOT work in-game.** Usually missing core
     bones. Nothing gets moved or changed; fix the rig in your 3D tool and re-import.
4. If your mesh isn't in the kit's content folders yet, an **Item name** box appears —
   that name becomes your item's folder and pak name. Pick a unique, final name
   (changing it later means a new Workshop item).
5. Click **Build Avatar Pak**. The log walks through every step: validating → moving
   your files into the right folder → fixing the skeleton → cooking → building the pak.
   The cook can take a few minutes and may *look* frozen during shader work — it isn't.
6. Fill in **Title**, **Description**, a **Preview image** (jpg/png), and click
   **Upload Avatar**.

## 4. Maps

1. Build your level. Drop a **PlayerStart** so players have somewhere to spawn.
2. **Tools → VR Realms Workshop → Map** → pick your level in the dropdown.
3. Same colored verdict as avatars. The most common warning is *"N assets outside the
   map's Community folder"* — meshes/materials your map uses that live elsewhere in
   the project. **Build moves them all in automatically**, so this is FIXABLE, not a
   problem.
4. Enter an **Item name** if asked (same rule: unique and final).
5. Click **Build Map Pak** → fill in Title/Description/Preview → **Upload Map**.

> If the editor pops a dialog saying *"Source code, config INI, and text files may
> need Find/Replace… Continue with rename?"* — click **OK**. That's a generic Unreal
> warning about maps referenced in config files, which Workshop maps never are.

> You can't build the map you currently have **open** — the tool will ask you to
> switch to another level first (File → New Level works).

## 5. Updating your item

After a successful upload, the **Workshop ID** box fills in automatically — **leave
it there**. With the ID filled, the next Upload **updates** your existing item and
subscribers get it automatically.

- **Empty ID = brand-new Workshop item.** Don't re-upload the same content as a new
  item — two items built from the same folder break each other in-game.
- New items are rate-limited by Steam (~10–15 per account per 24h). Updates are unlimited.
- Items upload as **hidden/private**. Open the item's Steam Workshop page to set it
  **Public** when it's ready — nobody can see or download a private item but you.

## 6. Errors to look for

| What you see | What it means / what to do |
|---|---|
| 🔴 *INCOMPATIBLE … missing core bones* | The rig isn't a standard mannequin humanoid (renamed/missing pelvis, spine, arms…). Fix the rig in Blender/Maya, re-import. The tool deliberately touches nothing in this state. |
| *Extra bones are currently only supported on the UE4 mannequin* | Your rig matched the UE5 skeleton AND has extra bones — not supported yet. Either remove the extra bones or re-rig on the UE4 mannequin. |
| *The map '…' is currently open in the editor* | Open a different level, then Build again. |
| *BUILD STOPPED — enter an item name first* | The Item name box is empty (letters/numbers/underscore only). |
| Cook seems frozen for minutes | Normal during shader compilation. Truly stuck = 5+ min with no new log lines. |
| *UPLOAD FAILED* + SteamCMD output in the log | Usually the one-time Steam login was never done (see §2), or Steam Guard expired — run the login again. |
| SteamCMD *exit code 9* | Steam's new-item rate limit (~10–15/day). Wait, or update an existing item instead. |
| *Pak is too large (max 700 MB)* | Reduce texture resolutions or remove unused assets, then rebuild. |
| Your avatar shows as the default body (Quinn) in game | The game rejected the mesh — almost always a rig that bypassed the tool's checks via a manual upload. Re-run Validate in the kit and re-upload. |

## Rules / standards

- Engine: **UE 5.8** only.
- Avatars: standard **UE4 or UE5 mannequin** rig (see §3 — extra bones welcome).
- **Do NOT enable Nanite on your meshes.** VR Realms uses the VR forward renderer,
  and Nanite only works with deferred rendering — Nanite-enabled meshes will be
  **invisible in game**. When importing, leave "Build Nanite" OFF; for existing
  assets, right-click the mesh → disable Nanite. Use normal LODs to control poly
  count instead.
- **Maps: bake your lighting** (Build → Lighting Quality → *Production*). VR Realms uses
  the VR forward renderer, so **Lumen does not run** — use Static/Stationary lights and a
  Lightmass Importance Volume. For sky, use SkyAtmosphere + a Directional Light with
  "Atmosphere Sun Light" (avoid HDRI sky-dome meshes — they often render black).
- Pak size limit: **700 MB**.
- One Community folder = one Workshop item, forever.
