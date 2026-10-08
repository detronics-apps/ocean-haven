# The build loop

How every piece gets built: an area, a feature, a fix. Small, tested, committed steps; the
game runs after each one.

## An area (level, island, world)
1. **Read the rules file** (`docs/RULES.md`) and CLAUDE.md first. Every area must follow every
   rule learned so far; that's what lets the 5th area be right first time.
2. **Design it in GAME_PLAN** (templates/AREA_DESIGN.md) and get the owner's approval:
   - its one lesson and its mechanic (its own, not the last area reskinned);
   - every character's role (what decision it changes) and which can run away;
   - buildings, which get 3 levels and what each level improves;
   - missions as research → action (each report says what to do next);
   - the rare event (prepare → strikes → survey → restore; tests this area's mechanic);
   - the objective (asked by a person) and the discovery it unlocks;
   - the score factors and the starting state (every kind at its minimum, a surge of trouble);
   - links to other areas.
3. **Simulate** (systems-and-calibration.md §10) until the numbers fit the target table.
4. **Number the build steps** (5-10), each small and playable, in an order where each step can
   be tested on its own (BlueHaven's Mangrove: shovel digs mud → mangrove trees → the water
   system → species → health, event, objective).
5. **Each step:**
   1. ripple check (ripple-check.md) and list the files it touches;
   2. code, data and placeholder art;
   3. a test for it (and a save check for any new progress);
   4. run the tests it touches; fix; commit with a clear message; push;
   5. update CLAUDE.md's milestone list and the plan.
6. **After the batch:** run the full suite, publish, tell the owner the revision and what to
   look at. They play it on the phone.
7. **Their corrections:** fix them (each a ripple check), and add the lesson to `docs/RULES.md`.

## A fix or small change
1. Reproduce it or find the cause (read the code; a quick probe script beats guessing).
2. Answer the owner's "why" first if they asked why.
3. Ripple check, fix, test, commit. Publish with the next batch (or right away if they're
   waiting to play).

## Ordering the work
- Foundations, then the vertical slice, then areas, then layers, then the ending, then
  calibration. Don't polish an area before the slice of the whole game works.
- Within a session: do the instructed items first, in the order given; plan items after.
- Long-running tasks (a full test suite) run in the background; don't edit project files while
  it runs; say what you're doing in one line.

## Tests
- One test per system; extend it when the system changes, never weaken it to pass.
- When a change makes old test numbers wrong, update the expectation and its message to the new
  rule (the test reads like the rules).
- Fix flaky tests (or log them); a "flake" is not a cause.
- Run the full suite before every publish.

## Commits
- One working step per commit, the message says what the player will notice.
- Commit and push before ending a turn (the session environment checks for it).
- Never commit a broken build; if you must stop mid-way, revert to the last green state.

## Midway reviews (phase 6)
After area 2-3, and when all areas exist:
- list done / open / parked ("for later") / ideas that came up / weaknesses seen in play;
- propose 2-3 directions with a recommendation;
- offer a full design overview document for an outside review (BlueHaven:
  GAME_OVERVIEW_FOR_REVIEW.md, which another AI reviewed; its feedback became the story layer);
- the owner picks; turn the pick into numbered phases; then build phase by phase.
