# VR Realms Creator Kit

**v0.4.18 (Alpha)** · Unreal Engine **5.8**

Build maps and avatars for [VR Realms](https://vr-realms.com) and publish them to the Steam Workshop.

No Visual Studio, no C++, no game source needed. Just Unreal Engine 5.8 and a Steam account that owns VR Realms.

> ⚠️ **Known issue (fix already in the next game update):** do **not** place a **Mirror Widget** item yet. Entering a map that has one crashes the current Steam build. Plain mirrors are fine. Remove the widget marker and rebuild until the update lands.

---

## Quick Start

1. Install **Unreal Engine 5.8** (Epic Games Launcher)
2. Unzip the kit somewhere with a short path
3. Open `VRRealms/VRRealms.uproject`
4. Go to **Tools → VR Realms Workshop**
5. In **Settings**, download SteamCMD and do the one-time Steam login
6. Build → Upload

Full details → [Workshop panel guide](https://vr-realms.com/docs/ugc-tools-panel.html)

---

## Avatars

- Standard UE4 / UE5 mannequin skeletons work out of the box
- Other humanoid rigs → **Build** works the bones out from the shape (no separate Prepare step)
- Physics for hair, tails, ears, etc. is added automatically when needed; **Advanced → Remove physics** if you want a still avatar
- Extra bones (hair, tails, wings…) are supported on UE4-style rigs
- Heavy cloth is refused: max **1,500 simulation particles** per clothing asset. Simulate a low-poly copy or remove the clothing data

Full details + troubleshooting → [Build an Avatar](https://vr-realms.com/docs/workshop-avatars.html)

---

## Maps

1. Make your level and place a **PlayerStart**
2. Tools → VR Realms Workshop → **Worlds** → pick your level
3. Build Map Pak → fill in info → Upload

Interactables (screens, jukeboxes, mirrors, game devices, etc.) are dropped in with `BP_VRItemMarker`.
Want game logic? See the [Scripting API](https://vr-realms.com/docs/api.html) for the allowed nodes.

Full details + troubleshooting → [Build a Map](https://vr-realms.com/docs/maps-build.html) · [Interactables](https://vr-realms.com/docs/interactables.html)

---

## Updating an item

After the first successful upload the **Workshop ID** is filled in automatically.
Leave it there: the next upload updates the existing item instead of creating a new one.

**Tags:** when updating an item, tags are applied *before* the upload while Steam is still connected. For a brand-new item they are applied afterwards; if Steam refuses, sign out of the Steam app and back in, then press Set Tags again.

---

## Important rules

| Rule | Why |
|------|-----|
| **UE 5.8 only** | Required by the kit |
| Keep the kit's `Config/DefaultEngine.ini` | Wrong renderer settings = black eye / broken materials |
| **Do not enable Nanite** | VR Realms uses the forward renderer; Nanite meshes become invisible |
| Bake lighting | Lumen does not run in the game |
| Max pak size | **700 MB** |
| One Community folder = one Workshop item | Forever. Do not reuse a folder for a different item |

---

## FAQ / Common errors

If it's not listed here, ask in [Discord](https://discord.com/invite/qMZ7gZzg6A).

| What you see | What it means / what to do |
|---|---|
| 🔴 **INCOMPATIBLE … missing core bones** | Rig is missing required bones (pelvis, spine, arms, legs, etc.). Re-rig in Blender/Maya and re-import. The tool does nothing in this state. |
| Extra bones only supported on the UE4 mannequin | Your rig is UE5-style and has extra bones. Not supported yet. Remove the extra bones or re-rig on the UE4 mannequin. |
| WARNING: forearm twist bones carry almost no skin weight | Wrists will pinch into a "bow-tie" in game. Paint weight onto the lowerarm_twist bones in your 3D tool, then re-upload. |
| TOO EXPENSIVE: cloth over 1,500 particles | Simulate a low-poly copy of the garment, or remove the clothing data (the garment stays as normal skinned geometry). |
| The map is currently open in the editor | You can't build the level that's open. Switch to a different level, then Build again. |
| BUILD STOPPED: enter an item name first | Item name box is empty. Type a name (letters, numbers, underscore only). |
| Cook seems frozen for minutes | Normal during shader compilation. Actually stuck = 5+ min with no new log lines. |
| Build fails: file in use | Close the model's `.fbx` in your 3D tool or the mesh editor before building. |
| UPLOAD FAILED + SteamCMD output | One-time Steam login was never done, or Steam Guard expired. Go to Settings → Steam Login and do it again. |
| SteamCMD exit code 9 | Steam rate limit on new items (~10-15 per day). Wait, or update an existing item instead. |
| Pak is too large (max 700 MB) | Lower texture resolutions or remove unused assets, then rebuild. |
| UE4 / UE5 mannequin avatar has a twisted or broken neck, arms or legs in game | The rig uses mannequin bone names but its bones are rotated differently. Press **Advanced → Map Community Rig**, then Build again. |
| Avatar shows as the default body (Quinn) | Game rejected the mesh. Usually means it skipped the kit's checks. Validate in the kit, then Build + Upload again. |
| Avatar or face is plain grey | Older kits packed materials wrong. Update the kit, Build again, re-upload. |
| Black in the right eye / grey checkerboard materials | Renderer settings drifted from the kit. VRR Updater → Verify files → Repair, then rebuild. |
| Steam refused the tag update: access denied | The Steam app is signed into a different account than the one that uploaded. Sign the Steam app in as the uploader, then Set Tags again. |
| EResult 3 while setting tags | Steam servers unreachable. Make sure Steam is online. The kit retries once on its own. |
| Build refused: Blueprint uses Execute Console Command / Open Level / Quit Game / … | Those nodes affect the whole game, not just your map. Remove them and Build again. Allowed nodes are on the Scripting API pages. |
| A node from this kit does nothing in game | Matching game update isn't out yet, or the player is on an older version. Nodes marked *next* on the docs need the matching VR Realms update. |
| Map has a Mirror Widget and the game crashes on entry | Known issue in the current Steam build, fixed in the next update. Remove the Mirror Widget marker for now. |

---

## Updating the kit

Run **VRR Updater** (`VRRUpdater.cmd`). It installs the latest release, then runs **Verify files** so drifted settings are caught. Repair is a separate button that backs up first. Your maps and avatars are never touched.

What changed in each version → [Release notes](https://github.com/crazysketch/VRRealmsCreatorKit/releases)

---

## Credits & Third-party

This kit uses **[KawaiiPhysics](https://github.com/pafuhana1213/KawaiiPhysics)** by [pafuhana1213](https://github.com/pafuhana1213) for soft-body / bone-chain physics on avatars (hair, tails, ears, cloth, etc.).

**All rights to KawaiiPhysics remain with its author under the [MIT License](https://github.com/pafuhana1213/KawaiiPhysics/blob/master/LICENSE).**
We only use it; we do not claim ownership of it.

The kit itself is © 2026 Sketchy Realms. See [LICENSE.md](LICENSE.md): use it to make VR Realms content, keep what you make, don't redistribute the kit.

---

## Links

- **Website & full guides** → [vr-realms.com](https://vr-realms.com)
- **Releases / downloads** → [GitHub Releases](https://github.com/crazysketch/VRRealmsCreatorKit/releases)
- **Help** → [Discord](https://discord.com/invite/qMZ7gZzg6A) · [Forum](https://vr-realms.com/forum/public/)

> This is an **alpha** kit. Always grab the newest release before starting a big project.
