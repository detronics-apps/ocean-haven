# People, litter sources, mini-games and seasons — draft 1 (not approved yet)

A planning draft only: nothing here is built. Once it's approved it moves into
`docs/MASTER_PLAN.md` and gets built in small steps, with each balance number simulated first.

## 1. Ground rules

1. **Objectives only come from people.** Nothing appears on screen until you've talked to
   someone. The goal line shows "Talk to …" until then.
2. **People ask questions; they don't hand out answers.** An objective-giver asks the question
   that needs asking ("Don't you think there's something better than plastic bags?"). The
   question goes into the ranger's notebook. A moment after the chat, the ranger's own thought
   turns it into an objective ("Find an alternative to plastic bags"). Once it's done, the
   objective drops away and the next one comes.
3. **Two people on every island:**
   - an **objective-giver** with a job title (Researcher, Diver…), never a specialist title like
     "turtle researcher". Their job matters on every island, so you keep going back to them.
   - a **hint-giver** you go to for advice. They can't give objectives, and they can send you
     to another island's hint-giver. This replaces the Tip button.
4. **Everything is worked out from where you are in the game, never from past talks.**
   - When you meet someone, they read the game's state: flags, objectives done, discoveries,
     what's built, the animal counts. They don't read a list of talks you've had.
   - So someone already at day 65 with four islands meets all the people. Each of them greets
     them for what they've already done ("You already pulled the sonar out of that wreck? Then
     you're the ranger I've heard about!"), skips anything that's done, and gives the first
     objective that isn't done yet.
   - **Two kinds of task.**
     - **Story objectives** (the wreck, the kelp balance…) are worked out from progress. Anything
       you've got past is never asked for.
     - **Collections** (the photo moments) are side tasks. They never block the story, and they
       pick up from what you have.
     - Example, for a ranger already at the Deep Sea: Maya doesn't say "start taking photos".
       She says: "You've come all this way from the wreck! I'm putting together a photo record
       of every island. You have 9 of the 30 moments so far. The crab digging on the beach and
       the dolphin leaping are still missing, if you're passing by." Then she gives a Deep Sea
       research question if there is one.
   - The only thing saved is which people you've met and which questions they've asked.
     Everything else is checked live, so it's always up to date. Loading a save never replays
     a talk.
5. **Names live in data** (`data/people/<id>.tres`: name, job, island, spot, lines), so they can
   be changed at any time without touching code.
6. **The Journal stays small.**
   - No new tabs except one **People** page: who they are and where to find them.
   - Current objectives show on the HUD goal line and in a short "Notebook" list, never as cards.
   - The photo album goes inside each animal's existing Journal page, at most 3 moments each.

## 2. The people

Each person stands at a fixed spot near their island's arrival, beside the building their work
uses (or a small camp until that building exists). You talk to them with the action button,
like an animal. Names are drafts.

### Starting Island

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Dr. Maya Okafor** | **Tom Pieters** |
| Job | Researcher | Lighthouse keeper |
| Where | Field camp, later the Marine Rescue & Research Station | The lighthouse on the point |

**Maya (Researcher).** She came to find out why the island's wildlife has dwindled. Her
research covers every island, so you keep coming back to her for:
- photo moments (the album), on every island;
- research questions on later islands ("predict, then watch", section 6);
- the plastic-bag question (section 3).

