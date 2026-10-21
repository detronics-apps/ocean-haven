# BlueHaven

A cozy 2D pixel-art ocean-conservation game. Start with one small island, clean up and restore the ocean around it, and watch wildlife return. Full design: `docs/GAME_DESIGN.md` — read it before adding any gameplay feature. The end goal and its steps
(islands, animals per island, exploration & fleet upgrades, cross-island effects): `docs/MASTER_PLAN.md`
— build every feature towards it. **Before designing any new island, read
`docs/ISLAND_RULES.md`** (the rules learned so far: design first and simulate, quick visible
consequences, species never disappear, island-wide balance, health range, 3-level buildings,
missions that lead to action…) and add to it whenever the user corrects something.

## Tech

- **Godot 4.7**, **GDScript only** (no C#, no GDExtension).
- Renderer: **Compatibility** (`gl_compatibility`) — must run on low-end PCs, tablets and mobile. No Forward+-only features.
- 2D only. Stretch mode `canvas_items`, aspect `expand`.
- Controls: design for touch and controller first; keyboard/mouse must also work. Use Input Map actions, never hard-coded keys.

## Game rules (non-negotiable)

- **No combat.** No weapons, enemies, killing, boss fights or combat stats.
- **Animals never die.** Rescued animals show care meters (health, fed, calm) in the care mini-game. They can go down (things can go bad, and kids should see that), but an animal never dies: health never drops below 20 % (Rescues.HEALTH_FLOOR).
- **No levels or XP.** Progress is Ocean Impact (per-area restoration); new regions unlock through restoration progress, not player level.
- **One currency: conservation funding.** No gems or other premium currency, no in-game purchases or donate buttons (kids' game). Real-world impact is a "Real Impact" page with links for parents. The one exception (the owner's choice): the Observatory's last section, Donations, after the ending: a "buy the creator a coffee" link, asking for parents' permission under 18.
- **No failure states.** Never "you failed"; say what needs more help ("The beach needs more protection") and let the player retry.
- **Conservation is positive.** Animals are cute but biologically recognisable; facts must be accurate.
- **Education never interrupts play.** Facts go in the Ocean Journal / Discovery Cards, not blocking popups. No mandatory quizzes.
- **Money comes from a healthy ocean** (eco-tourism, research, grants), never directly from rescuing an animal.
- **Progress is visible.** Restored areas change colour, sound and animal count — muted (dark blue, grey, brown) when damaged, vibrant (turquoise, coral pink, tropical green) when healthy.
- **The player is a conservation ranger**, not a superhero: no stats.
- **Avatar creation.** The player creates and customises their avatar (skin tone, face, hair style and colour, eye colour, outfit, gear, accessories, boat appearance). Build the player sprite as swappable layers from the start, so customisation never requires redrawing the character.
- **Multiple islands and regions.** The world grows: the starting island first, then five more discovered by exploring warmer (Mangrove Coast, Tropical Reef) or colder (Kelp Forest, Deep Sea, Polar Ocean) with the Exploration Ship — see `docs/GAME_DESIGN.md` "World map". The **Map** only travels to discovered islands; **Explore** (only at the ship) discovers new ones. Never merge the two. Each island is its own scene in `scenes/islands/`, placed into the world — never hard-code the world as one island.
- Playable by a 7-year-old; depth for adults comes from choices, not complex controls.

## Art

- Style reference: `docs/art_reference.webp` (the target look for a healthy ocean).
- `docs/feature_reference.jpg` shows features (avatar creator, rescue → care → release, region unlocks) only — its painted art style is NOT the target.
- 16-bit / modern cozy pixel art (SNES-inspired, not NES-retro), 32×32 tiles, larger character sprites.
- **¾ top-down view** (Stardew-style) on a square grid — not isometric. Chibi characters: big head, small body.
- Pixel-perfect: import textures with filter **Nearest**; no smoothing.
- Until real art exists, use placeholder shapes/colours. Code must not depend on final art dimensions beyond the 32×32 grid.
- Placeholder sprites get a 1-px outline in a darker shade of each shape's own colour:
  draw the SVG, then run `python3 tools/outline_sprites.py` (safe to re-run; it keeps the
  drawing in `<g id="art">`; pieces laid edge to edge, like dock planks, are skipped).
  Animals and items get a near-black one. Then run `tools/harden_sprites.gd` (godot --headless
  --script): an SVG with sloping edges (polygons) is drawn soft by Godot, so it writes a crisp PNG
  beside it (every pixel solid, the drawing's own colours) and points data, scenes and scripts at
  the PNG; the vet room's pictures are left out. Litter and other items have a lit (top-left) and
  a shaded (bottom-right) tone. The buildings sheet is cut like the owner's reworked pictures
  (cut_owner_pictures.shrink: averaged, outlines kept, snapped to the picture's own colours plus
  its bright accents), never smoothly resized.

## Project layout

Keep it shallow — never nest deeper than shown.

```
assets/<type>/<thing>/   raw art (sprites, tilesets, ui, effects)
scenes/<area>/           .tscn files — things that exist in the game
scripts/<area>/          .gd files — mirrors scenes/ areas, plus systems/
data/<type>/             game data (animals, items, buildings, islands, quests)
audio/{music,ambient,sfx}/
docs/                    design docs
addons/                  third-party Godot plugins only
```

- Files and folders: `snake_case` (`turtle_sanctuary.tscn`, `player_controller.gd`).
- A scene and its main script share a name: `scenes/animals/animal.tscn` ↔ `scripts/animals/turtle.gd`.
- Game-wide systems (save, money, quests, time, journal) live in `scripts/systems/` and are registered as autoloads.

## Code style

- Static typing everywhere: `var speed: float = 80.0`, `func collect(item: Item) -> void:`.
- `class_name` in PascalCase for reusable types; nodes referenced with `@onready var` or `%UniqueName`.
- Signals over direct references between unrelated nodes; systems communicate through autoload signals.
- Tunable numbers are `@export` vars or live in `data/`, not magic numbers in code.
- **Data, not code, defines content.** Adding a new animal, item, building or quest must mean adding a data file (Godot `Resource` `.tres` preferred, JSON acceptable), not writing a new script.
- No speculative abstractions: build what the current milestone needs.
- **Performance (the phone plays it in a browser):** never call `load()` in game code: use
  `DataFiles.res(path)` (loaded once, kept) or `preload`; `DataFiles.load_all` is cached too.
  `load()` and folder listings go to the disk / the web pack on every call, and made every frame
  lag. Per-frame code (`_process`, `_physics_process`, `_draw`) never loops over every tile or
  does a flood fill: cache it (the minimap's land picture, rebuilt only on SaveGame.tile_changed,
  which loading emits too; the Mangrove's `connected()`; SeaWaves' crests, worked out once per
  cell), and work that can wait runs a few times a second (patrol boats look for litter 4 times a
  second, the HUD's action buttons and info line 10 times, at once after a button or a jump).
  Islands the ranger isn't on sleep (`IslandSleep`, a world child: their animals, litter,
  buildings, people, trees, kelp beds, reef patches and dark areas get PROCESS_MODE_DISABLED,
  their old mode given back on arrival; the HUD skips disabled things; ecosystems keep running,
  they pause themselves). Lookups asked all the time are kept: `Terrain.island_ground` (at /
  walkable / covers), `Regions.nearest` (the islands lie in a line across: a binary search on the
  halfway points), `ControlledBody.active`. Checks over every animal or piece of litter
  (IslandHealth.count, Arrivals.grown_trees) are plain loops with the quick test first; the
  world's island check works each island's health out once for the tint and the arrivals, and the
  Clue Board checks half a beat after it. Measure with a late-game world (every island full of
  animals, litter and 6 patrol boats, the ranger running) before and after.
  Battery (the owner's iPhone got hot and ran flat in 10 minutes): phones (mobile / web_android /
  web_ios) run at 30 frames and 30 physics steps a second (ocean_world PHONE_FPS) and draw at 2
  pixels a point, not 3 (the Web Pages head_include caps window.devicePixelRatio at 2 before the
  engine sizes its canvas; touches and SafeArea work in points); every island's plain Ground tiles
  are on a drawing layer the screen leaves out (TerrainEdges.UNDRAWN_BIT), not hidden: a hidden
  tile layer drops its runtime collision (IslandGround's corner passes and boat bands).

## Workflow

- **Instructions vs discussion.** When the user says what to do (add / make / fix / change X),
  build it straight away (ask only if a key choice is really open, then just that). When they
  ask for ideas, ask what you think, or say something still needs planning, reply with a plan
  or options and wait for their pick. A message can be both: build the instructed parts, plan
  the rest. Never re-plan back what was already decided.
- **Something completely new is planned first, never built straight away.** Only build, code or
  create it when the user clearly confirms: they say "build the following" (or code it / create
  it), or it has gone back and forth over three or four chats and they then say something like
  "okay, cool, let's do this". Without that confirmation, reply with a plan and ask about
  anything that isn't 100 % clear. When building, build exactly what was asked, nothing extra
  (e.g. "show the picture from when I arrived" is that one picture, not a then-and-now comparison).
- Work in small, playable steps. After each step the game must still run.
- Commit after every working step with a clear message; never commit a broken project.
- Don't edit `project.godot` or `.tscn` files by hand when the change is risky; prefer small, reviewable diffs and say what to check in the editor.
- `.godot/` is a cache — never commit or edit it.
- Tests live in `tests/` as headless `SceneTree` scripts; run each with
  `godot --headless --path . --script res://tests/<name>.gd --quit-after 200000` (prints PASS, exits 1 on
  failure; `--quit-after` stops a test that hangs because a script failed to compile).
  In `--script` mode autoloads don't exist at compile time: don't name autoloads (e.g. `Inventory`)
  or classes that use them directly in a test — use `root.get_node("Inventory")` / untyped nodes.
  Nodes only get `_ready()` once the tree runs: `await process_frame` before using a world in `_initialize`.
- **Save game:** `SaveGame` autoload (`scripts/systems/save_system.gd`) writes `user://save.json`
  (on Windows `%APPDATA%\Godot\app_userdata\BlueHaven\save.json` — delete it to start fresh).
  Any new progress that must survive a restart gets a field in `save_to`/`load_from`, and a check in
  `tests/test_save.gd`. Bump `VERSION` if the format changes incompatibly. Only the real main scene
  auto-saves; tests never touch the player's save.
  On the web, user:// lives in the browser's IndexedDB and is only copied there when a file is
  closed after writing — so web saves are written directly (no temp-file rename), and the game
  warns if the browser won't keep saves (`OS.is_userfs_persistent()`).
  Web saves are also copied to localStorage (synchronous) and loading takes the newest copy
  (`saved_at`); a small "Saved" note flashes after each save.

## Website (GitHub Pages — where the phone should play)

The home page has "Play BlueHaven" and "Start a new game" (asks first, then opens play/?new=1;
SaveGame.attach sees ?new=1, erases the save file and its localStorage copy, and puts the address
back to play/ so a reload doesn't start over again). In the game, the Journal's "Load save code" box has "Start a new game" (asks first;
SaveGame.start_over: play/?new=1 on the web; elsewhere a button under it after Load). On the web
SaveGame.erase writes `{"erased": true}` over save.json (= no save) rather than deleting or emptying it: neither reaches the
browser's storage, so a reload brought the old save back.

The home page's picture (web/screenshot.png) is rendered by `tools/make_home_picture.gd` (xvfb):
the Starting Island as a new game starts, one of each animal, Maya and Tom at their places.

`bash tools/publish_pages.sh` exports the "Web Pages" preset (an installable PWA) to
`build/site/play/`, adds the home page from `web/` (Godot ignores it), and pushes the site to the
`gh-pages` branch (checked out as a worktree at `build/gh-pages`). Served at
https://detronics-apps.github.io/ocean-haven/. It's first-party storage, so saves survive,
unlike itch.io's iframe on iOS. The user plays it from their iPhone home screen.

**When:** not after every step — only once a batch of big, playable changes has landed (e.g. a
milestone or a major feature). Then publish and tell the user it's live.

itch.io is no longer kept up to date — don't rebuild the itch zip.

- `editor/export/convert_text_resources_to_binary` is **off**: the binary conversion silently reset
  `PackedStringArray` exports to their defaults (every building's `terrain`, crabs' habitat), so the
  phone build let docks go on land. The publish script compares all data/ in the exported .pck with
  the project (`tools/dump_data.gd`) and refuses to publish if they differ.
- Test exported builds, not just the editor: the browser caches `index.pck` (use a fresh port for a
  local server), and headless can run an exported pack: `godot --headless --main-pack <pck> --script <abs path>`.
- Loading screen: the boot splash `assets/ui/splash/splash.png` (drawn by `tools/make_splash.py`:
  the pixel BlueHaven title and a crisp line under it, see-through round them, so the one ocean
  colour #102c42 = boot_splash/bg_color fills the whole screen) and, on the web, a little pixel
  globe turning above the title and a loading bar just under that line with the game's top-view turtle swimming at its front (the Web Pages
  preset's head_include, which hides Godot's own bar; SUB_BOTTOM there = the line's bottom). Nothing about Detronics there; the subtitle is "restore the ocean, one step at a time" (the
other islands are a surprise). The HUD's Map button only shows once an Exploration Ship is built
(Fleet flag "map_shown"; older saves with another island found get it too).
- The game shows its revision (`rN sha`, bottom left) from `version.txt`, written at publish time.
- The installed app keeps the engine (`index.wasm`, ~39 MB) in its own cache across versions
  (`tools/patch_service_worker.py`, run by the publish script), so an update only downloads
  what changed. A new version switches over when the app is opened or returned to, never mid-load.

## Testing on a phone (web build over home Wi-Fi — needs firewall access)

Godot web builds need a secure context (HTTPS or localhost), so the phone gets HTTPS with a
self-signed certificate. Everything goes in `build/` (git-ignored).

1. Export (needs the "Web Single-Threaded" export template):
   `godot --headless --path . --export-release "Web" build/web/index.html`
2. Once per PC IP address, make the certificate (Git Bash; replace the IP with the PC's `ipconfig` IPv4):
   `MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 -nodes -keyout build/cert/key.pem -out build/cert/cert.pem -days 825 -subj "/CN=BlueHaven dev" -addext "subjectAltName=IP:192.168.0.111,DNS:localhost"`
3. Serve: `python tools/serve_web.py`, then on the phone (same Wi-Fi) open `https://<pc-ip>:8443` and
   tap through the certificate warning. Allow Python through the Windows firewall (Private networks) if asked.

## Milestones

**MVP 0.1 ✅** — ocean + island, walking + camera, boat, litter cleanup, inventory, one turtle,
first sanctuary, day/night, save game. (Plus avatar creator.)

**MVP 0.2 — "Home & habitat" (current).** Design: `docs/GAME_DESIGN.md` → "Home base, automation &
caring for animals". Build in this order, placeholder art:

1. ✅ Kind turtle interaction: calm approach, observe, photograph, free a tangled turtle
2. ✅ Menu bar (HUD): **Build** (what you can build now, and what's coming later), **Journal**
   (every species discovered, with what you've learned), **Change look**
3. ✅ Place-anywhere building from the Build menu; the turtle sanctuary moves to a player-chosen beach spot
4. ✅ Turtle nesting: the existing turtle lays eggs at the sanctuary → hatchlings → more turtles
5. ✅ Home base: start with a placed tent; upgrade to the house (funding). Interact with it at night to
   **sleep until morning** (Minecraft-style)
6. ✅ Funding: visitor donations / photo research money; buildings cost funding + recycled litter
7. ✅ Litter keeps washing in
8. ✅ Dock + a patrol boat that auto-collects litter in an area you choose

**MVP 0.3 — "A living island" ✅**

1. ✅ Visitor donations wait at the building (coin) until the ranger collects them
2. ✅ Dolphins (open-sea pod, curious about boats) and ghost crabs (beaches)
3. ✅ Every animal matters (rule below): dolphins — one caught in a ghost net; trusted dolphins lead
   you to floating litter after you play with them (again after each find). Crabs — one trapped in a
   plastic bag; crabs roam the beach and dig up buried litter at random spots (max 2 a day in total).
   One photo per animal per day.
4. ✅ Placement preview goes on the side the ranger faces (left/right/up/down), not only the right
5. ✅ Limit on Turtle Protection Areas; each holds a set number of turtles — extra hatchlings still
   count, but swim off into the open ocean
6. ✅ Palm trees (walk around/behind them; can't build on them)
7. ✅ Round minimap, bottom-left (Minecraft-style): the island, you, and a dot for your home (the home on
   the island you're on only)
8. ✅ Bigger horseshoe island around a sheltered lagoon; fewer crabs (2)
9. ✅ At a protection area, show its turtles (e.g. "Turtles here: 3 / 4"); turtles belong to the
   area they hatched / nested at
10. ✅ Move anything you've built: interact with it → Move → place it again
11. ✅ Voyages: rowboat limited to coastal waters; Expedition Boat (at the dock) + Map button → voyage
    map (data/regions/). (Unlocking replaced by exploring, item 24.)
12. ✅ Dolphins spread 120° around the island; they surface and dive
13. ✅ Action buttons, bottom right (stacked): one button per nearby action (free / photo / sleep / move / board) so the
    player chooses; E still does the most important one
14. ✅ Web saves also go to localStorage (instant) + a "Saved" note
15. ✅ Placement snaps to the nearest spot that fits; Expedition Boat moors next to a dock plank;
    patrol boats go round docks
16. ✅ Hatchlings fill empty protection areas before leaving
17. ✅ Recycling centre (litter -> funding); cut down / plant palm trees; drawbridge; shovel tool
    to scoop up beach sand and place it on shallows (sand isn't litter: ItemData.is_litter)
18. ✅ Save code (Journal): copy progress as text, paste it back; GitHub Pages site (installable)
19. ✅ Wood: cutting a palm gives 1 wood + 1-2 saplings (planting needs a sapling); buildings cost
    wood + litter + funding; carry 3 wood / 3 sand; Ranger Houses (up to 2) store 10 each; up to 3
    recycling centres; sand on deep water makes shallows (2 sand to make beach)
20. ✅ Building upgrades, 3 tiers each (buildings, not the player — no player levels): protection area
    +1 turtle per tier, Ranger House +1 storage per tier, recycling centre +1 funding per piece per tier
21. ✅ Up to 3 expedition boats (patrol boats were already unlimited)
22. ✅ Growing palms: a planted sapling grows small -> medium (after 1 day) -> full grown (after
    another day). Cutting it down gives: small = the sapling back; medium = 1 wood + 1 sapling;
    full grown = 1-2 wood + 1-2 saplings (the island's own palms are full grown)
23. ✅ Six islands (shape, size, colours only — animals, plants, mechanics later), painted by
    `tools/generate_islands.gd` (re-run it to tweak a shape), each with a little map in the Map menu:
    Starting Island (horseshoe; north half kept so saved buildings stay on land), Kelp Forest
    (crescent), Mangrove Coast (branching fingers, mud), Tropical Reef (broken ring, lagoon), Deep Sea
    (rocky hook), Polar Ocean (ice floes, rock). **Ground tiles are plain and shared: sand, grass,
    rock, ice, mud. Water: shallow, mid, deep (open ocean, no tile).** Coral, kelp and mangroves will
    be plants on top, never ground tiles.
24. ✅ Exploration (docs/GAME_DESIGN.md "World map"): the Exploration Ship (id expedition_boat)
    offers Explore warmer / colder → the next island that way not found yet, sailing on past found
    islands that have their own ship (`Regions.frontier`, along `Regions.next_from`: the islands lie
    in a line Polar, Deep Sea, Kelp, Starting, Mangrove, Reef; RegionData.direction + order; the
    owner: colder from the Reef must work), which is then discovered for good (saved) and reachable
    from the Map. To go further you need a ship on that island: a found island without one stops the
    way (no skipping ahead). And the fleet
    finds only one more island than its level (`Regions.can_find_more`: Level 1 finds the 2nd island,
    Level 2 the 3rd...), so every island found is helped before the next. The Map only shows and sails to discovered islands, listed coldest at the top to warmest at the bottom (`Regions.coldest_first`); undiscovered ones aren't on it at all, not even how many there are (the owner: each is a surprise); a 🧭 marks islands
    with an Exploration Ship. One ship per island (built by the player; `one_per_island`).
25. ✅ Island objectives & the fleet (MASTER_PLAN Step 1): each island's objective (RegionData.goals:
    ObjectiveGoal "help" a species / "litter" collected ever) must be done before its Exploration Ship
    can be built (BuildingData.needs_objective), and finds its discovery (data/discoveries/). The
    `Fleet` autoload keeps objectives done, discoveries found / installed; installing one at any ship
    upgrades every ship (equipment level = installed; BuildingData.fleet_textures). Exploring needs
    the next island's RegionData.requires installed. Starting Island: the wreck (MVP 0.4 item 7)
    → Salvaged Sonar Core. Islands with no objective yet: no ship. Shown in
    the Journal and the Build menu. Loading removes ships whose objective isn't done (funding
    returned) and re-locks islands found without the upgrade they need.

**MVP 0.4 — "Starting Island complete" ✅** Details: `docs/MASTER_PLAN.md` → "Build order",
Step 2. Build in this order:

1. ✅ Island health (`IslandHealth`, 0..1 per island): weighted RegionData.health factors
   (HealthFactor "clean" = litter within rowboat reach, "animals" = healthy residents: not hurt,
   caught or visiting; no oil). 100 % = no litter, no hurt or caught animals, fully populated
   (Starting Island: 6 turtles, 3 seabirds, 2 crabs, 2 dolphins). Ground colours go from muted to full with it (checked every 2 s); shown in the Journal.
   The Starting Island starts with 1 turtle, 1 crab, 1 dolphin and 50 litter (new game:
   `start_litter`; every other island's first visit brings 45: RegionData.arrival_litter); more animals arrive as islands recover (RegionData.arrivals, `Arrivals`, saved):
   2nd crab at 40 % health, 2nd dolphin at 65 %, then dolphins 3–5 and crabs 3–4 as 1–3 other
   islands become healthy (≥ 70 %).
2. ✅ Wildlife Conservation Parks (funding facilities, BuildingData.facility = "funding", shown in
   gold in the Build menu): up to 3 Turtle Protection Areas + 1 Dolphin Viewing Area (visitors per
   dolphin in view: `watches`). Morning funding (Building.visitors_today) × (1 + island health).
3. ✅ Marine Search & Rescue Station (signature facility, one per island, `only_on` the Starting
   Island): sends missions (data/missions/, MissionData; `Missions` autoload, one at a time, saved)
   for funding — rescue boat (animals in distress), pollution survey, turtle monitoring, dolphin
   tracking. Back after a few hours; what it found is marked on the minimap until the next morning.
4. ✅ Pollution types: entangling litter (ItemData.entangles) left near animals that can get caught
   (AnimalData.can_tangle) catches one each morning; oil patches (ItemData.ranger_cleans: only the
   ranger's boat cleans them; a "clean" health factor with a target); dolphins keep away from patrol
   boats (AnimalData.boat_shy_distance); turtles won't nest at a protection area with another
   building within 2 tiles (BuildingData.needs_quiet; docks and trees are fine)
5. ✅ Seabirds (red-footed boobies; AnimalData.flies / circles_litter): arrive by trees
   (ArrivalData.needs_trees / stay_trees: now 8 full-grown trees a bird to come, 4 to stay), fly off while there are too few and
   come back when palms regrow (never while tangled); circle over floating litter near home; can
   be caught in litter; a health factor
6. ✅ Upgrade art: BuildingData.tier_textures (a picture per tier: Ranger House, recycling centre,
   Turtle Protection Area; placeholders)
7. ✅ The wreck (WreckSite, off the west coast): hidden until the station's coastal survey finds
   it; its 8 pieces of litter are cleared from the boat; then its old sonar unit is lifted into
   the boat. The Starting Island's objective is now these three flags (ObjectiveGoal "flag",
   Fleet.mark) → Salvaged Sonar Core
8. ✅ Coastal Storm, the first rare event (data/events/, EventData; `RareEvents` autoload, saved):
   never within 30 days of the last (2 % a morning after that: ~1–2 per 120-day year); warned a day
   ahead (HUD banner); "Secure for the storm" on buildings (not storm_proof ones); unsecured ones
   may be damaged (no visitors / nesting / missions / recycling) until repaired with 1 wood; litter
   washes up; unprotected nests are washed over (1 egg hatches) and up to 3 turtles / seabirds
   are injured (never badly) until a Rescue mission helps them (MASTER_PLAN "Rare events")

Tweaks after 0.4: upgradable buildings show "Lv N/3" (the Make menu says "Each upgrade: ..." under
the build cost; the building's button stays just "Upgrade": buttons are actions, not notices); a Ranger House stores 4 / 8 / 10 of each by
level (BuildingData.storage_per_tier); saplings: carry 5, storable, spare ones given to coastal replanting at the Research
Station (BuildingData.accepts, ItemData.grant_value: 5 funding each); Research Station 400 funding
+ 20 litter + 10 wood, Exploration Ship 600 + 20 litter + 8 wood (exploring itself stays free).

Second batch of tweaks: litter only washes in within rowboat reach and drifts in towards the
island (out-of-reach litter doesn't count for health); hatchlings grow up (AnimalData.grow_days)
and spread out over the island's waters, keeping away from patrol boats; seabirds nest in one
full-grown palm each (move the nest before cutting it; perched picture); station missions are
real minutes and respond to the island (MASTER_PLAN Step 2 item 3: rescue, boat patrol, pollution
survey, turtle monitoring, dolphin tracking, coastal survey 20 % / sure by 5th); oil patches wait
for the Deep Sea's Deep-Ocean Outpost; Journal tabs (This island / Animals); Build menu lists only
this island's buildings (`only_on`); shovel digs up litter 10 %; patrol-boat pickup count; action
button dead zone; portrait-phone bottom margin.

**MVP 0.5 — "Kelp Forest" (current).** Design: `docs/MASTER_PLAN.md` → "Kelp Forest" and the
ecosystem principle (buildings create conditions, animals respond; limits aren't targets;
research leads to action). Built so far:

1. ✅ Coastal trees (own scene + `coastal_sapling`, same growth/cutting; `PalmTree` script with a
   `sapling` export); palms `only_on` the Starting Island
2. ✅ Kelp beds (`KelpBed`, placed by `KelpEcosystem` on the island's water tiles, saved via the
   "ecosystems" group): urchins graze and multiply, kelp regrows where grazing is low; ticks every
   `tick_days` of game time (sleep catches up); only once the island is discovered
3. ✅ Sea otters + Otter Habitat (BuildingData.hosts / animal_capacity 2 / upkeep / demolishable,
   max 6): every tick otters settle (newcomer or pup) while the island's `food` supports them and
   move away (never die) below `leave_below`. Island-wide, never placement-based: urchins and
   kelp approach the balance the otter count allows (`urchin_target` / `kelp_target`), half the
   way per `half_life_days` plus an `instant_share` nudge on every change (settles in 3–4 days).
   Restoration Sites restore the most damaged beds anywhere (`restores_beds`); the Discovery
   Centre counts all the island's otters (watch_range 0)
4. ✅ Blue rockfish follow healthy beds; double-crested cormorants follow fish and need full-grown
   trees to nest in (one change a morning)
5. ✅ Kelp Research Platform (signature) and its 7 missions (MissionData.effect handled by
   `KelpEcosystem.run_mission`; `Missions.last_report` shown at the facility)
6. ✅ Kelp Restoration Site (BuildingData.restore_range, max 4) and Kelp Discovery Centre (funding,
   watches otters, max 2)
7. ✅ Island health: HealthFactor "kelp" (condition %) and "balance" (no overgrazing, some urchins),
   otters 4, fish 8, cormorants 3, clean water
8. ✅ Heavy Swell (EventData.kelp_damage / visibility_days: missions 1.5× slower); events are warned
   only for discovered islands, and "Secure" only shows on the island it's heading for
9. ✅ Objective: balance (flag at 70 % health) → gather 5 shed kelp (ItemData.counts_as, ObjectiveGoal
   "count") → Kelp Fibre
10. ✅ Cross-island: clean Starting Island water speeds kelp regrowth (`upstream_boost`)

Then: urchins also follow their food (boom and bust; `urchin_starved`), no species ever drops
below 1, the island starts with every species struggling (a tangled otter, 2 rockfish, 1
cormorant) and a litter surge on every first visit (RegionData.arrival_litter); the urchin
balance scales the whole island's health (HealthFactor.scales_all; too_many for otters); the HUD
health gauge shows now vs where it's heading (IslandHealth.heading / KelpEcosystem.project);
buildings can be used from the rowboat; patrol boats (max 6, area 120/160/200 by tier) hurt
boat-shy animals when under 65 % of the island's water is free of them; 3 Dolphin Viewing
Areas; 10 turtles for full health; mission icons (MissionData.icon); Journal Plants tab
(data/plants/). (The Journal's Ocean tab was removed: the Global Ocean Observatory shows the whole ocean.)

Balance tweaks: islands the ranger isn't on are paused (no tangling, patrol injuries or
ecosystem change; a little litter on return; `Regions.ranger_on`); one recycling centre per
island; tangled seabirds wait on their nest; mission cards count runs per island; sea otters carry
floating litter near them ashore (AnimalData.carries_litter_ashore). Rare events: a random 30–60 days apart
(EventData.min_gap_days / max_gap_days); see "Storms" below for how they play out now.

**MVP 0.6 — "Mangrove Coast" (current).** Design: `docs/MASTER_PLAN.md` Step 4 (draft 2, approved).
Built so far: the shovel digs mud (carry 3, storable; mud on shallows makes flats); red mangroves
(propagules, only in mud); `MangroveEcosystem` (island child "Ecosystem"): 5 inland nursery pools
cut off by silt (flood fill from the open sea; closed Water Gates block it), silt settling in dug
channels (fast where water stands, slow where it flows, less beside full-grown mangroves and with
a few crabs, faster with too many), water level from open/closed gates (flamingos feed and build
mud-mound nests when it's right), young snappers per nursery pool (linked + mangroves), Crab
Habitats (runaway crabs), Crocodile Protection Zones (patrol boats keep out:
BuildingData.keeps_boats_out), Eco-Lodge; Waterworks Station with 6 missions and a "How it
works" card (BuildingData.guide); HealthFactor kind "eco" (the ecosystem scores it); Flash Flood
(EventData.flood_silt); objective: water flowing (4 pools linked, 70 %) -> 5 resin -> Mangrove
Resin. All building limits count per island.

Boats: every island starts with its own rowboat (world nodes Boat, KelpBoat, MangroveBoat…);
nothing sails along on voyages and every boat stays where it was left (saved). Up to 2 extra
Rowboats per island (building holding a Boat), each needing 2 dock planks on the island
(BuildingData.requires_each); an island keeps 3 rowboats at most (BuildingData.keep_boats): a
4th can always be built and one of the others (never the ranger's or one in tow) goes back to
the boatyard at random (BuildMode.let_boats_go; an island's own one is retired: Boat.retire,
saved "retired_boats"), e.g. when one was left stranded far out at sea; the ranger boards the nearest boat. From a boat the ranger can take
another boat in tow ("Tow the other boat" / "Let go"; Boat.towing) and use the shovel (dig a
beach or fill water from the boat). The bottom UI keeps clear of a phone's corners in portrait
and landscape, and the web page re-measures the window after the phone is turned.

Litter: only tents, Ranger Houses and recycling centres (6 litter, and 6 per upgrade:
BuildingData.upgrade_litter) are built with litter; everything else costs funding and wood (its
old litter cost added as 3 funding a piece). A recycling centre opens a menu (RecycleMenu):
recycle 25 / 50 / 75 / 100 % of the carried litter. Mangrove gate spots (narrow channels, one tile wide, with water on both sides and at least
`gate_water_behind` (2) tiles of it on one side) are
marked with posts and offer "Build a water gate here". Menu scroll bars are finger-wide.

**MVP 0.7 — "Tropical Reef" (current).** Design: `docs/MASTER_PLAN.md` Step 5 (the user's spec,
draft 2). `ReefEcosystem` (island child "Ecosystem"): 10 `ReefPatch`es whose coral grows back as
far as it's planted (coral fragments from Coral Restoration Sites, planted by hand from the boat)
and as fast as clear water (litter, giant clams) and grazing parrotfish allow. Each animal has a
job: parrotfish build the sea floor up (deep → mid → shallow → sand, max 3 a day / 40 ever) for
the Glassworks; giant clams in a Marine Water Treatment Facility make Clean Water each morning
(BuildingData.makes / makes_per_morning); a reef shark circles hidden ghost gear until the ranger
comes close; seahorses live in Seahorse & Seagrass Protection Areas once the seagrass has grown.
The Glassworks is a capability, not an item: 3 sand once (BuildingData.makes_from / made_flag
"glass_made"), then extra sand sells for funding. Glass + clean water made = reusable bottles
(`Fleet.reusable_bottles()`): no new plastic bottles drift in on any island. Clean Water is stored at the tent or
house ("Store N clean water"; `ControlledBody.water_until`, saved, shared by every island): while
any bottles are left the ranger and boat move 30 % faster; each lasts half a day (2 a day); a
blue WaterGauge under the health bar shows the bottles once clean water can be made. Coral Restoration Laboratory with 8 missions; Reef Diving Centre;
Shark Protection Zones; Hurricane; objective: 70 % → 5 dead coral rubble → Reef Limestone
(Underwater Habitat Mapping System). A patch at full coral can be split (ReefPatch.split: it drops to 35 % and a
new 35 % patch starts on free shallow water beside it; less coral in all), any patch can be
moved by boat (towed behind it, then set down on free shallow water), up to 30 patches
(ReefEcosystem.max_patches; positions saved); coral health is all the coral added up against
the first 10 patches, so a bigger reef never lowers it, and supports more parrotfish; spare
fragments go to the Coral Restoration Laboratory for 5 funding each (BuildingData.accepts). The Hurricane also tears up seagrass in battered
Protection Areas and washes parrotfish sand back into the lagoon. Every rare event shows its own
weather when it strikes (StormWeather; EventData.weather: storm / swell / flood / hurricane). The
ranger has a walking animation (bob, sway, stepping boots).

**MVP 0.8 — "Deep Sea" (current).** Design: `docs/MASTER_PLAN.md` Step 6 (draft 1, approved).
`DeepEcosystem` (island child "Ecosystem"): 8 dark areas (`DeepSector`, a veil over their deep
water) mapped island-wide by instruments (no levels: they're there or not): Hydrophone Buoys (quiet; whales' clicks boost them),
Deep Cameras (lamps light the dark; anglerfish let them use less; "Bait the camera" draws
sixgill sharks: too many) and submarine dives from the Deep-Ocean Outpost (mark an area from the
boat; noisy for a day; faster with the Reef's mapping system: MissionData.faster_with). Light and
noise make the quiet water (`quiet()`, HealthFactor "quiet" scales_all): whales and anglerfish
move away (never below 1), the giant squid only shows to a camera watching the mapped canyon in
quiet water for 2 days. Mapped areas show their habitat and lost gear (lost longline / ghost net
items, counts_as "deep_gear"); a sixgill with a hook surfaces some early; 3 recovered = the
evidence (`Fleet` flag "gear_recovered"; new deep gear sinks until nets are stopped). Deep-Sea
Sanctuaries (+1 of the area's animals, no new gear), Deep-Sea Discovery Centre (watches whales),
shore pines (`pine_sapling`). Oil Spill (EventData.oil_patches / needs_building): spreads each
morning until the Outpost's "Contain" mission. Objective: 6 areas mapped at 70 % -> Cargo search
-> tow the module in -> Cargo Module (the ships' cargo hold).

**MVP 0.9 — "Polar Ocean" (current).** Design: `docs/MASTER_PLAN.md` Step 7 (Arctic, approved).
`PolarEcosystem` (island child "Ecosystem"): a 3-day ice season (`cycle_days`; freezing,
frozen, thawing, open water, shown on the HUD gauge via `status_note()`): rings of water round
the old ice freeze and melt (`apply_ice`, every change through `SaveGame.record_tile`); boats keep
water near them open and, while it freezes, leave a lane of broken ice (`_wake`) that can cut the
corridor between floes. Ringed seals need Seal Pupping Zones on old ice (zones on seasonal ice
lose their pups when it melts; `planning()` scales all health; crowded seals eat the cod down);
polar bears stay with a Quiet Den Area and a joined freeze (`corridor_score`); Arctic cod follow
the ice; Arctic terns nest on rock in the thaw and visit the ranger's other healthy islands in
the freeze (visiting); the Arctic skua circles trouble. No trees: wood comes from storage.
Polar Research Station with 7 missions and a "How it works" card; Polar Research Centre; Major
Ice Breakup (EventData.ice_breakup: old ice broken off until the next freeze). Objective: 70 %
-> Ice Core Drill Site on old ice for 3 days -> Ice Core. Tents, houses and recycling centres can
go on rock.

**MVP 1.0 — "People & story" (current).** Design and build plan: `docs/GAME_OVERVIEW_FOR_REVIEW.md`
(sections 6–16; story rules in `docs/ISLAND_RULES.md` section 9). Phase 1 built: people
(`data/people/*.tres`, PersonData with TalkTopics; names live there) on the Starting Island:
Dr. Maya Okafor (Researcher, objective-giver, field camp → by her station: `moves_to`) and Tom
Pieters (Lighthouse keeper, hint-giver, lighthouse on the south-west tip). `People` autoload:
objectives only come from people; a question (TalkTopic.objective, ObjectiveGoal kinds now also
"photos", "built", "installed") becomes the objective DELAY seconds after the talk
(`finish_talk`); done → "Go back to Maya" → thanks + the next. Everything is worked out from the
game state (TalkTopic.when conditions, `People.check`), so questions the ranger has got past are
skipped and old saves meet everyone where they are; only met / asked / thanked / told are saved.
Person nodes (spawned by the world, group "people") block building on them and their place;
TalkBox shows the talk (tap through, "< Back" for the line before; the game waits). Tom's tracks story (`marks`
"tracks_noticed") makes turtle tracks show from nests to the sea. On islands with people the goal
line is `People.goal_text`.
Then: the ranger has a name (avatar creator; RangerProfile.ranger_name, saved) that people use
("{name}" in lines); the ranger's replies are 2 options to pick ("> A | B"); a question can be
`stuck` (e.g. Build menu opened, nothing built: Maya sends the ranger to Tom, who says to cut
palms for wood and plant a sapling for each); the station is the Marine Search & Rescue
Station; the tent is one tile; the Build menu shows only name, BuildingData.summary and cost;
new animals arrive gradually (see Births: breeding pace), and seabirds need trees
(health 30 / 50 / 70 %). Tree-nesting birds (boobies, cormorants) need 8 full-grown trees
for each bird to come (the 2nd at 16, 3rd 24, 4th 32: Arrivals.TREES_TO_COME) and 4 each to
stay (TREES_TO_STAY; Arrivals.birds_for_trees); the Starting Island starts with 14 palms, at
most 4 boobies.
Phase 2: a 120-day year of four 30-day seasons (GameClock.season / year / calendar: the HUD
reads "Day 42 · Summer, year 1"; a note when each season starts). Green turtles nest in spring
every 4 days (AnimalData.nest_season / off_season_interval_days 40), one hatchling per nest
stays (stay_per_nest; the rest swim off into the open ocean, a storm-hit nest's one too),
hatchlings take 8 days to grow up and nest from the next spring (nests_from_next_season):
about 8 turtles by day 30, 10 late in year 1 or early year 2 (simulated).
Phase 3: ranger activities (data/activities/, ActivityData; `Activities` autoload: story done +
personal bests per level, saved; ActivityScreen base: start page, timer, levels, finish).
Sonar Sweep (Grid; SonarSweep): opens at the Marine Search & Rescue Station once Maya asks about
the wreck (or it's found); the story play finds the wreck (reward_group "wreck_sites" /
"reveal"); replays are for fun only (5 levels, pings +1 s, best times). Minesweeper (the owner):
ping all the clear water to finish, marked or not; pinging a hidden thing runs the boat over it
(3 hearts; none left: back for a repair, another go); Mark puts a free buoy on a square (tap
again to take it away; a buoyed square isn't pinged); the first ping is always open water.
Phase 4: rescue companions (data/rescues/, RescueData; `Rescues` autoload, saved): one young
animal at a time, one per island, found once RescueData.offer_when holds (Starting Island:
a young green turtle once the rescue station is built). The ranger names it at the station
(RescueScreen); a care moment a day (two choices: the other only explains why not); stages
over 30 days, also while the ranger is away. Released, it lives on its
island with its name (world node "Rescued_<id>", respawned on load) and is listed in the
Journal's This island tab.
Phase 5: people on every island (data/people/, 12 in all), each island an objective-giver whose
questions are its existing objectives, ending with "build the Exploration Ship and fit the
discovery" (Finn, Diver; Rosa, Fisher; Kai, Engineer; Dr. Imani Osei, Pilot; Dr. Sanna Lind,
Expedition leader) and a hint-giver (Ines, Harbour cook; Samuel, Boat builder; Leilani, Dive
guide; Bram, Retired captain; Erik, Weather watcher) whose hints send the ranger on round the
chain Tom → Ines → Samuel → Leilani → Bram → Erik → Tom. The Tip button and the old flagship
goal line are gone: the goal line is always People.goal_text.
Phase 6: more ranger activities, each introduced by an island's objective-giver, its story play
doing one of the island's research missions at once (ActivityData.reward_mission,
Missions.run_now); some have their own place (ActivitySpot, e.g. the old jetty): Otter Dive
(Finn, old jetty on the Kelp Forest; urchin pressure survey: 5 urchins, out of air just floats
up; then levels of 10 / 20 / 30 / 40 / 50 urchins as fast as you can, 0.5 s less air each
level, and staying under with no air costs a heart like litter does: 3 hearts; the most
urchins is the record until all are collected, then the best time; the story sets no level
time: ActivityScreen._story_sets_time; old endless-level records start fresh on load), Channel Flow (Rosa, Waterworks
Station; water flow survey; boards built with a way through), Echo Dive (Imani, Deep-Ocean
Outpost; cargo search: reach the sea floor (the sub climbs the screen fast enough to go back for something missed; jellyfish and
boulders to avoid), then faster and faster. The view sinks by itself
and never goes back up; the lower the sub is on the screen the faster it sinks; below the
sunlight only the sonar light shows anything, on 90 % of the time at level 1 down to 50 % at
level 5; lost gear sinks slowly (1.5 s off each); 3 hearts, one lost per bump (walls, wrecks,
boulders), wrenches deeper down repair one; out of hearts the sub heads back up and the depth
reached is the level's record (Activities.reached, saved) until its floor is reached, then the
time is; the game's own animal sprites at their real depths; levels 1,000 to 5,000 m, faster and
with more obstacles each), Floe Fit (Sanna, Polar Research Station; drill
planning; floes cut from a real filling, placed floes can be taken back). Glass Sort waits for
phase 9 (Kai's bottle story).
Phase 7: rescue companions on the Kelp Forest (an otter pup separated from its mother; Finn,
Kelp Research Platform), the Mangrove Coast (a flamingo egg left behind; Rosa, Waterworks
Station) and the Polar Ocean (an orphaned ringed seal pup; Sanna, Polar Research Station):
data only (data/rescues/), each found once its building is up and the ranger is there
(condition "here"); still one at a time. The Reef's and the Deep Sea's wait for the owner's
choice of species.
Phase 8: photo moments (AnimalData.moments: PhotoMoment, 2-3 per species, conditions checked
by Animal.moment_holds: young, nesting, digging, guiding, perched, surfaced, on:ice...): the
first photo of each is kept (a 160x120 crop of the screen, user://photos; Journal.photos_dir,
tests point it elsewhere) and shown in the species' Journal page, missing ones as hints; a
seasonal moment's photo is a bonus 4th (PhotoMoment.bonus: not counted, shown only once taken, in
a gold frame; the clam, the whale and the tern have 3 everyday ones besides); Maya
mentions the collection. Released rescue companions that travel (RescueData.visits: the turtle
to the Mangrove Coast and the Reef, the flamingo to the Reef) turn up for a day on the
ranger's island, only while both islands are healthy (70 %), at most every 6 days; sightings
are listed in the Journal.
Phase 9: litter at its source. Inventory.picked counts litter picked up per kind (saved,
"litter_picked"); two new kinds: six-pack rings (entangle) and foam boxes. After each island's
story its objective-giver asks where one kind comes from (TalkTopic.when "picked:X>=12",
"installed>=2"...; `marks` e.g. "rings_asked"), an Investigate mission (MissionData.effect
"investigate", show_flag / marks_flag) finds out, and a fix building appears in the Build menu
(BuildingData.needs_flag) that stops it on every island (BuildingData.stops_litter;
`Fleet.stopped(id)` / `stopped_by(id)`, ObjectiveGoal kind "stopped"; the LitterSpawner skips stopped kinds;
the recycling centre's menu lists every kind: picked up, carried, stopped by what or still washing in).
Finn: rings -> Trace the rings -> Lemonade Refill Station (Ines: lemonade from refill jugs; never kegs or a "bar": a kids' game). Rosa: bags -> Trace the bags
-> Weaving Workshop (Samuel: nipa palm baskets). Maya: foam boxes -> Trace the foam boxes ->
Box Return Depot (Tom: crates that go back). Kai: bottles (reusable bottles). Imani: fishing
gear: bring up 3 pieces (who lost them? none is marked) -> Trace the lost gear (Outpost) ->
Net Return Point on the Deep Sea (Bram: nowhere to take old nets; old nets recycled, new ones
marked: stops ghost nets and fishing line; older saves' "gear_marking" becomes "gear_recovered"). Sanna: the threads in the ice core -> Look at the fibres -> Kai's Filter
Workshop on the Reef ("microfibres", not an item). A question that can't be asked yet never
counts as done, so a problem solved early (reusable bottles, lost gear brought up) doesn't skip an
island's story.
Phase 10: seasonal moments (data/seasons/, SeasonEvent: the coral spawns on summer nights 8-10
on the Reef, sperm whales pass the Deep Sea in autumn 10-14, the Arctic terns arrive in spring
2-6): the HUD says so once a year on that island (Fleet flag "seen_<id>"), SeasonShow draws it
round the species (pink spawn, slanted blows, a flock), a photo moment ("event:X": the giant
clam, the whale, the tern), the island's hint-giver mentions it a week ahead (condition
"soon:X") and the Journal's This island tab lists them ("Through the year"). Predict, then
watch: an objective-giver's topic with `outcome` / `outcome_when` is a prediction, asked along
with a reminder (never once what it predicts has happened); the ranger's reply is kept as the
guess (People.chose from the TalkBox; saved "guesses"/"outcomes"), and once it happens they say
what really happened. The Journal shows "Your predictions" beside the guesses. No score.
Phase 11: the ending, not "You won". With all six discoveries fitted every Exploration Ship is
an Ocean Research Vessel (ExploreMenu title) and the Map opens the Global Ocean Observatory
(ObservatoryScreen): the six islands as they lie (Panorama) with arcs for the links the ranger
has made (clean water -> kelp, mangrove fish -> reef, terns, each fix stopping litter
everywhere, fibres -> the polar ice, travelling rescues), every island's health and the whole
ocean's. Once every kind of litter is stopped at its source too (`final_chapter()`), it asks
"You've helped every island. What have you learned?" with observations from the ranger's own
game, then "One ocean. Many places. Everything connected." and each person's closing line
(their "ending" topic, which they also say afterwards: flag "observatory_opened"). Maya's last
question ("observatory") is answered by opening it. Play goes on.
The Observatory's layout (the owner's): fixed at the top, the six islands with the white
routes joining them (Panorama) and each one's health under it (tap one: its start picture, the same for everyone:
assets/ui/islands/<id>_start.png, rendered by tools/make_start_pictures.gd from a new game's
world with every island found, photographed itself (ground art, rounded and height edges, waves,
its start litter, its few starting animals and its people; RegionData.start_frame), with the
ranger's avatar drawn at true size where they land (the owner) and the day they first got there
in the title (Journal.arrived_day, saved "arrived_days", noted by Explore); + / - and arrow buttons zoom and
pan); below, scrolling, the whole ocean's health and sections that drop down one at a time (open_section): How the
islands help each other (Panorama + links(): clean water, fish, terns, travelling dolphins /
whales / turtles, seeds, seagrass grazing, mapping, cargo, each fix, fibres, rescues), and in
the final chapter You've helped every island (helped_stats + observations), What we hope you
have learned (LEARNED: short and to the point: appreciate nature and its complexity, and help
it find its balance in the future; never facts about the animals; + the motto), Who you have met (each person's picture, name, job,
closing line), Your ocean poster, End credits (x1-x5), Donations (buymeacoffee.com/detronics,
detronics.co.za).
The prize: the final chapter shows the ocean poster (assets/ui/poster/ocean_poster.jpg) with
"Download your ocean poster" (`ObservatoryScreen.download_poster`: the browser's download on the
web, the Pictures folder elsewhere); before it, "Still watching" says a poster waits there.
The first time the final chapter opens, the screen goes black and the end credits roll
(EndCredits: data/ending/final_word.tres, CreditsData; centred gold text rolling slowly up and
away, stars; a tap doubles the speed, Close or the end returns; Fleet flag "credits_seen"); the
Observatory's "End credits" button plays them again.
Phone-play fixes (docs/ISLAND_RULES.md 9b): every species starts with one (a tangled booby,
Seabird0) and nothing new arrives or settles until the ranger has helped the island
(`Regions.helped`, Inventory.picked_on, saved); TextPrompt asks the browser for typed names on
the web (phone keyboard); the shovel shows green (dig) and blue (fill) tiles at once and a tap
does it; swimmers don't collide with tiles (wading shallows did) but stop where the water ends;
CameraZoom (pinch, wheel, zoom_in/zoom_out, + / - buttons; saved); notes move up above the
action buttons; Ranger House drawn 1.5 tiles, people's places bigger; Imani at Dive Control on
the shore (people never stand in the water); patrol boats rest off-island, are demolishable, and
on the Deep Sea are noisy only over dark areas (patrol_noise / patrol_noise_away); unmapped dark
areas always show a dashed outline and "N% known"; the ship's build message names the next
story step and who to ask; hint-givers asked the same thing twice point at what's holding the
island back (IslandHealth.weakest + ecosystem `advice()`); Polar buildings that go on rock can go
on ice; terns nest on rock and sit (AnimalData.nests_on_ground); stores offer "Store everything"
and "Look in storage" (no taking out: the shovel and coral use storage like building does);
Journal list = picture on a light tile, name, AnimalData.role; tap for the animal's page
(photo moments, real-life facts); "Only what I've found" toggle.
Second phone batch: zoom has five fixed steps, only the + / − buttons (or keys; no pinch); a
tap walks the ranger all the way, a held finger is followed; photos crop 4 x 3 tiles round the
animal through the camera and window stretch, and every moment it's in keeps the latest photo;
rescues are 6 days in the vet room (VetScene: on a towel on the counter, or a fish tank for
RescueData.tank animals; it breathes, blinks and grows a little every day: Rescues.growth;
egg-layers, RescueData.from_egg, hatch once named: the turtle and the flamingo; the sixgill is
born live, so it's a pup): care is done by hand, dragging the tray's things to it (food to its
mouth or shaken over the tank: sprinkle; stroke or place: comfort_kind / comfort_tool; the
plaster on wound_at; the dropper; buttons below too): feed / comfort /
patch / medicine raise Health, Fed and Calm, and they can drop again (see "Care bars" below); it goes home tagged
(TagBand) in the shape the care left it in, which sets how often it's about each morning
(Rescues.check_visits: its island or RescueData.visits, never elsewhere; "Rescued_<id>",
ocean_world.place_tagged), its name showing once met again; rescues for every island (Reef
seahorse, Deep Sea sixgill pup); hint-givers alternate island clues with pointers to anything
open elsewhere (People.open_things); after what they say, people add (once a day each) what to do
when funding (< 60: their island's funding facilities, upgrade the recycling centre) or wood (< 3:
cut grown trees, replant, mind nests; or stored wood from an island with trees; only while
getting started: before the fleet's first upgrade, People.WOOD_TIPS_UNTIL) runs low, and
island news the ranger may have missed (People.add_news: rescued visitors, hatchlings, a species'
first newcomer; told once, within 3 days); the giant squid has a step-by-step hint (DeepEcosystem.squid_hint: map the canyon, a camera, 70 % quiet,
2 days on the island; Bram's squid topic "{advice:giant_squid}", condition "journal:X"); Glass Sort (GlassSort, Kai, the Glassworks: water-sort
puzzle, opens when the furnace is firing, story play finishes the first batch).
Every ranger activity is a drawn, living scene, not a grid of buttons: Sonar Sweep (the sea by
the shore from above, waves, fish shadows, gulls, the boat gliding to each ping, rings, sea floor
and buoys), Channel Flow (mud flats, pieces swing round, water runs along linked channels, a young
snapper swims into each linked pool, mangroves and a wading flamingo), Ice Match (sea ice and
snow, a seal on a floe, pieces slide, burst and fall, combos), Glass Sort (the Glassworks:
furnace, glass pieces arcing between jars, corks on sorted jars), Otter Dive and Echo Dive.

Progression and pointers: the HUD grows with the game (the minimap with the Salvaged Sonar
Core, the island health bar with a research station on the 2nd island: Fleet flag
"health_gauge"); a StatusColumn top right stacks the health bar, water bar, the goal line (bring
the island's headline animal back, RegionData.flagship: "3 / 10", then explore to find a new
island), a Tip button (one tip when asked, for where the player is: the objective's next step
+ ObjectiveGoal.hint, the ship, installing, exploring, then RegionData.flagship_tip) and a storm warning; every first visit says what the
island is about; oil patches and other boat-only things explain themselves close up. An island's
storm timer starts when the ranger first gets there: nothing is warned or strikes within
15-25 days of that (RareEvents.first_gap_min / first_gap_max, _first_on / _too_soon; earlier
warnings are called off), later ones min_gap_days..max_gap_days apart.
Economy: full-grown trees give 2-3 wood, the ranger carries 6, buildings need about a third less
wood than before, recycling pays 2 a piece (+1 per centre level), photo research 20 a species a
day (Funding.PHOTO_RESEARCH), and the first replay of each ranger activity each day pays its
research grant (ActivityData.daily_grant 30, never more for a better score; Activities.research_grant,
saved "granted"). A day-by-day model of a full playthrough (all six islands, real costs) found
funding held every island up: about 68 game days (~11 h) with these numbers.
Funding balance (the owner: 5 days to the rescue station lost players; too much with nothing to
buy at the end): Maya hands over a 200 founding grant with her camera, from the fundraiser that
sent the ranger to the island (Funding.FOUNDING_GRANT, on Fleet.marked "camera"); the first photo
of each species pays 50 (FIRST_PHOTO), later ones the daily 20; no clean-up grants. Visitor income
levels off on each island: its busiest funding facility pays in full, the next 75 %, the next
56 %... (Funding.LEVEL_OFF). Costs rise along the chain: Marine Search & Rescue Station 300, Kelp
and Mangrove signature buildings 500, Reef and Deep Sea 650, Polar 800; each Exploration Ship
400 plus 160 for every one already built (BuildingData.cost_rises_by: 400 to 1,200); upgrades cost
more each level (upgrade_funding_at: the 2nd twice the 1st; the Make menu lists both).

Playable islands: all six. An unfinished island would be `RegionData.in_development`: Explore
says the fleet is ready (or what it still needs) and that the island is still under
development, and the Map doesn't sail there.

Storage (BuildingData.stores, shared by every island): Ranger Houses keep only wood and
saplings (4 / 8 / 10 of each), so islands without trees can still build; nothing else is stored
until the fleet has the Deep Sea's Cargo Module, which opens a cargo hold on every Exploration
Ship: 99 of everything, wood and saplings too (BuildingData.storage_needs). Both open a
Storage menu (StorageMenu) instead of a line of text; more stored than there's room for can be
taken out at any store.

Sound (`Sound` autoload, scripts/systems/sound_system.gd): placeholder sounds made by
`tools/make_sounds.py` (effects in audio/sfx/, nature loops and calls in audio/ambient/, single
notes in audio/music/; loops have edit/loop_mode=2 in their .import). Each island's music is
data (data/music/, MusicData: instruments, key, tempo, chords, ambient loop, animal calls) and
is made up as it plays: a damaged island only hums a low pad; bass, the tune, bells and calls
join in as its health rises. Each island sounds like itself (the owner), the tune the same everywhere:
Starting Island breaking surf, boobies, dolphins, crabs; Kelp Forest swell, otters, cormorants;
Mangrove Coast lagoon and insects, flamingos, a crocodile, frogs; Reef distant surf and snapping-shrimp
crackle, parrotfish crunching coral, seahorse clicks; Deep Sea the deep hum, sperm-whale codas and song;
Polar Ocean loud white-noise wind, polar bear huffs and growls, seals, terns, skuas, ice creaks. Buses Music / Ambient / Sounds (in default_bus_layout.tres: buses added at runtime are silent
on the web); the page plays like a music app (navigator.audioSession, iPhone silent switch); the speaker button in the menu bar
(SoundButton) mutes everything or sets the music and sound volume (saved: "sound"). Every
button clicks (Sound connects to each BaseButton; meta "silent" opts out); `Sound.play(&"id")`
for the rest. Progress feedback (ProgressCheer, never tappable): sparkles and a chime when the
ranger's island passes a new 5 % of health, a card with the animal's picture when one comes
to an island (HUD.animal_returned, called wherever animals arrive or settle: "Another X has
joined the island!", never "the first"; the first newcomer of a species is a gold card: Fleet
flag "returned_<id>") (only on the island the ranger is on: elsewhere it just happens), and "+N" rising from the funding.

"What is this?" (BuildingInfo: its picture, BuildingData.description, stats and fact) depends
on BuildingData.explains: Always for markers and enclosures (protection areas and zones, habitats,
sanctuaries, restoration sites, the drill site, water gates, hydrophone buoys); When unclear for real buildings, only while none
of their own buttons already says what they are (Missions, Recycle, Look in storage...:
Building._says_what_it_is); Never for built items (docks, drawbridges, deep cameras, boats,
trees, the tent); and its picture shows what it does (the Glassworks' furnace and bottles, the refill
refill station's lemonade jugs, baskets, crates, the filter drum, the net bin; animal signs on the visitor
centres). Full-screen pages keep clear of a phone's home bar, corners and notch (SafeArea: the
browser's safe-area insets, never less than a phone margin); activity level buttons wrap.
Birds have four pictures (the standing one is their Journal and card picture: AnimalData.icon /
picture()): flying (from above; always while moving, also to the nest; birds circling litter or
trouble never land: Animal.circling), standing (resting_sprite), floating on the sea
(floating_sprite) and sitting on the nest (perched_sprite: tree nesters, ground nesters, and the
flamingo on its mud mound: MangroveEcosystem.mound_near); the sea otter swims belly-down and
rests on its back, the polar bear lies down to rest.

Travelling animals (`Travellers` autoload, saved "travellers"; AnimalData.travel_home /
travels_to / travel_chance / travel_news): bottlenose dolphins (from the Starting Island; never
the Arctic), sperm whales (from the Deep Sea; everywhere) and green turtles (from the Starting
Island to the Mangrove Coast and the Reef; young snappers from the Mangrove Coast's pools to the
Reef) spread one island further along the chain every
DAYS_PER_STEP (8) days once they live at home, so the whale reaches the Reef last; a morning
visitor comes for the day to the ranger's island (visiting) only while both islands are above 70 %, its
chance rising with the less healthy of the two to AnimalData.travel_chance at 100 % (Travellers.chance;
the owner: a booby on a 16 % Reef was wrong; seed-bringing visits too), and the first time on an island its
people mention it (People.add_news). Rescued companions visit more often. A green turtle on the
Reef grazes the seagrass: one more seahorse per grown Protection Area (ReefEcosystem.turtle_grazing).
Rubbish near camp on the Polar Ocean (2+ litter within 200 px of the tent / house / research
station / centre) draws a polar bear in (Fleet flag "bear_at_camp"; PolarEcosystem.check_camp):
Sanna and Erik get nervous (PersonData.scared_line, a red "!"), the skua circles it; no building
keeps it away: cleared, it wanders back to the ice. Flamingos' legs show the Mangrove Coast's water
level (AnimalData.shows_water_level: their note says dry feet / ankle-deep and feeding /
belly-deep, and a shader, assets/effects/wading/, tints only the leg pixels in the water the
tile's own colour, feet still showing, or hides the feet in mud; nothing on dry land). The end credits start at x3 (EndCredits.START_SPEED) and have an x1 to x5 speed button; Close and
the speed button keep inside the phone's safe area (SafeArea) (a phone tap counted once: touch and its mouse click used to step twice). Buttons keep short
labels (Plant coral, Split, Move, Put down, Let go, Give N x (+N)).

Rounded terrain edges: a visual-only `TerrainEdges` overlay after `Ground` in every island scene
(`docs/TERRAIN_EDGES.md`); every runtime tile change must go through `SaveGame.record_tile` so
its corners update (loading rebuilds them).
Height edges (the owner's pick: the line and the height together; looks only, walking unchanged):
the sea is 0, a ground touching it stands its own step above it (sand 0, mud 2, grass 5, ice 6,
rock 12 px) and any other patch stands on top of the ground it shares most border with, of those
further out or bigger beside it (on a tie the higher; TerrainEdges.STEPS: grass on
rock 4, rock on grass 5, sand on anything 0...), so islands go up from the beach and back down,
the Deep Sea's grass is on top of its rock (never holes), and no land is a pit. Faces show only
on the south side ("TerrainFaces" layer, assets/tilesets/terrain_faces.png from
tools/make_terrain_tiles.py), hanging into the lower ground and following its edge's rounded
corners and inside curves, with the line along their foot and ends, foam in the water, a lip
(light north and west, dark east) where the ground drops away unseen; SeaWaves skips the water
under a face (TerrainEdges.covers). Heights are redone once a frame after tiles change.
Boats keep out of the water strip under a face (IslandGround.bands: a collision band on the
land's physics layer, which only boats use), swimmers too (Animal.in_habitat) and floating
litter moves out in front (Debris); the ranger walks over steps freely, with a little hop (4 px, a
quarter second: Player.hop_*) over any step of 5 px or more (TerrainEdges.height_at); decks lie over a face,
level with the land.
Building art (the owner's buildings sheet, docs/buildings_sheet.webp, on magenta): cut by
`tools/cut_building_sheet.py` into a PNG per building, beside each old picture's path, fitted into
the box the old art filled (tools/building_sheet_targets.json: the owner, their original sizes).
Everything outside each building's dark outline goes (specks, the pink fringe, grey fill between
pillars), labels are dropped; the water gate (closed) and drawbridge (open) pictures aren't on it yet.
Turtle protection areas: their label dropped (loose bits below a picture go) and the grey fill
inside see-through (target "see_through"), so the sand shows. Docks and the drawbridge keep the
game's own plank art (the sheet's were framed squares that didn't join into a jetty: targets null).
The owner's building pictures carry twice the game's pixels (the owner: nothing squeezed out of
them; like the ground art and the rowboat) and the game draws them at half size:
BuildingData.picture_scale 0.5 (also the Make menu's ghost), PersonData / ActivityData.place_scale,
WreckSite.PICTURE_SCALE, PatrolBoat.hull_scale, AnimalData.picture_scale (the polar bear); the
sand item and the trees stay at the game's own pixels. Any magenta left blended into a picture's
outline becomes the near-black line (cut_building_sheet.no_magenta). The recycling centre is drawn
about the Ranger House's size.
The owner's reworked pictures (docs/rework/*.jpg: on a pale green grid, labels, soft shadows) are
cut by `tools/cut_owner_pictures.py` (background, grid, shadows and labels out, also between
pillars; colours snapped to each picture's own palette; their boxes in tools/rework_targets.json,
null in the sheet's targets): the Eco-Lodge, Waterworks Station, water gate (open; the closed one
is it with planks where the water was), the three Ranger Houses, the Deep-Ocean Outpost and
Discovery Centre, the Polar Research Centre and Station, the four polar bears, and the patrol boat
(docs/patrol_boat_sheet.png). The Make menu shows the patrol boat, not its buoy
(BuildingData.menu_texture).
Docks and the drawbridge are drawn by `tools/make_deck.py` (64 px a tile, the water gate's wood):
four boards a tile, staggered joints, nails; 16 pictures each (BuildingData.joined_texture, bit 1
north, 2 east, 4 south, 8 west) so decks side by side make one solid deck, with a near-black edge
only where they meet water and, with no deck to the south, the deck's front and pilings
(Building._show_joined / rejoin_decks, group "decks", redone when one is laid, moved, taken away or a
drawbridge goes up or down; a raised drawbridge doesn't join). The raised drawbridge: its deck
standing up on the hinge, the water between its posts.
The flamingo's mud-mound nest is a pixel picture (tools/make_flamingo_nest.py, twice the pixels:
the mud's colours, a hollow on top with the egg) with a soft shadow. The mangroves' reddish roots
are recoloured to the mud's hue (cut_building_sheet.mud_roots). Young flamingos show the water
level too (the wading rows scaled to their size); they sit only on land, mud or the nest, never in
the water; the chick has its own chubby sitting picture (make_young_birds.OWN_BABY_SITTING) and
no flying one (it can't fly yet: it walks, in its standing picture).
The trees (`cut_building_sheet.py trees`, every picture in assets/environment/vegetation) are made
flat like the characters (flat_tones: 2 flat tones per colour family, hard edges, one near-black
outline: the owner liked them); the buildings stay as drawn (an automatic flattening made them
look run down: the owner preferred the originals).
Ground art (the owner's terrain sheet, docs/terrain_sheet.jpg): drawn by
`tools/make_terrain_tiles.py` at 64x64 per tile (the sheet's lines are half a game pixel), 8
versions of each ground with the sheet's colours, marks and contrast (measured against it), but
fewer waves on shallow water and a rare yellow or orange flower on grass (the owner: no white,
it read as static), no repeating pattern, every mark inside its own tile. TerrainEdges lays them as a "GroundArt" tile layer at
half size just above Ground (a version per cell, half mirrored; mipmapped) and hides Ground's own
tiles (Ground.self_modulate), which keep the terrain, walking and saves; terrain_tiles.png (each
ground's first version at 32 px) is Ground's texture and gives the rounded edges their colours.
Water cells get no art tile: all of an island's water is one small picture (TerrainEdges'
WaterBlend, 4 pixels a cell, linear filtering) under the ground, so every two waters fade into
each other over a few pixels, round corners too (no line, no rounding between waters); SeaWaves'
faint speckle (deep_water.png, fixed to the world) and its moving waves (one every 60 px) play
over all water. The open ocean is darker than mid water (default_clear_color) and takes the health
tint of the island in view, as that island's water does (DayNight). Each island's sea has its
own tint too (RegionData.water_tint, on its WaterBlend and the open ocean, blended between the
two nearest islands outside their coastal waters): the Mangrove Coast a touch greener and
muddier, the Reef a touch lighter and more turquoise (the owner: barely, but noticed between
those two). Ground details
(decoration only, `tools/make_ground_details.py`, a "GroundDetails" tile layer over the rounded
edges, picked per cell by TerrainEdges and redone round any changed tile): grass patches inside 3 x 3
grass, shells and a starfish on sand, bird tracks / boot prints / clumps on mud, small stones on
rock, little rocks on ice where 3 in a row are the same ground, one snowman on an icy island (the
ice cell with ice all round it that its hash picks), and animated tiles (random start times) of
waves running up the sand and sliding back (8 frames: a curve from the water's edge, full only at
its peak, gone well before the tile's sides where the coast's corners curve away) and spray on
half the rocky shores, turned to face the water, each spot then pausing for one of
TerrainEdges.WAVE_PAUSES (0.2-5.5 s, a tile source each) so the shore never comes in and goes out
in step (the spray is drawn on the water beside the rock, breaking over the water: the owner). A dark line (60 %, as strong as the buildings' outlines) runs where two terrains meet
(TerrainEdges._lines, following the rounded corners' arcs; never round every tile: the owner's
pick); where four different terrains meet there's no rounding (it made a dark star). Mud, ice and
rock carry fewer, softer marks than the sheet (the owner: too prominent); plain grass a few
fewer, softer blades too, so its patches show (the owner: halfway between the sheet and a faded
look); the patches (on 45 % of the cells inside 3 x 3 grass) have blades a game pixel wide, lit
on the left, on a slightly darker bit of ground.
Where two land tiles touch only at a corner (water in the other two: drawn joined up), the ranger
can walk across: IslandGround (every island's Ground) cuts the two water tiles' collision back at
that corner and Terrain.walkable lets the ranger stand there (TerrainEdges tells it where).
The owner's option A, so the new building and tree art sits in the world: soft shadows
(`Shadow`) under buildings on land (not decks, markers or things on the water), trees, the
ranger, people and animals on land (not while swimming or flying); near-black outlines on animals
(tools/outline_sprites.py: darker for assets/animals) and on the avatar's parts (LINE 40).
Layers (z_index, back to front): the water's colours -6, the sea speckle -5, ground and ground art
-4, waves and things in the water (kelp beds, reef patches, dark areas, the wreck) -3, swimming
animals -2 (Animal.SWIMMING_Z, checked a few times a second), decks, jetties and markings on land
-1, everything else 0 (y-sorted): animals swim under decks and the drawbridge (the owner).
A boat left in the water lies at -1 too (Boat._layer): the ranger stepping out, and everyone on
land, are always in front of it (the owner); with the ranger aboard it's at 0.

A living island: most species roam all round their island's waters (AnimalData.roams /
roam_share: turtles, dolphins, whales, sharks, fish, otters, seals, cod), not just round the area
they belong to; crocodiles, polar bears, crabs and nesting birds keep to their places. After the
Polar Ice Survey (Fleet flag "old_ice_shown") old-ice tiles show a little bluer than seasonal ice
(a tint on the tile only, no outline). People's observations (PersonData.observations, TalkTopics
with `when`): 26 things they've noticed about the animals (crabs dig up litter, otters crack
urchins, flamingo legs show the depth, rubbish brings bears...), and 12 about young ones while
one is on the island (condition "young:X": the grey flamingo chick, the white seal pup, the
floating otter pup...); one is added after what they say
when there's no news or tip, at most once a day each, only while it holds, each up to
People.OBSERVATION_TIMES (3) a game, least-said first (saved "observed"). Bram keeps a lighthouse on
the little islet off the Deep Sea hook's base; the hook's inside (the canyon) is rock, with sand
only in a line up from the base and round the east tip.

Trees on the treeless islands (the owner: only to islands with no trees, only a kind that grows
there, and the Clue Board says plainly how each came): red-footed boobies visiting the Reef (once
the Starting Island is thriving, 70 %) bring the Pisonia tree (AnimalData seeds_tree / seeds_from /
seeds_to / seeds_max 6 / seeds_chance; Travellers.spread_seeds every morning, wherever the ranger is):
its sticky seeds catch on seabirds' feathers, and boobies nest in it; once one has come up, Pisonia
saplings can be planted there (needs_flag "sprouted_tropical_reef"). A storm brings a tree only to an
island with none (EventData.seeds_tree / seeds_news): the Reef's hurricane a palm (a coconut washed
ashore), the Polar ice storm a polar willow (fluffy seeds on the wind; a few centimetres tall, too
small to cut: PalmTree.cuttable false, never in the Make menu: BuildingData.in_make_menu). The terns
no longer bring pines. The first sprout is news. Arctic plants carry snow
(PolarEcosystem.snow_cover, assets/effects/snow/: the tops of the plant's own pixels turn white,
building up in the freeze, deepest when frozen, gone by open water).

When you first arrived (Observatory): see "The Observatory's layout" (start pictures; the
old per-player screenshot is gone). No "now" picture.

Births and growing up: the islands still decide when one more animal comes (same triggers and
limits); Births.bring turns that newcomer into a young one born beside a grown one of its kind
(the parent goes to where it belongs first: Animal.expect; hidden until then: unborn; the card
shows at the birth; a sleep catches up: Births.born_now), which follows it while growing up and
then keeps its own spot. Fish, clams and squid drift in from the island's edge
(AnimalData.drifts_in). Growth: grow_days 2 / 4 / 6 (grown on day 3, 5 or 7), two young
stages (Animal.stage) with their own pictures for 12 species (AnimalData.young_sprites:
crabs, terns, skuas, boobies, cormorants, flamingos, otters, seals, turtles, crocodiles,
polar bears); dolphins, whales and sharks just grow. Young birds also fly and sit in their own colours
(AnimalData.young_flying_sprites / young_sitting_sprites, [baby, young], drawn by
`tools/make_young_birds.py` from the grown bird's pictures, keeping their shading, shown at 55 % /
75 %): a baby sits whenever it's down, an older one on the nest, and on the water the young of
birds that float sit (never stand) on it. Moving like the real thing (looks only, the owner's
pick): flying birds beat their wings for about a second, then glide (Animal._flap: wing frames
made once from the flying picture, wings drawn shorter and back out, the body staying put);
turtles sway as they swim and now and then dip a little under (AnimalData.sways). People's
places have a soft shadow. Clean water: the first time it's carried a note says to store it at
home (it makes you faster; Fleet flag "water_hint"), and Kai says it too. Trees show sapling and young pictures
(PalmTree.stage_textures). Turtles: while their protection areas have room any grown turtle
nests again once her own last nest has hatched (Nest.mother), several at once; a nest hatches
2-4 (AnimalData.hatchlings / hatchlings_max), those with room stay, the rest swim off. Breeding
pace (Births.can_have / busy): an island's limit is never filled at once; each parent has young
again only once its last ones are a step on (hatched: AnimalData.lays_eggs, incubation_days;
born live: out of the baby stage), and drifters come one per species every third of a day;
the old one-arrival-a-day limit is gone. The HUD's Build button is
"Make" (buildings, planting, the shovel: the Make menu). Photo moments: at most 5 everyday ones per species (3 grown poses or
places plus a baby and a young one, or 4 plus one young; conditions baby / juvenile /
standing / resting / taking_flight / resting_pose / swimming), plus an uncounted gold bonus.

Later: more animals (seabirds, reef fish), plantable mangroves, net boats, sanctuary interiors
(turtle rehab mini-game).

Care bars (Rescues; the user's rule: things can go bad, never death): fed +10 a bite, as often
as it isn't full, empties over 1.25 days (FED_LASTS); it only eats once calm is 80 % (EATS_FROM:
comfort first, as often as it isn't full, +10). Health rises with medicine (once a day), a
plaster per wound (rescued ones only: hatchlings start healthy, no wounds) and food; it only
drops while fed is empty, never below 20 %. Calm only rises by comforting; left alone it
settles to 50 % (not distressed), and only drops below that while health is dropping; a hurt
rescue starts below 50 %. The bars freeze once it's ready to go home. The vet room shows them
live and says what it needs now.
Care reactions: dragging a tool or pressing its button (both go through VetScene.do_care) pops
icons (hearts, a fish, green sparkles, gold stars) and the animal moves its own way
(RescueData.reactions per action: hop / wiggle / squash / bob / shiver / puff).
Storm rescues (Rescues.storm_count, saved): once an island's own rescue has gone home, a storm
striking that island hurts another young one of its kind; it's brought in like the first (when
offer_when holds), never while another is in care (it waits its turn), at most Rescues.MAX_TIMES
(3) of each kind in all. It's named and cared for the same way; released, its name is kept in
done[id].others (ponytail: not placed in the world; the first one stays the tagged one about).
Care costs funding: each bite of food and each dose of medicine (RescueData.food_cost 2 /
medicine_cost 10; comfort and plasters are free; without the funding it says what it costs).
Stroking (comfort_kind "stroke") calms it a step every 140 px stroked, while stroking
(VetScene.soothed). On a phone on its side the room (sized to the page's real height, following its resize, so the
bars and everything to drag fit one screen; the buttons below may scroll) fills the screen with the day, the bars and
what it needs on a panel on its wall; the buttons are below it.

Rescue pictures (the owner's art: docs/rescue_stages_sheet.jpg, one row per animal, six care
days; the turtle row starts with it hatching): tools/cut_rescue_sheet.py cuts it into clean
pixel-art PNGs (background flooded away, snapped to the 4-px art grid, one canvas per animal so
the growth is the sheet's own), sets RescueData.stage_pictures / stage_points (eyes, mouth,
wound per picture: eyes found or set by hand, EYES) and hatching_picture; the vet room shows
the day's picture (Rescues.stage) with its blink, feeding and plaster spots. The turtle and
the flamingo hatch from a cracked egg (RescueData.egg_damaged) with a wound (flipper, leg);
every rescue has a reason it needs care; a wound can always be patched.

Storms (the owner's design; RareEvents, docs/MASTER_PLAN.md "Rare events"): warned 2 days
ahead for every island the ranger has been to, wherever they wake up (EventData.warning_days; nothing may depend on waking up on that island); the event's clouds
gather beyond its rowboat waters (StormClouds, StormClouds.nearness: thin and further out 2 days
ahead, thick at the edge the day before) and the minimap's rim pulses red, faster the nearer it is; its people get a red
"!" (PersonData.storm_worry). On its day, STRIKE_AFTER 10 s after the ranger is on the island,
StormWeather passes over for 10 s (the game runs; clear 1.5 tiles round the ranger, fading into
the storm over 4 more: assets/effects/storm/storm_fog.gdshader; the six looks:
EventData.weather storm / swell / flood / hurricane / oil / blizzard), then it strikes. The
day after: 5 s of its end at once; later: only the aftermath, on arrival. It strikes whether
the ranger is there or not; no calm days. Aftermath: 20–35 litter on any ground plus 8
floating (EventData.litter_washed / _max / litter_floating; none for the oil spill:
LitterSpawner.storm_litter); damaged buildings show a warning sign and offer only "Fix"
(EventData.repair_funding 20 + repair_wood 1); the Flash Flood silts natural narrow channels
too; no notes: the island's people are shaken (RareEvents.shaken, saved) and say what it was
like (PersonData.storm_after) until the ranger talks to them.

The storm storyline (the Clue Board's Storms note, "What does a storm bring?"): a storm stirs up
old litter, even kinds that have stopped coming (LitterSpawner.OLD_PIECES), damages what wasn't
secured, hurts a young animal (storm rescues), and brings good too: the island's people help fix
the damage ("fixed, with Tom's help"), a seed washes ashore and a young tree comes up, only on an island with no
trees yet and only a kind that grows there (EventData.seeds_tree: the Reef's hurricane, a palm;
never other islands' trees mixed in), and a flash flood's rain brings water back to dry mangrove flats for a few
days (MangroveEcosystem.flood_water). Erik says warmer seas feed stronger storms (a line only,
never a mechanic). Fleet flag "storm_struck".

Notes (HUD.show_toast; the owner: too big, too wordy, too often): one short line (HUD.brief:
first line and sentence, at most 60 letters) in a small see-through box; one at a time with a
2.5 s pause, only the newest waits (a busy moment never piles up), the same note not again
within 90 s; `now` for what the ranger just did; notes about another island are dropped (an
`at` position: world things pass theirs; nests and hatchings via Journal.event_at). Facts
stay in the Journal; funding shows only as the rising "+N". Notes are hints that something
happened ("Wreck cleared", "Otter moved away: …"), never chatty sentences.
Buttons are short: animals and buildings have a short button name (AnimalData / BuildingData
.short_name, button_name(): "Photo flamingo", "Move station", "Free dolphin"), unique on its
island; fixed labels are one or two words (Sleep, Secure, Storage, Store all (N), Recycle (N),
Open gate, Bait, Dig sand, Put away, Cut down, Board, Tow boat, Mark dive). The line above the
buttons is short too ("Flamingo: ankle-deep, feeding").
A button only shows when pressing it would do something (the owner's rule): no buttons that only
show a note; what a thing has to say goes on the line above the buttons (`info_line()` on any
interactable: oil "sail into it", "Arms full", a closed activity spot, a dark area's "N% known",
a reef patch that can't go down here). Reef patches show their coral % above them; "Restore"
(plant a fragment) only while it would raise the coral (ReefEcosystem.planting_helps), "Split"
only when there's room to split onto.

People's own wants (PersonData.want, People.want_line / wish_came_true; ISLAND_RULES 9): each of
the twelve hopes for something of their own, said once after a talk without news or tips
(`lines`, when `when` holds), and once it comes true (`outcome_when`: Tom a nest, Maya 10
turtles, Finn / Rosa / Sanna their island at 70 %, Ines / Samuel / Bram rings / bags / ghost
nets stopped, Kai glass made, Leilani and Erik the coral spawning and the terns seen, Imani the
giant squid) they say what it means, once (saved in what's been heard). After the ending
(flag "observatory_opened"): someone met on another island visits the ranger's island for the
day (People.visit, VISIT_CHANCE 35 % a morning: a Person in group "visitors" beside one of its
people, saying PersonData.visit_line, gone the next morning), and on reunion mornings
(Rescues.REUNION_CHANCE 20 %) every released rescue is out, on the ranger's island if it lives
or visits there, else at home, with news from the island's people.

Each island breaks the shared pattern once (ISLAND_RULES 9; tests/test_breaks.gd): Kelp, Finn
found an otter pup at the jetty and the platform is wanted as its vet room; Mangrove, Rosa
wants every gate open, Samuel some shut (his "gates_argue" / "gates_agree" topics; condition
"water_right" = MangroveEcosystem.level_right); Reef, the patch nearest the dive guide starts
as the last living one (ReefEcosystem.last_healthy_coral 0.7, planted in full) and fades
unless the water is cleaned; Deep Sea, the sixgill pup is offered only at "quiet>=70" (a
People.check number: DeepEcosystem.quiet x 100; Bram's "pup_quiet" hint); Polar, the island's
people's places count as camp (PolarEcosystem._camp) and the first visit washes
RegionData.camp_litter (3) pieces up by the camp (LitterSpawner.wash_up_near), so the bear
comes on day one.

**Clue Board ✅** Spec and "As built" notes: `docs/CLUE_BOARD.md` (the only one; rules in
ISLAND_RULES 9). A connected map of what the player has understood (Journal → Clues tab,
ClueMap: left to right in landscape, top to bottom in portrait, zoom steps, tap for details):
the opening turtle mystery, 7 nodes, and the final question "Who created all of this?" (never
answered). 18 cards are data (`data/clues/*.tres`, ClueData), checked by the `Clues` autoload
with People's conditions plus its own observations (only while the ranger is on that island,
never health flags). The first activation that holds opens a card, evidence is kept even before
that, and answers stick (blue), their statements fixed from the evidence that answered them. The
game tells it what happened through the `clue_watchers` group. It never affects the game. The
first turtle's ghost net carries the hook tag (Animal.frees_flag "net_tag_found"; Tom hands it
over on old saves; Bram's "hook_tag"). The seed news and the Observatory's tree link say what was
seen, not that birds carried seeds.

The first minutes (the owner: a push line only works if the timing is right): Maya's first talk is
short: hello, her camera (Fleet flag "camera": photos need it, Animal.has_camera), then "go and
see Tom" (skipped if Tom was met first). The first turtle stays hidden until Tom is met
(Animal.shows_after "met:tom"), and its Clue Board question starts with Tom. People never ask as
if the ranger hadn't done something: a topic says TalkTopic.instead (when instead_when holds)
rather than its lines (Maya's station question once the ranger has been out in a boat: Fleet flag
"boat_used"; Tom's hello once a turtle area is built); questions already done are skipped.
New cards on the Clue Board show a red dot with their number on the HUD's Journal button and
the Journal's Clues tab (ClueMap.notice_dot; Clues.unseen / mark_seen, saved "_seen"; older
saves: what's on the board counts as seen), cleared once the board is opened; a card turning
blue or getting evidence isn't new (the owner).
The Clue Board never opens by itself over a talk or another page (it waits), and its pinned note
is only as tall as its words (sized a frame after it's added: wrapped text) with a "Got it" button;
a tap anywhere on the board puts it away too.

Ocean Day (People.ocean_day; the owner's pick for the one-year mark): from the first day of year
two, the first time the ranger is on the Starting Island (it waits for them), one person they've
met from each other island comes over for the day (People.visit_by, side by side), everyone says
their PersonData.year_line once that day, every released rescue is out at once
(Rescues.check_visits(true)), a gold card (HUD.show_card) says "One year as a ranger!", and the
ranger wears the Ocean Day badge (RangerProfile "badge", shown in the creator only once earned:
RangerProfile.EARNED). Fleet flag "ocean_day"; People "festival_day" saved.
After a talk people add one thing at most: their island's news, else one tip (funding or wood).

Characters (the owner's character sheets): the ranger and all 12 people are one layered `Avatar`
(scripts/player/avatar.gd; avatar.tscn is just the root): parts drawn by
`tools/make_avatar_parts.py` into assets/characters/avatar/ (grey, shaded, outlined, tinted by
modulate; shoes, glasses, badge and face in colour), each a strip of four 32x36 views (front,
side facing right, side mid-step, back; hair, tops and jackets 8: hair's back layer, the sleeves
on the near arm). About one tile tall (a tile is about 2 m; the owner: two tiles made them 4 m
tall), laid out on the sheet's measured ratios: the face about two thirds the width of the body,
the chin narrowing in steps, a one-pixel neck above the collar (make_avatar_parts.lowered: the head a row shorter above the eyes, the body a row lower; the owner), big low eyes (2 x 3) with a white highlight down their left side, the
arms joined to the body by rounded shoulders and a soft seam lower down (the hands on the arm layer, over the trousers), boots as wide as the legs, a short stride. Only the front is
chosen; the side and back views come from the same choices (Avatar.set_view: the ranger turns as
they walk, with a stride picture sideways; long hair and the backpack go over the body when
turned, never over the face; from the side the near arm, `arm.png`, and its sleeves are drawn
over the clothes). Parts (AvatarOptions): 12 hair styles (bald, fade and army cut too: the scalp is drawn with the skin under every crown; short sides fade out see-through), 5 headwear, 4 tops, a vest or jacket,
trousers or shorts, boots or sandals, 3 glasses (round ones as wide as tall), backpack, badge. People wear the same parts
(PersonData top / jacket / bottoms / shoes / glasses, PersonData.outfit). The Avatar Builder (the
owner's layout): the ranger in a wooden frame with their name, tabs Body / Hair / Headwear /
Outfit / Accessories of picture tiles (the part on the ranger) and colour swatches, a Controls tab
(how to play on a phone, a keyboard, a controller: the game shows no control hints of its own,
e.g. no "E / tap boat" label on the boat), and along the bottom Surprise me!, Back (undo, close)
and Confirm (no people as presets: the owner took them out). The rowboat is 2 m (32 px: at 2.5 m
it got stuck in one-tile channels and the drawbridge): the owner's picture
(docs/rowboat_sheet.jpg) cut by `tools/cut_rowboat.py` at its own detail (56 x 19) and drawn 32 px long
(Boat.hull_scale), in two halves (rowboat_front.png from the rim's inner edge down, following
the curved nose, Boat.hull_front):
the ranger sits behind the near side, waist just behind the rim (Avatar.sit: down to just below the
waist). The sheet's rowboat is skipped (its target is null). The
patrol boat is 2.5 m.

**Every animal matters.** No background animals: each species either needs the ranger's help
(tangled, trapped, injured…), gives something that helps other animals (finds litter, digs it up…),
or both. Design each new species' role before adding it.
