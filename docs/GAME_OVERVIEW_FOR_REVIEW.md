# BlueHaven: the full game layout, decisions and plans

**Version 2**, updated after an outside AI review and the owner's follow-up decisions.

**What this document is.** BlueHaven is a game being built by one developer (the owner) with an
AI coding assistant. This document is self-contained, so it can be given to another AI or person
for review. It describes:
- what the game is and who it's for;
- what is already built and playable;
- the design rules learned so far;
- the story and the next layer: people, ranger activities, rescue companions, litter sources and
  seasons;
- every decision made, what is still open, and the build plan (section 16).

**For a reviewer:**
- Respect the non-negotiable rules (section 2) and the rejected ideas (section 14).
- Check the facts marked **[verify]**.
- Recommend answers to the open questions (section 15).

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

## 6. The story: wonder → discovery → stewardship (decided, from the review)

The reviewer's main finding: the game's systems are excellent, but it needs a stronger emotional
reason to care about what they do. **People, ranger activities and rescue companions are the way
the player experiences the story, not features bolted on.**

### 6.1 The core loop

> **Meet someone → hear their story or question → explore → do something → discover
> something → make a change → watch nature respond → become curious about the next place.**

This replaces "an objective appears → complete it → unlock an island". Each discovery should
move the player through three thoughts:

> "I wonder what's happening here?" → "Oh! That's why." → "What can I do about it?"

**The emotional journey, the game's unofficial philosophy:**

1. Wonder ("Look at that turtle!")
2. Curiosity ("Why does it do that?")
3. Understanding ("It affects this.")
4. Responsibility ("Something is wrong.")
5. Action ("What can I do?")
6. Restoration ("It's getting better!")
7. Connection ("What I did here affects that island.")
8. Stewardship ("I need to look after the whole thing.")

### 6.2 Six acts, one per island (in the warmer-first order; the acts follow the islands)

| Act | Island | The player's discovery |
|---|---|---|
| 1. Wonder | Starting Island | "Look what's here." Animals aren't collectibles: every one has a role. Maya asks for photos; Tom tells how it used to be. |
| 2. Everything is connected | Kelp Forest | "Why are there so many urchins? …Oh, the otters eat them." The player watches the food web work: otters ↑ → urchins ↓ → kelp ↑ → fish ↑ → cormorants ↑. |
| 3. Land and sea are connected | Mangrove Coast | Rain → water → silt → channels → nursery pools → young fish → ocean. Through Rosa: healthy ecosystems support people too ("When these pools fill with young fish, my nets aren't empty any more"). Not "animals good, humans bad". |
| 4. Astonishingly intricate | Tropical Reef | "There are so many things happening here": parrotfish make sand, clams clean water, the shark points to ghost gear. The "everything has a job" island. |
| 5. We don't know everything | Deep Sea | Learn before acting. Even helping takes wisdom: the instruments themselves disturb. A major story moment. |
| 6. One ocean | Polar Ocean | Terns visit your other islands, microfibres in the ice came from far away. There isn't an "island ocean"; there's one connected ocean. |

The acts follow the islands, whatever order the player finds them in. The colder route meets
Kelp (Act 2) first. Each island's people tell its act, so the order can vary.

### 6.3 Balance is the central concept (decided)

- Not "save the ocean" but **"find the balance"**: doing too little is bad, and so is doing too
  much.
- Already in the design: overbuilding has consequences, limits aren't targets, and several
  setups reach 100 %.
- The message for adults (still clear to children): **conservation isn't about controlling
  nature; it's about understanding it and giving it room to work.**

### 6.4 Faith and wonder (the owner's perspective, decided approach)

- The owner's family is Christian, and the owner wants the game to leave room for "look what God
  created".
- **No preaching.** Characters never say "God made this animal". Instead, the game's identity is
  **wonder**: after many hours of seeing parrotfish make sand, otters protect kelp, mangroves raise
  fish and terns cross the world, the player's own reaction is "wow".
- The underlying message: **creation is wonderfully intricate, beautiful and worth caring for.**
  We aren't here to own it or control it; we're here to understand it, care for it, and give it
  the chance to flourish.

### 6.5 The ending: not "You won"

- Collecting everything (all six discoveries, all six source problems) is the **beginning of the
  final chapter**, not a victory screen.
- **The Global Ocean Observatory** asks: **"You've helped every island. What have you learned?"**
  - It shows observations from the player's own game: "Turtles returned because…", "Kelp
    recovered because…", "Fish returned because…".
  - Then: **"One ocean. Many places. Everything connected."**
