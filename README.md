# VR Realms Creator Kit — v0.4.15 (Alpha, UE 5.8)

Build maps and avatars for **VR Realms** and publish them to the Steam Workshop.
You do **not** need Visual Studio, C++, or the VR Realms source — just Unreal
Engine 5.8 and a Steam account that has VR Realms in its library.

**New in v0.4.15 — animation and input for your own games.** Both came out of building a complete
boxing game with nothing but this kit, and both are now nodes under **VR Realms** in the palette.
**Play Animation On Player (Server)** plays an animation sequence on a player's avatar body for
everyone: any clip authored on a mannequin-style skeleton works, because the game maps its bones onto
whatever avatar the player wears, and it returns the clip's length so you can wait for it. **Stop
Player Animation** and **Is Player Animating** go with it, and the **Realm Events** component gains
**On Player Animation Finished**. Headset players' arms keep following their real hands, so on a
headset it is for legs, spine and full-body emotes; on desktop it is the whole body. **On Player
Action** on Realm Events hands you a button press or release from the player at this machine, with
one device-agnostic name per action: Fire, FireLeft, Grab, GrabLeft, Jump, Crouch, Sprint, Interact,
Menu, Aim, ButtonB, ButtonY, StickLeft, StickRight. No Enable Input, no key events, and it reads the
same for a headset, a keyboard and a gamepad. **Is Action Held** reads the current state. Input never
leaves a machine, so act on it with Tell Host. The full game, rule by rule, is written up at
<https://vr-realms.com/docs/api-boxing.html>; the node tables are at
<https://vr-realms.com/docs/api-nodes.html>.

**These nodes need the matching VR Realms update.** They appear in your palette now, and they do
their work in-game once the game build that ships alongside this kit is live. Everything from
0.4.13 and 0.4.14 (the scripting nodes, the Blender and VRoid fixes, the cloth check) is folded into
the sections below.

The sample content has not changed, so VRR Updater brings you up to date with the small patch.

- Full step-by-step guides: **https://vr-realms.com** (Maps & Avatars)
- Latest version / downloads: **https://github.com/crazysketch/VRRealmsCreatorKit/releases**
- Help & feedback: Discord → `#workshop-support`

> This is an **alpha** kit — expect updates. Grab the newest release before starting a big project.

## 1. Install

1. Install **Unreal Engine 5.8** from the Epic Games Launcher (free).
2. Unzip this kit anywhere (avoid very deep folder paths).
3. Open `VRRealms/VRRealms.uproject` in UE 5.8. The Workshop tool is already
   installed as a plugin — open it from the top menu bar: **Tools → VR Realms Workshop**.
4. Uploads run through **SteamCMD**. You do not need to find it yourself: the Settings
   panel has a **Download SteamCMD** button that fetches it from Valve into `C:\steamcmd`
   and fills in the path. If it is already there, the button adopts it.
5. Later, get new kit versions with **`VRRUpdater.cmd`**: double-click it with Unreal
   closed, and a window lists every release, marks the one you have, and installs the
   one you pick, usually as a small patch. A release that changes the sample content
   says so and needs the full kit download instead. The updater only writes to the
   kit's plugin folder and to itself, and backs up your current tools first. Your maps
   and avatars are never touched. Its **Verify files** button checks every file the kit
   shipped, and **Repair** restores the ones that are modified or missing.

## 2. One-time Steam login (do this first, or uploads will fail)

In **Tools → VR Realms Workshop → Settings**: click **Download SteamCMD** if the path
box is empty, enter your Steam login name, and click **Steam Login (one time)**. A console window opens —
type your password and Steam Guard code there. Steam remembers you afterwards, so
every later upload runs silently.

## 3. Avatars

### The skeleton rules (read this once, it saves you a re-upload)

- A character **rigged to the standard Epic mannequin skeleton**, either the **UE4**
  or the **UE5** version, is driven directly and needs no preparation. Most
  marketplace/Fab characters advertised as "rigged to the Epic skeleton" work as-is.
- **Rigged some other way?** Press **Prepare Avatar** in the Avatar tab. It works out
  where the spine, arms, legs and fingers are from the shape of the skeleton rather
  than from bone names, so it does not matter what your hips are called. It also adds
  physics for anything loose (tails, ears, hair, cloth) as an ordinary Animation
  Blueprint you can edit or throw away, and prints every chain it found with a
  verdict. Pressing it twice is safe: existing physics is never overwritten, and a
  mannequin rig is left alone. This needs the full kit download rather than the
  updater patch, because the physics plugin cannot ship in a patch.
- The core humanoid bones are **required**: pelvis, spine, neck, head, clavicles,
  arms, hands, thighs, calves, feet. If your rig has no equivalent of these, no tool
  can fix it — re-rig in Blender/Maya first.
- **Extra bones are totally fine** — eyes, jaw, hair, ears, tails, wings, whatever.
  You don't have to do anything: the tool detects them and **automatically adds them**
  (it builds a private copy of the mannequin skeleton for your avatar and merges the
  extra bones in). *(Currently supported for UE4-skeleton rigs; UE5 rigs with extra
  bones are not supported yet — the tool will tell you.)*
- Don't worry about which skeleton asset you pick in the FBX import dialog — even if
  you leave it empty or your pack ships its own skeleton, the tool detects the right
  mannequin (UE4 vs UE5) and re-assigns your mesh automatically.
