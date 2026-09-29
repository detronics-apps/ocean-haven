# BlueHaven — Rules for building an island

Learned from the corrections made while building the Starting Island and the Kelp Forest.
Read this (with `CLAUDE.md` and `docs/MASTER_PLAN.md`) **before designing or coding a new
island**, so each island is right from the start instead of fixed afterwards.

**Every island is its own game.** Each has one lesson about the ocean and how people can
protect it, and a mechanic built around that lesson (Starting Island: human impact and
cleanup; Kelp Forest: a food web in balance; Mangrove Coast: water flow and connectivity).
Don't reskin the last island with new animals and plants. The rules below are the shared
foundations the mechanics sit on, not the mechanics themselves.

---

## 1. Process: design first, then build

1. **Write the island's design in MASTER_PLAN and check it with the user before coding.** It
   covers:
   - the lesson and the core loop;
   - every species' role (and which can run away);
   - buildings and their 3 levels;
   - missions, each as research → action;
   - the rare event, the objective and its discovery;
   - the health factors and their range;
   - the starting state;
   - the cross-island link.
2. **Simulate before shipping.** Write a throwaway headless script that plays several
   strategies for ~6 in-game days and prints health each day. At minimum:
   - do nothing;
   - the balanced way (at least two different balanced setups);
   - overbuilding;
   - one species running away;
   - litter left about.

   Check the numbers against section 4. Delete the script afterwards.
3. **Every new feature gets a test** in `tests/`, and every new piece of progress gets a
   save field and a check in `tests/test_save.gd`.
4. **Publish** once a batch of big changes lands (`tools/publish_pages.sh`), with the full git
   history (never a shallow clone: the revision number comes from the commit count). Tell the
   user the revision shown bottom-left.
5. When the user corrects something, **add the lesson here**.

## 2. Time and feedback

- **No in-game clock times anywhere.** Say real time ("back in 2 minutes", "2 more minutes").
  Days are fine ("for 2 days"; a day is 10 real minutes).
- **Mission durations are real minutes.** Their effects use real elapsed time, not "until
  midnight".
- **Consequences must be quick to see.** About 20 % of a change's effect happens instantly, 50 %
  within the first in-game day, and it has settled within 3–4 days. Then the player can tell
  what their choice did and fix it.
- **Something happens straight away when the player acts.** A building that invites animals
  gets its first one immediately. Taking something down makes its animals react right away.
- **Islands the ranger isn't on are paused**, so time spent on one island never costs
  progress on another (`Regions.ranger_on`):
  - no storms start there, and a warned one waits until the ranger is back (then strikes a
    morning later at the earliest);
  - no animals get caught, and patrol boats hurt none;
  - the ecosystem waits.

  Only litter builds up a little: a few pieces per day away wash in when the ranger gets
  back (`RegionData.away_litter_per_day`, capped). Growth keeps going (trees, hatchlings), so
  after 2 days away planted trees are full grown.
- **Show where things are heading.** The HUD health gauge shows two lines: health now, and
  where it will settle if everything stays as it is (`IslandHealth.heading`). Every
  ecosystem must provide a `project()` so the gauge works on its island.
- **Quiet actions still need feedback** (e.g. "Patrol boats: +3 litter"), but never a note for
  every single piece.

## 3. Ecosystems and animals

- **Buildings create conditions; animals respond.** A building never manufactures animals.
  Not every animal needs a building.
- **Every animal has a role** that changes a decision (needs help, helps others, or drives the
  island's mechanic). No background animals.
- **Animals never die, and no species ever disappears** from an island. Each keeps at least
  1; a declining species "moves away", except the last one. Injuries (storms, boats) are
  never bad and never get worse; a Rescue helps them.
- **When the player first arrives, every species is present but struggling**, at minimum
  numbers:
  - one (or two) that need help (e.g. caught in a net);
  - the island's runaway species just past a boom-and-bust;
  - a litter surge (`RegionData.arrival_litter`).

  Health starts close to 0 %.
- **Give each island one or two species that can run away** when the player helps unevenly
  (Kelp Forest: urchins when kelp recovers before otters; otters when habitats are
  overbuilt). Top predators and indicator species follow their food and are capped: they
  never take over (cormorants follow fish, capped by trees and a maximum).
- **Runaway species are animals, never people.** Tourists aren't seen in the game, so tourism is
  never a runaway or a balancing loop; funding buildings just earn more on a healthier island.
- **Nesting differs by island** where the biology does: turtles on protected sand, boobies and
  cormorants in full-grown trees, flamingos on mud-mound nests on the flats.
- **Helper animals can make placement a convenience, never a balance.** Sea otters carry floating
  litter near them ashore, so otter habitats on one side of the crescent keep that side's
  water clean for the ranger on foot.
- **Boom and bust:** a species that eats something follows its food as well as its predators.
- **Island-wide, not layout-based.** How many of something the player builds matters, never
  exactly where they put it on the island. A player must be able to keep all the wildlife on
  one side and people and boats on the other and still reach 100 %. Buildings that restore or
  watch things work island-wide (e.g. Restoration Sites restore the most damaged beds anywhere).
- **The balance must be forgiving.** Several different setups reach 100 % (Kelp Forest:
  2–4 habitats, or fewer habitats plus restoration). Only clearly lopsided play loses badly.
- **Grown young spread out** around their island's waters (near their habitat's food), away
  from busy boats. Hatchlings and pups grow bigger over a couple of days, then grow up.
- **Birds nest only in full-grown trees**, one nest per bird, and the nest shows in the tree.
  - A bird caught in litter flies back to its nest and waits there, so the ranger can find
    and free it.
  - A tree with a nest can't be cut down until the ranger moves the nest.
  - Perched birds switch to a standing picture, so they're easy to photograph.