- The camera pulls back to a panorama of all six islands: animals moving between them, boats, the
  research vessel, vibrant water.
- Each person is seen at their work with one line about what the player helped them discover.
  Maya: "When we started, we thought we were helping six islands." Another: "There was only ever
  one ocean." The player sees that the people were connected too.
- Then play continues: the world stays open.

## 7. People (decided structure; names in data, easy to change)

### 7.1 Rules (decided)

1. **Objectives only come from people**, with a real story reason to talk to them.
   - The player can still do anything freely; objectives never block actions.
   - Until the first talk, the goal line says "Talk to Dr. Maya".
2. **People ask questions; they don't give answers.**
   1. A person asks ("Don't you think there's an alternative to plastic bags?").
   2. A moment later the objective appears ("Find an alternative to plastic bags").
   3. When it's done it drops away and the next one comes.
3. **Two people per island:**
   - an **objective-giver** with a general job title. You keep coming back to them from any island
     for things in their field.
   - a **hint-giver**. You go to them when you're stuck; they can't give objectives, and they send
     you on to the next island's hint-giver.
   - The hint-givers **replace the Tip button**.
4. **Every person is a way of understanding the ocean**, and the player learns who to visit:

   | Person | Go to them when… |
   |---|---|
   | Maya (Researcher) | "I want to understand something." Her recurring question: *"What do you think is happening?"* |
   | Tom (Lighthouse keeper) | "I don't know what to do." He's the game's memory. |
   | Finn (Diver) | "Something underwater isn't right." |
   | Rosa (Fisher) | "Something is happening to fish or fishing." |
   | Kai (Engineer) | "How could we make or change something?" Kai asks "why are we making something we throw away after one use?", never "here's the answer". |
   | Imani (Pilot) | "Where should we explore?" |
   | Sanna (Expedition leader) | "What does this mean for the whole ocean?" |

5. **People have lives, not just missions.**
   - **Micro-stories** sometimes come with no objective and no reward. Example: Tom says "My
     father could tell where turtles had been just by looking at the sand." "How?" "Tracks." Then
     the player notices turtle tracks on the beach for the first time.
6. **People remember what you've done** through world reactions, not friendship meters, gifts
   or XP.
   - Tom: "I haven't seen many turtle tracks lately" → "Three nests this morning" → "Come and
     look at this" (hatchlings).
   - Finn: "The kelp is struggling" → "Look at this patch" → "The fish are back".
7. **Everything they say is worked out from the current game state**, never from past talks.
   - Players far into the game meet everyone, are greeted for what they've done, and skip
     what's done.
   - Example: a ranger at the Deep Sea visits Maya. She doesn't say "start taking photos"; she
     mentions the photo moments they're still missing.
   - Saved: who you've met and which questions were asked. Everything else is checked live.
8. **Keep the Journal small:** one People page, a short Notebook of current objectives, no
   extra cards.

### 7.2 The cast and their arcs (draft names)

| Island | Objective-giver | Arc (beginning → end) | Hint-giver | Arc |
|---|---|---|---|---|
| Starting | **Dr. Maya Okafor**, Researcher: came to find out why the wildlife dwindled; curious and analytical | "We need to understand what happened" → "Understanding never really ends" | **Tom Pieters**, Lighthouse keeper: 50 years at the light | "I remember when there were more turtles" → "Now I have something new to remember" |
| Kelp | **Finn Larsen**, Diver: used to dive for urchins to sell, and watched the kelp collapse | "I thought I was only taking urchins" → "Now I know what I'm part of" | **Ines Moreau**, Harbour cook: her grandmother's stories of otters hunted for fur **[verify wording]** | The old harbour comes back to life |
| Mangrove | **Rosa Mendes**, Fisher: her catch depends on the nursery pools | "The fish are disappearing" → "There are more fish than when I was young" | **Samuel Achebe**, Boat builder: knows the channels and tides | — |
| Reef | **Kai Nakoa**, Engineer: runs the water treatment and the Glassworks | "How can we make this differently?" → "Maybe the best design is the one that doesn't create the problem" | **Leilani Kahale**, Dive guide: knows where currents dump litter | — |
| Deep Sea | **Dr. Imani Osei**, Pilot: the Outpost's submarine pilot | — | **Bram de Vries**, Retired captain: lost nets out here himself | Honest regret → seeing the gear recovered |
| Polar | **Dr. Sanna Lind**, Expedition leader | — | **Erik Holm**, Weather watcher: 30 years of ice records | — |

