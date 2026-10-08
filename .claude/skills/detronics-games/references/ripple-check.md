# The ripple check

Before any change, however small. Most BlueHaven rework was a change made in one place that
also belonged in others. Go down the list; say in your reply what else you changed and why.

## 1. Who else does this rule cover?
A rule written for one thing usually belongs to a whole kind. Find the kind, apply it to all.
- A rule for one animal → every animal with the same trait (BlueHaven: the tree rule for boobies
  → cormorants too; "lays eggs" for turtles → crocodiles, birds, crabs; "drifts in" for one fish
  → every fish, clam and squid).
- A rule for one area → every area (building limits count per island; every island starts with
  its own rowboat; every island's storm timer starts on arrival).
- A rule for one building → every building of that kind (markers and enclosures vs real
  buildings vs built items; only real buildings with no button of their own explain themselves).
- A rule for one mini-game → all of them (same detail and standard across all six).
- Search the data for the trait (`grep -l nests_in_trees data/`), not just the one you were
  told about.

## 2. Where else is this used?
- **An image**: its icon, the journal page, cards, the minimap, island maps, the home page
  screenshot, and the other states of the same character (walking, standing, flying, sitting,
  baby, young). Changing one bird's view → all four birds' icons. Search by file name.
- **A word or name**: every line of dialogue, hint, tip, button, test message and doc that says
  it (renaming "Build" to "Make" → every "Build menu" in the people's lines).
- **A number**: the docs that quote it, the people's hints that mention it, tests, the
  simulation, the economy model.
- **A message**: does another message already say the same? (The news line "Another dolphin has
  joined us here. Another dolphin has joined the pod" said it twice.)

## 3. What changes downstream?
- The score/health: can 100 % still be reached, more than one way? The target table?
- The economy and the game's length (re-run the model if income or costs moved).
- Pace and limits: does anything now fill at once, or take far too long?
- Saves: does an old save still load and make sense? Need a migration or a new saved field?
- Areas the player isn't on: paused as they should be?
- Phone: does it fit in portrait and landscape, near the corners?
- Tests: which ones assert the old behaviour? Update them to the new rule.
- People and hints: does any person now say something untrue?

## 4. Which written rules does this touch?
- Search CLAUDE.md, the plan and the rules file for the old rule. Update **every** place it
  appears, and make the old one say what replaced it. (After the care-bars change, two old lines
  still said "care bars only go up" and "one new animal a day": found only by searching.)
- If the change breaks a non-negotiable rule, stop: ask the owner whether the rule changes. If
  yes, change the rule text first, then build.
- Add the correction to the rules file as a lesson.

## 5. Is it undoable and never zero?
- Can the player undo it? Can a resource the balance needs run out for good? Can a kind of
  thing disappear?

## 6. Exactly what was asked?
- Re-read the request. Remove anything extra. If you think something extra would help, offer it
  in one line instead.