Her first conversations, in order (each skipped if it's already done):
1. A new game only: "Let's get to know who still lives here: photograph them" → *photo
   moments: 3 different animals*. For a ranger who has moved on, this becomes the photo
   collection side task with the moments still missing (section 1, rule 4).
2. "Something odd shows up on old charts off the west coast…" → *Build the research station*
   → *Survey the coast*.
3. → *Clear the wreck* → *Lift the sonar unit*.
4. → *Build an Exploration Ship and install the sonar* ("…and see what else is out there").

**Tom (Lighthouse keeper).** He has kept the light for fifty years. He remembers beaches covered
in turtle tracks every summer. Today's beach looks normal to young people, but to him it's
almost empty. That's the shifting baseline. He gives hints, never objectives:
- On the turtles: "When I was a boy you couldn't walk the beach at night for nesting turtles.
  They need a quiet stretch of sand: no buildings right next to it."
- On litter: "The litter always comes back on the same tide. Pick it up before it reaches the
  beach."
- He comments on how things are going: "Seven turtles… I haven't seen that many since my
  father's day."
- He sends you on to the next hint-giver: "Out in the cold kelp waters there's a harbour cook,
  Ines. Nobody knows those waters better."

### Kelp Forest

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Finn Larsen** | **Ines Moreau** |
| Job | Diver | Harbour cook |

**Finn (Diver).** He used to dive for urchins to sell. He watched the kelp disappear and leave
bare "urchin barrens" behind (real). Now he dives to restore it. Underwater work on any island
runs through him:
- kelp balance → shed kelp;
- the six-pack ring question (section 3);
- on later islands, the dives to plant coral fragments and to recover gear.

**Ines (Harbour cook).** She runs the harbour café. Her grandmother told her the otters were
hunted for their fur until almost none were left (real: the fur trade of the 1700s–1800s).
- Hints on otters, urchins and kelp: "Otters eat urchins. Bring the otters back and the kelp
  looks after itself."
- She sends you to the Mangrove boat builder for questions about water.

### Mangrove Coast

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Rosa Mendes** | **Samuel Achebe** |
| Job | Fisher | Boat builder |

**Rosa (Fisher).** Her catch depends on the young fish that grow up in the mangrove pools.
When the silt cut the pools off, her nets came up empty. Questions about fishing and markets on
any island go to her:
- water flowing → resin;
- the foam-box question (section 3);
- on the Deep Sea: "How do fishers lose their nets?"

**Samuel (Boat builder).** He has built wooden boats from these channels all his life.
- Hints on the channels, tides, gates and silt: "Water that stands still drops its mud. Keep
  it moving."
- He sends you to the Reef's dive guide.

### Tropical Reef

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Kai Nakoa** | **Leilani Kahale** |
| Job | Engineer | Dive guide |

**Kai (Engineer).** Kai runs the water treatment and the Glassworks. Kai asks the "how could we
make it differently?" questions, and doesn't answer them:
- "Don't you think there's something better than buying water in plastic bottles?" →
  *Find an alternative to plastic bottles* (Glassworks + clean water: section 3);
- coral restoration → rubble;
- on the Polar Ocean, Kai is who you ask about the washing-machine filters.

**Leilani (Dive guide).** She runs the dive centre and knows where every current dumps its
litter.
- Hints on coral, clams, seahorses and the shark: "The shark isn't the trouble. Follow it:
  it's circling something caught down there."
- She sends you to the Deep Sea's retired captain.

### Deep Sea

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Dr. Imani Osei** | **Bram de Vries** |
| Job | Pilot | Retired captain |

**Imani (Pilot).** She pilots the Outpost's submarine. Navigation and exploring on any island
go through her:
- mapping → the cargo;
- the fishing-gear question (section 3);
- she is the one who mentions the fleet's next upgrade ("With a cargo hold we could carry…").

**Bram (Retired captain).** He fished these waters on a trawler for forty years and admits he
lost nets out here himself. That's an honest, kind way to tell the gear story.
- Hints on the dark areas, noise, light and the whales: "Whales talk in clicks. Make noise and
  they go quiet, then they go away."
- He sends you to the Polar weather watcher.

### Polar Ocean

| | Objective-giver | Hint-giver |
|---|---|---|
| Name | **Dr. Sanna Lind** | **Erik Holm** |
| Job | Expedition leader | Weather watcher |

**Sanna (Expedition leader).** She leads the station's expedition:
- the ice season → the Ice Core;
- what the ice core shows: microfibres (section 3).

**Erik (Weather watcher).** He has written down the ice every day for thirty years, and
remembers when the ice stayed longer.
- Hints on the ice season, the pupping zones and the corridor: "Pups need ice that lasts. The
  white ice in the middle never melts."
- He sends you back to Tom: the circle closes.

*To decide:* the Arctic is home to Inuit communities, and Inuit knowledge really is part of
Arctic research. A respectful Inuit character would need careful research and accurate
representation. Until then, this draft keeps two station staff.

### Going back to earlier people

| Job | What you keep coming back for |
|---|---|
| Researcher (Maya) | photo moments on every island; research questions |
| Diver (Finn) | underwater work: coral planting, gear recovery |
| Fisher (Rosa) | fishing gear, markets, food boxes |
| Engineer (Kai) | how things are made: bottles, filters |
| Pilot (Imani) | the fleet and exploring |
| Expedition leader (Sanna) | the final, ocean-wide questions |

On each new island, its objective-giver gives that island's main objective. Side questions can
point you back to earlier people ("Rosa would know how nets get lost").

## 3. Stopping litter at its source: six problems, all six islands

**Six problems, from five pickable items plus one you can't see.**

| # | Litter (item) | Where it washes up most | Asked by | Researched at | The fix that really works |
|---|---|---|---|---|---|
| 1 | Plastic bottles (exists) | Tropical Reef | Kai, Engineer | Reef: Glassworks + clean water | Reusable bottles and refill water (exists) |
| 2 | Plastic bags (exists) | Mangrove Coast (bags snag in mangrove roots: real) | Rosa, Fisher | Starting Island: Maya's station, Tom's memory | Reusable bags woven from palm leaves (a real tradition across the Pacific and Southeast Asia) |
| 3 | Six-pack rings (**new**, tangles animals) | Kelp Forest (seals and otters get caught) | Finn, Diver | Reef: Kai designs it out | Packs that don't need rings: returnable crates |
| 4 | Foam food boxes (**new**, crumble into bits) | Starting Island (picnics, visitors) | Maya, Researcher | Mangrove: the Eco-Lodge | A return-and-reuse box scheme |
| 5 | Fishing line and ghost nets (exist) | Deep Sea | Imani, Pilot | Deep Sea, with Rosa's help | Gear marking (exists) + collecting old nets for recycling |
| 6 | Microfibres (not pickable: tiny threads from washing clothes) | Polar Ocean: found in the Ice Core | Sanna, Expedition leader | Reef: Kai builds a filter | Filters on washing machines |

All facts get checked before anything is written into the game.
- Mangroves really do trap plastic.
- Microplastics have been found concentrated in Arctic sea ice.
- France requires microfibre filters on new washing machines from 2025.
- Old nylon nets really are recycled into new yarn.

### When a question comes

- **Trigger:** every item counts how many you've picked up over the whole game, on every
  island. When a type reaches its threshold, the person who asks about it brings it up the next
  time you talk to them. Thresholds rise with each new question: **20, 30, 40, 55, 70**
  pieces. The microfibres come with the Ice Core instead.
- **A question is only asked once its research island has been found**, so it can always be
  answered. That keeps the island order free: warmer first or colder first both work.
- **When the chain starts.** You suggested the Tropical Reef, and the fresh water there is a
  good first story. But the Reef can be your 3rd island or your 6th, depending on the way you
  explore. So two options:
  - **A (yours):** the chain starts on the Reef with bottles. On a colder-first route, all six
    problems come late in the game.
  - **B (my recommendation):** the chain starts when you reach your **2nd island**. The first
    question is whichever one is possible there. Bottles stay the Reef's, and they're still the
    first if you go warmer.
- **Hints:** "Where should I look?" is answered by the hint-givers ("Tom might remember how
  bags were made before plastic").
- **The research step:** that island's research facility has an "Investigate: …" mission.
  Its report gives the answer and the building or task that follows.

### Honesty rule (for ISLAND_RULES once approved)

- A fix is never a swap from one throwaway thing to another (the paper-straw lesson). It's
  always reuse, refill, return, or designing the problem out.
- **Correction to your kelp-bag example:** seaweed is used for compostable films and coatings,
  but it doesn't make strong reusable bags. That's why bags go to woven palm leaves here.

**A fact to fix in the existing game:** parrotfish sand is coral sand (calcium carbonate). Glass
is mostly silica (quartz) sand, plus lime. Lime is made from calcium carbonate, so the honest
version is: beach quartz sand + lime from parrotfish sand → glass. The Glassworks text should
say that.

## 4. Mini-games: one per island, replayable

**Rules for all of them:**
- Nobody loses: bumping into something only slows you down.
- Each one has numbered levels that get harder, so it stays a challenge after the first time.
- You can play as often as you like for fun. **It affects the island once per game day**, so it
  never replaces playing the island.
- The effect is research or an animal effect, never money from an animal. Research grants
  already count as money from research, so a small grant is allowed.

**Popular styles we could borrow from:**

| Style | Popular example | Why it replays well |
|---|---|---|
| Tap to fly / swim through gaps | Flappy Bird, Jetpack Joyride | Endless, beat your distance |
| Swim-and-collect levels | Mario underwater levels, Ecco | Level layouts and timing |
| Falling blocks | Tetris | Endless, always different |
| Match-3 | Candy Crush, Bejeweled | Random boards and level goals |
| Memory pairs | Concentration | Shuffled every time, more cards per level |
| Sort and pour | Water Sort Puzzle | Generated puzzles, more colours per level |
| Connect the pipes | Flow Free, Pipe Mania | Generated puzzles |
| Clues on a grid | Minesweeper (without the bombs) | A random grid every time |
| Draw the path | Flight Control | Busier as it goes |

**My picks:**

| Island | Game | Style | How it plays | Effect in the real game |
|---|---|---|---|---|
| Starting Island | **Sonar Sweep** | Minesweeper without bombs | Tap ocean squares to ping. Each square shows how many hidden objects are next to it; work out where the wreck and the lost litter are. Levels: bigger grids, more pieces. | The coastal survey's research: your first win finds the wreck. Afterwards it marks hidden litter on the minimap for that day. |
| Kelp Forest | **Otter Dive** | Mario-style swim levels | Hold to dive, let go to rise. Grab urchins among the kelp and come up for air; the otter cracks shells on its belly (real tool use). Levels: deeper, currents. | Counts as an urchin survey: urchins go down a little that day. |
| Mangrove Coast | **Channel Flow** | Connect the pipes | Turn channel pieces until every pool is linked to the sea, before the tide turns. | Water-flow research: shows the best channels to dig on your island that day. *Your Flamingo Flight idea could go here instead, or on the Reef.* |
| Tropical Reef | **Glass Sort** | Water Sort Puzzle | Pour layers of coloured sand from jar to jar until each jar holds one colour (real: glass colour comes from minerals). | A batch of reusable bottles at the Glassworks. That's progress in the bottle story and a small research grant. |
| Deep Sea | **Echo Dive** | Cave flyer in the dark | Steer the submarine through a black canyon. Each sonar ping lights the walls for a moment; pick up lost gear on the way. | Maps part of a dark area, like a submarine dive. |
| Polar Ocean | **Floe Fit** | Tetris | Ice floes drift down and freeze into place; every full row joins the bears' corridor. | Repairs lanes broken by boats for that freeze. |

*Alternatives:* Flamingo Flight (Flappy Bird) for the Mangrove, Tern Journey (Flappy Bird) for
the Polar Ocean, or Coral Match (match-3) for the Reef.

## 5. Turtles and the seasons

**The calendar.** The HUD's top line reads **"Year 1 · Spring, day 12 · Evening"**, with four
seasons of 30 days in the 120-day year.
- The total number of days played stays in the Journal.
- Tropical islands have no real four seasons. Their events follow their own real timing
  (nesting, coral spawning), but the HUD shows the same calendar.
- The Polar Ocean keeps its quick 3-day ice cycle for gameplay; its own note already shows it.

**Turtles today:** they nest every 2 days, eggs hatch after 1 day, and hatchlings grow up in 2
days. That's very fast.

**The proposal:**
- Hatchlings take **8 days** to grow up instead of 2.
- **The nesting season** is the first season of every year (Spring, days 1–30): nesting every
  3 days.
- The rest of the year it drops right down: one nest a season per turtle.
- Real: green turtles nest seasonally, and each female only every 2–4 years.

**The target**, to be checked with a simulation before building:
- with three Turtle Protection Areas built in good time, about **6–8 turtles by day 30**;
- **all 10 early in the second year's nesting season**.

**Existing saves:**
- turtles already grown stay grown;
- the season is worked out from the day number, so a save at day 65 is in Autumn and its turtles
  wait for next Spring to nest again.

## 6. Predict, then watch (Maya's research questions)

- Before some missions, Maya asks a question with 2–3 picture answers: "What happens to the kelp
  if the otters come back?"
- A few game days later, her Notebook entry shows what really happened next to your guess. There
  are no points, and a surprise counts as much as a right guess.
- The ecosystems already work out where they're heading, so the result is always true.

## 7. Questions for you

1. The names, jobs and backstories above: change any of them? And should the Polar Ocean get an
   Inuit character (with research first), or stay with two station staff?
2. The litter chain: start it on the **2nd island (B, my recommendation)** or on the
   **Reef (A)**? And are the six problems and the 20 / 30 / 40 / 55 / 70 thresholds right?
3. The mini-games: these six, or swap in Flamingo Flight / Tern Journey? And is "it affects the
   island once per day, never with animal money" the right rule?
4. Turtles: 8 days to grow up, and a Spring nesting season: OK?
5. When people arrive: the Tip button goes away once the hint-givers are in. Should the Tip
   button stay until you've met your first hint-giver?