- **Made in Blender or VRoid?** Export with Unit Scale 0.01 and Apply Scale, or the root bone
  carries a scale of 100: every preview looks right and the avatar stands about eighty metres in the
  air in game. Prepare Avatar refuses such a skeleton and names the bone and the Blender steps. Leg
  detection takes the lowest branch (skirt and hair bones are not calves), both hands get IK so they
  reach your controllers, the avatar is scaled to your eye height, and hair, skirts and tails no
  longer pull a limb into physics with them.
- **Cloth costs everyone.** Validate reads every clothing asset and prints its simulation cost. Up to
  about 1,500 simulated particles with Iteration Count and Subdivision Count of 2 or less and Self
  Collision off is fine; more than 3,000 particles, more passes, or self collision is marked HEAVY.
  One such dress cost about two milliseconds of every player's frame, every frame. The check never
  blocks a build. Fix it in the Skeletal Mesh Editor's Clothing tab: simulate a low-poly copy of the
  garment, Iteration Count 1, Subdivision Count 1, Self Collision off. In game only the nearest few
  players' cloth simulates and the rest freezes in place, so a heavy dress mostly shows up frozen
  while a light one keeps moving for everyone. For hair, tails and small pieces, bone-chain physics
  costs a fraction of cloth and looks the same.

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
6. Fill in **Title**, **Description**, a **Preview image** (jpg/png, under 1 MB or
   Steam rejects it), tick the **Workshop tags** that fit, and click **Upload Avatar**.
   Tags are applied as part of the upload. To change them later without re-uploading,
   tick the new set and press **Set Tags on Steam**. The ticked boxes are the whole
   list, so anything unticked is removed, and your Steam *client* must be signed in as
   the account that owns the item. A **Personal** tag (the Access group) means only
   you can wear it; other players still see you wearing it.

## 4. Maps

1. Build your level. Drop a **PlayerStart** so players have somewhere to spawn.
2. **Tools → VR Realms Workshop → Map** → pick your level in the dropdown.
3. Same colored verdict as avatars. The most common warning is *"N assets outside the
   map's Community folder"* — meshes/materials your map uses that live elsewhere in
   the project. **Build moves them all in automatically**, so this is FIXABLE, not a
   problem.
4. Enter an **Item name** if asked (same rule: unique and final).
5. Click **Build Map Pak** → fill in Title/Description/Preview, tick your tags → **Upload Map**.

Screens, jukeboxes, drawing boards, mirrors, weapon pads, a drivable car: drag
`VRRealms/Items/BP_VRItemMarker` into the level and pick the item from the **Item**
dropdown in *Details → VR Realms*. The placeholder takes that item's real size and shows
which way it faces. The same panel has **Game mode**, **Match role** and **Movement mode**
dropdowns, and the **Game device** dropdown (scoring zones, ball homes, round rules)
turns a map into a volleyball, soccer or lap-race game with no scripting. Guides:
<https://vr-realms.com/docs/interactables.html> and <https://vr-realms.com/docs/game-modes.html>.

**Your own game logic.** When tags and devices do not cover it, a map can ship Blueprints you
wrote, and the **Scripting API** is how they reach the players and the room: about fifty nodes under
**VR Realms** in the palette plus the **Realm Events** component. Who is here and where each player
is, points and labels everyone can read, messages and chat lines, teleport and respawn, a way for a
press on one machine to reach the host, channels, screens, voice, animation and input. Every node
says where it runs: Local nodes read this machine's copy, Server nodes act on the host only, and a
trigger's overlap fires on the host for every player who walks in, so most gameplay needs no
networking nodes at all. A scoreboard marker in a map with no game mode lists everyone's points.
Build refuses a map whose Blueprints use Execute Console Command, Open Level, Quit Game, Launch
URL, Set Game Paused or the session nodes, and names the Blueprint and the node. Tables and worked
scenarios: <https://vr-realms.com/docs/api.html>. A complete game built this way, rule by rule:
<https://vr-realms.com/docs/api-boxing.html>.

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
- The kit tells vr-realms.com about your item the moment an upload succeeds, so it
  reaches the review queue straight away, whatever Steam's search index shows.

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
| Your avatar, or just its face, is plain grey in game | Update the kit, press Build again and re-upload. Older kits packed materials without their parent, or without the *Used with Morph Targets* switch a face needs; the validator now warns about both before upload. |
| Content looks right on a flat screen but is **black in the right eye**, or every material is a grey checkerboard | Your project's renderer settings drifted from the kit's (instanced stereo off, or no SM5 shaders). Build now refuses to cook in that state and lists each line. Restore the kit's `Config/DefaultEngine.ini` (VRR Updater → **Verify files** → **Repair**) and rebuild. |
| *EResult 3* while setting tags | Steam could not reach its servers. Check Steam is online; the call is retried once on its own. |
| *Build refused: Blueprint '…' uses Execute Console Command / Open Level / Quit Game / …* | Those nodes act on the whole game rather than your map. Remove them from the named Blueprint and Build again. The allowed nodes are on the Scripting API pages. |
| A node from this kit does nothing in game, or a Blueprint using it will not load | The game build that ships alongside this kit is not out yet, or the player is on an older game version. Nodes marked *next* on the docs pages need the matching VR Realms update. |

## Rules / standards

- Engine: **UE 5.8** only.
- Avatars: standard **UE4 or UE5 mannequin** rig, or any humanoid rig after **Prepare Avatar** (see §3 — extra bones welcome).
- **Keep the kit's `Config/DefaultEngine.ini`.** Those lines decide what your cooked shaders
  contain, and Build refuses to cook if they drifted from the game's. Using GPU Lightmass?
  It needs SM6 and ray tracing in the editor: bake with them on, then put the kit's file
  back before you Build. Your baked lighting stays with the map. The comments in that
  file spell it out.
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
