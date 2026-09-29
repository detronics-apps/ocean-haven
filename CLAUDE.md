# BlueHaven

A cozy 2D pixel-art ocean-conservation game. Start with one small island, clean up and restore the ocean around it, and watch wildlife return. Full design: `docs/GAME_DESIGN.md` — read it before adding any gameplay feature. The end goal and its steps
(islands, animals per island, exploration & fleet upgrades, cross-island effects): `docs/MASTER_PLAN.md`
— build every feature towards it.

## Tech

- **Godot 4.7**, **GDScript only** (no C#, no GDExtension).
- Renderer: **Compatibility** (`gl_compatibility`) — must run on low-end PCs, tablets and mobile. No Forward+-only features.
- 2D only. Stretch mode `canvas_items`, aspect `expand`.
- Controls: design for touch and controller first; keyboard/mouse must also work. Use Input Map actions, never hard-coded keys.

## Game rules (non-negotiable)

- **No combat.** No weapons, enemies, killing, boss fights or combat stats.
- **Animals never die.** Rescued animals may show gentle care meters (health, hunger, injury) in the care mini-game, but they only ever get better, never die or get worse from neglect.
- **No levels or XP.** Progress is Ocean Impact (per-area restoration); new regions unlock through restoration progress, not player level.
- **One currency: conservation funding.** No gems or other premium currency, no in-game purchases or donate buttons (kids' game). Real-world impact is a "Real Impact" page with links for parents.
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

## Workflow

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
- The game shows its revision (`rN sha`, bottom left) from `version.txt`, written at publish time.

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
7. ✅ Round minimap, bottom-left (Minecraft-style): the island, you, and a dot for your home
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
    wood + litter + funding; carry 3 wood / 1 sand; Ranger Houses (up to 2) store 10 each; up to 3
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
    offers Explore warmer / colder → the next undiscovered island that way (`Regions.next_undiscovered`,
    RegionData.direction + order), which is then discovered for good (saved) and reachable from the
    Map. The Map only sails to discovered islands; undiscovered ones are greyed out; a 🧭 marks islands
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
   (HealthFactor "clean" = litter about its waters, "help" = species freed, "animals" = living
   there). Ground colours go from muted to full with it (checked every 2 s); shown in the Journal.
   The Starting Island starts with 1 turtle, 1 crab, 1 dolphin and ~30 litter (new game:
   `start_litter`); more animals arrive as islands recover (RegionData.arrivals, `Arrivals`, saved):
   2nd crab at 40 % health, 2nd dolphin at 65 %, then dolphins 3–5 and crabs 3–4 as 1–3 other
   islands become healthy (≥ 70 %).
2. ✅ Wildlife Conservation Parks (funding facilities, BuildingData.facility = "funding", shown in
   gold in the Build menu): up to 3 Turtle Protection Areas + 1 Dolphin Viewing Area (visitors per
   dolphin in view: `watches`). Morning funding (Building.visitors_today) × (1 + island health).
3. ✅ Marine Rescue & Research Station (signature facility, one per island, `only_on` the Starting
   Island): sends missions (data/missions/, MissionData; `Missions` autoload, one at a time, saved)
   for funding — rescue boat (animals in distress), pollution survey, turtle monitoring, dolphin
   tracking. Back after a few hours; what it found is marked on the minimap until the next morning.
4. ✅ Pollution types: entangling litter (ItemData.entangles) left near animals that can get caught
   (AnimalData.can_tangle) catches one each morning; oil patches (ItemData.ranger_cleans: only the
   ranger's boat cleans them; a "clean" health factor with a target); dolphins keep away from patrol
   boats (AnimalData.boat_shy_distance); turtles won't nest at a protection area with another
   building within 2 tiles (BuildingData.needs_quiet; docks and trees are fine)
5. ✅ Seabirds (red-footed boobies; AnimalData.flies / circles_litter): arrive by trees
   (ArrivalData.needs_trees: 5 / 10 / 14 full-grown palms), fly off while there are too few and
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

Tweaks after 0.4: upgradable buildings show "Lv N/3"; a Ranger House stores 10 of each per level
(30 at level 3); saplings: carry 5, storable, spare ones given to coastal replanting at the Research
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

Next: MVP 0.5 Kelp Forest (Step 3), then MVP 0.6 Mangrove Coast (Step 4).

Later: more animals (seabirds, reef fish), plantable mangroves, net boats, sanctuary interiors
(turtle rehab mini-game).

**Every animal matters.** No background animals: each species either needs the ranger's help
(tangled, trapped, injured…), gives something that helps other animals (finds litter, digs it up…),
or both. Design each new species' role before adding it.
