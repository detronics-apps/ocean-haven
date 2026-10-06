# BlueHaven: the full game layout, decisions and plans (for outside review)

**What this document is.** BlueHaven is a game being built by one developer (the owner) with an
AI coding assistant. This document is self-contained. It describes:
- what the game is and who it's for;
- what is already built and playable;
- the design rules learned so far;
- the next layer we have been planning (characters, litter sources, mini-games, seasons);
- every decision already made, and what is still open.

**What we'd like from you (the reviewing AI):**
1. Evaluate the plan. Is it fun for a 7-year-old, does it have depth for an adult, and does it
   get the real-world message across without preaching?
2. Point out risks: overload, confusing flows, balance problems, scope that's too big.
3. Check the facts marked **[verify]** and flag any other claim that may be wrong.
4. Suggest improvements and alternatives, especially for the mini-games, the character story
   and the litter chain.
5. Answer the open questions in section 10 with a recommendation.
6. Respect the **non-negotiable rules** (section 2) and the **rejected ideas** (section 9).
   Don't bring rejected ideas back without a new reason.

Your feedback goes back to the owner, then to the coding assistant as step-by-step tasks.

---

## 1. The game in short

- **Name:** BlueHaven.
- **What it is:** a cozy 2D pixel-art ocean-conservation game.
- **Core fantasy:** "Start with one little island. Help the ocean around you. Watch it come
  alive." You're a conservation ranger, not a superhero.
- **The owner's real aim:** people should care about the *real* ocean, not just the game. The
  owner wants their own children to grow up still able to see these animals. The game should
  teach about animals, research, logistics and sustainability, in a way that's fun and worth
  the time.
- **Players:**
  - playable by a 7-year-old (simple controls, touch first);
  - depth for older children and adults comes from choices, not complex controls;
  - three layers in one game:
    - kids: explore, collect, build, animals;
    - older children: ecosystems and cause and effect;
    - adults: planning, funding and connected ecosystems.
- **Platform:**
  - Godot 4 (GDScript), the low-end-friendly "Compatibility" renderer;
  - published as an installable web app (PWA) on GitHub Pages;
  - the owner plays it mainly from an iPhone home screen; keyboard, controller and touch all
    work.
- **Look:** 16-bit cozy pixel art (SNES-like), ¾ top-down view (Stardew-style), 32×32 tiles,
  chibi characters. Placeholder art for now.
  - Damaged areas look muted (dark blue, grey, brown).
  - Healthy areas look vibrant (turquoise, coral pink, tropical green).
- **Time:**
  - one game day is 10 real minutes;
  - a game year is 120 days;
  - players sleep at night (tent or house) to skip to morning.
- **Save:** an automatic save (browser storage plus a localStorage copy) and a copyable save
  code.

## 2. Non-negotiable rules

- **No combat.** No weapons, enemies, killing, bosses or combat stats.
- **Animals never die**, and no species ever disappears from an island. Each species keeps at
  least 1. A declining species "moves away".
  - Injuries are never bad and never get worse.
  - Care meters only ever go up.
- **No levels or XP for the player.** Progress is the restoration of each island ("Ocean
  Impact"). New islands are unlocked through restoration, not by player level. (Buildings do have
  3 upgrade levels.)
- **One currency: conservation funding.**
  - No premium currency, no in-game purchases, no donate buttons.
  - Money comes from a **healthy ocean** (eco-tourism, research, grants), **never directly from
    rescuing an animal**.
