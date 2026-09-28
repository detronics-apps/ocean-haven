# BlueHaven

A cozy 2D pixel-art ocean-conservation game. Start with one small island, clean up and restore the ocean around it, and watch wildlife return. Full design: `docs/GAME_DESIGN.md` — read it before adding any gameplay feature.

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
- **Multiple islands and regions.** The world grows: home island first, then new regions (Tropical Waters, Mangrove Coast, Kelp Forest, Coral Kingdom, Open Ocean / Deep Sea, Arctic Ocean — see `docs/GAME_DESIGN.md`) unlock through exploration and conservation progress. Each island is its own scene in `scenes/islands/`, placed into the world — never hard-code the world as one island.
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
unlike itch.io's iframe on iOS. Publish it whenever the itch zip is rebuilt.

## Testing on a phone (itch.io)

This PC's firewall can't accept connections from the phone, so phone builds go to itch.io
(restricted page, HTTPS, works on Wi-Fi or mobile data).

1. Export the "Web" preset (step 1 below). `build/.gdignore` must exist so Godot doesn't import the build.
2. Zip the *contents* of `build/web` (index.html at the zip root) to `build/bluehaven-web.zip`.
3. Upload on itch.io: project → Edit → Uploads → replace the zip → Save.

**When:** not after every step — only once a batch of big, playable changes has landed (e.g. a
milestone or a major feature). Then rebuild the zip and tell the user it's ready to upload.

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

**MVP 0.3 — "A living island" (current).**

1. ✅ Visitor donations wait at the building (coin) until the ranger collects them
2. ✅ Dolphins (open-sea pod, curious about boats) and ghost crabs (beaches)
3. ✅ Every animal matters (rule below): dolphins — one caught in a ghost net; trusted dolphins lead
   you to floating litter. Crabs — one trapped in a plastic bag; crabs dig up buried beach litter
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
    map (data/regions/); Tropical Waters (second island) unlocks once home has a patrol boat
12. ✅ Dolphins spread 120° around the island; they surface and dive
13. ✅ Action bar at the top: one button per nearby action (free / photo / sleep / move / board) so the
    player chooses; E still does the most important one
14. ✅ Web saves also go to localStorage (instant) + a "Saved" note
15. ✅ Placement snaps to the nearest spot that fits; Expedition Boat moors next to a dock plank;
    patrol boats go round docks
16. ✅ Hatchlings fill empty protection areas before leaving
17. ✅ Recycling centre (litter -> funding); cut down / plant palm trees; drawbridge; shovel tool
    to scoop up beach sand and place it on shallows (sand isn't litter: ItemData.is_litter)
18. Tropical Waters' own mechanics: coral reef restoration, reef fish ("save the fish")

Later: more animals (seabirds, reef fish), plantable mangroves, net boats, sanctuary interiors
(turtle rehab mini-game), **bigger boats and ships built at the dock to travel to other islands**
(the new regions).

**Every animal matters.** No background animals: each species either needs the ranger's help
(tangled, trapped, injured…), gives something that helps other animals (finds litter, digs it up…),
or both. Design each new species' role before adding it.
