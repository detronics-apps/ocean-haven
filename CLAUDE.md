# Ocean Haven

A cozy 2D pixel-art ocean-conservation game. Start with one small island, clean up and restore the ocean around it, and watch wildlife return. Full design: `docs/GAME_DESIGN.md` — read it before adding any gameplay feature.

## Tech

- **Godot 4.7**, **GDScript only** (no C#, no GDExtension).
- Renderer: **Compatibility** (`gl_compatibility`) — must run on low-end PCs, tablets and mobile. No Forward+-only features.
- 2D only. Stretch mode `canvas_items`, aspect `expand`.
- Controls: design for touch and controller first; keyboard/mouse must also work. Use Input Map actions, never hard-coded keys.

## Game rules (non-negotiable)

- **No combat.** No weapons, enemies, killing, health bars, boss fights or combat stats.
- **No failure states.** Never "you failed"; say what needs more help ("The beach needs more protection") and let the player retry.
- **Conservation is positive.** Animals are cute but biologically recognisable; facts must be accurate.
- **Education never interrupts play.** Facts go in the Ocean Journal / Discovery Cards, not blocking popups. No mandatory quizzes.
- **Money comes from a healthy ocean** (eco-tourism, research, grants), never directly from rescuing an animal.
- **Progress is visible.** Restored areas change colour, sound and animal count — muted (dark blue, grey, brown) when damaged, vibrant (turquoise, coral pink, tropical green) when healthy.
- **The player is a conservation ranger**, not a superhero: no stats.
- **Avatar creation.** The player creates and customises their avatar (shirt, hat, backpack, clothes, boat appearance). Build the player sprite as swappable layers from the start, so customisation never requires redrawing the character.
- **Multiple islands and regions.** The world grows: home island first, then new islands and regions (reef, mangrove, kelp, open ocean, polar sea) unlock through exploration and conservation progress. Each island is its own scene in `scenes/islands/`, placed into the world — never hard-code the world as one island.
- Playable by a 7-year-old; depth for adults comes from choices, not complex controls.

## Art

- 16-bit / modern cozy pixel art (SNES-inspired, not NES-retro), 32×32 tiles, larger character sprites.
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
- A scene and its main script share a name: `scenes/animals/turtle.tscn` ↔ `scripts/animals/turtle.gd`.
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

## Current milestone: MVP 0.1

Build in this order, with placeholder art:

1. Ocean + small starter island
2. Player walking + following camera
3. Simple boat (board at shore, sail)
4. Plastic cleanup (collectable floating debris)
5. Basic inventory
6. One turtle (swim → rest behaviour)
7. First sanctuary (built with collected items)
8. Day/night cycle
9. Save game

Anything outside this list waits until MVP 0.1 is playable.
