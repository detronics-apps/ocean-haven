---
name: detronics-games
description: Detronics' way of making a game with Claude, from the first idea to a finished, published, calibrated game. Use it whenever the owner starts a new game, asks to plan or build a game feature, area, level, character, mini-game, story, save system, ending, balance or calibration pass, or says "detronics-games". It covers how the owner communicates (plan vs build), the phases (vision, systems model, foundations, vertical slice, area-by-area build, midway review, story layer, ending, calibration), the ripple check before every change, and the lessons learned building BlueHaven (Godot 4, phone web app, ~300 commits in 14 days): loading screen, home page, speed, phone portrait/landscape, storms, the ending and where donations go.
---

# Detronics games

How to take a game from "I have an idea" to a finished game the owner plays on their phone,
fast and without rework. Built from the BlueHaven build (a cozy ocean-conservation game: six
islands, people, story, mini-games, an ending). Most of BlueHaven's lost time came from three
things; this skill exists to stop them:

1. **Building before the idea was clear**, then rebuilding it (the "then and now" photo, the
   male/female rule, the nesting rules: four rounds each).
2. **Rules fixed in one place but not in the others they apply to** (one bird got the tree rule,
   a doc kept the old rule, an image was redrawn but its Journal icon wasn't).
3. **Numbers set as content instead of as a model**: limits that filled instantly, a 120-day
   wait for turtles, funding that held every island up. Model first, calibrate last.

Read the reference files when you reach their phase; don't load them all at once.

| When | Read |
|---|---|
| Every message from the owner | [references/working-with-the-owner.md](references/working-with-the-owner.md) |
| A new game, or the game's big picture | [references/phase-1-vision.md](references/phase-1-vision.md) |
| Any number, rule, population, economy or timing | [references/systems-and-calibration.md](references/systems-and-calibration.md) |
| Setting up the project (before any content) | [references/foundations.md](references/foundations.md) |
| Building any step | [references/build-loop.md](references/build-loop.md) |
| Before every change, however small | [references/ripple-check.md](references/ripple-check.md) |
| People, story, mini-games, storms, the ending, donations | [references/story-and-ending.md](references/story-and-ending.md) |
| Phone / web / publishing, loading screen, home page, portrait + landscape, speed | [references/phone-and-web.md](references/phone-and-web.md) |
| Starting a project or an area | [templates/](templates/) |
| To avoid repeating a known mistake | [references/lessons-from-bluehaven.md](references/lessons-from-bluehaven.md) |

---

## The one rule about talking: plan or build?

Decide this for every message before doing anything (details and examples in
working-with-the-owner.md):

- **Instruction** ("add / make / fix / change / remove X", "build the following", "do 1 and 3",
  "yes, change it", "make it 2-4") → build it now, exactly that, nothing extra. Ask only if a
  key choice is truly open, and then only that one question.
- **Discussion** ("what do you think", "ideas?", "only plan", "we're still discussing",
  "explain", "why is…?", "what's open?") → answer or plan, then wait. Never touch code.
- **Something completely new** (a feature never discussed) → always plan first, even if worded
  as an instruction, unless they say "build / code / create the following" or it has gone back
  and forth 3-4 times and they say "ok, let's do this".
- **Mixed message** → build the instructed parts, plan the rest, and say which is which.
- **Never re-plan what was decided.** If the owner already answered, act on it. Looping
  ("here's the plan again") is as bad as building the wrong thing.
- **"Keep it as it was" / "never mind"** → revert every file you touched for it, confirm, stop.

## The phases

Each phase ends with something the owner can see or play. Never skip ahead; never leave a
phase without its exit check.

### Phase 1 — Vision (planning only, no code)
One conversation, driven by the question list in phase-1-vision.md. Output: `docs/GAME_PLAN.md`
from the template, approved by the owner. It fixes, up front, what BlueHaven only found out
late:
- who it's for (BlueHaven: playable by a 7-year-old, depth for adults through choices);
- **how long it is** (BlueHaven: most players finish in 60-90 game days, ~10-12 hours) and
  that **it has an end** (an ending scene, credits, a prize), after which play may go on;
- the story (people who ask questions, never hand out answers), the areas and what each one
  teaches, the core loop;
- the non-negotiable rules (no combat, no death, no failure states, one currency, no levels…);
- the platform: the owner plays on an iPhone home screen, so phone-first web app from day 1;
- **saving from day 1**: autosave, a save code to copy/paste, survives phone closing the app.

Exit: the owner says the plan is right. Then copy the rules into the project's CLAUDE.md.

### Phase 2 — Systems model (planning + a throwaway simulation, no game code)
Write every moving quantity as an equation with named tunables before any content exists
(systems-and-calibration.md). For each population or resource: **its limit (where it's going)
and its pace (how fast it gets there)** — separately. Fix the time scale (one game day = N real
minutes), the feedback rule (20 % of an effect at once, 50 % within a day, settled in 3-4 days),
the health/score formula with its target range table, the economy flow, and the full-game
length model. Simulate with a throwaway script: do nothing, the right way, overbuilding, one
thing running away. Exit: the numbers land in the target table and the length target.

### Phase 3 — Foundations (skeleton, before content)
Set up what is expensive to add later (foundations.md): repo and branch, CLAUDE.md, the test
harness, data-driven content (one data file per thing), the save system with a version number
and a save code, the publish pipeline to the phone with a revision label, touch-first input,
safe areas for portrait and landscape, a HUD that can grow, sound buses, placeholder-art
pipeline, the shared frameworks (mini-game base, talk box, menus). Exit: an empty world
runs on the owner's phone, saves, reloads, shows its revision.

### Phase 4 — Vertical slice (area 1, end to end)
The first area, small but complete: the core loop, one person who asks the first question, an
objective, a discovery, the path to the next area, and a stub of the ending. Publish it. Exit:
the owner plays it on the phone and the loop feels right. Their corrections go into the
project's rules file (`docs/RULES.md`, BlueHaven's `ISLAND_RULES.md`).

### Phase 5 — Area by area (the build loop)
For each area/level (build-loop.md):
1. design it in GAME_PLAN (lesson, mechanic, every character's role, buildings and their
   levels, missions, the rare event, objective, score factors, starting state, link to other
   areas), **read the rules file first**, get approval;
2. simulate its numbers;
3. build it in numbered small steps; each step: ripple check → code → test → commit;
4. publish when a batch lands; the owner plays; corrections become rules.

### Phase 6 — Midway review (after area 2-3, and again when all areas exist)
Stop building and lay out: what's done, what's parked ("for later" items the owner mentioned),
new ideas that came up, weaknesses seen in play, and 2-3 possible directions (e.g. a story and
people layer, mini-games, polish). Offer to write a full design overview the owner can give to
another AI for review (BlueHaven did this: GAME_OVERVIEW_FOR_REVIEW.md). The owner picks; the
pick becomes numbered phases. Exit: an agreed phase list.

### Phase 7 — The layers that make people care
People and story, mini-games (real work done with a person, understood in 10 seconds), the care
mini-game, photos and the journal, seasonal moments, travelling characters, cross-area links
(story-and-ending.md). Same build loop.

### Phase 8 — The ending
The final chapter: a place that shows everything the player connected, each person's closing
line, credits that roll, the prize (BlueHaven: a downloadable poster), and play carries on.
Donations only here, as the last section, after the ending (a coffee link for parents, with
permission asked for players under 18).

### Phase 9 — Calibration and phone polish
Only now tune numbers: a day-by-day model of a full playthrough (all areas, real costs) against
the length target; tune the tunables, never the equations. Then phone play batches: the owner
plays, sends numbered issues, each one fixed and ripple-checked. Include a speed pass (the
phone browser lags first in the busiest area: measure, then cache) and a portrait + landscape
pass of every full-screen page.

## Before every change: the ripple check
Never change one thing alone. Before editing, answer (ripple-check.md has the full list):
- **Who else falls under this rule?** (a rule for one bird → every tree-nesting bird; a rule
  for turtles' breeding → every species that breeds; "this building needs X" → every building
  of its kind).
- **Where else is this used?** (an image → its icon, journal, cards, minimap, the other
  states/stages of the same character; a word → every line of dialogue and hint that says it;
  a number → docs, NPC hints, tests, the simulation).
- **What does it change downstream?** (health score, economy, the length of the game, saves
  from older versions, tests, the rules file, CLAUDE.md, the design doc).
- **Does any written rule now contradict it?** Update the rule in every doc it appears in.

## Done means
Tests pass (full suite before publishing), the change is committed and pushed, docs and rules
updated in every place they mention it, and when published, the owner gets the revision
number. Report plainly: what changed, what you assumed, what's still open — short.
