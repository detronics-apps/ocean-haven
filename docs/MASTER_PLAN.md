# BlueHaven — Master Plan

The end goal to build towards. Each step below is a playable milestone; the detailed
build order for the current step lives in `CLAUDE.md` (Milestones). Game rules in
`CLAUDE.md` always win (no combat, animals never die, no failure states, one currency…).

> **The more we understand and care for one part of the ocean, the better equipped we
> become to understand the whole system.**

Progression of scale: individual wildlife → populations → ecosystems → global systems.

---

## The six islands

| # | Island | Lesson | Core question | Signature mechanic | Found by |
|---|---|---|---|---|---|
| 1 | 🏝️ Starting Island | What we do locally affects the ocean | What are humans doing? | Pollution → cleanup → recovery | (start) |
| 2 | 🌿 Kelp Forest | Species depend on one another | What happens when one species changes? | Predator → prey → habitat (food web) | Colder, 1st |
| 3 | 🌱 Mangrove Coast | The land and ocean are connected | Where do the water and wildlife go? | Water flow & nursery network | Warmer, 1st |
| 4 | 🪸 Tropical Reef | An ecosystem is many systems working together | How do many systems work together? | Habitat restoration | Warmer, 2nd |
| 5 | 🌊 Deep Sea | We can't protect what we don't understand | What don't we know yet? | Research & hidden information | Colder, 2nd |
| 6 | ❄️ Polar Ocean | The ocean connects the whole planet | How does everything connect globally? | Seasonal ice & colonies | Colder, 3rd |

Routes: **colder** Starting → Kelp Forest → Deep Sea → Polar Ocean; **warmer** Starting →
Mangrove Coast → Tropical Reef.

Ground tiles are plain and shared (sand, grass, rock, ice, mud; water shallow / mid / deep).
Coral, kelp, seagrass and mangroves are **plants** placed on top — never ground tiles.

---

## Exploration

### Map vs Explore — two separate things, never one menu
- 🗺️ **Map** (HUD button) — *"Where can I go?"* Every island is shown. You can sail only to islands
  you've discovered. Undiscovered islands are informational only.
- 🚢 **Explore** — *"Where can I discover next?"* Only by walking up to an **Exploration Ship**.
  It offers **Explore warmer / Explore colder** — a direction, never a named island — and finds the
  **next undiscovered island in that direction** from wherever you are.
- Once discovered, an island stays on the Map for good. No rebuilding ships just to go back.

### Exploration Ready (per island)
An island is **Exploration Ready** once the player has *earned* and established an Exploration
Ship there. The ship is a reward for engaging with the island, not something you get by landing:

Arrive → explore the ecosystem → solve its core problem (the island objective) → establish the
Exploration Ship → 🧭 on the Map → explore warmer/colder from there.

This stops "build ship → explore → build ship → unlock everything".

### Island discoveries & ship upgrades (the whole fleet)
Every island's restoration gives one unique discovery that **cannot be obtained anywhere else** —
tangible proof of what the player restored or learned there, gathered through a small objective,
never "collect 10 of X". It upgrades the **whole** fleet (every ship), and some upgrades are what
make the next region reachable:

| Island | Discovery | How it's gathered | Ship capability | Opens |
|---|---|---|---|---|
| 🏝️ Starting | Salvaged Sonar Core | Clean up a polluted underwater wreck / debris field; once enough is cleared, recover its old sonar unit | Basic navigation | The first exploration (Kelp Forest or Mangrove Coast) |
| 🌿 Kelp Forest | Kelp Fibre | Restore the otter → urchin → kelp balance; once the kelp is dense, gather a little naturally shed / overgrown kelp from set areas | Underwater durability | Deeper water → Deep Sea |
| 🌱 Mangrove Coast | Mangrove Resin | Restore the damaged channels and protect mature mangroves; collect resin from naturally fallen branches on the mud banks | Water & environment sensors | Complex coastal waterways → Tropical Reef |
| 🪸 Tropical Reef | Reef Limestone | Restore coral and seagrass and clean damaged reef zones; collect dead coral rubble from the seabed — never break living coral | Detailed habitat mapping | (reef tools; part of the full set) |
| 🌊 Deep Sea | Cargo Module | Use the deep-sea research system (sonar, cameras, the research sub) to locate and recover an abandoned cargo module lost on the seabed — cleanup and discovery in one | **Cargo storage** — the ship can carry resources between islands | Polar Ocean (carry wood there) — and a world-wide change: supplies can move between islands |
| ❄️ Polar Ocean | Ice Core | Establish a safe research site and drill a small scientific core from ancient ice (climate history), stored aboard | Extreme-cold navigation | (polar field work; part of the full set) |

The gathering grows more sophisticated island by island: 🧹 clean → discover · ⚖️ restore balance →
harvest sustainably · 💧 restore waterways → collect natural material · 🪸 restore habitat → collect
non-living material · 🔬 research → locate → recover · 🧊 research → set up a station → take a
scientific sample.

**The full set — Ocean Research Vessel & Global Ocean Observatory.** Because the world branches,
the player can reach every island without every discovery. Collecting **all six** is the mastery
reward, not a travel requirement: the ship's final upgrade turns it into an **Ocean Research
Vessel** (the six components visibly built in), and unlocks the **Global Ocean Observatory** on the
Map — a view of BlueHaven's whole ocean system:
- overall ocean health; pollution moving between regions; fish and wildlife population links;
  water-quality changes; temperature/climate effects;
- how restoration on one island has affected another (e.g. mangroves restored → more juvenile
  fish → more fish reach the Reef → healthier Reef → more food further north).

It's the reason to explore *both* branches, and it lands the game's biggest message: the ocean
isn't six separate ecosystems, it's one connected system. Discover → restore → obtain the unique
discovery → upgrade the ship → explore further → complete all six → understand the whole ocean.