- **Boats and wildlife share the water.** Boat-shy animals keep away from patrol areas. If
  patrol boats leave too little quiet water (measured as a share of the island's water, not
  by layout), boats start hurting animals.

## 4. Island health

- **100 % must be reachable**, in more than one way:
  - no litter within the rowboat's reach;
  - no hurt or caught animals;
  - the island fully populated;
  - its mechanic in balance.

  Never include things the player can't affect yet (oil only arrives mid-game, with the Deep
  Sea's equipment). Litter out of reach doesn't count and drifts in.
- **The range, as a target for the simulation:**

  | Situation | Health |
  |---|---|
  | first arrival | ≈ 0–10 % |
  | runaway species with litter left | ≈ 15–25 % |
  | balanced but littered | ≈ 50–60 % |
  | balanced and clean | 100 % |

- **The island's core balance scales the whole score** (`HealthFactor.scales_all`), so a broken
  mechanic pulls everything down. Too many of one species scores lower again (`too_many`).
- **Counts in the Journal are never capped** at the health target: show the real number
  ("Turtles: 18 (10 for full health)").
- Litter only washes in within the rowboat's reach, and floating litter drifts towards the
  island.

## 5. Buildings

- **Buildings with a proper function to improve get 3 levels.** Each level is visibly
  different (`tier_textures`) and improves what the building does:
  - capacity (turtle areas);
  - storage (Ranger Houses);
  - reach (patrol boats: 120 → 160 → 200 px);
  - output (recycling, visitors).

  Simple structures (docks, drawbridges) never get levels. Which buildings get levels, and
  what each level does, is worked out per island.
- **Shared buildings stay modest**, so they don't make other choices pointless: a Ranger House
  stores 4 / 8 / 10 of each (by level), and there's one recycling centre per island.
- **Hard limits are not targets** (`max_count`). Overbuilding is allowed and has consequences:
  - upkeep (`BuildingData.upkeep`);
  - an unbalanced island;
  - lost space.

  The game never says "you built too many" and never gives the optimal number.
- **Anything that can unbalance an island can be demolished or moved**, so mistakes can be fixed.
- **Nothing the player does can be permanent.** Every action can be undone and no resource the
  balance depends on can run out for good. Dug mud or sand is never destroyed: it's carried or
  stored and can be put back. Species never disappear. Taking down a building gives some
  materials back.
- **The Build menu only lists what can be built on the island the ranger is on** (`only_on`).
  Buildings for other islands don't appear, not even greyed out.
- **Buildings can be used from the rowboat as well as on foot** (e.g. moving an offshore buoy).
- Each island has **one signature facility** (research → action missions) and **funding
  facilities** whose income rises with island health. Money always comes from a healthy
  ocean.

## 6. Missions

- **Missions respond to what's happening on the island and always lead to an action**
  (detect → understand → intervene → observe again). Never a report that only says "you have
  a problem".
  - Each report says what was found and what the player can do next.
  - It stays readable at the facility afterwards.
- **Surveys mark what they find on the minimap.** Marks last until the next morning, or until
  what they mark is gone.
- **Chance-based missions use a pity guarantee** (e.g. the coastal survey has a 20 % chance
  and always succeeds by the 5th try).
- **Every mission has its own drawn icon** (`MissionData.icon`).
- **Rare events are warned only for the island they're heading for** and test that island's
  mechanic:
  - prepare → it strikes → survey → restore;
  - never "animals die" or "free population".

## 7. Plants and trees

- **Each island has its own land trees and saplings** (palm, coastal spruce, mangrove…).
  - Planted as a sapling, a tree grows one stage a day (3 stages).
  - It can be cut down and replanted.
  - A full-grown tree gives wood and saplings.
- **Plants are in the Journal's Plants tab**, found the first time the ranger comes close
  (`data/plants/`). Sea plants (kelp, seagrass, coral) are plants, never ground tiles or wood.

## 8. Journal, UI and touch

- **A species only goes into the Journal once the ranger has photographed it.** Spotting one
  says "take a photo to add it to your Journal". Every species must be photographable, even
  ones that aren't separate animals in the world (urchins, at their kelp beds).
- **Plants and habitat pieces the player didn't place can still be moved** where it makes sense
  (kelp beds are towed behind the boat to other shallow water).

- **The Journal has tabs:** This island / Animals / Plants, plus Ocean (the whole ocean's
  stats) once all 6 fleet upgrades are installed.
- **Touch comes first:**
  - a dead zone around action buttons, so near misses don't walk the ranger;
  - bottom UI kept clear of rounded phone corners in portrait;
  - no tooltips-only information (show problems as text).
- **No emoji in game text** (the font can't draw them); use drawn pictures instead.
- Long notes get more time on screen.

## 9. Code habits that avoided bugs

- New `class_name` scripts need `godot --headless --path . --import` before tests find them.
- Tests can't name autoloads or classes that use them; load scripts at runtime. Advance
  `GameClock` when a rule depends on time passing (e.g. homeless otters leave after a day).
- Anything spawned at runtime must be saved: give it a stable name, keep `born_at >= 0` for
  animals that belong to the island, and save its state (tangled, injured, nest tree…).
- Data defines content: a new animal, plant, building, mission or event is a `.tres` file;
  code only for a genuinely new mechanic.

## Still to work out

- **Levels for the functional buildings that don't have them yet** (Otter Habitat, Kelp
  Restoration Site, Kelp Discovery Centre, Kelp Research Platform, Dolphin Viewing Area,
  Marine Rescue & Research Station, tent/house), and a picture per level for the patrol buoy.
