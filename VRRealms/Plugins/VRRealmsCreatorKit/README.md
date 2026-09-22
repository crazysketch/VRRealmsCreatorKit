# VR Realms Creator Kit (editor plugin)

In-editor Steam Workshop pipeline: **Tools → VR Realms Workshop**.
Replaces the standalone WPF `Tools/WorkshopTool` app (cook → pak → SteamCMD upload, same
command lines and gotcha workarounds), and adds avatar skeleton validation/fix-up the
external tool could never do.

## What it does

- **Avatar — one button.** Pick a skeletal mesh anywhere; validation runs on pick.
  *Build Avatar Pak* then does the whole pipeline with step-by-step log output:
  1. **Validate** — bones vs the **golden manifests** (what the shipped game's
     skeletons actually have), required-core-bones check (pelvis/spine/arms/legs/head),
     polluted-kit-skeleton detection, wrong/orphan-skeleton detection
     (`SKEL_<MeshName>` from an FBX import with the Skeleton field left empty) with
     auto-pick of the right mannequin (UE4 vs UE5) by bone overlap. A rig that can't
     work (missing core bones, extra bones on a non-UE4 base) stops the build HERE —
     nothing gets moved or modified.
  2. **Adopt** — if the mesh lives outside `Community/Avatars/<Name>/` (e.g. a Fab
     purchase), moves it + everything it references (materials, textures, physics
     asset...) into the item's folder named by the *Item name* box, preserving the
     pack's subfolders (redirectors keep old references working). The folder structure
     is load-bearing: all Workshop paks mount into the same /Game/ namespace, so the
     per-item folder is what stops two items from colliding.
  3. **Fix skeleton** — re-assigns to the detected mannequin; rigs with extra bones
     (eyes/jaw/face) get a per-avatar duplicate (`SK_UE4Mannequin_<Name>`) in the
     avatar's folder with the extras merged in. The duplicate cooks into the avatar's
     pak — base game untouched, no two avatars can fight over the shared skeleton.
  4. **Cook & pak.**
  *Validate Avatar* is a read-only preview of what Build would do.
- **Map — same one-button treatment.** Pick a `.umap` anywhere; validation runs on pick
  with the same colored verdicts. *Build Map Pak*: validates references → moves the map
  AND any out-of-folder assets it uses into `Community/Maps/<Name>/` (stray references
  are the classic "focused cook produced nothing" failure) → cooks & paks. Refuses to
  move a map that's currently open in the editor (switch levels first).
- **Settings**: steamcmd.exe path + Steam username; one-time interactive Steam login
  (SteamCMD caches the session, uploads run silently afterwards). No passwords stored.

## Interactables — make a grabbable (tag-based)

You don't need VRE in the kit to add interactive objects. Place a plain **Static Mesh
Actor**, give it your mesh, and add an **Actor Tag** — the shipping game upgrades it into
the real interactable at runtime, so the kit itself stays content-only.

**Grabbable (v1):**
1. Drag a **Static Mesh Actor** into your map (the engine actor — *not* a VRE one).
2. Set its **Static Mesh** (and materials) to whatever should be grabbable.
3. In **Details → Actor → Tags**, add one tag: `VRGrab`
4. Place it where it should rest, then publish the map as normal.

In VR Realms, when the map loads, every `VRGrab`-tagged actor becomes a real **physics
grabbable** — players can pick it up and throw it. Your mesh + materials carry over; the
marker is replaced automatically.

### Grab options (optional tags)

Add any of these **alongside** `VRGrab` (or use them on their own — they also enable grab)
to tweak how the object behaves. Tags are case-insensitive.

| Tag | Effect |
|---|---|
| `VRGrab` | One-hand physics grabbable — falls when dropped, throwable. The default. |
| `VRGrab.TwoHand` | Two-handed grip (a second hand can grab it — good for big/long objects). |
| `VRGrab.Static` | No physics — stays exactly where you release it. Still grabbable. Good for shelf/wall props. |
| `VRGrab.NoGravity` | Physics on, gravity off — floats wherever it's left. |
| `VRGrab.Heavy` | Heavier — a more weighty, sluggish feel. |
| `VRGrab.Light` | Lighter — easier to fling around. |

Mix them, e.g. `VRGrab.TwoHand` + `VRGrab.Heavy` for a heavy two-handed object.
(`Heavy` wins if you set both `Heavy` and `Light`.)