**The fleet visibly evolves** (every ship's sprite changes with the equipment level):
1. Basic hull, small antenna, simple navigation
2. Reinforced hull, underwater equipment, diving sensor
3. Water sensors, navigation scanner, mapping equipment
4. Biological scanner, reef mapping, improved sonar
5. Pressure-rated hull, deep sonar, bioluminescence camera
6. Ice navigation, cold-weather gear, advanced global communication

At the ship:
```
EXPLORATION SHIP
Current equipment: Level 2
Next upgrade: Deep-Water Equipment
Required: Kelp Fibre — ✓ Obtained
[ UPGRADE ]
```

**The Map stays simple** — it answers only two questions:

| State | On the Map |
|---|---|
| Not discovered | Island greyed out |
| Discovered | Normal island picture |
| Has an Exploration Ship | Normal picture + a small 🧭 |

No levels, readiness, upgrades or expedition counts on the Map — those belong in the ship's screen.

**Exploration Level** — the fleet's equipment level (one per discovery installed), shown at the
ship with what every ship can now do. Not charges, fuel or tokens.

---

## Island by island

Animal rule (CLAUDE.md): every animal needs the ranger's help, helps other animals, or both —
and **animals never die**. Declines are shown as animals leaving, fewer arriving, colonies moving
away or fewer young — and always recoverable. Interventions are never lethal.

**Ecosystem principle (from the Kelp Forest on): population growth is an outcome of successful
conservation, not an animal's gameplay purpose.** The player changes the environment and the
ecosystem responds. Every animal has an ecological role that creates or changes a decision; if it
could be removed without changing the player's decisions, it doesn't belong. The player can
identify a problem, understand its cause, choose an intervention, see the response, make mistakes
(including creating new problems), recognise the consequences, remove or change infrastructure,
and restore balance. So:
- **Buildings create conditions; animals respond.** Never "build 3 Otter Habitats = 3 otters";
  buildings never manufacture animals; not every animal needs its own building.
- **Hard limits are not targets.** A habitat may allow up to 6, but the healthy number might be
  2–3 depending on the ecosystem. Overbuilding is allowed and has consequences (space, upkeep,
  displaced activities, imbalance) that the ecosystem shows — never "you built too many". The
  player can demolish and adapt. The game never tells an exact optimal number.
- **Research always leads to an action** (observe → understand → intervene → observe again),
  never just a report.
- Mission effects use real elapsed time where it matters, not "until midnight".
- **Animals are functional, not resources:** never currency, collectible cards, production
  units or bare population counters. Buildings create habitat, protection, access, research,
  restoration, water management or funding — never wildlife.
- **The player can overbuild and can always correct it:** every major conservation structure
  that can create imbalance can be demolished or moved.
- **Cascading consequences:** a change in one part can affect the others (kelp: otters ↓ →
  urchins ↑ → kelp ↓ → fish ↓ → cormorants ↓; mangroves: poor flow → mangroves degrade → nursery
  disrupted → juvenile fish ↓ → fewer fish reach the ocean).
- **Conservation isn't "more":** more habitats, zones, tourism, restoration or infrastructure
  doesn't automatically make a better island.
- The intended shift: from "what building gives me more animals?" to "what is causing the
  ecosystem to change?" — learned through cause and effect, not textbook explanations. BlueHaven
  is a simplified ecosystem simulation inside an accessible management game: build → observe →
  decide → see consequences → adapt → restore balance. The goal isn't to maximise every animal,
  but an ecosystem that can sustain itself.

### 1. 🏝️ Starting Island — Human impact
Pollution isn't one score; each kind hits a different system, and the player chooses what to clean
first and what to protect:
- Plastic → wildlife hazard · Oil/chemicals → water quality · Fishing debris → entanglement ·
  Boat traffic → disturbance · Too much beach use → nesting disruption

| Animal | Role |
|---|---|
| 🐬 Dolphin | Finds pollution: reveals floating and submerged litter (✅ leads you to litter after you play with it) |
| 🦀 Ghost Crab | Finds buried beach litter by digging (✅) |
| 🐢 Sea Turtle | Nesting zones the player keeps free of disturbance and obstacles (✅ protection areas, hatchlings) |
| 🐦 Seabird | Nests in coastal vegetation — you can't clear every tree for resources |

Result: cleaner beach → more nesting → more wildlife — by changing how the island is used.
**Discovery:** clean up the underwater wreck / debris field → **Salvaged Sonar Core**.

### 2. 🌿 Kelp Forest — Food web ("species depend on one another")
Sea otter → sea urchin → kelp → kelp fish → cormorant. Otters control urchin grazing pressure;
urchins graze kelp; kelp is habitat for fish; fish feed cormorants. No problem can be solved in
isolation. **Exactly four animal species — no seals.**

| Animal | Ecological role | Gameplay |
|---|---|---|
| 🦦 Sea Otter | The predator that keeps urchin grazing in check | Never bought or spawned: Otter Habitats create resting, feeding, low-disturbance and breeding conditions; otters establish and reproduce naturally if the ecosystem supports them. Fewer otters → more urchins → kelp damaged → less fish habitat → fewer cormorants |
| 🟣 Sea Urchin | The main kelp grazer — not bad; a healthy forest has some | Creates the island's main pressure. No habitat building: part of the ecosystem, influenced indirectly (otters, kelp restoration) and, when needed, relocated from overgrazed areas to low-pressure ones (a limited management tool: "not the enemy — too many in the wrong place") |
| 🐟 Kelp fish / Rockfish | Depend on healthy kelp: the indicator of a functioning forest | Not managed directly; numbers follow habitat quality. No fish farm |
| 🐦 Cormorant | Visible top of the food chain; eats fish | Feedback: an underwater problem shows at the surface. No cormorant building; they follow fish and ecosystem health (nest in full-grown coastal trees, like all tree-nesting birds) |

**Kelp** is the foundation habitat (structure, shelter, fish), not decoration: its condition is a
main indicator of balance. It can be restored — but endless planting never fixes overgrazing:
restored kelp keeps struggling until the food web is fixed. Land trees: **coastal trees** (wood;
sapling → 3 stages, one a day; cut and replant as on the Starting Island).

**Buildings**
- ⭐ **Kelp Research Platform** (exactly 1): observe → understand → intervene → observe again.
  Missions: Kelp Health Survey (where kelp is healthy / damaged / recovering), Urchin Pressure
  Survey (where grazing is getting dangerous), Otter Monitoring (presence, habitat use, whether
  conditions support growth), Ecosystem Balance Survey (spells out links like low otters → high
  urchins → declining kelp), Kelp Restoration (restores damaged kelp), Urchin Relocation (moves
  excess urchins from high- to low-pressure areas), Storm Damage Survey (after heavy swell:
  damage and restoration priorities).
- **Otter Habitat** (hard max 6; the healthy number isn't fixed — often 2–3). Overbuilding uses
  shore space, raises upkeep, displaces other uses and unbalances the island; demolish to adapt.
- **Kelp Restoration Site** (hard max): local kelp restoration; spamming them can't win while
  urchin grazing is too high.
- 💰 **Kelp Discovery Centre** (max 2): visitors learn about kelp, otters, food webs, research →
  funding. Healthy ecosystem / attraction → funding → research and interventions → healthier
  ecosystem; balance infrastructure rather than building unlimited income.

**Rare event — Underwater Storm / heavy swell:** warned ahead; damages kelp sections, moves
debris, reduces visibility, may disrupt habitat. Response through the ecosystem: survey damage →
prioritise → restore → monitor. Never kills animals or gives a population bonus.

**Core loop:** observe → kelp declining → research shows high urchin pressure → check otter
conditions → build / protect suitable Otter Habitat → otters recover if conditions allow →
urchin pressure falls → kelp recovers → fish habitat improves → cormorants recover. And the
mistake loop: overbuild → space and resources constrained → inefficient → spot it → demolish /
reposition → balance improves.

**Discovery:** restore the food web, then gather shed kelp → **Kelp Fibre**.

### 3. 🌱 Mangrove Coast — Land meets ocean ("the land and ocean are connected")
Freshwater + sediment + nutrients → mangroves → juvenile fish nursery → ocean: an island about
water flow and connectivity. Current animal set (more only if they add a genuinely useful
mechanic, never to look populated):

| Animal | Ecological role | Gameplay |
|---|---|---|
| 🦀 Mangrove Crab | Ecosystem engineer: burrows change sediment, drainage, infiltration and local habitat | Crab Habitats (protected muddy burrowing ground) let crabs establish naturally; crab activity changes how water moves nearby — changing one habitat can change water elsewhere. Too little activity → poor drainage |
| 🐟 Juvenile fish | Mangroves are their nursery (shallows, roots, protected channels); grown, they move offshore | Keep mangrove → nursery channel → ocean connected; pollution, obstruction or bad construction cuts recruitment. No fish farm |
| 🦩 Flamingo | Feeds in shallow water; follows water depth and condition | Makes water-level management visible: too deep / too shallow / stagnant → feeding areas fail. Managed via the Waterworks Station |
| 🐊 Crocodile | Needs protected territory where visitors and boats can't go | A spatial-planning trade-off: Crocodile Protection Zones protect territory but restrict boat routes, visitor access, tourism and building; too many are inefficient and may need moving or demolishing |

**Mangrove trees** are the foundation habitat and the island's visible structure: they stabilise
shorelines, steer water flow, give nursery habitat, trap sediment; their health depends on the
right water and sediment.

**Buildings**
- ⭐ **Mangrove Waterworks Station** (exactly 1): Water Flow Survey (where freshwater enters,
  flows, is blocked, collects), Water Level Management, Nursery Flow Management, Channel Clearing,
  Sediment Management, Mangrove Recovery. "Water isn't just a resource: it's the transport
  system connecting the ecosystem."
- **Crab Habitat** (hard max): muddy protected burrowing ground; too many use valuable shoreline,
  interfere with other structures and shift the balance; demolishable.
- **Nursery Channels**: buildable / restorable pathways from mangroves to open water, critical for
  juvenile fish; can become blocked, damaged, disconnected or badly placed; restore or modify.
- **Crocodile Protection Zone** (hard max): protects territory but restricts boats, visitor routes
  and access. More protected area ≠ automatically better.
- 💰 **Mangrove Eco-Lodge** (max 3): visitors, education, kayak / boat tours, wildlife viewing →
  funding; but more tourism also means more boat traffic, more disturbance, more pressure on
  wildlife: tourism income ↔ ecological protection. Not just a money generator — part of the
  island's management problem.

**Missions** (from the Waterworks Station; always information → action): Water Flow Survey
(current flow, blocked / unhealthy areas), Nursery Connectivity Survey (can juvenile fish get
through to the ocean?), Water Level Adjustment (redistribute freshwater to restore shallow
habitat), Channel Restoration (clear / restore blocked nursery channels), Sediment Management
(excess sediment), Mangrove Recovery (restore mangroves damaged by flow problems), Wildlife
Monitoring (crab activity, nursery health, flamingo feeding areas, crocodile territory).

**Rare event — Flash Flood:** heavy rain sends a surge of freshwater and sediment through the
mangroves: water levels change fast, sediment is dumped, channels block, nursery connectivity
breaks, parts of the mangrove are damaged. Warned where appropriate. Response: Waterworks
Station → survey flow → find blocked areas → redirect water → restore channels → recover the
nursery. It tests that changing flow in one place affects the whole system — not random damage.

**Core loops:** water flow changes → a mangrove area becomes unhealthy → a nursery channel is
restricted → juvenile fish recruitment falls → investigate at the Waterworks Station → find the
blocked / poorly connected channel → restore it → water flows again → mangroves recover → nursery
improves → more fish reach the ocean. And alongside: more tourism → more boat traffic → more
disturbance → crocodile protection matters more → protected zones → too many restrict tourism →
reposition / remove zones. Two interlocking decision systems, not one linear puzzle.

**Discovery:** restore the channels, then collect resin from fallen branches → **Mangrove Resin**.

### 4. 🪸 Tropical Reef — Ecosystem complexity
Lagoon, coral reef, seagrass, outer reef, deep reef edge. Not just "plant coral": create the
conditions — water quality + coral + grazing + predators + seagrass + protection. The reef visibly
progresses: bare rock → algae → recovering coral → structured reef → diverse ecosystem.

| Animal | Role |
|---|---|
| 🐠 Parrotfish | Grazing keeps algae from overwhelming the reef |
| 🦈 Reef Shark | Predator balance: protect predator habitat, not only small animals |
| 🐚 Giant Clam | Part of the reef's water-quality / nutrient system |
| 🐴 Seahorse | Sensitive seagrass zones: manage boats and anchors |

Event: **crown-of-thorns starfish outbreak** — detect → map → prioritise → intervene → monitor.
Interventions stay non-lethal (e.g. protect its natural predators, cut the nutrient run-off that
feeds outbreaks, shield priority coral). Plants: coral, seagrass.
**Discovery:** restore the reef, then collect dead coral rubble → **Reef Limestone**.

### 5. 🌊 Deep Sea — Scientific discovery
You can't see everything: deploy cameras, hydrophones, mapping equipment, sensors and research
vessels to build up understanding. "There's nothing here" becomes "we didn't know what was here".
Findings (species, habitats, fishing impacts, migration routes) are useful on later islands.

| Animal | Role |
|---|---|
| 🐋 Sperm Whale | Acoustic mapping: its sounds reveal activity where you can't see |
| 🦑 Giant Squid | Rare discovery: leave cameras/sensors running long enough to find it |
| 🐟 Anglerfish | Bioluminescence helps identify animals and navigate the dark |
| 🦈 Deep-sea shark | Encounters reveal lost fishing gear to investigate and clean up |

**Discovery:** locate and recover an abandoned module from the seabed → **Cargo Module** (the ship
can now carry resources — the answer to "the Polar Ocean has no trees: how will I build there?").

### 6. ❄️ Polar Ocean — Global connectivity
Seasons change the island: ice forms → breeding habitat appears → food arrives → animals feed →
ice retreats → colonies relocate. It can't be "fixed" once; the player plans around change.
Chain: sea ice → penguin colonies → fish/krill → predators → ocean health.

| Animal | Role |
|---|---|
| 🐧 Penguin | Colonies need undisturbed breeding sites and access to feeding waters |
| 🦭 Seal | Uses particular ice areas to rest and breed; protected zones move with the ice |
| 🐻‍❄️ Polar Bear | Needs connected ice corridors between feeding and resting areas |
| 🐦 Skua / Arctic seabird | Early warning: responds fast to changes in fish and colonies |

No trees and no wood: everything built here uses wood brought in the ship's cargo.
**Discovery:** set up a research site (with the wood you brought) and drill → **Ice Core** (with all
six: the Ocean Research Vessel).

---

## Wood & cargo

Wood comes from each island's own land trees (cut down, plant saplings; growth stages as on the
Starting Island). Kelp, coral and seagrass are sea plants — never wood.

| Island | Wood source |
|---|---|
| 🏝️ Starting Island | 🌴 Palm trees (✅) |
| 🌿 Kelp Forest | 🌳 Coastal trees |
| 🌱 Mangrove Coast | 🌱 Mangrove trees |
| 🪸 Tropical Reef | 🌴 Coconut palms |
| 🌊 Deep Sea | 🌲 Coastal (conifer) trees |
| ❄️ Polar Ocean | ❌ No trees, no wood — bring it with you |

**Polar has no wood. Bring it with you.** No special Arctic plant, no "ice wood", no conversions.
With the Deep Sea's Cargo Module the Exploration Ship gets a cargo hold: gather wood on another
island, load it at the ship, sail, unload at the Polar Ocean, build (and eventually establish the
Polar Exploration Ship). Before sailing somewhere without wood, the ship warns:

```
🚢 Cargo: Wood 0 / XX
⚠️ Polar Ocean has no wood. Load wood before departure.
```

The cargo hold also allows, occasionally, other supplies that are hard or impossible to get on
some islands — a reason to plan what to take, without turning BlueHaven into inventory management.

## Buildings: signature & funding facilities

Every island has two kinds of island-specific building, and they're different both to look at and
in what they do:

- ⭐ **Signature Facility — exactly 1 per island.** The island's special machine: its research
  or restoration mechanism. **Spends** funding to operate: fund an operation → perform an action →
  discover / restore / learn → unlock progress. It's where the island's signature mechanic lives,
  and what drives its objective and discovery.
- 💰 **Funding Facility — a few per island (2–3).** The island's sustainable income. Simple:
  build it → visitors enjoy the ecosystem → funding each morning. A healthier ecosystem means a
  better experience and more funding. Money only ever comes from a healthy ocean, never from
  rescuing an animal.

**The loop:** build funding facilities → earn funding → spend it at the signature facility → use
the signature facility to restore the island → a healthier island makes the funding facilities
worth more. Income pays for conservation and research, and conservation and research make the
income grow.

| Island | ⭐ Signature facility (1) | What it does | 💰 Funding facility | Max |
|---|---|---|---|---|
| 🏝️ Starting Island | Marine Rescue & Research Station | Funds rescue-boat missions, finding wildlife in distress and coastal surveys | Wildlife Conservation Parks: Turtle Protection Area + Dolphin Viewing Area | 3 + 1 |
| 🌿 Kelp Forest | Kelp Research Platform | Sends divers / submersibles into the kelp forest to check its health and food-web balance | Kelp Discovery Centre | 2 |
| 🌱 Mangrove Coast | Mangrove Waterworks Station | Runs gates and pumps to manage freshwater flow through the mangroves | Mangrove Eco-Lodge | 3 |
| 🪸 Tropical Reef | Coral Restoration Laboratory | Grows and prepares coral and deploys restoration projects | Reef Diving Centre | 3 |
| 🌊 Deep Sea | Deep-Ocean Outpost | Launches submarines for deep-sea exploration and research | Deep-Sea Discovery Centre | 2 |
| ❄️ Polar Ocean | Polar Research Station | Drills and analyses ice cores; polar research | Polar Research Centre | 2 |

Shared infrastructure on any island, in neither category: Ranger Houses (storage), recycling
centres, docks, the workshop, the Exploration Ship.

### 🏝️ Starting Island
- ⭐ **Marine Rescue & Research Station** — the first signature facility, which introduces the
  idea. Spend funding to send out missions: wildlife rescue boat, coastal survey equipment,
  dolphin tracking, turtle monitoring, pollution surveys.
- 💰 **Wildlife Conservation Parks** — up to 3 Turtle Protection Areas (✅ exist) alongside a
  Dolphin Viewing Area. Each earns funding every morning. Start with one (enough to run basic
  rescue missions), then grow as the island improves.

### 🌿 Kelp Forest
- ⭐ **Kelp Research Platform** — home of the food-web mechanic. Fund research / diving missions to
  different parts of the forest to reveal urchin density, kelp health, otter activity and fish
  habitat.
- 💰 **Kelp Discovery Centre** (2) — guided dives / submersible trips. Healthier kelp → better
  experience → more funding each day.

### 🌱 Mangrove Coast
- ⭐ **Mangrove Waterworks Station** — an interactive mechanism: funding powers water gates, pumps
  and monitoring equipment; the player adjusts water flow through the mangrove network.
- 💰 **Mangrove Eco-Lodge** (3) — visitors explore the mangroves along controlled routes. Healthier
  mangroves + better access → more funding.

### 🪸 Tropical Reef
- ⭐ **Coral Restoration Laboratory** — the main reef-restoration mechanism: grow coral, keep coral
  nurseries, deploy coral, monitor the reef's recovery.
- 💰 **Reef Diving Centre** (3) — snorkelling, diving, watching wildlife, visiting restored reef.
  Sensitive reef areas are closed to visitors. Healthier reef → better diving → more funding.

### 🌊 Deep Sea
- ⭐ **Deep-Ocean Outpost** — an oil-rig-style platform. Spend funding to launch submarines; the
  player chooses where to send them, to investigate deep-sea animals, lost fishing gear, geological
  features, unknown habitats and pollution.
- 🛢️ **Oil-spill response equipment** comes with the outpost (building id `deep_ocean_outpost`).
  Only from then on do oil patches (from passing ships) start drifting in around every island —
  oil is a mid-game problem, met once the ranger has the equipment to handle it. Oil isn't part
  of island health.
- 💰 **Deep-Sea Discovery Centre** (2) — visitors don't go down themselves: live submarine feeds,
  deep-sea specimens and data, interactive displays, and the outpost's discoveries. The funding
  pays for more submarine expeditions.

### ❄️ Polar Ocean
- ⭐ **Polar Research Station** — the ice-core mechanism: funding runs the core drill, analysis
  equipment and research teams; the player chooses where to drill and what to investigate.
- 💰 **Polar Research Centre** (2) — penguin colonies, ice-core displays, research data, wildlife
  monitoring. Its funding supports the research station.

The signature facility is also how each island's discovery is gathered (e.g. the Deep-Ocean
Outpost's submarines locate the Cargo Module; the Polar Research Station drills the Ice Core).

## Rare events

One rare event per island. It **tests the island's main mechanic** — never a new mechanic or
mini-game. The player should think "I've built this ecosystem; now it has to withstand a
disturbance", not "another mini-game".

Rules:
- **An in-game year is 120 days** (a setting in the event data); "1–2 a year" means 1–2 every
  120 days.
- **Rare and predictable enough to prepare for:** a warning comes first (the Deep Sea's oil spill
  is detected rather than forecast). **At most once every 30 in-game days per island**; most
  events are rarer still (below).
- **Damages habitat, infrastructure, resources or access — not animal numbers.** No population
  surges or animal-management problems. Animals never die. A few may be **injured** (never badly,
  never worse over time): they rest until the island's signature facility's Rescue mission helps
  them recover, and don't count as living there meanwhile. The loop: warning → protect (e.g.
  turtle monitoring protects nests; a boat patrol means fewer injuries) → it strikes → rescue →
  back to normal. Protection prevents losses, rescue reverses injuries, breeding grows numbers.
