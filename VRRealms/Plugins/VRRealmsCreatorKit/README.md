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
