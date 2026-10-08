# Phase 1 — Vision

Goal: in one planning conversation, settle everything BlueHaven only discovered over 12 days.
No code. Output: `docs/GAME_PLAN.md` (template: templates/GAME_PLAN.md), approved.

Ask these in small groups (3-5 at a time, recommendation first), not as one wall. Skip what the
owner already said. Fill the plan as answers come in.

## 1. The game in one breath
- One sentence pitch. (BlueHaven: "Start with one little island. Help the ocean around you.
  Watch it come alive.")
- Who plays it? Youngest player and what they can do (BlueHaven: a 7-year-old; adults get depth
  from choices, not complex controls).
- What does the player *feel* at the end? (BlueHaven: "Oh, everything is connected", and caring
  about the real ocean.)
- The real-world message, and how it's shown without preaching.

## 2. Length and ending (decide now, BlueHaven decided late)
- How long is a full playthrough? In real hours and in game days. (BlueHaven: most players done
  by game day 60-90, ~10-12 hours; a game year is 120 days, so most never see a second year.)
- It has an **end**: what's the final scene? (BlueHaven: a Global Ocean Observatory showing all
  six islands and the links the player made, each person's closing line, credits that roll
  like Star Wars, a downloadable poster as the prize.) After it, can play go on? (Yes.)
- What's the end goal, step by step? (BlueHaven: help each island → its discovery → upgrade the
  fleet → find the next island; all six = the ending.)

## 3. Rules that never bend
Write the non-negotiables now; they decide hundreds of later choices. BlueHaven's, as a menu:
- No combat, no enemies, no killing.
- No death: things can go bad (with a floor), never die.
- No failure states: say what needs more help, let the player retry.
- No levels or XP for the player; progress is the world getting better.
- One currency, earned from the world being healthy, never from a single kind act; no in-game
  purchases (a kids' game).
- Education never interrupts play: facts go in a journal, never blocking popups or quizzes.
- Progress is visible: damaged places look muted, healthy ones vibrant; sound changes too.
- The player is a ranger/helper, not a superhero: no stats.
- Avatar creation with swappable layers (build the sprite as layers from the start).
- Nothing the player does is permanent; every action can be undone.
- Never zero of a species/kind; one means trouble.
- Nothing grows until the player has done something there.

## 4. World structure
- Areas/levels: how many, the order, how they're found (BlueHaven: 6 islands in a line, found
  one at a time by exploring; a Map only travels to found ones; Explore only at the ship).
- Each area is its own small game: one lesson, one mechanic built around it (don't reskin).
- How does the player move between them, and what carries over (shared storage? one currency?)
- Areas the player isn't in: paused (BlueHaven rule: no storms, no losses while away).
- Gating: never more than one unfinished area open at once.

## 5. People and story
- Who are the people? General job titles so they're useful everywhere (a "Researcher", not a
  "Turtle researcher").
- Objectives only come from people, as questions they ask, never as answers they hand out.
- One objective-giver and one hint-giver per area; hint-givers send you round the world.
- The player has a name the people use; replies are 2 choices.

## 6. Platform and controls
- Where will the owner play it? (BlueHaven: iPhone home screen, so a phone-first web app,
  installable, landscape and portrait, safe areas.) Also PC? Controller?
- Touch first: big buttons, short labels, no hover-only info, a tap walks, nothing tiny.

## 7. Saving (from day 1)
- Autosave (when, how often), one save slot or more, a **save code** to copy and paste (move
  between devices), survives the phone closing the browser, a version number for old saves.
- What must survive a restart? Rule: everything the player did. Every new feature adds its save
  field and a save test.

## 8. Look and sound
- Art style and view (BlueHaven: 16-bit cozy pixel art, ¾ top-down, 32×32 tiles, chibi people).
- Placeholder art until real art: simple SVG shapes with an outline; code never depends on final
  art sizes.
- Every character's states listed now (walking, standing, flying, sitting, swimming, baby,
  young…), so art and code plan for them (BlueHaven added most of these one by one).
- Sound: music that reacts to the world's state, effects, a mute and volume control.

## 9. Economy sketch (numbers come in phase 2)
- What does the player earn, from what, and spend on what? What resources exist (BlueHaven:
  funding, wood, litter, saplings, sand, mud)? Which are shared between areas?
- Where could the player get stuck (BlueHaven: wood on a treeless island → shared storage)?

## 10. Parked ideas
Keep a "Later" list in the plan for every idea not in the first version. Review it at each
midway review.

Exit check: the owner reads GAME_PLAN.md and says it's right. Then copy section 3 into
CLAUDE.md as "Game rules (non-negotiable)".