- **Preparation pays:** a well-prepared island gets through with little damage; an unprepared
  one needs more recovery work. Always recoverable; never "you failed", only what needs help.
- Each has three phases: **Before** (warning, prepare) → **During** (what it damages or closes)
  → **After** (repair, restore, reopen).

| Island | Event | What it tests | How often |
|---|---|---|---|
| 🏝️ Starting | 🌪️ Coastal Storm | Protection & cleanup | 1–2 a year |
| 🌿 Kelp Forest | 🌊 Underwater Storm (heavy swell) | Habitat restoration | 1–2 a year |
| 🌱 Mangrove Coast | 🌧️ Flash Flood | Water management | 1–2 a year |
| 🪸 Tropical Reef | 🌀 Hurricane | Habitat preparation & resilience | once every 1–2 years |
| 🌊 Deep Sea | 🛢️ Oil Spill | Research & emergency response | once every 2–3 years |
| ❄️ Polar Ocean | 🧊 Major Ice Breakup | Adaptation & connectivity | 1–2 a year |

### 🌪️ Starting Island — Coastal Storm
- **Before:** "Storm approaching — prepare the island." Secure visitor facilities, close
  vulnerable visitor areas, protect turtle nesting areas, clear litter from vulnerable beaches,
  move important equipment inland.
