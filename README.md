# VR Realms Creator Kit

**v0.4.26 (Alpha)** · Unreal Engine **5.8**

Build maps and avatars for [VR Realms](https://vr-realms.com) and publish them to the Steam Workshop.

No Visual Studio, no C++, no game source needed. Just Unreal Engine 5.8 and a Steam account that owns VR Realms.

> **New in 0.4.26:** picking an avatar mesh now shows a **Face:** line. It names the morph target the game opens when you talk and the one it closes to blink, or says that none was found and how to rename one, so "the sliders work but the mouth is still in game" is answered before you upload. Avatars whose hands have no finger bones, or too few (a mitten hand from an auto-rigger), now Build: the kit finds the two hands by their bone names and tells you the fingers will not curl. The `vrc.v_aa` viseme (Unreal imports it as `vrc_v_aa`) and a bare `AA` are moved as the mouth from the next VR Realms update.

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
- Hands with no finger bones, or too few (a mitten hand from an auto-rigger), still Build: the kit finds the two hands by their bone names. The avatar works and can grab, but its fingers will not curl, and Build says so
- Heavy cloth is refused: max **1,500 simulation particles** per clothing asset. Simulate a low-poly copy or remove the clothing data
- Decorations that hang in front of your face without being attached to the head (a card, banner or collar piece on its own bone) are hidden from **your own** first-person view. Everyone else, and your mirror, still see them. Build lists what it hid (needs VR Realms 0.1.7)
- **Face shapes:** picking a mesh now shows a **Face:** line that names the morph target the game opens when you talk and the one it closes to blink, or says that none was found. The game goes by the shape's **name**: `MouthOpen`, `JawOpen`, `vrc.v_aa` (Unreal imports it as `vrc_v_aa`), `viseme_aa`, `AA` or VRoid's `Fcl_MTH_A` for the mouth, and any name with `Blink` in it for the eyes. It moves one mouth shape; other visemes are not used (`vrc.v_aa` and `AA` work from the next VR Realms update)
- **Play Avatar** runs the real game with your built avatar on you, before you upload (needs the current VR Realms update)
- A UE4 / UE5 mannequin avatar with a twisted neck or limbs: **Advanced → Map Community Rig**, then Build again

Full details + troubleshooting → [Build an Avatar](https://vr-realms.com/docs/workshop-avatars.html)

---

## Maps

1. Make your level and place a **PlayerStart**
2. Tools → VR Realms Workshop → **Worlds** → pick your level
3. Build Map Pak → fill in info → Upload

Interactables (screens, jukeboxes, mirrors, game devices, etc.) are dropped in with `BP_VRItemMarker`.
Want game logic? See the [Scripting API](https://vr-realms.com/docs/api.html) for the allowed nodes.

**Sounds and the players' volume sliders:** select an Ambient Sound → Details → **VR Realms → Volume slider** and pick
Music, SFX, Ambience, Dialog or TV / Media. Left "Not connected", only the Master slider turns it down. Sounds played
from a Blueprint: set the audio component's **Sound Class Override**, or the sound asset's own **Sound Class**, to one
of `/Game/VRRealms/Sounds/SC_Music`, `SC_SFX`, `SC_Ambience`, `SC_Dialog` or `SC_Media`. Map validation lists every
placed sound still on Master only. (The preview in the editor always plays at full volume.)

**Props that go back to their spot:** on a Grabbable mesh, tick Details → **VR Realms → Returns to its spot**. If players
leave it somewhere else and nobody holds it, it dissolves and materializes back where you placed it after the time you
set (60 seconds unless you change it). Everyone sees it. Good for drinks, tools, anything that should not end up scattered.

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
| 🟠 **NEEDS MAPPING — not an Unreal mannequin rig** | Your rig uses its own bone names (e.g. `Hips`, `Spine`, `Left arm`). That's fine — press **Build Avatar Pak** and it maps the skeleton by its shape automatically. No renaming or re-rigging needed. (Older kits showed this as red "BLOCKED … missing core bones" — same fix: just press Build.) |
| **"…carried a ×100 scale — fixed automatically"** | Nothing to do. The FBX was exported from Blender in metres (its default), and Build rewrote the skeleton at the right scale for you. Your avatar's shape doesn't change. |
| **Bone '…' has a scale of 100.00 baked into the skeleton** | Build couldn't fix this one automatically (usually a mesh with several LODs, or a bone scaled unevenly). In Blender: Scene Properties → Units → **Unit Scale = 0.01**, select the armature and all meshes, press **S, 100, Enter**, then **Ctrl+A → Apply → Scale**. Export the FBX again and reimport the mesh from the new file. |
| **"Hands found by NAME"** + WARNING: this rig has no finger bones (or too few) | Build could not find the hands by their shape (a hand normally has 3 or more finger chains under it), so it used the bones named as the left and right hand. The avatar works: body, arms, legs and head move normally and it can grab, but its fingers stay stiff. For moving fingers, rig it again with a full set of finger bones. |
| **Could not find two hands on this rig** | The hands have no fingers (or only one or two finger chains) and the bone names do not say which bone is the left and the right hand. Rig it again with fingers (start from a mesh that has no skeleton, or the auto-rigger keeps the old bones), or name the two hand bones so they contain `hand` and `left` / `right` (or end in `_l` / `_r`), then reimport and Build again. |
| WARNING: forearm twist bones carry almost no skin weight | Wrists will pinch into a "bow-tie" in game. Paint weight onto the lowerarm_twist bones in your 3D tool, then re-upload. |
| TOO EXPENSIVE: cloth over 1,500 particles | Simulate a low-poly copy of the garment, or remove the clothing data (the garment stays as normal skinned geometry). |
| WARNING: cloth that will NOT move in game | The clothing data exists but is not applied to any part of the mesh. Open the mesh → Clothing tab → select the section → Apply the clothing data, or re-import the original mesh, then Build again. |
| The map is currently open in the editor | You can't build the level that's open. Switch to a different level, then Build again. |
| **"Level: … taken from the pak being uploaded"** | Nothing to do. Upload reads which level is inside your built pak and tells the game to load that one, so you never have to type or re-pick it. |
| **UPLOAD STOPPED — the built pak has no level in it** | The pak in your staging folder has no map in it (usually an old or unfinished build). Pick your level, press **Build Map Pak**, then **Upload** again. |
| BUILD STOPPED: enter an item name first | Item name box is empty. Type a name (letters, numbers, underscore only). |
| Cook seems frozen for minutes | Normal during shader compilation. Actually stuck = 5+ min with no new log lines. |
| Build fails: file in use | Close the model's `.fbx` in your 3D tool or the mesh editor before building. |
| UPLOAD FAILED + SteamCMD output | One-time Steam login was never done, or Steam Guard expired. Go to Settings → Steam Login and do it again. |
| SteamCMD exit code 9 | Steam rate limit on new items (~10-15 per day). Wait, or update an existing item instead. |
| Pak is too large (max 700 MB) | Lower texture resolutions or remove unused assets, then rebuild. |
| UE4 / UE5 mannequin avatar has a twisted or broken neck, arms or legs in game | The rig uses mannequin bone names but its bones are rotated differently. Press **Advanced → Map Community Rig**, then Build again. |
| Morph target sliders work in the mesh editor, but the mouth or eyes don't move in game | The game only moves a shape whose **name** it recognises. Pick the mesh in the Workshop panel and read the **Face:** line: it names the shapes the game will use, or says none was found. To fix it, open the mesh, right-click the open-mouth shape in the Morph Targets list → **Rename** → `MouthOpen` (and `Blink` for closed eyes), save, then Build and upload again. |
| Avatar shows as the default body (Quinn) | Game rejected the mesh. Usually means it skipped the kit's checks. Validate in the kit, then Build + Upload again. |
| Avatar or face is plain grey | Older kits packed materials wrong. Update the kit, Build again, re-upload. |
| Black in the right eye / grey checkerboard materials | Renderer settings drifted from the kit. VRR Updater → Verify files → Repair, then rebuild. |
| Steam refused the tag update: access denied | The Steam app is signed into a different account than the one that uploaded. Sign the Steam app in as the uploader, then Set Tags again. |
| EResult 3 while setting tags | Steam servers unreachable. Make sure Steam is online. The kit retries once on its own. |
| Build refused: Blueprint uses Execute Console Command / Open Level / Quit Game / … | Those nodes affect the whole game, not just your map. Remove them and Build again. Allowed nodes are on the Scripting API pages. |
| A node from this kit does nothing in game | Matching game update isn't out yet, or the player is on an older version. Nodes marked *next* on the docs need the matching VR Realms update. |
| A mirror on a wall shows grey or the room behind the wall | Add `r.AllowGlobalClipPlane=True` under `[/Script/Engine.RendererSettings]` in `VRRealms/Config/DefaultEngine.ini` (a fresh kit download has it), then rebuild the map. |

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