Notes:
- **One mesh per grabbable.** Tag a plain **Static Mesh Actor**, *not* a Blueprint. For a multi-part
  object (e.g. a bottle + a cap as separate meshes), merge the parts into one mesh first — select
  them in the level → **Actor menu → Merge Actors** — then tag that single Static Mesh Actor.
  (A Blueprint with multiple mesh components won't work; the grabbable holds one mesh.)
- **It won't be grabbable inside the kit editor** (the kit has no VRE) — that's expected.
  Test grabbing by publishing and loading the map in VR Realms, same as everything else.
- Your mesh needs **collision** to be thrown/simulated — set Collision Complexity / a simple
  collision on the mesh, or it'll spawn but won't move.
- More interactables (mirrors, buttons, seats, …) get added on this same tag system over time.

## Ready-made tools (`VRItem`)

Some objects are **complete tools we ship whole** — they come with their own model *and* behavior,
so you place them rather than build them. The kit includes ready-made stand-in actors under
`Content/VRRealms/Spawnables/`:

- `BP_VRItem_DrawingBoard`, `BP_VRItem_Marker`, `BP_VRItem_Eraser`, `BP_VRItem_SprayCan` (art tools)

Drag one into your level, position/rotate it (the stand-in shows the tool's size + which way it
faces), and publish. In VR Realms each stand-in is replaced by the **real, working tool** at that
exact transform. You **can't change these models** (unlike grabbables — these are finished tools);
you only choose where they go. More tools get added the same way over time.

## Portals — warp to a map or swap avatar (`VRPortal`)

A **portal** is a prop players point at and select to jump to another Workshop map, or to put on a
Workshop avatar. Like a grabbable you build it from **your own mesh** — but instead of picking it up,
players select it to travel. Place a **Static Mesh Actor**, set its mesh (a doorway, archway, poster,
statue, wardrobe mannequin), and add **one** tag:

| Tag | What happens when a player selects it |
|---|---|
| `VRPortal.Level.<id>` | Takes them to that Workshop **map** — joining a session already running it if there is one, otherwise hosting it fresh so others can follow. |
| `VRPortal.Avatar.<id>` | Equips that Workshop **avatar** on them, on the spot. |

`<id>` is the Workshop item's **ID number** — the number after `?id=` in its Steam Workshop web
address (e.g. `…/filedetails/?id=3829473827` → `VRPortal.Level.3829473827`). Use the ID of a
**published** item: a map for `Level`, an avatar for `Avatar`.

Notes:
- The portal is a **fixed** object — it **can't be grabbed, thrown, or knocked around**. Players just
  aim at it and select. (Under the hood it's a grippable locked to deny-grip + don't-teleport, so it
  never gets picked up or pulled toward the hand.)
- The **mesh is the portal's whole look** — make it read like a destination. Build a hub world of
  doorways into your other maps, or a wardrobe room where statues swap the player's avatar.
- A **wrong or unpublished `<id>`** simply does nothing when selected — double-check the number.
- Like grabbables, **you can't test it inside the kit editor** (no VRE here) — publish the map and load
  it in VR Realms, same as everything else.

## Media — TVs & jukeboxes (`VRItem.TV` / `VRItem.Jukebox`)

A shared **video screen** or **audio player / radio** you drop into a map. Place a plain **Static Mesh
Actor** where it should sit (a cube is fine — it's just a position marker; face it the way the screen
should point) and add one tag:

| Tag | In VR Realms |
|---|---|
| `VRItem.TV` | A networked **video screen** at that spot. |
| `VRItem.Jukebox` | A networked **audio player / radio** (no screen — great for a club). |

Players set what it plays from a **URL** in VR (the keyboard panel), synced for everyone in the session.
Works with:

- **TV** — live HLS (`.m3u8`) or a hosted `.mp4` (H.264 video + AAC audio, 1080p).
- **Jukebox** — internet radio, HLS (`.m3u8`), or a direct `.mp3` / `.aac` link.

Notes:
- **No YouTube page links** — a `youtube.com/…` URL isn't a direct stream and won't play. Use a direct
  media URL (internet radio, an `.m3u8`, or a file you host).
- Like the ready-made tools, **the screen/speaker model is ours** — your tagged mesh only sets position
  and facing (it's replaced in-game). Broadcast only video/music you **have the rights to**.
- A **live** stream stays in sync for everyone automatically; a plain file starts from the beginning for
  each viewer (perfect for radio and live shows).

## Golden manifests (developer step)

Validation compares against `Config/GoldenSkeletons/*.txt`, NOT the kit's live skeleton
asset — an FBX import can silently merge bones into the kit's skeleton and make a bad
avatar validate clean (that's exactly how AlienRanger passed in-tool and got rejected
in-game). Export the manifests from the **main game project** while its skeletons are
pristine (Developer section → pick skeleton → Export Golden Manifest), once per shipped
skeleton (UE4 mannequin + Mimic UE5 mannequin). Re-export ONLY after a base-game
skeleton change actually ships.

## Distributing to creators

Copy this plugin folder into the kit's `Plugins/` **without** `Source/`:

```
VRRealmsCreatorKit/
  VRRealmsCreatorKit.uplugin
  Binaries/Win64/          <- built by the main project (exact engine version match!)
  Config/GoldenSkeletons/  <- exported manifests ship with it
  README.md
```

Binaries-only keeps the logic unreadable (unlike the old .NET exe, which decompiles to
near-source). The kit project is content-only, so the editor loads the prebuilt module
without compiling — but the **engine minor version must match** the one that built it
(rebuild + re-ship on every UE upgrade).

`Binaries/` and `Intermediate/` stay out of git as usual; `Source/`, `Config/` and the
`.uplugin` are committed in the main project.