- **During:** damages some buildings, pushes litter onto the beach, washes over nests that turtle
  monitoring hasn't protected (only one egg still hatches), injures up to 3 turtles / seabirds
  (fewer during a boat patrol), temporarily closes visitor areas.
- **After:** clean the beach, repair facilities, send a Rescue mission for the injured animals,
  reopen visitor zones.
- **Impact:** funding and conservation capacity dip for a while; beach condition and visitor
  access drop.

### 🌊 Kelp Forest — Underwater Storm (heavy swell)
- **Before:** "Heavy swell approaching." The Kelp Research Platform identifies vulnerable areas;
  prioritise strong established beds, fish nursery areas and beds that are already recovering.
- **During:** strong currents break some kelp, move rocks and debris, damage habitat, and cut
  underwater visibility for a while.
- **After:** send researchers down to survey the damage; prioritise restoration.
- **Impact:** research costs more / is limited while visibility is poor; kelp habitat (and so fish
  habitat) dips.

### 🌧️ Mangrove Coast — Flash Flood
- **Before:** "Flash flood approaching." Prepare the water network at the Waterworks Station: open
  some channels, close others, protect nursery areas, send excess water through resilient channels.
- **During:** a big freshwater and sediment pulse. Poor preparation → blocked channels, excess
  sediment, damaged mangroves, cut-off nurseries; good preparation spreads the water safely.
