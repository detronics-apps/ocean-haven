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

**Exploration Level** — the fleet's equipment level, shown at the ship ("Level 1: one basic
expedition vessel" … "Level 5: a global research network"). Not charges, fuel or tokens.

---

## Island by island

Animal rule (CLAUDE.md): every animal needs the ranger's help, helps other animals, or both —
and **animals never die**. Declines are shown as animals leaving, fewer arriving, colonies moving
away or fewer young — and always recoverable. Interventions are never lethal.

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

### 2. 🌿 Kelp Forest — Food web
Sea otter → sea urchin → kelp → habitat → fish. Lose otters: urchins ↑, kelp ↓, habitat ↓, fish ↓.
The lesson isn't "remove urchins" but "why are there too many urchins?" — restore the otters and the
system fixes itself.

| Animal | Role |
|---|---|
| 🦦 Sea Otter | Keeps urchins in balance; restoring otters changes the whole forest |
| 🦔 Sea Urchin | Kelp grazer — managed through the food web, never eliminated |
| 🦭 Seal | Needs safe haul-out / breeding areas → protected coastal zones |
| 🐟 Kelp fish / Rockfish | Habitat indicator: numbers follow the forest's health |

Plants: kelp (grows back visibly). **Discovery:** restore the food web, then gather shed kelp → **Kelp Fibre**.

### 3. 🌱 Mangrove Coast — Land meets ocean
Land → freshwater → sediment/nutrients → mangroves → juvenile fish → ocean. The player restores (or
damages) mangrove channels, mud flats, shallow pools, nursery areas, boat channels; a blocked channel
stops fish reaching the nursery.

| Animal | Role |
|---|---|
| 🦀 Mangrove Crab | Ecosystem engineer: burrows change sediment and water flow, and where mangroves thrive |
| 🐟 Juvenile fish | Nursery connection: grow up in the channels, then move to other habitats (later the Reef) |
| 🦩 Flamingo | Water-level indicator: feeding areas follow shallow-water conditions |
| 🐊 Crocodile | Territories are protected zones where boats and people must keep away |

Plants: mangroves. **Discovery:** restore the channels, then collect resin from fallen branches → **Mangrove Resin**.

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

## Rare events

Occasional events, different per island type, that call for **preparation** (warned in advance)
or **immediate action** (sudden) — otherwise wildlife numbers dip. Per the rules, animals never
die: a dip means animals leave, fewer arrive, nests are lost to the sea or colonies move, and it
always recovers when the player responds. Never a "you failed"; say what needs help.

| Event | Where | Warning? | Prepare / respond |
|---|---|---|---|
| 🌀 Storm | Tropical islands (Starting, Mangrove, Reef) | Yes — forecast a day ahead | Secure nests above the tide line, moor boats, protect young plants; afterwards clear the storm litter and check buildings and reef damage |
| 🛢️ Oil spill | Any, near shipping (Starting, Kelp, Reef) | No — sudden | Boom it off fast, clean oiled beaches and water, care for oiled animals (rescue → care → release) |
| 🌡️ Marine heatwave / coral bleaching | Tropical Reef | Yes — water warming | Shade and cool priority coral, cut other stress (runoff, anchors), watch recovery |
| 🦔 Urchin boom | Kelp Forest | Builds up slowly | Read the food web: support the otters rather than removing urchins |
| ⭐ Crown-of-thorns outbreak | Tropical Reef | Detectable early | Detect → map → prioritise → non-lethal intervention → monitor |
| 🌊 King tide / flood | Mangrove Coast, Starting | Yes — tide tables | Keep channels open, move nests, protect nursery pools |
| 🥅 Ghost-net drift | Deep Sea, Kelp | Found by research / animals | Track and recover the lost gear before it entangles wildlife |
| 🧊 Early ice break-up | Polar Ocean | Yes — seasonal signs | Relocate protected zones, keep colonies' route to the sea open |

Preparation is rewarded: a well-prepared island shrugs a storm off; an unprepared one needs a
cleanup. Events also connect islands (a spill's slick drifts; a storm scatters litter to the
next island).

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
- **Step 1 — Island objectives & the fleet.** An objective per island (data-driven) that must be
  completed before its Exploration Ship can be built; the six discovery items; ship equipment level
  (one level for the whole fleet) with the upgrade screen at the ship; each direction's next island
  requires the right discovery; ship sprites per level. (The Map keeps just grey / normal / 🧭.)
- **Step 2 — Starting Island complete.** Pollution types (plastic, oil/chemicals, fishing debris,
  boat disturbance, beach use) each affecting its own system; seabirds nesting in vegetation (a
  reason not to cut every tree); turtle nesting zones kept clear; the underwater wreck / debris
  field → Salvaged Sonar Core.
- **Step 3 — Kelp Forest.** Kelp as plants; otters, urchins, seals, kelp fish; the food-web
  simulation (visible forest thinning and regrowing); shed kelp → Kelp Fibre.
- **Step 4 — Mangrove Coast.** Mangroves as plants; water flow, channels, mud flats, nursery;
  mangrove crab, juvenile fish, flamingo, crocodile zones; fallen branches → Mangrove Resin.
- **Step 5 — Tropical Reef.** Coral and seagrass plants; reef stages from bare rock to diverse reef;
  parrotfish, reef shark, giant clam, seahorse; crown-of-thorns events; coral rubble → Reef Limestone.
- **Step 6 — Deep Sea.** Research equipment (cameras, hydrophones, mapping, sensors) and hidden
  information; sperm whale, giant squid, anglerfish, deep-sea shark; findings unlock protections
  elsewhere; recovering the lost module → Cargo Module (ship cargo storage).
- **Step 7 — Polar Ocean.** Seasons and moving ice; colonies; penguin, seal, polar bear, skua;
  no trees — build with wood brought as cargo; research site and drilling → Ice Core.
- **Step 8 — Connected ocean.** The cross-island effects above, shown in the world (grown
  gradually from Step 3 on: each new island links to the ones before it).
- **Step 8b — Rare events.** Storms, oil spills, heatwaves and the island-specific events above:
  forecasts / warnings, preparation, immediate response, visible dips and recovery. Start with a
  storm and an oil spill on the Starting Island, then add each island's own event with its step.
- **Step 9 — Ocean Research Vessel & Global Ocean Observatory.** With all six discoveries the ship
  becomes the Ocean Research Vessel and the Map gains the Global Ocean Observatory: the whole
  ocean's health and how the islands affect each other. Every ship visible across the ocean.
