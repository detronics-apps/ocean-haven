# Phone and web

The owner plays the game on an iPhone, from the home screen, in portrait and on its side.
Everything below broke at least once on BlueHaven.

## Publishing
- Static site on GitHub Pages (first-party storage: saves survive on iOS; an itch.io iframe
  lost them). An installable web app (PWA) with a home page and an app icon of the game (not the
  engine's).
- One command does it all; it refuses to publish when the exported data differs from the
  project. Needs the full git history (the revision number is the commit count).
- The revision (`rN sha`) shows in a corner; always tell the owner the revision after
  publishing.
- Engine file cached across versions; updates only download what changed; the new version
  starts when the app is opened or returned to, never mid-load.
- Test the exported build, not just the editor (the browser caches the data pack: use a fresh
  port for a local server; a headless run can load the exported pack).
- Local phone testing over Wi-Fi needs HTTPS (self-signed certificate) and firewall access.

## Loading screen (set it up in foundations, not at the end)
- Replace the engine's logo from the first publish: the game's own boot splash (Godot:
  `application/boot_splash/image`, `bg_color` the same colour as the page, `use_filter=false`
  for pixel art). Drawn by a script (`tools/make_splash.py`) so it can be redrawn: the title on
  the game's world, lower part left empty for the loader.
- The splash has a see-through background and the page and engine use one solid colour behind
  it: a picture with its own background is fitted to the screen and leaves bands of another
  colour (dark and light blue) above and below it in portrait.
- Small text in the splash at full resolution, not as scaled-up pixel letters (unreadable on a
  phone).
- The web loading bar is part of the brand, but keep it a plain bar the eye understands: hide
  the engine's bar and draw a simple one just under the title (placed from the splash's own
  layout, so it sits there in portrait and landscape), with the game's own character on it
  (BlueHaven: the top-view turtle swimming at the bar's front). A globe the turtle swam round
  was moved: the bar shows the progress, and the globe turns on its own just above the title.
  Centre the character on the bar's line, not resting on top of it. It goes in the export preset's head include (a `<style>`
  and a `<script>`); the engine sets inline styles, so the CSS needs `!important`. Read the
  engine's own progress value, ease it, fall back to time when there's none; stop the animation
  once the canvas leaves the page.
- Nothing about the company on the loading screen (the owner's choice): only the game.
- No spoilers in the splash, home page or early HUD: BlueHaven's other islands are a surprise,
  so "one island at a time" became "one step at a time", and the Map button only shows once
  the first ship is built.
- Check it in a real browser: serve the export, delay the data file, screenshot mid-load.

## Home page
- A short, warm page: title, one line of what it is, one big picture, a big Play button,
  4 cards of what you do, small "promise" chips for parents (no fighting, nothing dies, no
  purchases), and how to add it to the home screen (iPhone / Android, collapsible).
- The picture is rendered from the game by a tool (`tools/make_home_picture.gd`), not a
  screenshot of someone's save, and it shows the game **as it really is when you start**
  (BlueHaven: one of each animal, still in trouble, the litter, the people at their places, no
  HUD). A "restored" picture with five turtles promised what day one isn't.
- Check it at phone width (390 px) and desktop width.

## Saves on the web
- Files are copied to browser storage only when closed after writing: write directly, no
  temp-file rename. Mirror every save to localStorage (synchronous) and load the newest copy.
- Warn when the browser won't keep data (private mode, storage not persistent).
- A save code (copy/paste text) as the safe way to move or back up a game.

## Screen: portrait and landscape
- UI clear of rounded corners, the notch and the home bar (the browser's safe-area insets,
  never less than a phone margin) in both orientations; re-measure after rotating.
- **iPhone keeps the page scrolled where it was before turning.** Pin the page (fixed
  position, no overflow), use a viewport meta with `maximum-scale=1`, and on
  `orientationchange` / resize re-set the viewport meta and `scrollTo(0, 0)`, then re-measure
  the window a moment later.
- **Measure after layout, not before.** A screen sized in `_ready` used the old (portrait)
  height and came out twice the screen on its side. Size full-screen rooms from the real size of
  their container and follow its `resized` signal (BlueHaven's vet room).
- The owner's rule for a full-screen activity on its side: **everything you look at or drag
  (the animal, its bars, the tray of things) fits one screen**; buttons below may scroll. The
  bars go on a small panel to the side, never over the main thing; focus on the subject.
- Check every screen at a phone portrait size (390x844) and landscape (844x390) before
  publishing a UI change; screenshot both.
- Bottom corners: minimap left, action buttons right, revision label; notes appear above the
  buttons.
- Full-screen pages (menus, mini-games, the care room) use the same safe area.
- Text boxes need a minimum width (a note box shrank to one character wide).

## Touch
- Buttons finger-sized; a dead zone round button stacks; scroll bars finger-wide.
- Tap walks all the way there; holding is followed. Fixed zoom steps with + / − (pinch fought
  with walking).
- A tap is a touch **and** an emulated mouse click: handle one or the other, or a button steps
  twice (the credits' speed button jumped x1 → x3).
- Typing names: ask the browser for text (the phone keyboard), since in-game text fields don't
  bring it up.
- Drag-to-do actions (care) need a button alternative for keyboard and controller; dragging
  must change the bars as well as show the effect (hearts without a rise felt broken).
- A button only when pressing it does something (see lessons); information goes on the line
  above the buttons or above the thing.
- Downloads (a poster): the browser's download on the web, the pictures folder elsewhere.

## Sound
- Buses in the project's bus layout file (runtime-added buses were silent on the web).
- The page plays as media (respects the iPhone silent switch); sound starts after the first tap.

## Performance (a phone browser is the slowest place it runs)
- Lowest renderer (Compatibility in Godot); shaders that run there; placeholder art small.
- **Never load from disk in game code**: `load()` and folder listings go to the web pack on
  every call. One cached loader (`DataFiles.res(path)`, `load_all` cached) or `preload`.
- **Nothing per frame loops over every tile or does a flood fill.** Cache it and rebuild on
  change: the minimap's land is one texture rebuilt when a tile changes (a signal from the one
  place tiles change), a circle mask in a shader; the water-flow flood fill cached until a tile
  or gate changes. Work that can wait runs a few times a second, not every frame.
- Objects that rarely change (trees) do nothing until something changes.
- The biggest, busiest area is where it lags first (BlueHaven: the Mangrove). Measure before
  guessing: stack samples of the running game, per-script timing, then fix the top item.
- Drawing a texture region past the image's edge repeats its edge pixels (a light-blue stripe
  down the minimap): clip the source rectangle to the image.

## Screenshots without a phone (for checking your own work)
- Game screens: run the engine under a virtual display at the phone's size
  (`xvfb-run -a godot --path . --resolution 844x390 --script <tool>`), keep the HUD piece you're
  checking visible, crop in window coordinates.
- The web build: a headless browser (Playwright with the preinstalled headless shell binary;
  the full browser refused the old headless mode) against a local server.
- Look at every screenshot before saying it works; say what you checked on desktop and that
  the real phone wasn't tested.