- **After:** clear blocked channels, repair waterways, reconnect the nurseries.
- **Impact:** juvenile-fish habitat dips if the water was badly managed; water flow and mangrove
  health are disrupted for a while.

### 🌀 Tropical Reef — Hurricane
- **Before:** "Hurricane approaching — prepare the reef." Is the habitat strong enough? Seahorses
  need healthy seagrass to anchor to with their tails: restore and protect seagrass beds, close
  boat routes through sensitive seagrass, restrict diving and snorkelling in vulnerable areas, and
  prioritise vulnerable coral.
- **During:** big waves, strong currents and moving sediment; some coral and seagrass damage;
  diving areas close for a while.
- **After:** well prepared → little habitat damage, seahorses keep their habitat, the reef
  recovers quickly. Poorly prepared → more seagrass and coral damage, the Reef Diving Centre earns
  less, restoration needed.
- **Impact:** tourism funding dips; reef and seagrass health dip. This gives the player a reason to
  build strong seagrass habitat *before* anything goes wrong.

### 🛢️ Deep Sea — Oil Spill
- **Starts:** "Oil detected in offshore waters." The player can't see the whole problem: the
  Deep-Ocean Outpost's submarine must search → locate → map → respond → monitor, finding where the
  oil is, which way it's moving and which habitats are at risk. Funding pays for the response.
