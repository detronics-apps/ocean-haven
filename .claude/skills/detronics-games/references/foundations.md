# Phase 3 — Foundations

Everything here was added to BlueHaven later, at a cost (old saves, retrofitting, phone bugs).
Set it up before the first piece of content. Engine notes are for Godot 4 (GDScript,
Compatibility renderer), BlueHaven's stack; translate if the game uses another engine.

## Project and repo
- Shallow folder layout, snake_case: `assets/<type>/<thing>/`, `scenes/<area>/`,
  `scripts/<area>/` (+ `scripts/systems/` for game-wide systems as autoloads), `data/<type>/`,
  `audio/{music,ambient,sfx}/`, `docs/`, `tests/`, `tools/`.
- `CLAUDE.md` from templates/CLAUDE.md: tech, rules, art, layout, code style, workflow, tests,
  save, publishing, milestones. Keep it the single source of truth and update it as you go.
- `docs/GAME_PLAN.md` (the design), `docs/RULES.md` (rules learned from corrections; read before
  designing any area).
- Commit after every working step, push to the session branch; never commit a broken project.
- The engine cache (`.godot/`) never committed.

## Content is data
- One data file per animal, item, building, mission, person, event, area… (Godot `Resource`
  `.tres`). Adding content = adding a data file, not code.
- Fields for every state a character will have, from the start: sprites per state (walk, stand,
  fly, sit, swim), young stages, icon, role line, facts, photo moments.
- Watch the engine's quirks with data files: in Godot `.tres`, properties written before the
  `script = …` line are silently ignored; binary export of text resources reset arrays (keep
  "convert text resources to binary" off and compare exported data with the project).

## Tests from day 1
- Headless test scripts in `tests/`, one per system, printing PASS / exiting 1 on failure, run
  with a time limit (`--quit-after`) so a compile error doesn't hang.
- A full-suite runner; run it before every publish. Know your flaky tests and fix them.
- Tests never touch the player's save (point save and photo paths elsewhere).
- Every new feature: a test. Every new saved field: a save round-trip check.

## Save system (day 1)
- One autoload owns saving: a dictionary per system (`to_dict` / `restore`), a `VERSION`, and
  migration for older saves (old saves must load: never lose a player's progress).
- Autosave on changes and on leaving; a small "Saved" note.
- A **save code**: the whole save as copyable text and a paste box to load it (test that a code
  from one game loads in another).
- Web: write files directly (no temp-file rename), mirror to localStorage synchronously, load
  the newest copy (`saved_at`), warn if the browser won't keep data. Saves were lost when the
  phone closed the page before this.
- Anything spawned at runtime gets a stable name and its state saved (tangled, injured, nest).
- Prefer working state out from the world (conditions) over storing it, so old saves meet the
  new rules where they are (BlueHaven's people: only met / asked / told are saved).

## Publishing to the phone (day 1)
- A one-command publish script: export the web build as an installable app (PWA) to a static
  site (GitHub Pages: first-party storage, so saves survive on iOS; itch.io's iframe didn't),
  with a home page.
- A revision label in a corner (`rN sha`, N = commit count) so the owner can say which build.
- The service worker keeps the engine cached across versions; a new version switches over on
  open/return, never mid-load.
- Compare the exported data with the project before publishing (refuse if they differ).
- Publish after a batch of playable changes, not every commit; tell the owner the revision.
- The game's own loading screen from the first publish: boot splash + a branded web loader
  (phone-and-web.md), nothing about the company, no spoilers.
- A home page whose picture is rendered from a new game (how it really starts).

## Phone-first UI (day 1)
- Input actions only (no hard-coded keys); touch, controller and keyboard all work.
- Tap walks all the way; a held finger is followed; fixed zoom steps with + / − buttons (pinch
  fought with walking).
- Safe areas: keep UI clear of notches, rounded corners and the home bar, in portrait and
  landscape; re-measure after rotating.
- Action buttons bottom right, one per nearby action, with a dead zone so near misses don't move
  the player; notes appear above them, never under.
- Short labels; no hover-only information; no emoji in game text (the font can't draw them);
  long notes stay longer.
- A HUD that grows with progress (BlueHaven: minimap and gauges appear when earned).
- One note system from the start: one short line (cut automatically), a small box, one at a
  time with a pause, only the newest waiting, no repeats soon, only about where the player is.
  Facts belong in the journal, not in notes.

## Shared frameworks (build once, reuse)
- A talk box (tap through, Back, 2 reply choices), an overlay/menu screen base, a storage menu.
- A mini-game base (start page, timer, levels, hearts, records, finish) and 2-3 shared
  frameworks for mini-games (grid, mover, sort).
- A "what is this?" info card for things that aren't self-explanatory.

## Performance rules (in CLAUDE.md from day 1)
- One cached loader for data and pictures; never `load()` or list folders in game code.
- Nothing per frame loops over every tile or flood-fills; cache it, rebuild on change (one place
  changes tiles and sends a signal). Slow work runs a few times a second.
- Measure on the biggest area before guessing.

## Art pipeline
- Placeholder SVGs with a script that adds a 1-px darker outline; import with Nearest filter.
- Name art by thing and state (`flamingo.svg`, `flamingo_flying.svg`, `flamingo_baby.svg`) so
  the ripple check can find every use.
- Shaders only if they run on the lowest renderer (Compatibility).

## Sound
- Buses defined in the project's bus layout (buses added at runtime were silent on the web).
- Placeholder sounds generated by a script; music made from data so it can react to the game.
- The web page plays like a music app (respects the iPhone silent switch).
- Mute and volume control in the menu, saved.

Exit check: the empty world runs on the owner's phone from the home screen, saves, survives
closing, reloads, shows its revision, rotates cleanly.