- **No failure states.** Never "you failed". Say what needs more help ("The beach needs more
  protection") and let the player try again.
- **Education never interrupts play.** Facts go in the Ocean Journal and on Discovery Cards,
  never in blocking popups. No mandatory quizzes.
- **Facts must be accurate.** Animals are cute but biologically recognisable.
- **Progress is visible:** colour, sound and the number of animals change.
- **Every animal matters.** No background animals. Each species needs the ranger's help, helps
  other animals, or both.
- **Data, not code, defines content.** A new animal, item, building, mission or person is a data
  file.
- **Avatar creation:** skin, face, hair, eyes, outfit, gear, boat look, built as layers.
- **Map and Explore are never merged.**
  - **Map** sails only to islands you've already found.
  - **Explore** is only at an Exploration Ship, and it discovers new islands.

## 3. What's built today (playable, published as revision r184)

### 3.1 The six islands

The islands lie in a line, **Polar · Deep Sea · Kelp · *Starting* · Mangrove · Reef**, so
there are two routes from the Starting Island:
- colder: Kelp Forest → Deep Sea → Polar Ocean;
- warmer: Mangrove Coast → Tropical Reef.

Every island is its own game with its own lesson:

| # | Island | Lesson | Signature mechanic |
|---|---|---|---|
| 1 | Starting Island (horseshoe island with a lagoon) | What we do locally affects the ocean | Pollution → cleanup → recovery |
| 2 | Kelp Forest | Species depend on one another | Food web: otter → urchin → kelp → fish → cormorant |
| 3 | Mangrove Coast | Land and ocean are connected | Water flow, silted channels, nursery pools, water gates |
| 4 | Tropical Reef | An ecosystem is many systems working together | Coral restoration; each animal has a job |
| 5 | Deep Sea | We can't protect what we don't understand | Mapping 8 dark areas with instruments that also disturb |
| 6 | Polar Ocean (Arctic) | The ocean connects the planet | A 3-day ice season; planning around change |

**Starting Island**
- **Animals and their jobs:**
  - green turtles: nest at Turtle Protection Areas; hatchlings grow up; 10 for full health;
  - dolphins: lead you to floating litter after you play with them;
  - ghost crabs: dig up buried litter;
  - red-footed boobies: nest in full-grown palms, so you can't cut every tree.
- **Buildings:** Marine Rescue & Research Station (missions), Turtle Protection Areas, Dolphin
  Viewing Areas.
- **Rare event:** Coastal Storm.
- **Objective:** a station survey finds an old wreck → clear its litter → lift its sonar →
  **Salvaged Sonar Core**.

**Kelp Forest**
- **Animals:** sea otters (eat urchins; carry floating litter ashore), urchins (graze kelp;
  boom and bust), blue rockfish, cormorants (need full-grown trees).
- **Buildings:** Otter Habitats, Kelp Restoration Sites, Kelp Discovery Centre, Kelp Research
  Platform (7 missions).
- **Rare event:** Heavy Swell.
- **Objective:** balance → gather shed kelp → **Kelp Fibre**.

**Mangrove Coast**
- **The mechanic:** dig silted channels so the 5 nursery pools are linked to the sea; Water
  Gates set the water level.
- **Animals:** young snappers per linked pool, flamingos (feed when the level is right; mud-mound
  nests), mangrove crabs (engineers; a few slow silting), crocodiles (Protection Zones keep boats
  out).
- **Other buildings:** Waterworks Station (6 missions), Eco-Lodge.
- **Rare event:** Flash Flood.
- **Objective:** water flowing → resin → **Mangrove Resin**.

**Tropical Reef**
- **Coral:** 10 reef patches grow back as far as coral fragments are planted (from the boat), and
  as fast as clear water and grazing allow.
- **Each animal has a job:**
  - parrotfish build the sea floor up into sand;
  - giant clams in a Marine Water Treatment Facility make **Clean Water**;
  - a reef shark circles hidden ghost gear;
  - seahorses need grown seagrass in Protection Areas.
- **The Glassworks:** turns sand into the ability to make glass. Glass + clean water =
  **reusable bottles**, and then no new plastic bottles drift in on any island.
- **Rare event:** Hurricane.
- **Objective:** 70 % health → dead coral rubble → **Reef Limestone**.

**Deep Sea**
- **The mechanic:** 8 dark areas are mapped by instruments:
  - Hydrophone Buoys (quiet);
  - Deep Cameras (lamps light the dark; baiting draws sixgill sharks);
  - submarine dives (noisy).
- **Learning costs quiet:** light and noise make whales and anglerfish move away; the giant squid
  only shows itself in quiet water.
- **Lost gear:** mapped areas show it; 3 recovered = **gear marking**, and no new nets or fishing
  line drift in anywhere.
- **Rare event:** Oil Spill (spreads until it's contained).
- **Objective:** map 6 areas at 70 % → find and tow in the **Cargo Module**, which opens a cargo
  hold on every Exploration Ship.

**Polar Ocean (Arctic)**
- **The season:** a 3-day ice cycle: freezing, frozen, thawing, open water. Boats break the thin
  ice.
- **Animals:**
  - ringed seals: need Seal Pupping Zones on *old* ice (zones on seasonal ice lose their pups
    when it melts);
  - polar bears: need a Quiet Den Area and an ice corridor joined at the freeze;
  - Arctic cod: follow the ice;
  - Arctic terns: nest in the thaw and visit the ranger's other healthy islands in the freeze;
  - Arctic skua: circles trouble.
- **No trees:** wood comes from storage.
- **Rare event:** Major Ice Breakup.
- **Objective:** 70 % → drill on old ice for 3 days → **Ice Core**.

### 3.2 Systems that tie it together

- **Island health** (0–100 % per island) comes from litter in reach, healthy animals, and the
  island's own balance (which scales the whole score).
  - Rough targets: first arrival ≈ 0–10 %, lopsided play ≈ 15–25 %, balanced but littered
    ≈ 50–60 %, balanced and clean 100 %.
  - The HUD gauge shows health now and where it's heading.
  - Ground colours go from muted to vibrant with health.
- **Exploration:**
  - an Exploration Ship can only be built once its island's objective is done;
  - each discovery, installed at any ship, upgrades the whole fleet (fleet level = discoveries
    installed);
  - a ship only finds the island *next to its own*;
  - the fleet finds only one more island than its level (level 1 finds the 2nd island, level 2
    the 3rd…), so there's never more than one island that hasn't been helped yet.
- **Islands you're not on are paused:** no storms, no animals getting caught, no ecosystem change.
  Only a little litter builds up while you're away.
- **Rare events:**
  - one per island, a random 30–60 days apart, warned 3–4 days ahead;
  - you "Secure" buildings to prepare;
  - damage is always recoverable (repairs; a Rescue mission for injured animals);
  - **each island's storm timer starts when you first reach that island.**
- **Funding:** visitor facilities pay each morning × (1 + island health); research grants;
  recycling (2 per piece). Buildings cost funding + wood (tents, houses and recycling centres use
  litter).
- **Wood:**
  - from each island's own trees (palms, coastal trees, mangroves, shore pines; 3 growth stages);
  - the Reef and Polar Ocean have no wood source, so Ranger Houses store wood and saplings for
    every island;
  - after the Cargo Module, ships hold 99 of everything.
- **Boats:**
  - every island has its own rowboat (+2 more that can be built);
  - boats stay where they were left;
  - you can tow a boat from a boat;
  - the shovel works from the boat (sand and mud reshape shallows and beaches).
- **Missions** from each island's signature facility take real minutes, respond to what's
  happening, and always lead to an action. What they find is marked on the minimap.
- **Journal:** tabs This island / Animals / Plants (+ Ocean at the end). A species only goes in
  once photographed. A save code is kept there too.
- **The HUD grows with the game:**
  - the minimap appears with the Sonar Core;
  - the island health bar appears with the research station on your 2nd island;
  - the blue water bar appears once you can make clean water.
- **Clean water (just changed):** clean water bottles are stored at your tent or house. While any
  are stored you move 30 % faster on foot and by boat. Each bottle lasts half a day (2 a day).
- **Goal line + Tip button (just added, will be replaced by people, section 6):** the goal shows
  the island's headline animal ("Bring the sea turtles back: 3 / 10"), then "explore to find a new
  island". A Tip button gives one tip for where you are in the game.

## 4. Design rules learned so far (from the owner's corrections)

- **Design each island first, get the owner's OK, simulate the balance, then build.**
- **Consequences must be quick to see:** about 20 % of the effect at once, 50 % within a day,
  settled in 3–4 days.
- **Buildings create conditions; animals respond.** Buildings never manufacture animals.
  - Hard limits are not targets.
  - Overbuilding is allowed and has consequences.
  - The game never tells you the optimal number.
- **Island-wide, not layout-based:** how many you build matters, not exactly where.
- **The balance must be forgiving:** several different setups reach 100 %.
- **Solving a problem at its source ends it**: restoration has an end state.
- **Learning has a cost, and it can be undone** (the Deep Sea's instruments disturb, and can
  be taken out again).
- **Seasons must be quick** to see within a session (the 3-day ice cycle).
- **Nothing the player does is permanent.** Everything can be undone, moved or demolished.
- **Research always leads to an action:** detect → understand → intervene → observe again.
- **Every thing in the world explains itself close up.**
- **Touch first:** finger-wide buttons, a dead zone round action buttons, safe areas on phones.
- **No emoji in game text**, since the font can't draw them.
- **Don't overload the player early.** The HUD and features unlock with progress.

## 5. Recent feedback from the owner, and what was done

| Owner's feedback | Result |
|---|---|
| "I don't understand the dark patches on the Deep Sea / the clean water bottle thing" | Every island got a first-visit note; boat-only things explain themselves; clean water was simplified |
| Clean water should simply give a boost while bottles are stored at home | Done: 2 bottles a day, an automatic boost |
| Storms hit an island 5 days after I first got there | Done: each island's storm timer starts on first arrival |
| Plenty of funding, too little wood | Done: trees give more wood, buildings need about a third less, recycling pays less |
| The minimap and health bar should come with progress | Done |
| The screen jumps when getting off the boat | Done: the camera glides |
| The goal should be about turtle numbers and exploring; one tip at a time, only when asked | Done for now (Tip button); to be replaced by the people system |
| Explore found 2 islands at once / too far ahead | Done: one island at a time, at most one more than the fleet level |

## 6. The next layer: people, story and objectives (agreed direction, details still open)

### 6.1 The owner's requirements (decided)

1. **Objectives never just appear on screen.** They come only from talking to people in the
   game. There must be a proper story reason to go and talk to someone.
2. **People ask the questions that need asking; they don't give the answers.** That way the game
   helps the player think. The flow:
   1. a person asks a question ("Don't you think there's an alternative to plastic bags?");
   2. a bit later, the objective appears ("Find an alternative to plastic bags");
   3. when it's done, it drops away and a new one comes.
3. **Two kinds of people on every island:**
   - **an objective-giver.** They have a *general* job title (Researcher, Diver, Fisher…), never
     a narrow one like "turtle researcher" that would leave them stuck on one island. You keep
     going back to them from later islands for tasks in their field.
   - **a hint-giver** (like an old lighthouse keeper). You go to them for advice and opinions.
     They can't give objectives, but they can send you to another island's hint-giver. **This
     replaces the Tip button.**
4. **On the Starting Island, all objectives come from the Researcher until the Sonar Core** is
   found. Each new island introduces its own objective-giver for that island. Earlier people
   stay available for more tasks in their field.
5. **The first hint:** the old lighthouse keeper remembers many more turtles on the beach, so it
   might be good to protect them. That's the "shifting baseline": each generation thinks the
   ocean it grew up with is normal.
6. **Existing saves (decided):** players who are already far into the game get all the
   characters. Nothing they say depends on past conversations: every objective and hint is
   worked out from the current state of the game, so it's always up to date.
   - Example: a player already at the Deep Sea goes to the Researcher. She doesn't say "start
     taking photos". She greets them for what they've done and mentions the photo collection
     they don't have yet ("9 of 30 moments; the crab digging is still missing").
   - Story objectives they've already got past are skipped.
   - Collections (photo moments) are side tasks that never block the story.
7. **Names must be easy to change**, so they live in data files.
8. **Don't overpopulate the Journal or cards.**

### 6.2 The characters (draft names; jobs and roles proposed)

One objective-giver and one hint-giver per island. Each stands at a fixed spot near the
island's arrival, by the building their work uses (or a small camp until it exists).

| Island | Objective-giver (job) | Backstory | Keeps coming back for | Hint-giver (job) | Backstory and style of hints |
|---|---|---|---|---|---|
| Starting | **Dr. Maya Okafor** (Researcher) | Came to find out why the island's wildlife has dwindled | Photo moments on every island; research questions | **Tom Pieters** (Lighthouse keeper) | 50 years at the light; remembers beaches covered in turtle tracks. "They need a quiet stretch of sand." Comments as things recover. Sends you to Ines |
| Kelp Forest | **Finn Larsen** (Diver) | Used to dive for urchins to sell; watched the kelp vanish into urchin barrens; now restores it | All underwater work: coral planting, gear recovery | **Ines Moreau** (Harbour cook) | Her grandmother saw otters hunted nearly to extinction for fur **[verify wording]**. "Bring the otters back and the kelp looks after itself." Sends you to Samuel |
| Mangrove | **Rosa Mendes** (Fisher) | Her catch depends on the young fish from the nursery pools; silt emptied her nets | Fishing gear, markets, food boxes | **Samuel Achebe** (Boat builder) | Built boats from these channels all his life. "Water that stands still drops its mud." Sends you to Leilani |
| Tropical Reef | **Kai Nakoa** (Engineer) | Runs the water treatment and the Glassworks; asks "how could we make this differently?" | How things are made: bottles, filters | **Leilani Kahale** (Dive guide) | Knows where every current dumps litter. "Follow the shark: it's circling something caught down there." Sends you to Bram |
| Deep Sea | **Dr. Imani Osei** (Pilot) | Pilots the Outpost's submarine | The fleet, navigation, exploring | **Bram de Vries** (Retired captain) | 40 years on a trawler; admits he lost nets out here. "Whales talk in clicks; make noise and they go quiet." Sends you to Erik |
| Polar | **Dr. Sanna Lind** (Expedition leader) | Leads the station's expedition | Final, ocean-wide questions | **Erik Holm** (Weather watcher) | Has written down the ice every day for 30 years. "Pups need ice that lasts." Sends you back to Tom (the circle closes) |

**Open:** the Arctic is home to Inuit communities, and Inuit knowledge is part of real Arctic
research. An Inuit character would need careful research and respectful portrayal. Until that's
decided, the draft has two station staff.

**Maya's story objectives on the Starting Island**, in order. Each is skipped if it's already
done:
1. Photograph 3 different animals. This is a new game only; for later players it becomes the
   photo collection side task.
2. Build the research station → survey the coast.
3. Clear the wreck → lift the sonar.
4. Build an Exploration Ship and install the sonar.

The objectives of the other islands map onto their objective-giver the same way: the existing
objectives (section 3.1) become their conversations.

**How talking works:**
- You talk to a person with the action button, like an animal.
- A talk is 2–3 short speech bubbles.
- The current objective shows on the HUD goal line and in a short Notebook list.
- The only things saved: who you've met, and which questions have been asked. Everything else is
  checked live.

### 6.3 Photo moments (the album) (decided in principle)

- **2–3 photo moments per species**, each one a *specific situation*. For example, the ghost crab:
  digging on the sand · in the water · out at night.
- An image is saved only the first time you catch a new moment, never one a day.
- Ordinary photos still earn research funding, but aren't kept.
- Missing moments show as silhouettes with a hint, so there's always something to look for.
- The album sits inside each animal's existing Journal page (no new tab).
- **Tagged, named animals (agreed idea, not yet detailed):** you can tag an animal and give it a
  name. A tagged migrating animal (e.g. "Steve" the turtle from the Starting Island) can turn up
  on another island, **but only while both islands are in good condition**. Its Journal page
  shows its photos over time.

### 6.4 Stopping litter at its source (decided in principle; details open)

**Decided:**
- **At most six litter problems**, chosen for the best real story and a real reusable
  alternative.
- **Solving all six takes all six islands.**
- The research station does *not* send a "trace the source" mission. Instead, each litter type
  counts how many you've picked up over the whole game. At its threshold the question comes up,
  and each next threshold is a bit higher.
- The flow follows section 6.1: a person asks → an objective → a hint-giver says where to
  look → an "Investigate" mission on that island → the report explains the alternative →
  building or doing it stops that litter on every island.
- **Honesty:** a fix is never a swap from one throwaway thing to another. The owner's example:
  paper straws turned out badly (studies found PFAS in many paper straws **[verify]**, and they
  make drinks taste bad). Fixes are reuse, refill, return, or designing the problem out.
- **Don't overwhelm the start:** the chain doesn't begin on the Starting Island.

**Proposed six problems:**

| # | Litter | Washes up most at | Asked by | Researched at | The real fix |
|---|---|---|---|---|---|
| 1 | Plastic bottles (already in the game) | Tropical Reef | Kai | Reef: Glassworks + clean water | Reusable bottles and refills (already built) |
| 2 | Plastic bags (already in the game) | Mangrove Coast: bags snag in mangrove roots **[verify]** | Rosa | Starting Island: Maya's station; Tom remembers woven bags | Reusable bags woven from palm leaves (a tradition in many Pacific and Southeast Asian places **[verify]**) |
| 3 | Six-pack rings (new; they tangle animals) | Kelp Forest | Finn | Reef: Kai designs it out | Packs that don't need rings: returnable crates |
| 4 | Foam food boxes (new; they crumble) | Starting Island (picnics) | Maya | Mangrove: the Eco-Lodge | A return-and-reuse box scheme |
| 5 | Fishing line and ghost nets (already in the game) | Deep Sea | Imani | Deep Sea, with Rosa's help | Gear marking (built) + old nets recycled into nylon yarn **[verify]** |
| 6 | Microfibres (can't be picked up) | Polar: found in the Ice Core (microplastics concentrate in Arctic sea ice **[verify]**) | Sanna | Reef: Kai builds a filter | Washing-machine filters (France requires them on new machines from 2025 **[verify]**) |

**Fact corrections already found:**
- The owner's example of kelp making reusable bags isn't realistic. Seaweed makes compostable
  films and coatings, not strong reusable bags.
- The existing Glassworks says parrotfish sand makes glass. Parrotfish sand is coral sand
  (calcium carbonate), but glass is mostly silica (quartz) sand plus lime. The honest version:
  beach quartz sand + lime from parrotfish sand → glass **[verify]**.

**Proposed thresholds:** 20 / 30 / 40 / 55 / 70 pieces, rising with each question. The
microfibres come with the Ice Core.

**Open: where the chain starts.**
- The owner suggested the Tropical Reef, because its fresh-water story is a good first problem.
- The catch: the Reef can be your 3rd island or your 6th, depending on the way you explore.
- So there are two options:
  - **A:** start on the Reef. On a colder-first route the whole chain comes late.
  - **B (assistant's recommendation):** start when you reach your 2nd island, with each question
    only asked once its research island has been found.

### 6.5 Mini-games: one per island (decided in principle; picks open)

**The owner's requirements:**
- *fun* games, one per island;
- replayable, never only hard the first time (no hidden-object games);
- inspired by popular games (Flappy Bird, Mario-style diving levels, Tetris, memory card pairs,
  sorting coloured sand or liquid between bottles, puzzles);
- the effect on the main game should be clear: funding, or the research one of the missions
  needs (e.g. finding the sonar).

**Proposed rules:**
- Nobody loses: bumping into something only slows you down.
- Numbered levels get harder.
- You can play as often as you like, but each one **affects the island once per game day**.
- The effect is research or an ecosystem effect, or a small research grant. Never money from
  rescuing an animal.

**Styles we could borrow from:**

| Style | Popular example |
|---|---|
| Tap to fly / swim through gaps | Flappy Bird, Jetpack Joyride |
| Swim-and-collect levels | Mario underwater levels, Ecco |
| Falling blocks | Tetris |
| Match-3 | Candy Crush |
| Memory pairs | Concentration |
| Sort and pour | Water Sort Puzzle |
| Connect the pipes | Flow Free, Pipe Mania |
| Clues on a grid | Minesweeper (without bombs) |
| Draw the path | Flight Control |

**Proposed picks:**

| Island | Game (style) | How it plays | Effect in the main game |
|---|---|---|---|
| Starting | **Sonar Sweep** (Minesweeper without bombs) | Tap ocean squares to ping; numbers show how many hidden objects are next to it; work out where the wreck and lost litter are. Random grids, bigger each level. | The coastal survey's research: the first win finds the wreck. Afterwards it marks hidden litter on the minimap for that day. |
| Kelp | **Otter Dive** (Mario-style swim levels) | Hold to dive, let go to rise; grab urchins, come up for air; the otter cracks shells on its belly with a rock (real tool use). | An urchin survey: urchins go down a little that day. |
| Mangrove | **Channel Flow** (Flow Free / pipes) | Turn channel pieces until every pool is linked to the sea before the tide turns. | Shows the best channels to dig that day. |
| Reef | **Glass Sort** (Water Sort Puzzle) | Pour layers of coloured sand from jar to jar until each jar holds one colour (glass colour really comes from minerals **[verify]**). | A batch of reusable bottles (bottle story progress) + a small grant. |
| Deep Sea | **Echo Dive** (cave flyer in the dark) | Steer the submarine through a black canyon; each sonar ping lights the walls for a moment; pick up lost gear. | Maps part of a dark area. |
| Polar | **Floe Fit** (Tetris) | Ice floes drift down and freeze into place; full rows join the bears' corridor. | Repairs lanes broken by boats for that freeze. |

**Alternatives:**
- Flamingo Flight (Flappy Bird style migration; the owner's own example) for the Mangrove;
- Tern Journey (Flappy Bird style; the Arctic tern's migration is the longest of any animal
  **[verify]**) for the Polar Ocean;
- Coral Match (match-3) for the Reef;
- a memory card game for animal or fish identification.

### 6.6 Seasons and turtles

**Decided:**
- Show the time of year on the HUD, next to the time of day and the day count, e.g.
  **"Year 1 · Spring, day 12 · Evening"**. That's four 30-day seasons in the 120-day year.
- **Turtles should take longer to grow up**, and nesting is seasonal:
  - in the first season (30 days) the turtles should reach a good number;
  - after that, egg-laying drops until the next nesting season.

**Today:** turtles nest every 2 days, eggs hatch in 1 day, hatchlings grow up in 2 days.

**Proposal** (to be simulated before building):
- hatchlings take **8 days** to grow up;
- nesting season is Spring (days 1–30), with a nest every 3 days per turtle;
- the rest of the year, about one nest a season per turtle;
- real basis: green turtles nest seasonally, each female only every 2–4 years **[verify]**.

**The target:**
- with 3 Turtle Protection Areas, about **6–8 turtles by day 30**;
- **10 early in year 2**.

**Existing saves:**
- the season comes from the day number;
- grown turtles stay grown.

**Caveats:**
- Tropical islands don't have four real seasons. Their events can follow their own real timing.
- The Polar Ocean keeps its quick 3-day ice cycle for gameplay.

**Seasonal moments (liked, details to come):** nesting season, hatchling runs, whale migration
passing, terns arriving, a coral spawning night after a full moon **[verify]**.
- Each comes with a note the evening before and is a special photo chance.
- Nothing is lost if you miss one; it comes back next year.

### 6.7 Predict, then watch (liked)

- Before some missions, the Researcher (or another objective-giver) asks a question with 2–3
  picture answers: "What happens to the kelp if the otters come back?"
- Days later, the Notebook shows what really happened next to your guess. There's no score: a
  surprise counts as much as a right guess.
- The ecosystems already compute where they're heading, so the result is always true to the
  game.

### 6.8 The real-world message (agreed aim)

- The game should make people care about the real ocean, so the next generation still sees these
  animals.
- Tools agreed so far:
  - the "shifting baseline" through Tom and Erik (what used to be normal);
  - real success stories (e.g. sea otters and humpback whales recovering under protection
    **[verify]**);
  - the honest, evidence-based litter fixes.

## 7. Characters and objectives through the whole game (the intended flow)

1. **New game, Starting Island.**
   - The goal line says "Talk to Dr. Maya". She gives the first objective.
   - Tom (lighthouse) is there for advice: the turtle memory, quiet beaches.
   - Maya's chain leads to the wreck and the Sonar Core.
   - Building the Exploration Ship and exploring is her last Starting Island objective.
2. **2nd island (Kelp or Mangrove).**
   - Its objective-giver gives that island's objective.
   - Its hint-giver gives advice, and Tom has pointed you there.
   - From here the litter chain may begin (option B): a question about one litter type.
3. **Later islands.**
   - Each adds its two people.
   - You go back to earlier objective-givers for tasks in their field: Maya for photos and
     research questions on every island, Finn for underwater work, Rosa about fishing gear,
     Kai about how things are made, Imani about the fleet.
   - Hint-givers link up: Tom → Ines → Samuel → Leilani → Bram → Erik → Tom.
4. **The end.**
   - All six litter problems solved, all six discoveries installed.
   - Then the Ocean Research Vessel and the Global Ocean Observatory (already planned): a view of
     the whole connected ocean.

## 8. The existing plan beyond this (already agreed earlier)

- **Connected ocean:** cross-island effects seen in the world, e.g. mangrove nursery fish
  reaching the Reef, and safer migration routes.
- **Ocean Research Vessel and Global Ocean Observatory:** the end-game view.
- **Smaller items:**
  - levels for some buildings that don't have them yet;
  - planting seagrass by hand;
  - more animals;
  - a turtle rehab care mini-game (an earlier idea; it could become part of section 6.5);
  - real art.

## 9. Ideas considered and rejected or parked (and why)

| Idea | Status | Why |
|---|---|---|
| Climate change via solar panels / electric boats / "green energy" buildings | **Rejected for now** | The owner won't tell kids that solar or electric is good without a full life-cycle assessment: mining, manufacturing, lifespan, efficiency, infrastructure, disposal. Ocean effects that are well established (warming water bleaching coral) are fine to show; tech fixes aren't. |
| A real-world "Ocean Pledge" checklist | **Rejected** | Too preachy, and pledges can push bad swaps (paper straws). |
| A "Real Ocean" tab / "Spot it for real" list / parent links | **Parked** | The owner didn't like these ideas; set aside for now. |
| The research station sending a "trace the source" mission | **Rejected** | Replaced by the pickup-count threshold that raises a question. |
| One character (Kai) handing out the solution ideas | **Rejected** | People must ask questions, not give answers, so the player thinks. |
| Vague characters ("a visiting child") | **Rejected** | Each person needs a clear job and a reason to visit. |
| Narrow job titles ("turtle researcher") | **Rejected** | They would tie the person to one island. |
| Hidden-object style mini-games | **Rejected** | Only a challenge the first time. |
| Daily streaks / daily rewards | **Rejected** | Pressure doesn't suit a kids' game. |
| Kelp-made reusable bags | **Corrected** | Not realistic (see 6.4). |
| A Tip button | **To be replaced** | The hint-givers take over. |

## 10. Open questions (the owner hasn't decided yet; recommendations welcome)

1. Are the character names, jobs and backstories in 6.2 right? Should there be an Inuit
   character on the Polar Ocean, with research first?
2. The litter chain: does it start on the 2nd island (B) or on the Reef (A)? Are the six
   problems and the 20 / 30 / 40 / 55 / 70 thresholds right?
3. Mini-games: are these six picks right, or should Flamingo Flight or Tern Journey come in? Is
   "affects the island once per game day; research or ecosystem effect, never animal money" the
   right rule? Should a mini-game ever *replace* a mission's waiting time (like Sonar Sweep finding
   the wreck)?
4. Turtles: 8 days to grow up and a Spring nesting season? Are 6–8 turtles by day 30 the right
   target?
5. Should the Tip button stay until the first hint-giver has been met, then go?
6. Tagged animals: how does tagging work (after a rescue? a photo moment?), and how many named
   animals at most?
7. Photo moments: 2 or 3 per species? Which situations per species?
8. Predict-then-watch: how often, so it never interrupts play?

## 11. Suggested build order (a draft, to become step-by-step tasks)

Each step is small, playable, tested and saved, and balance changes are simulated first.

1. **People: the foundation.**
   - Person data files (name, job, island, spot, lines).
   - Talking with the action button.
   - Speech bubbles.
   - The Notebook with current objectives.
   - The first people: Maya and Tom on the Starting Island.
   - Objectives from Maya, worked out from the game state.
   - Remove the Tip button once Tom exists.
2. **People on the other five islands.** Their objectives come from the existing ones, worked out
   from the game state for existing saves. Hint-giver chains.
3. **Seasons on the HUD + the turtle growth / nesting rework** (simulated).
4. **Photo moments and the album** (2–3 per species).
5. **Litter chain:** pickup counters, thresholds, the questions, the "Investigate" missions, two
   new litter items (six-pack rings, foam boxes), the fixes. Microfibres with the Ice Core.
6. **Mini-games, one at a time**, starting with Sonar Sweep (Starting Island).
7. **Predict-then-watch questions.**
8. **Tagged, named animals visiting healthy islands.**
9. **Seasonal moments.**
10. **Connected ocean, then the Ocean Research Vessel / Observatory.**

## 12. Glossary (names used in the code, in case a reply refers to them)

- **RegionData:** an island's data (health factors, objective goals, arrivals, flagship animal).
- **ObjectiveGoal:** one step of an island's objective (kinds: help, litter, flag, count; with a
  hint).
- **Fleet:** the discoveries found and installed, flags, counts; fleet level = installed.
- **IslandHealth / HealthFactor:** health scoring per island.
- **Ecosystem:** each island's own simulation node (kelp, mangrove, reef, deep, polar).
- **Missions / MissionData:** the signature facility's missions.
- **RareEvents / EventData:** the storms and other events.
- **BuildingData:** building content (cost, limits, levels, storage, hosting).