- **During:** the slower the response, the further it spreads: more deep-sea habitat affected, and
  research missions suspended in contaminated areas.
- **After:** contain the source, monitor the area, survey its recovery.
- **Impact:** research funding goes to the emergency response; pollution and reduced research
  access for a while.

### 🧊 Polar Ocean — Major Ice Breakup
- **Before:** "Major ice movement detected." Protect key penguin colony areas, keep routes open
  between colonies and feeding areas, adjust protected zones, move research equipment off
  unstable ice.
- **During:** a large section of ice breaks away: travel routes change, some habitat is cut off,
  some areas close and others open.
- **After:** re-map the coastline and ice, re-establish safe routes, monitor penguin and seal
  habitat, move or rebuild affected facilities.
- **Impact:** some areas can't be reached for a while; the habitat layout changes rather than
  animal numbers.

Real-world basis: storms damage coral, seagrass and mangroves and tear up kelp, while healthy
coastal habitats also protect coasts from storms; heavy rain changes water and sediment flow
through mangroves; deep-water oil spills are hard to see and track without research equipment.

## Changes that travel between islands

Effects must be **seen in the world**, not only in statistics.

| Player action | Immediate result | Elsewhere |
|---|---|---|
| 🗑️ Clean pollution (Starting) | Cleaner coastal water | Kelp Forest recovers faster |
| 🚤 Reduce boat disturbance | Wildlife returns | Dolphins, seals, migrants use safer routes |
| 🌿 Restore the Kelp Forest | More habitat & fish | More food for migrating predators |
| 🦦 Restore sea otters | Urchins balanced | Kelp expands → more fish habitat |
| 🌱 Restore mangroves | More nursery habitat | More juvenile fish reach the Tropical Reef |
| 🚧 Keep mangrove channels open | Fish move through the nursery | Reef fish improve later |
| 🪸 Restore the reef | More adult fish habitat | Better feeding grounds for migrants |
| 🐠 Protect parrotfish | Better grazing | Coral restoration succeeds more |
| 🔬 Research the Deep Sea | Discover migration/fishing problems | New protections available elsewhere |
| 🎣 Change fishing practices | Less bycatch | Deep-sea and polar populations recover |
| 🧭 Protect migration routes | Animals travel safely | Wildlife returns to several islands |
| ❄️ Protect polar habitat | Migration succeeds | Animals later appear in other regions |

Seen examples: restored mangroves → more juveniles in the channels → later, more adult fish on the
reef ("they came from the nursery I restored"). Unprotected otters → the forest is thinner when you
come back → restore otters → it regrows. Unmanaged pollution at home → slower kelp, poorer nursery,
fewer reef fish — traceable back to where it started.

---

## Steps