- **Hint chain:** Tom → Ines → Samuel → Leilani → Bram → Erik → Tom.
- **Open:** an Inuit character on the Polar Ocean (needs careful research first).

**Starting Island, Maya's story** (each step skipped if it's already done):
1. Photograph animals (a new game only; for later players this becomes the photo collection).
2. Build the station.
3. Find the wreck. This is her first ranger activity, Sonar Sweep (section 8).
4. Clear the wreck → lift the sonar.
5. Build the Exploration Ship.

**The first 10 minutes of a new game:** walk → meet Maya → photograph an animal → meet Tom →
discover the turtles → a simple cleanup. Sonar Sweep comes later.

## 8. Ranger activities (the mini-games; decided structure)

### 8.1 Rules (decided)

- **In the player's world they're ranger activities, not mini-games.** You go diving with Finn;
  you don't "play Otter Dive".
- **Introduced by a person, as part of the story.** Finn: "I've got ten minutes before I head
  back up. Want to help me check the kelp?"
- **Only the first, story play gives something:** one unique item or piece of information the
  island's progress needs.
  - It's a story or world item, never a power-up for the activity itself.
- **After that, a permanent location in the world** (for example a jetty on the beach for
  diving).
  - The location is visible from the first visit (an old jetty) but inactive, and opens after
    the first story play.
