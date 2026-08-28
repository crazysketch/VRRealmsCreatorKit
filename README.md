# VR Realms Creator Kit — v0.4.7.3 (Alpha, UE 5.8)

Build maps and avatars for **VR Realms** and publish them to the Steam Workshop.
You do **not** need Visual Studio, C++, or the VR Realms source — just Unreal
Engine 5.8 and a Steam account that has VR Realms in its library.

**New in v0.4.7.3 — your tags are applied when you upload, and the editor no longer
pretends to be the game.**

Two things went wrong within an hour of 0.4.7.2 shipping, and both are fixed.

**Tags now apply automatically.** Tick your tags *before* uploading and the upload finishes
the job — no separate button press to discover. In 0.4.7.2 the "Set Tags on Steam" button
was easy to miss entirely, and missing it left an item with no tags at all, which is exactly
what the feature exists to prevent. The button is still there for retagging later without
re-uploading, and if you upload with nothing ticked the log now says so loudly.

**Steam no longer thinks you are playing VR Realms while the kit is open.** Setting tags
needs Steam, and asking for it from inside Unreal registered the *editor* as running the
game. That meant Steam showed you as in-game, playtime piled up against the editor, Steam
could refuse to launch the real game believing it was already running — and pressing Stop
in Steam **closed the editor**, taking unsaved work with it. Tagging now happens in a tiny
helper that exists for about two seconds, so Stop can only ever close that.

Errors got a lot more useful too. `EResult 3` now reads "Steam could not reach its servers —
check Steam is online", and that particular failure is retried once automatically before you
are told about it.

**New in v0.4.7.2 — the tag check-boxes are back, and this time they work.**

They were removed in 0.4.7 for lying to you: they collected tags and handed them to
SteamCMD, which has no way to set tags and silently threw them away. The tags never
reached Steam, but the panel acted like they had.

They now go through Steam's own API instead, which is the thing that actually sets tags.
Tick what you want, press **Set Tags on Steam**, and the item is tagged — no visiting the
Workshop page, no asking anyone to do it for you. This was tested against a real item on a
plain creator account before being built, so it is not a second guess at the same problem.

Three things worth knowing:

- **Upload first.** Tags apply to an item that already exists, so the button needs a
  Workshop ID. Build, upload, then tag.
- **Steam must be signed in as the account that owns the item.** That is your Steam
  *client*, which is not necessarily the account you typed into Steam Login in the kit.
  If they differ you get a clear "this Steam account does not own the item" instead of a
  silent failure.
- **Ticked is the whole list.** Setting tags replaces them, so anything you untick is
  removed from the item. The boxes are restored from your saved item details when you
  re-open the kit, so they show what the item is already tagged.

**Personal** has its own **Access** group now, instead of being buried in Avatar Style and
Map Type. An avatar or map tagged Personal can only be worn or hosted by its owner — other
players still see you wearing it, they just cannot use it themselves.

**New in v0.4.7.1 — the kit can fetch SteamCMD for you.**

Uploading needs SteamCMD, and until now the kit assumed you already had it: the Settings
panel offered a path box and a Browse button, which is only useful once the thing exists.
Finding it, downloading it and unzipping it yourself was the first wall a new creator hit,
before they had published anything at all.

There is now a **Download SteamCMD** button next to Steam Login. It downloads SteamCMD from
Valve, unzips it into `C:\steamcmd`, and fills in the path for you — one click, then straight
on to Steam Login. If you already have it there it just adopts it instead of downloading
again, and if the download fails it tells you where to get it manually.

The button sits *before* Steam Login on purpose: without SteamCMD, Login can only fail.

**New in v0.4.7 — the Workshop tag check-boxes are gone, and that is the fix.**

They never worked. Steam's uploader has no way to set Workshop tags at all, so every tag you
ticked was collected, packed, sent, and silently dropped on arrival. The panel was telling you
your map was tagged when it was not, which is worse than not offering the boxes at all.

~~Set tags on the item's own Steam page instead.~~ **That advice was wrong and 0.4.7.2 replaces
it — see above.** There is no tag editor on a Workshop item's page for its owner; only the app's
admins get one. So between 0.4.7 and 0.4.7.2 the only way to get an item tagged was to ask. Sorry.
Nothing else about filtering changed: the in-game Filters read the tags straight back off Steam,
so whatever you tick is exactly what players filter by.

**Also in v0.4.7 — you can read the row you just clicked in VRR Updater.** Selecting a version
highlighted it in pale blue underneath pale text, so the one row you cared about was the one
row you could not read.

**New in v0.4.6.1 — two settings for ball games, both from a real match.**

**Zone → "Only reacts to".** Type a tag and nothing without it can set the zone off.
"Triggered by" answers *is it a person?*, which turns out not to be the same question as
*is it the ball?* — in testing somebody threw a rifle out of the court and it reset the
volleyball, because a rifle is an object too. For a ball game type **`VRHit`**; that tag is
already on your ball because it is what makes it hittable. Leave it empty for the old
behaviour.