Each step ends with a playable build. ✅ = done.

- **Step 0 — Foundations ✅** Home island, walking, rowboat, litter & inventory, turtles & nesting,
  protection areas, dolphins & crabs, funding, buildings & upgrades, wood/trees/sand, docks, patrol
  boats, recycling, save/backup codes, phone PWA; six island shapes; Map vs Explore; Exploration
  Ready (one ship per island) with the 🧭 on the Map.
- **Step 1 — Island objectives & the fleet ✅** An objective per island (RegionData.goals,
  data-driven) that must be completed before its Exploration Ship can be built; the six discovery
  items (data/discoveries/); ship equipment level (one level for the whole fleet = discoveries
  installed) with the upgrade screen at the ship; each direction's next island requires the right
  discovery (RegionData.requires); ship sprites per level. (The Map keeps just grey / normal / 🧭.)
  The Starting Island's objective is the wreck (Step 2). No ship can be
  built until its island's discovery is found, so islands with no objective yet have none. Older
  saves: ships whose island objective isn't done are removed (funding returned), and islands found
  without the upgrade they need are locked again.
- **Step 2 — Starting Island complete ✅** Pollution types (plastic, oil/chemicals, fishing debris,
  boat disturbance, beach use) each affecting its own system; seabirds nesting in vegetation (a
  reason not to cut every tree); turtle nesting zones kept clear; the underwater wreck / debris
  field → Salvaged Sonar Core. Buildings: ⭐ Marine Rescue & Research Station
  (funded missions) and 💰 Wildlife Conservation Parks (up to 3 Turtle Protection Areas + a Dolphin
  Viewing Area). Rare event: 🌪️ Coastal Storm.
- **Step 3 — Kelp Forest.** Kelp as plants; otters, urchins, kelp fish, cormorants; the food-web
  simulation (visible forest thinning and regrowing); shed kelp → Kelp Fibre. ⭐ Kelp Research Platform, 💰 Kelp Discovery Centre (2). Rare event: 🌊 Underwater Storm.
- **Step 4 — Mangrove Coast.** Mangroves as plants; water flow, channels, mud flats, nursery;
  mangrove crab, juvenile fish, flamingo, crocodile zones; fallen branches → Mangrove Resin. ⭐ Mangrove Waterworks Station, 💰 Mangrove
  Eco-Lodge (3). Rare event: 🌧️ Flash Flood.
- **Step 5 — Tropical Reef.** Coral and seagrass plants; reef stages from bare rock to diverse reef;
  parrotfish, reef shark, giant clam, seahorse; crown-of-thorns outbreaks (part of the reef mechanic); coral rubble → Reef Limestone. ⭐ Coral Restoration Laboratory, 💰 Reef Diving
  Centre (3). Rare event: 🌀 Hurricane (seagrass for seahorses).
- **Step 6 — Deep Sea.** Research equipment (cameras, hydrophones, mapping, sensors) and hidden
  information; sperm whale, giant squid, anglerfish, deep-sea shark; findings unlock protections
  elsewhere; recovering the lost module → Cargo Module (ship cargo storage). ⭐ Deep-Ocean Outpost
  (with oil-spill response equipment: from now on oil patches drift in around every island), 💰 Deep-Sea Discovery
  Centre (2). Rare event: 🛢️ Oil Spill.
- **Step 7 — Polar Ocean.** Seasons and moving ice; colonies; penguin, seal, polar bear, skua;
  no trees — build with wood brought as cargo; research site and drilling → Ice Core. ⭐ Polar Research Station, 💰 Polar
  Research Centre (2). Rare event: 🧊 Major Ice Breakup.
- **Step 8 — Connected ocean.** The cross-island effects above, shown in the world (grown
  gradually from Step 3 on: each new island links to the ones before it).
- **Step 8b — Rare events.** One per island (see "Rare events"), each testing that island's main
  mechanic: warning → prepare → event → recover, at most once per 30 days. Built with each island's
  step, starting with the Starting Island's Coastal Storm (Step 2).
- **Step 9 — Ocean Research Vessel & Global Ocean Observatory.** With all six discoveries the ship
  becomes the Ocean Research Vessel and the Map gains the Global Ocean Observatory: the whole
  ocean's health and how the islands affect each other. Every ship visible across the ocean.

---

## Build order: finish the Starting Island, then its two neighbours

The Starting Island is finished first, then the two islands you can explore from it: the
**Kelp Forest** (colder) and the **Mangrove Coast** (warmer). Each item is one small, playable,
tested commit. Placeholder art throughout.

### Step 2 — Starting Island complete ✅
1. **Island health (Ocean Impact for one island).** A 0–100 % health per island from what's been
   done there (litter left, animals helped, nests protected, later pollution types). Shown at the
   signature facility and in the Journal; the island's water and ground colours shift from muted
   to vibrant as it rises. Everything below feeds it, and funding facilities read it.
2. **Funding facilities → Wildlife Conservation Parks.** Up to 3 Turtle Protection Areas (✅
   exist) alongside a Dolphin Viewing Area (on the shore, near the pod). Both marked as funding
   facilities; morning funding grows with island health.