- **Replays are purely for fun:**
  - harder levels;
  - a timer or score, with the **personal best** saved, arcade style ("NEW PERSONAL BEST:
    19.8 s");
  - no progress, items, funding, daily rewards or ecosystem effects, and no penalty for
    ignoring it;
  - no global leaderboards.
- **Understood in 10 seconds.** Nobody loses: bumping something only slows you down.
- **Not overloaded:** one activity per island, unlocked in the story, never all at once.
- **Scope rule:** six themes on only **3 shared frameworks**, so it stays buildable by one
  developer.

### 8.2 The six activities

| Island | Activity (introduced by) | Framework | Like | First story play gives | Permanent location | Replay |
|---|---|---|---|---|---|---|
| Starting | **Sonar Sweep** (Maya) | Grid | Minesweeper without bombs | **Locates the wreck** (instead of the survey's chance) | Survey point on the station's jetty | Bigger grids, more pieces; best time |
| Kelp | **Otter Dive** (Finn) | Mover | Mario-style swim levels | **The urchin survey**: shows where grazing is too heavy | The old jetty / dive spot | Currents, deeper levels; best time |
| Mangrove | **Channel Flow** (Rosa or Samuel) | Grid | Flow Free / Pipe Mania | **The channel layout**: marks which silted channels to dig | Waterworks control table | Bigger networks; best time |
| Reef | **Glass Sort** (Kai) | Sort | Water Sort Puzzle | **The first batch of glass**: opens glass-making | The Glassworks' sorting bench | More colours and jars; fewest moves / best time |
| Deep Sea | **Echo Dive** (Imani) | Mover | Cave flyer in the dark | **Finds the lost cargo module** (the Cargo search step) | Submarine dock | Longer canyons; best time |
| Polar | **Floe Fit** (Sanna) | Grid | Block Blast / polyomino fitting | **The drill-site plan**: shows the old ice that's safe for 3 days of drilling | Station planning table | More pieces, odd shapes; best time |

**Frameworks:**
- **Grid:** reveal, rotate or place tiles (Sonar Sweep, Channel Flow, Floe Fit).
- **Mover:** tap or hold to swim, collect, avoid (Otter Dive, Echo Dive).
- **Sort:** jars and layers (Glass Sort).

**Alternatives:** Flamingo Flight (Mover, Flappy Bird style) for the Mangrove, Tern Journey
(Mover) for the Polar Ocean.

**Existing saves:** if the story step is already done, the person mentions the activity and its
location is open straight away.

## 9. Rescue companions (decided structure; species partly open)

The owner's idea, built from Tamagotchi's emotional structure: a specific little individual you
check on, watch develop, get attached to, and let go. **But none of its pressure:** no death, no
hunger or sickness that gets worse, no timers, no "feed me", no streaks.

### 9.1 Rules (decided)

- **You don't own an animal; you're helping one get home.**
  - The word is "rescue companion" / "My Rescue", never "adopt" or "pet".
  - "You don't own an animal. You're helping one get home."
- **One per island, one at a time.** Each island has one animal that needs human help: an injured
  or caught young animal, or an egg that won't make it alone.
- **You name it.**
- **30 game days of care** at the island's rescue habitat, by its signature facility. Then it's
  released: a special **Release Moment**, a milestone. Its name and story stay in the Journal.
- **You can leave.**
  - The station staff keep caring for it while you're away. This is an exception to "islands you
    aren't on are paused".
  - A note now and then: "Shelly is doing well. She's started swimming on her own."
  - You must be there for the release itself.
- **The next one comes when the previous one has been released** and you're on an island that
  hasn't had one yet. So six rescues take about 180 game days, about a year and a half (four
  30-day seasons in a 120-day year).
- **Recovery is a journey of stages you can see**, never bars that drop. For example:
  1. critical care;
  2. eating on its own;
  3. moving normally;
  4. exploring;
  5. natural behaviour;
  6. ready.

  The animal visibly changes: it hides at first, gets braver, follows you, and finally behaves
  like a wild animal.
- **Care activities are 30-second interactions:** choosing the right food, enrichment, a swim
  course, cleaning, a behaviour check. They're built on the activity frameworks.
- **They teach through behaviour, not lessons.** Maya: "It keeps hiding." "Why?" "Perhaps it needs
  somewhere quiet." The player adds a quiet shelter, and the animal uses it.
- **It works by visiting:** each visit shows progress and a care moment. Not visiting is fine.
- **After release it's a tagged animal** (section 10.2). Later sightings are the big payoff,
  for example a photo of Shelly near the Mangrove Coast.
- **It teaches the difference between individuals and ecosystems:** "I care about Milo" → "Milo
  is one turtle" → "turtles are part of this ecosystem" → "Milo is part of the ocean".

### 9.2 The six (species to finalise; realism checked first)

| Island | Proposed rescue | Real basis |
|---|---|---|
| Starting | **Green turtle**, a juvenile caught in fishing line or floating weakly | Rescue centres really rehabilitate injured and floating turtles **[verify]**. Better than raising from an egg: head-starting hatchlings is a debated practice **[verify]**. |
| Kelp | **Sea otter pup**, stranded without its mother | Aquariums really raise stranded pups with surrogate mothers and release them **[verify]** |
| Mangrove | **Flamingo chick** from an abandoned egg | Mass hand-rearing of abandoned flamingo chicks has happened **[verify]** |
| Reef | *Open:* seahorse (captive breeding for release exists in places **[verify]**), or a juvenile turtle of another species, or a seabird | — |
| Deep Sea | *Open:* a sixgill shark with a hook (short care), or a stranded young whale (rare but real cases **[verify]**) | — |
| Polar | **Ringed seal pup**, orphaned | Seal pup rehabilitation is common **[verify]** |

## 10. Photos, tagged animals and the Journal

### 10.1 Photo moments (decided)

- **2–3 per species**, each a specific situation. For example, ghost crab: digging on the sand ·
  in the water · out at night.
- An image is kept only the first time you catch a new moment. Ordinary photos still earn research
  funding but aren't kept.
- Missing moments show as silhouettes with a hint.
- Kept inside each animal's existing Journal page.

### 10.2 Tagged, named animals (decided)

- **Rare: about 3–5 named animals active at once.** Rescue companions are the first ones.
- A tagged migrating animal can turn up on another island **only while both islands are
  healthy**.
- Its Journal entry: "Steve, green turtle: first seen Starting Island · seen Mangrove Coast ·
  wild."
- The world remembers: "Look at this photograph" (the tag number is visible). That's how the
  connected ocean becomes personal.

## 11. Stopping litter at its source (decided in principle)

- **Secondary to the ecosystem story.** The story is: "You came to help an island; while helping
  it, you learned how the ocean works; and you found that some problems begin far away." It's
  not "the game about picking up rubbish".
- **Six problems, six "aha!" moments, solved across all six islands.** Seeing a problem stop
  appearing is the reward: "I didn't just clean this beach; I changed what was happening."
- **It starts on the 2nd island (option B, decided).** The player first learns "I can help
  nature", then "prevent it at the source".
- **Trigger:** each litter type counts every piece picked up over the whole game. At its
  threshold (rising: 20, 30, 40, 55, 70) the right person asks the question. A question is only
  asked once its research island has been found.
- **The flow:** question → objective → a hint-giver suggests where to look → an "Investigate"
  mission → the report → the fix → that litter stops everywhere.
- **Honesty rule:** never a swap to another throwaway thing. The owner's paper-straw example:
  PFAS were found in many paper straws **[verify]**, and they ruin the drink. Fixes are reuse,
  refill, return, or designing the problem out.

| # | Litter | Asked by | Researched at | The real fix |
|---|---|---|---|---|
| 1 | Plastic bottles (exists) | Kai | Reef: Glassworks + clean water | Reusable bottles and refills (built) |
| 2 | Plastic bags (exists; snag in mangrove roots **[verify]**) | Rosa | Starting Island: Maya + Tom's memory | Reusable bags woven from palm leaves **[verify the tradition]** |
| 3 | Six-pack rings (**new**, tangle animals) | Finn | Reef: Kai designs it out | Returnable crates, no rings |
| 4 | Foam food boxes (**new**) | Maya | Mangrove: the Eco-Lodge | A return-and-reuse box scheme |
| 5 | Fishing line and nets (exists) | Imani | Deep Sea, with Rosa | Gear marking (built) + net recycling **[verify]** |
| 6 | Microfibres (can't be picked up) | Sanna, after the Ice Core | Reef: Kai builds a filter | Washing-machine filters (France, 2025 **[verify]**) |

- **The microfibre lesson:** "cleaning isn't always enough."
- **Fact fixes:**
  - seaweed doesn't make strong reusable bags;
  - glass is quartz sand plus lime, and the lime can come from parrotfish (coral) sand. The
    existing Glassworks text must say that **[verify]**.

## 12. Seasons, turtles and other agreed layers

- **Calendar:** the HUD shows "Year 1 · Spring, day 12 · Evening": four 30-day seasons.
- **Turtles (proposed, to be simulated):**
  - hatchlings take 8 days to grow up (now 2);
  - nesting season is Spring, with a nest every 3 days; little nesting the rest of the year;
  - the target is 6–8 turtles by day 30, and 10 early in year 2;
  - existing saves take the season from the day number.
- **Seasonal moments (liked, details later):** nesting, hatchling runs, whales passing, terns
  arriving, coral spawning **[verify timing]**. Each is a photo chance; nothing is lost by
  missing one.
- **Predict, then watch (liked):** Maya asks a picture question before some missions ("What
  happens to the kelp if the otters return?"). The Notebook later shows what really happened next
  to your guess. No score.
- **Already planned:** the connected ocean (cross-island effects seen in the world), then the
  Ocean Research Vessel and Global Ocean Observatory (now the ending, section 6.5).

## 13. Design principles to add to the rules (decided)

1. **The player discovers; the game doesn't lecture.** Let the player observe, choose, act and
   see the result before the Journal explains the science.
2. **Every person is a way of understanding the ocean** (research, memory, diving, fishing,
   engineering, navigation, observation).
3. **Every ranger activity is real work in the world**, done with a person, never an unrelated
   arcade game.
4. **The greatest reward is seeing creation recover.** Funding, items and unlocks support
   progress; the emotional reward is animals returning, habitats recovering and people reacting.
5. **Reward curiosity; never demand repetition.**
6. **Every new feature serves the one loop:** meet → wonder → investigate → understand → act →
   watch → connect.

## 14. Rejected or parked ideas (and why)

| Idea | Status | Why |
|---|---|---|
| Climate via solar / electric / "green tech" buildings | Rejected for now | No tech claims without a full life-cycle assessment. Well-established ocean effects are fine. |
| A real-world pledge checklist | Rejected | Preachy; can push bad swaps |
| "Real Ocean" tab / "spot it for real" / parent links | Parked | The owner didn't like these |
| Research station "trace the source" mission | Rejected | Pickup thresholds raise the question instead |
| Characters handing out answers | Rejected | People ask questions; the player thinks |
| Vague characters ("a visiting child") or narrow titles ("turtle researcher") | Rejected | Each needs a clear job usable on every island |
| Hidden-object games | Rejected | Only a challenge the first time |
| Mini-game replays giving progress / daily effects | **Rejected (changed)** | Replays are only for fun and personal bests |
| Daily streaks, Tamagotchi-style decay, "feed me" timers | Rejected | Pressure and anxiety don't suit the game |
| One permanent pet all game | Rejected | One rescue per island, released after 30 days |
| "Adopting" an animal | Rejected wording | "You're helping one get home" |
| NPCs saying "God made this" | Rejected | Wonder carries the message |
| A "You won!" ending | Rejected | The Observatory reflection instead |
| Kelp-made reusable bags | Corrected | Not realistic |
| Tip button | Replaced | By the hint-givers |

## 15. Open questions

1. Final names, and an Inuit character on the Polar Ocean?
2. The Reef and Deep Sea rescue species.
3. Who introduces Channel Flow: Rosa (the fisher's pools) or Samuel (the channels)?
4. 2 or 3 photo moments per species, and which situations?
5. The turtle numbers (8 days to grow up; Spring nesting), after the simulation.
6. How often predict-then-watch questions come.

## 16. Build plan: phases (each one small, playable, tested, saved and published)

The scope is the biggest risk, so every phase delivers something you can play, and the order puts
the shared foundations first.

| Phase | What | Why here |
|---|---|---|
| **0. Rules** | This document; the principles (section 13) added to ISLAND_RULES | Done now |
| **1. People (Starting Island)** ✅ built | People, talking, the Notebook, Maya's story worked out from game state, Tom's hints, micro-stories and world reactions; the Tip button goes | Every later feature is delivered through people |
| **2. Calendar + turtles** | Seasons on the HUD; turtle growth and the nesting season (simulated first) | Small; the rescue's 30 days and seasons need it |
| **3. Sonar Sweep** | The Grid framework, personal bests, Maya introduces it, the survey point | The first ranger activity, and it proves the activity rules |
| **4. Rescue companion #1** | The turtle at the Starting Island: naming, stages, care moments, the release, its Journal story | The emotional hook, early in the game |
| **5. People on the other islands** | Ten more people, from the existing objectives (state-based); the hint chain; arc lines by progress | Uses phase 1's system |
| **6. The other activities** | Mover (Otter Dive, Echo Dive), more Grid (Channel Flow, Floe Fit), Sort (Glass Sort), one at a time | Each reuses a framework |
| **7. Rescue companions 2–6** | Once the species are decided | Reuses phase 4 |
| **8. Photo moments + tagged animals** | The album, named animals, sightings on healthy islands | Rescue companions become the first tagged animals |
| **9. Litter at its source** | Counters, questions, Investigate missions, two new litter items, the fixes, microfibres, the Glassworks fact fix | Needs the people of several islands |
| **10. Predict-then-watch + seasonal moments** | — | Polish on top |
| **11. The ending** | Connected ocean, Ocean Research Vessel, Observatory reflection, the people at the end | Needs everything else |

### Phase 1 in detail (built)

1. **People as data:**
   - `data/people/maya.tres` and `tom.tres`, with name, job, island, spot and role
     (objective / hint);
   - a placeholder chibi sprite built from the avatar layers;
   - a "Talk to Dr. Maya" action, like the animals.
2. **Places:** Maya at a small field camp near the start (later by her station), and Tom at a
   lighthouse on the island's point (a new placeholder building).
3. **Talking:**
   - speech bubbles, tapped through, 2–3 lines;
   - each person's lines are data: topics with conditions on the game state (flags, objective
     steps, counts, health);
   - the first topic that fits is the one shown.
4. **Questions → objectives:** a question is asked, and a moment later it becomes the objective on
   the goal line and in the Notebook. It's removed when done.
5. **Maya's story, worked out from game state,** with every step skipped when it's done:
   photos → station → wreck → sonar → ship. Existing saves get their current step.
6. **Tom:**
   - hints for where the player is (the turtles, quiet beaches, litter on the tide);
   - one micro-story (the tracks);
   - world reactions as the turtles return (tracks → nests → hatchlings).
7. **The Tip button is removed** once Tom exists. The goal line reads "Talk to …" or the current
   objective.
8. **Saved:** people met and questions asked. Tests, including an existing far-along save.
9. Publish, then you try it on the phone.

**Before phase 1 can start:** OK the plan, and decide whether the draft names stay for now (they
live in data, so they can change any time).

## 17. Glossary (names used in the code)

- **RegionData:** an island's data (health factors, objective goals, arrivals, flagship animal).
- **ObjectiveGoal:** one step of an island's objective (help, litter, flag, count; with a hint).
- **Fleet:** discoveries found and installed, flags, counts; fleet level = installed.
- **IslandHealth / HealthFactor:** health scoring per island.
- **Ecosystem:** each island's own simulation node.
- **Missions / MissionData:** the signature facility's missions.
- **RareEvents / EventData:** storms and other events.
- **BuildingData:** building content (cost, limits, levels, storage, hosting).
