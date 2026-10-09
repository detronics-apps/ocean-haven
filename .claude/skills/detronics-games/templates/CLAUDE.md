# <Game name>

<One-line pitch>. Full design: `docs/GAME_PLAN.md`. Rules learned so far: `docs/RULES.md`
(read before designing any area; add to it whenever the owner corrects something). Use the
`detronics-games` skill for the way of working.

## Tech
- Engine and language: <e.g. Godot 4.x, GDScript only>; lowest renderer (<Compatibility>), runs
  on phones.
- 2D/3D, stretch mode, aspect.
- Controls: touch and controller first; keyboard/mouse too; input actions, never hard-coded keys.

## Game rules (non-negotiable)
- <from GAME_PLAN §3>

## Art
- Style, view, tile size, characters.
- Placeholder SVGs, outline script, Nearest filter; code never depends on final art sizes.

## Project layout
<folders, naming: snake_case; a scene and its script share a name; systems are autoloads>

## Code style
- Static typing; class names PascalCase; signals between unrelated nodes.
- Tunable numbers are exported or in data, with units in a comment.
- Data, not code, defines content.
- Performance: never `load()` or list folders in game code (one cached loader); nothing per
  frame loops over every tile or flood-fills (cache, rebuild on change).

## Workflow
- Instructions vs discussion: instructions are built straight away; discussion gets a plan and
  waits. Something completely new is planned first unless the owner says "build the following".
  Build exactly what was asked.
- Ripple check before every change (who else, where else, what downstream, which rules).
- Small playable steps; commit after each; never commit a broken project.
- Tests in `tests/`: `<command>`; full suite before publishing.
- Save game: `<SaveGame>` autoload, `VERSION`, save code; every new progress gets a save field
  and a save test.

## Publishing (where the owner plays)
`<publish command>` → <URL>. After a batch of playable changes; tell the owner the revision.
The game's own splash and web loader (nothing about the company, no spoilers); the home page
picture rendered from a new game. Check UI changes at 390x844 and 844x390.

## Milestones
**<0.1 — vertical slice>** …