3. **Signature facility → Marine Rescue & Research Station (exactly 1).** The island's active
   conservation response tool, not a source of permanent upgrades: spend funding to send a
   mission (one at a time, back after a few real minutes) that responds to what's happening:

   | Mission | What it does | Lasts |
   |---|---|---|
   | 🛟 Rescue | Injured animals (after a storm) recover and return to the ecosystem; ones caught in litter are marked for the ranger to free | immediate |
   | 🚤 Boat patrol | Busy boats don't disturb animals, and a storm injures fewer | 2 days |
   | 🗑️ Pollution survey | Searches beyond the usual visible litter (max 15): 5–10 more hidden pieces turn up, even on a clean island | marked until collected |
   | 🐢 Turtle monitoring | Finds and protects the active nests (a storm can't wash them over) — best when a storm is coming | 2 days |
   | 🐬 Dolphin tracking | A visiting dolphin joins the island (near the Dolphin Viewing Area: more visitors) | 2 days |
   | 🧭 Coastal survey | Searches for the wreck (the Exploration Ship's component): 20 % chance, always found by the 5th try; no longer offered once found | — |

   Rescue recovers existing animals — it never creates new ones; numbers grow through healthy
   animals breeding. Its screen shows island health and what's going on.
4. **Pollution types.** Each hits its own system: plastic → wildlife hazard (✅ litter);
   fishing debris → entanglement (ghost nets and line wash in; animals can get tangled again, and
   the rescue boat finds them); oil / chemicals → water quality (dark patches on the water, cleaned
   with the boat, lowering health while there) — **mid-game only**: oil patches don't appear until
   the Deep Sea's Deep-Ocean Outpost is built, which brings the oil-spill response equipment
   (Step 6). Oil is never part of island health: 100 % is no litter in reach, no hurt or caught
   animals and a fully populated island; boat disturbance → dolphins avoid busy water near
   patrol routes; beach use → turtles won't nest next to buildings (keep nesting beaches clear).
5. **Seabirds** (red-footed boobies). Nest in grown palms — a reason not to cut every
   tree. Need help: chicks caught in fishing line. Give: flocks circle over floating litter and
   fish, showing where to go.
6. **Upgrade art.** Each building upgrade tier changes its picture (a texture per tier in
   BuildingData), like the ship's fleet levels.
7. **The underwater wreck / debris field.** Found by the coastal survey; a zone of sunken litter
   cleared from the boat; once cleared, recover the old sonar unit → **Salvaged Sonar Core**. This
   replaces the stand-in objective (litter + freeing three animals).
8. **🌪️ Coastal Storm (first rare event; see "Rare events").** The event system (warning →
   prepare → storm → recover, at most once per 30 days per island) plus the storm itself: prepare
   by securing visitor facilities, closing vulnerable areas, protecting nesting areas, clearing
   beach litter and moving equipment inland; afterwards clean the beach, repair facilities,
   restore nesting habitat and reopen visitor areas.

### Step 3 — Kelp Forest (colder, 1st)
See "Island by island → Kelp Forest" for the design. Build order (each a playable commit):
1. **Coastal trees** replace the leftover palms: wood and saplings, sapling → 3 stages (one a day).
2. **Kelp beds and urchins:** kelp beds on shallow and mid water, each with its health (drawn
   denser / sparser) and its urchins; the daily food-web model: urchins graze and multiply, kelp
   regrows where grazing is low.
3. **Sea otters + Otter Habitat** (hard max 6): otters settle and breed only while habitats offer
   room *and* the forest can feed them; they move away (never die) when food runs short. The
   food web is island-wide: **how many** habitats matters, never where they are (a player can
   keep wildlife on one side and people and boats on the other). 2–4 habitats can all reach
   100 % (2 with some restoration); 5–6 let otters eat nearly every urchin (out of balance, and
   the upkeep adds up). **Response time:** every change moves 20 % of the way at once and half
   of the rest each day, so it has mostly settled within 3–4 days and the player sees what
   their choice did.
4. **Kelp fish and cormorants** follow kelp and fish (arrive / move away day by day);
   cormorants nest in full-grown coastal trees.
5. **Kelp Research Platform** (signature, 1) with its missions: kelp health survey, urchin
   pressure survey, otter monitoring, ecosystem balance survey, kelp restoration, urchin
   relocation, storm damage survey.
6. **Kelp Restoration Site** (hard max) and 💰 **Kelp Discovery Centre** (max 2).
7. **Island health** from the food web (kelp cover, otters, fish, cormorants, clean water), all
   scaled by the urchin balance (neither overgrazing nor none): an unbalanced web pulls the
   whole island down. Too many of one species (otters above 8) scores lower again. Range: every
   island starts near 0 % on the first visit (a surge of litter left over years:
   RegionData.arrival_litter); one species dominating with the litter left about ≈ 20 %; balanced
   but littered ≈ 55 %; balanced and clean 100 %.
8. **🌊 Underwater Storm (heavy swell):** warned; damages kelp beds, moves debris, reduces
   visibility (missions take longer for a while); respond by surveying and restoring.
9. **Objective → Kelp Fibre:** restore the balance, then gather shed kelp at set spots. Kelp
   Forest Exploration Ship; Deep-Water Equipment opens the Deep Sea.
10. **First cross-island link:** Starting Island water quality speeds the kelp's recovery.

### Step 4 — Mangrove Coast (warmer, 1st)
1. **Mangrove trees** as the island's wood and a plant: planted along mud edges, they hold mud
   and grow the nursery.
2. **Water flow and channels:** channels can be blocked (debris, silt) or open; blocked ones stop
   fish reaching the nursery pools.
3. **Mangrove Waterworks Station** (signature): funding runs gates and pumps; the player opens,
   closes and clears channels to manage freshwater flow.
4. **Mangrove Eco-Lodge** (funding, up to 3): visitors on set routes; healthier mangroves and
   better access → more funding.
5. **Mangrove crabs** (burrows change sediment and flow), **juvenile fish** (grow in the
   nursery, later move to the Reef), **flamingos** (feed where shallows are right: a water-level
   indicator), **crocodile zones** (boats and people keep away).
6. **Objective → Mangrove Resin:** restore the channels, then collect resin from fallen branches.
   Mangrove Exploration Ship; Environment Sensors open the Tropical Reef.
7. **Cross-island link:** open channels → more juvenile fish (shown later on the Reef).
8. **🌧️ Flash Flood:** set the gates and channels before it arrives; afterwards clear blocked
   channels and restore nursery connectivity.

