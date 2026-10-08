# Systems first, calibration last

Set up the equations at the start so the game works; tune the numbers at the end with a test.
In BlueHaven most balance rework came from numbers chosen per feature instead of from a model.

## 1. The time scale (fix it first)
- One game day = N real minutes (BlueHaven: 10). Write it down; every duration derives from it.
- Never show clock times ("back at 14:00"); say real time ("back in 2 minutes") or days.
- Missions and timers use real elapsed time, not "until midnight".
- A full playthrough target in game days (BlueHaven: 60-90) and so in hours.
- Seasons, if any, must be short enough to be seen (BlueHaven: a 3-day ice season; a 120-day
  year that most players never finish, so nothing important may wait a year).

## 2. Feedback speed (the owner's rule)
Every change the player makes must show its effect quickly enough to connect cause and effect,
but not instantly fill everything:
- ~20 % of the effect at once, ~50 % within the first game day, settled within 3-4 days.
- Something visible happens straight away when the player acts (a building that invites animals
  gets its first one immediately).
- A gauge shows **now** and **where it's heading** (BlueHaven: two lines on the health bar). Every
  system needs a `project()` that says where it will settle if nothing changes.

## 3. Every population or stock = a limit AND a pace
The biggest BlueHaven lesson. For each thing that grows (animals, plants, resources), define two
separate equations:
- **Limit (capacity)**: how many the world can hold now (from what the player did). This is
  where it's heading, shown on the gauge.
- **Pace**: how fast it gets there. Never "fill to the limit at once".

BlueHaven's final pace rules (a good default for any breeding thing):
- each parent breeds again only once its last young are one step on (eggs hatched; or born-live
  young out of the baby stage); several parents breed at once, so more adults = faster;
- a clutch is a small range (turtles 2-4), not "enough to fill the gap";
- things that drift in from outside come at most K per day per kind (3);
- growth stages have fixed lengths in groups (grown on day 3 / 5 / 7);
- result to check: from 1 to full in roughly a week of game time, not 1 night, not 120 days.

The four rounds BlueHaven needed on turtles (all avoidable with limit + pace from the start):
"fill the gap" (8 at once) → "next spring" (120 days) → "3-4 a nest, nightly" → per-parent pace.

## 4. Thresholds with hysteresis
When something needs X to arrive, use a higher number to come than to stay, so it doesn't
flicker: BlueHaven's tree-nesting birds need 8 grown trees per bird to come, 4 per bird to stay
(the 4th bird at 32 trees, it stays while 16 remain). Same mechanism for every species of that
kind (write it once, apply to all).

## 5. Floors and ceilings
- Never zero of a kind; one means trouble and needs help.
- Bars that can drop have a floor (care health ≥ 20 %): things go bad, never to death.
- Hard limits (max buildings) are not targets; overbuilding is allowed and has consequences
  (upkeep, imbalance, lost space). Never say "you built too many"; never reveal the optimum.
- Several different setups must reach 100 %; only clearly lopsided play loses badly.

## 6. The score / health formula
Weighted factors per area, each 0..1, with the area's core balance able to scale the whole
score. Write the **target range table** first, then make the simulation hit it. BlueHaven:

| Situation | Score |
|---|---|
| first arrival (surge of trouble) | ≈ 0-10 % |
| one thing running away, mess left | ≈ 15-25 % |
| balanced but messy | ≈ 50-60 % |
| balanced and clean | 100 % |

Rules: 100 % must be reachable in more than one way; never count anything the player can't
affect yet; counts shown to the player are never capped at the target.

## 7. Placement shouldn't matter more than quantity
Systems work area-wide (how many, not exactly where), so a player can keep wildlife on one side
and buildings on the other and still reach 100 %. Placement can be a convenience, never the
balance.

## 8. The economy model
- List every source and sink of every resource, per area, with its tunable.
- Money comes from the world being healthy (visitors, research), scaled by health.
- Check each area can be done with what that area provides (a treeless area needs wood from
  shared storage).
- Daily caps on repeatable income (photos: once per kind per day; mini-game replays: one grant
  a day, never more for a better score).
- Upgrades: each level does the same job a bit better (+1 capacity, wider reach), never levels
  just to have levels; simple structures get no levels.

## 9. Write tunables as data
Every number is an exported variable or lives in a data file, with a comment saying what it
means and its unit ("days a full fed bar lasts"). Never a magic number in code. Then
calibration is editing data, not code.

## 10. Simulate (throwaway scripts)
Before shipping an area, a headless script plays it for ~6-10 game days with several strategies
and prints the score each day:
- do nothing; the balanced way (two different balanced setups); overbuilding; one thing running
  away; mess left about.
Compare with the target table. Delete the script afterwards (it's not a test).

## 11. Calibration (at the end, phase 9)
- A day-by-day model of the whole playthrough: all areas, real costs, real income, the player's
  likely order. BlueHaven's found funding held every island up: ~68 game days (~11 h) after
  tuning photo pay 20, recycling 2 + 1 per level, mini-game grants 30, trees 2-3 wood.
- Tune tunables only. If the equation is wrong, that's a design change: plan it with the owner.
- Re-run after every economy change, including upgrades and storms.
- Then the owner plays on the phone; every "this feels off" gets a number change and a re-check.

## 12. Tests for systems
Tests must advance the game clock when a rule depends on time, run what normally needs frames
(births that wait for a parent to walk there: call the catch-up function), and allow random
ranges (`in [2, 3, 4]`, not `in [2, 4]`: that's a list, not a range).
