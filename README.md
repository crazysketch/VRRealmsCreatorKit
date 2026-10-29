# VR Realms Creator Kit

**v0.5.3 (Alpha)** · Unreal Engine **5.8**

Build maps and avatars for [VR Realms](https://vr-realms.com) and publish them to the Steam Workshop.

No Visual Studio, no C++, no game source needed. Just Unreal Engine 5.8 and a Steam account that owns VR Realms.

> **New in 0.5.3:** **Open World maps work.** A map made from the Open World template (World Partition) used to show up empty in VR Realms. Build Map Pak now makes a normal copy of it, named after your map with _VRR at the end, with every actor and the landscape, and ships that. Keep editing your own map: every Build makes the copy again.

---

## Quick Start

**Easiest:** the [Creator Kit app](https://github.com/crazysketch/VRRealmsCreatorKitApp/releases/latest) does steps 1 to 3 for you and keeps the kit up to date.

1. Install **Unreal Engine 5.8** (Epic Games Launcher)
2. Unzip the kit somewhere with a short path
3. Open `VRRealms/VRRealms.uproject`
4. Go to **Tools → VR Realms Workshop**
5. In **Settings**, download SteamCMD and do the one-time Steam login
6. Build → Upload

Full details → [Workshop panel guide](https://vr-realms.com/docs/ugc-tools-panel.html)

---

## Avatars

- **Import avatar file** (Avatar page, under Skeletal mesh): pick a **.unitypackage**, a **.zip / .rar / .7z** download, an **.fbx**, a **.vrm** or a **.glb**. The kit unpacks it, finds the avatar in it and brings it in with the game's own converter: each part gets the material its avatar's own prefab gives it, its pictures come along, and parts the avatar keeps off stay off. It lands in its own item folder and is picked for you. Then **Build Avatar Pak** and **Play Avatar**. Guide → [Import an avatar file](https://vr-realms.com/docs/avatars-import.html)
- Standard UE4 / UE5 mannequin skeletons work out of the box
- Other humanoid rigs → **Build** works the bones out from the shape (no separate Prepare step)
- Physics for hair, tails, ears, etc. is added automatically when needed; **Advanced → Remove physics** if you want a still avatar
- Extra bones (hair, tails, wings…) are supported on UE4-style rigs
- Hands with no finger bones, or too few (a mitten hand from an auto-rigger), still Build: the kit finds the two hands by their bone names. The avatar works and can grab, but its fingers will not curl, and Build says so
- Heavy cloth is refused: max **1,500 simulation particles** per clothing asset. Simulate a low-poly copy or remove the clothing data
- Decorations that hang in front of your face without being attached to the head (a card, banner or collar piece on its own bone) are hidden from **your own** first-person view. Everyone else, and your mirror, still see them. Build lists what it hid (needs VR Realms 0.1.7)
- **Face shapes:** picking a mesh now shows a **Face:** line that names the morph target the game opens when you talk and the one it closes to blink, or says that none was found. The game goes by the shape's **name**: `MouthOpen`, `JawOpen`, `vrc.v_aa` (Unreal imports it as `vrc_v_aa`), `viseme_aa`, `AA` or VRoid's `Fcl_MTH_A` for the mouth, and any name with `Blink` in it for the eyes. It moves one mouth shape; other visemes are not used (`vrc.v_aa` and `AA` need VR Realms 0.2.4 or later)
- **Looks** (optional): several texture sets in one avatar. Open **Optional: Looks** on the avatar page, add a look, and pick a material or textures for each part of the body. A look is a folder beside the avatar's mesh, `Looks/<Name>/`, and Build packs every look with the avatar. Players choose a look in game (needs VR Realms 0.3.0). Guide → [Looks](https://vr-realms.com/docs/avatars-looks.html)
- **Parts and outfits** (optional): pieces a player can change. Open **Optional: Parts**. A piece is a skeletal mesh (hair, a torso, legs, shoes), a slot wears one piece or none, and sets of pieces are saved as named outfits. A piece that is not skinned to the body (wings, a tail, a hat) is placed on one bone with the handles in the 3D view. In a modular pack the head is usually the only mesh with the whole skeleton: pick the head as the avatar's mesh and add everything else as pieces. Players change pieces and outfits in game (needs VR Realms 0.3.0). Guide → [Parts and outfits](https://vr-realms.com/docs/avatars-parts.html)
- **MetaHuman** (optional): open **Optional: MetaHuman → Avatar**, pick the Blueprint of an assembled MetaHuman and press **Make modular avatar**. The body leads, the face is worn as a piece with 51 named shapes (talking, blinking, gaze, face tracking), and outfit, hair and a cape become pieces in the Parts box. Every material is drawn into plain textures the game can show. **Start MetaHuman mode** restarts the kit for one session in Shader Model 6 with Epic's MetaHuman tool switched on: make the MetaHuman and press the button there (it needs a DirectX 12 graphics card). Assemble as **UE Optimized**, which gives the hair its cards. The face moves and the sleeves are right in game from VR Realms 0.3.2. A **.mhpkg** from Epic's MetaHuman tool (a character, or an outfit for one) comes in with **Import MetaHuman package (.mhpkg)...** in MetaHuman mode. Guide → [MetaHuman](https://vr-realms.com/docs/avatars-metahuman.html)
- **Textures are built at 2048 px at most.** Build Avatar Pak builds every bigger texture in the avatar's folder at 2048 px and the log says how many. Your imported image is kept. Avatars only, map textures are not touched
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

**Sticks, buttons and things you drive (needs VR Realms 0.2.4):** read a player's sticks and triggers with
**Get Input Axis** and **Get Action Amount**, take over their controls with **Start Controlling**, and buzz a hand with
**Vibrate Controller**. You name an action, never a key, so it works on a headset, a keyboard and a gamepad, and follows
the player's own bindings. Walkthrough → [A remote control car or a boat](https://vr-realms.com/docs/api-scenarios.html#remote-control).
Tap, hold and double tap, **On Player Controlling Changed** and **On Control Action** are events of the **Realm Input Events**
component: add it to your Blueprint beside Realm Events. (Kits 0.4.27 and 0.4.28 had them on Realm Events. A map built
with one of those two kits that uses Realm Events must be built again with this kit.)

**Sounds and the players' volume sliders:** select an Ambient Sound → Details → **VR Realms → Volume slider** and pick
Music, SFX, Ambience, Dialog or TV / Media. Left "Not connected", only the Master slider turns it down. Sounds played
from a Blueprint: set the audio component's **Sound Class Override**, or the sound asset's own **Sound Class**, to one
of `/Game/VRRealms/Sounds/SC_Music`, `SC_SFX`, `SC_Ambience`, `SC_Dialog` or `SC_Media`. Map validation lists every
placed sound still on Master only. (The preview in the editor always plays at full volume.)

**Props that go back to their spot:** on a Grabbable mesh, tick Details → **VR Realms → Returns to its spot**. If players
leave it somewhere else and nobody holds it, it dissolves and materializes back where you placed it after the time you
set (60 seconds unless you change it). Everyone sees it. Good for drinks, tools, anything that should not end up scattered.

**Held in hand (early):** on a Grabbable mesh, tick Details → **VR Realms → Held in hand**. Tick **Preview** and pick a
**Preview body** (any skeletal mesh with `hand_r` and `hand_l` bones, your own avatar included). The body stands beside
the item with a copy of it in its hand. Move the copy until it sits right: the grip is saved on the item. **Hand** chooses
right, left or either, **Hold animation** is optional, **Clip time** shows any moment of it, **Start again** forgets the
grip. In game since VR Realms 0.3.0, desktop players first: E puts the item in the hand the way you placed it.
VR players grab as before. A Hold animation and the skeleton it was made on must be inside your map's folder.

**Gun matches (the new parts need VR Realms 0.3.3):** set an item marker's **Item** to **Rifle Pad**, **Pistol Pad** or **SMG Pad** (Weapons) for guns, and to **Health Pickup** or **Shield Pickup** (Match) for a heart (50 health, back after 20 seconds) or a shield (50
shield points, back after 30 seconds) that sits on the floor under the marker. Taking a gun from a pad costs a little gold in game. A map
that is also a place to hang out: draw a Trigger Box around the match and set its **Match role** to **Match area (arena box)**. Inside it the
guns work, a gun carried out of it dissolves and shots stop at its walls. A map that is all match needs none.
Walkthrough → [Deathmatch](https://vr-realms.com/docs/modes-deathmatch.html)

Full details + troubleshooting → [Build a Map](https://vr-realms.com/docs/maps-build.html) · [Interactables](https://vr-realms.com/docs/interactables.html)

---

## Updating an item

After the first successful upload the **Workshop ID** is filled in automatically.
Leave it there: the next upload updates the existing item instead of creating a new one.

Title, description, preview and Workshop ID belong to the item you picked: each avatar and each map keeps its own, and they
come back when you pick it again. **New avatar** and **New map** start with an empty form. If the Workshop ID in the form is
also saved with another item of yours, Upload asks before it replaces anything.

**Tags:** when updating an item, tags are applied *before* the upload while Steam is still connected. For a brand-new item they are applied afterwards; if Steam refuses, sign out of the Steam app and back in, then press Set Tags again.

---

## Important rules

| Rule | Why |
|------|-----|
| **UE 5.8 only** | Required by the kit |
| Keep the kit's `Config/DefaultEngine.ini` | Wrong renderer settings = black eye / broken materials |
| **Do not enable Nanite** | VR Realms uses the forward renderer; Nanite meshes become invisible |
| Bake lighting | Lumen does not run in the game |
| Max pak size | **700 MB** (800 MB for an avatar with parts) |
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
| Pak is too large (max 700 MB, 800 MB for an avatar with parts) | Lower texture resolutions or remove unused assets, then rebuild. |
| A map with a Realm Events component fails to load, or the game closes while it loads | The map was built with kit 0.4.27 or 0.4.28. Update the kit, press **Build Map Pak** again, upload again. |
| A Blueprint shows an error on On Player Action Tap, Hold or Double Tap after updating the kit | Those events moved to the **Realm Input Events** component. Add it beside Realm Events and bind the events there. |
| An avatar with parts shows only a head in game | Parts need VR Realms 0.3.0 or later. Update the game. |
| A MetaHuman avatar's face does not move in game, or a sleeve shows spikes at the wrist | Both are right from VR Realms 0.3.2. Update the game. |
| The head in Epic's MetaHuman tool is grey | The kit draws like the game (Shader Model 5) and that tool needs Shader Model 6. On the avatar page open **Optional: MetaHuman → Avatar** and press **Start MetaHuman mode**. |
| Epic's MetaHuman tool seems stuck at its rig step | The first time, it opens an Epic sign in page in your browser and waits for it. Finish the sign in there. |
| A MetaHuman avatar has no hair | The game cannot draw hair strands. Assemble the MetaHuman as **UE Optimized** so the hair has cards, then press **Make modular avatar** again. |
| One of my Workshop items turned into another avatar after an upload | Kits before 0.4.30 kept the last item's Workshop ID in the form. Update the kit, pick the right avatar, check the Workshop ID box and upload it again. |
| Build says there is no Nav Mesh Bounds Volume | Advice only, the build goes on. VR players who move by Teleport, Point to Walk or Out of Body land only on a nav mesh, and the game's own fallback can also land them on roofs and props. **Place Actors → Volumes → Nav Mesh Bounds Volume**, scale it over every floor players walk on, press **P** to see it, then Build again. |
| Players are a flying camera in your map, or Build warns about the GameMode Override | **Window → World Settings** and set **GameMode Override** to None. VR Realms brings its own game mode; the game modes of a map are its VRGame tags. |
| Grass or small stones on a landscape show black in game | Open each landscape grass type and tick **Use Landscape Lightmap**, build lighting, then Build Map Pak again. Build lists the grass types that need it. |
| Build stopped: "Still non-conforming after the fix-up" on a skeleton with a virtual bone | Fixed in kit 0.4.29. Update the kit and Build again. |
| UE4 / UE5 mannequin avatar has a twisted or broken neck, arms or legs in game | The rig uses mannequin bone names but its bones are rotated differently. Press **Advanced → Map Community Rig**, then Build again. |
| Upload stops with "Steam did not upload anything" | SteamCMD has no saved login for the Steam user in the panel. Put your own Steam login name in the Steam user box (not a placeholder), click **Steam Login (one time)** if it is new on this PC, then Upload again. Kits before 0.4.32 said UPLOAD COMPLETE here although nothing went up. |
| Import avatar file says the avatar stands many metres tall | That is the size its file gives it. If it is meant to be person sized, scale the mesh in Unreal before Build. |
| Import avatar file left a piece out | A modular avatar's pieces that replace the ones worn at first (another hairstyle, another jacket) stay out of the one mesh, as the game shows it at first. The log names them. To keep every piece, type `vrr.Kit.ImportAvatarAllPieces 1` in the console and import again. |
| Morph target sliders work in the mesh editor, but the mouth or eyes don't move in game | The game only moves a shape whose **name** it recognises. Pick the mesh in the Workshop panel and read the **Face:** line: it names the shapes the game will use, or says none was found. To fix it, open the mesh, right-click the open-mouth shape in the Morph Targets list → **Rename** → `MouthOpen` (and `Blink` for closed eyes), save, then Build and upload again. |
| Avatar shows as the default body (Quinn) | Game rejected the mesh. Usually means it skipped the kit's checks. Validate in the kit, then Build + Upload again. |
| Avatar or face is plain grey | Older kits packed materials wrong. Update the kit, Build again, re-upload. |
| Water ripples (or another moving material) work in the editor but are still in game | The material uses one of Unreal's engine textures, and the game only carries the few it uses itself. Update the kit to 0.4.28 or later and press **Build Map Pak** again: Build copies the texture into your map's folder (look for `copied` in the build log). Then upload again. |
| FBX props in a map are plain grey in game | Kits before 0.4.28 did not pack the material every FBX import depends on. Update the kit, Build again, re-upload. |
| A lake or ocean made with Unreal's Water plugin shows a grey grid in game | The Water plugin's materials are not in the game. Use a plane with your own water material instead. |
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

**Import avatar file** reads FBX files with **[ufbx](https://github.com/ufbx/ufbx)** by Samuli Raivio, under the MIT License. Its notice is in `VRRealms/Plugins/VRRealmsCreatorKit/THIRD-PARTY-NOTICES.txt`.

The kit itself is © 2026 Sketchy Realms. See [LICENSE.md](LICENSE.md): use it to make VR Realms content, keep what you make, don't redistribute the kit.

---

## Links

- **Website & full guides** → [vr-realms.com](https://vr-realms.com)
- **Releases / downloads** → [GitHub Releases](https://github.com/crazysketch/VRRealmsCreatorKit/releases)
- **Help** → [Discord](https://discord.com/invite/qMZ7gZzg6A) · [Forum](https://vr-realms.com/forum/public/)

> This is an **alpha** kit. Always grab the newest release before starting a big project.
