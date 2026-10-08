# Phone and web

The owner plays the game on an iPhone, from the home screen. Everything below broke at least
once on BlueHaven.

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

## Saves on the web
- Files are copied to browser storage only when closed after writing: write directly, no
  temp-file rename. Mirror every save to localStorage (synchronous) and load the newest copy.
- Warn when the browser won't keep data (private mode, storage not persistent).
- A save code (copy/paste text) as the safe way to move or back up a game.

## Screen
- Portrait and landscape both: UI clear of rounded corners, the notch and the home bar (the
  browser's safe-area insets, never less than a phone margin); re-measure after rotating.
- Bottom corners: minimap left, action buttons right, revision label; notes appear above the
  buttons.
- Full-screen pages (menus, mini-games, the care room) use the same safe area.

## Touch
- Buttons finger-sized; a dead zone round button stacks; scroll bars finger-wide.
- Tap walks all the way there; holding is followed. Fixed zoom steps with + / − (pinch fought
  with walking).
- Typing names: ask the browser for text (the phone keyboard), since in-game text fields don't
  bring it up.
- Drag-to-do actions (care) need a button alternative for keyboard and controller.
- Downloads (a poster): the browser's download on the web, the pictures folder elsewhere.

## Sound
- Buses in the project's bus layout file (runtime-added buses were silent on the web).
- The page plays as media (respects the iPhone silent switch); sound starts after the first tap.

## Performance
- Lowest renderer (Compatibility in Godot); shaders that run there; placeholder art small.