**Ball home → "Serves for".** Place two home markers, one on each side, and set this to Red
on one and Blue on the other. The ball then returns to whichever team just won the point,
the way volleyball actually works. Leave it on *Always* if you only have one marker.
Worth doing: with a single home marker on one half, that side won 10 points to 2 in
testing purely because the ball kept reappearing on their side of the net.

**New in v0.4.6 — you no longer re-download the kit to get new tools.** Double-click
**`VRRUpdater.cmd`** with Unreal closed and a window lists every release, marks the one
you have, and installs the one you pick — about **450 KB** instead of the full 1.2 GB.
Drop it anywhere inside your kit; it finds the kit on its own.

It only ever writes to the kit's plugin folder and to itself. Your maps and avatars are
never touched, every download is checked before anything is unpacked, and your current
tools are backed up first. No login, no password — the repository is public and it reads
it anonymously.

**Also new in v0.4.6 — scoring zones now actually see the ball.** The first real
playtest of the game devices turned up three things, and none of them was
anything you did wrong.

**Zones could not detect a ball at all.** They saw players and nothing else — so
floor goals only scored when somebody walked on them, team scores sat at 0-0 all
match, and an out-of-bounds box never fired once no matter how you drew it. Fixed
in the game, so **your existing map just starts working**; nothing to re-place.

**A new "Triggered by" dropdown** on the Scoring zone: *Anything*, *Players only*,
or *The ball / objects only*. Pick the last one for a goal or an out-of-bounds
box and players can walk through it freely without setting it off. If you already
chose a team under "Scores for", that is assumed — a goal a player can walk into
and score isn't a goal.

**Standing on the edge of a zone no longer machine-guns points.** A body resting
right on the boundary flickers in and out of it every frame, and each flicker used
to be worth a point (a real match ended up handing out 22 points in a third of a
second). Zones now refuse to re-fire that fast, whatever the Cooldown says.

**Balls play like balls, and clients can hold them.** Hit power went up and balls
now have drag, so a spike travels instead of vanishing and you can still get under
it. And a player who *joined* your world — rather than hosting it — can finally
keep hold of a grabbed ball instead of it popping out of their hands.

**New in v0.4.5 — your map can be an actual game now.** A new **Game device**
dropdown in *Details → VR Realms* turns any actor into one of four things. A
**Scoring zone** fires when a player or a ball enters it, and you say how many
points that is worth. A **Ball home** is where a ball comes back to — stopped
dead and ready to grab. **Round rules** decide what it takes to win: a score, a
clock, teams or not. And the **scoreboard** now renders any of it, not just kills.

The part that ties them together is **channels**. Any device can *announce* a
name when it fires, and anything else can be told to *react to* that name. A goal
zone announces `Ball`; the ball's home reacts to `Ball`. So does a light, if you
want one. There is no scripting language and no graph to wire — you type a name
in two boxes and they are connected.

That is enough for **volleyball, soccer and a lap race** today. The guide at
[vr-realms.com/game-modes.php](https://vr-realms.com/game-modes.php) walks through
all three with diagrams; the volleyball one takes about five minutes.

The Workshop build check got smarter too, because most of the ways this goes
wrong are silent. It now refuses to build a map with two sets of round rules, and
warns you when something reacts to a name nothing announces, when a ball has no
home to return to, or when a map scores points but nobody can ever win. Those
used to be things you only discovered by publishing and playing.

**New in v0.4.0 — you don't need to look up tags any more.** Drag
`VRRealms/Items/BP_VRItemMarker` into your level and pick what it should be from the
**Item** dropdown in *Details → VR Realms*: a video screen, a surface screen, a
jukebox, a drawing board, a marker, an eraser, a spray can, a mirror, a button, a
rifle or pistol pad, and a **drivable car**. The placeholder immediately reshapes
itself to that item's real size and draws an arrow showing **which way it faces**,
so you can lay a room out around true dimensions and see at a glance that your
screen points into the room and not into a wall. The same panel holds the grab
options, the media URL and the sound range.

Three more dropdowns landed with it: **Game mode** (deathmatch or team deathmatch,
with sliders for score, health and damage), **Match role** (respawn points and
scoreboards), and **Movement mode** (force a locomotion style inside a Trigger Box —
climbing walls, running trails). And a **Scripting API**: a handful of Blueprint
nodes that hand you the VR player — their hands, their head, whether they're
gripping, the nearest player to a point — so you can attach a prop to someone's
hand or build your own vehicle, with no plugins in your project.

Two long-standing bugs went out with it: a tagged TV spawned an invisible screen
that never played anything, and tagging your own boombox as a jukebox deleted your
model — now your mesh stays and becomes the thing playing.

**Typing tags still works exactly as before.** Nothing you have already published
needs changing; the dropdowns write the same Actor Tags by hand. Full docs:
<https://vr-realms.com/interactables.php>

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
