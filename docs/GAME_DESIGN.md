# BlueHaven — Game Design

## Core fantasy

> "Start with one little island. Help the ocean around you. Watch it come alive."

You begin with almost nothing:

- 🏝️ A small island
- 🏚️ A tiny shack
- 🛶 A little boat
- 🧹 A few basic tools
- 💰 A small amount of funding
- 🌊 A damaged ocean around you

Over time, you transform the island into a base for ocean conservation.
You aren't conquering the ocean. You're giving it a chance to recover.

## Core game loop

### 1. Explore 🌊
Take your boat around the surrounding ocean. You discover: plastic waste, fishing debris, damaged coral, sea turtle nesting areas, dolphins, seabirds, whales, seals, penguins, mangroves, kelp forests, shipwrecks, small islands, hidden beaches.

### 2. Help 🧹
Simple interactions, not complicated simulations.

- **Ocean cleanup** — Collect 10 pieces of plastic.
- **Turtle rescue** — Find an injured turtle and bring it to the sanctuary.
- **Beach protection** — Clear debris from a nesting beach.
- **Coral restoration** — Plant 5 coral fragments.
- **Mangrove restoration** — Plant mangrove seedlings.

### 3. Restore 🌱
Once you've helped an ecosystem, it visibly changes. The player gets to see their impact.

| Before | After |
|---|---|
| 🏝️ Grey beach | 🏝️ Clean beach |
| 🌊 Murky water | 🌊 Clear blue water |
| 🪸 Dead coral | 🪸 Colourful coral |
| 🐢 No turtles | 🐢 Turtles swimming around |

### 4. Animals return 🐢
Healthy habitats attract animals: 1 turtle → 8 turtles after restoration → many more. The animals themselves are part of the reward.

### 5. Funding increases 💰
A healthy ocean creates funding opportunities: eco-tourism, educational tours, research partnerships, wildlife photography, sanctuary visitors, sustainable fishing, ocean research, conservation grants, beach clean-up events.

Help nature → nature improves → more people become interested → funding increases → more conservation becomes possible.

### 6. Expand 🏝️
The tiny island becomes a proper conservation centre: turtle sanctuary, marine research centre, coral nursery, wildlife clinic, recycling centre, ranger station, mangrove nursery, ocean laboratory, education centre, boat dock, observation tower, weather station, research vessel. Eventually you gain access to new parts of the ocean.

## The island

The island is the heart of the game. You start with perhaps only 20–25% of it usable, and it becomes a visual representation of your progress.

```
Start:                      Later:
        🌴🌴                        🌴🌴🌴
    🌊🌊🌊🌊🌊                    🌳  🔬  🌳
  🌊    🏝️🏝️     🌊            🌴 🐢 🏝️ 🪸 🌴
 🌊    🏚️ 🧹      🌊          🌊 🛶 🏠 ♻️ 🚤 🌊
 🌊      🛶       🌊            🌊 🌱 🐠 🐋 🌊
  🌊             🌊                🌊🌊🌊🌊🌊
    🌊🌊🌊🌊🌊
```

## Sanctuary system

Each animal is part of an ecosystem rather than a collectible.

**Sea Turtle Sanctuary** — you discover a beach where turtles nest:

1. Clean the beach
2. Install protective markers
3. Build a ranger hut
4. Protect nests
5. Help hatchlings reach the ocean
6. Track returning turtles
7. Establish a permanent turtle sanctuary

The player learns *why turtles need clean beaches*, *why we shouldn't disturb nesting turtles*, *why plastic is dangerous to turtles* — without the game becoming a classroom.

## Coral reef restoration

Initially a dull/brown reef. The player:

1. Cleans the area
2. Builds coral nursery
3. Grows coral fragments
4. Places coral
5. Waits for growth
6. Fish return
7. Reef becomes colourful 🌈 🪸 🐠 🐟 🦀 🐙 🐡

## Ecosystems

| Ecosystem | Animals | Tasks |
|---|---|---|
| 🪸 Coral Reef | Clownfish, sea turtles, rays, seahorses, octopus, reef sharks, parrotfish | Coral restoration, remove debris, monitor water quality, restore fish habitat |
| 🌿 Mangrove Forest | Crabs, juvenile fish, birds, small reptiles, dolphins | Plant mangroves, remove rubbish, restore waterways |
| 🌊 Kelp Forest | Sea otters, seals, fish, sea lions | Replant kelp, monitor water, protect wildlife |
| 🏖️ Turtle Beach | Green, loggerhead, hawksbill turtles | Protect nests, remove plastic, hatchling patrol, beach restoration |
| 🐧 Cold Ocean | Penguins, seals, whales, albatross | (Different visual style) |
| 🐋 Open Ocean | Humpback whales, dolphins, sharks, tuna, manta rays, whale sharks | Via research vessel |

## World map

Six islands, discovered by exploring — not by player level.

| # | Region | Theme | Island | Found by exploring |
|---|---|---|---|---|
| 1 | 🏝️ Starting Island | Human impact | Horseshoe round a lagoon | (start) |
| 2 | 🌿 Kelp Forest | Food-web relationships | Long thin crescent | Colder, 1st |
| 3 | 🌱 Mangrove Coast | Land/ocean connection | Branching fingers, mud | Warmer, 1st |
| 4 | 🪸 Tropical Reef | Ecosystem complexity & restoration | Broken ring, big lagoon | Warmer, 2nd |
| 5 | 🌊 Deep Sea | Scientific discovery | Rocky hook round deep water | Colder, 2nd |
| 6 | ❄️ Polar Ocean | Global connectivity | Ice floes and rock | Colder, 3rd |

Routes: **colder** Starting → Kelp Forest → Deep Sea → Polar Ocean; **warmer** Starting → Mangrove
Coast → Tropical Reef.

### Map vs Explore — two separate things, never one menu

- 🗺️ **Map** (HUD button) — "Where can I go?" Shows every island. Sails only to islands you've
  already discovered (no ship needed). Undiscovered islands are shown but locked, informational only.
- 🚢 **Explore** — "Where can I discover next?" Only by walking up to an **Exploration Ship** on
  the current island. It offers **Explore warmer** / **Explore colder** — a direction, never a named
  island. Each finds the **next undiscovered island in that direction**, from wherever you are (e.g.
  from the Deep Sea, warmer finds the Mangrove Coast if it's still unknown, else the Tropical Reef).
- Once discovered, an island is permanently on the Map. To explore on from it, establish its own
  Exploration Ship there (a 🧭 on the Map). Never rebuild ships just to go back.
- The full end goal — islands, animals, island technology and fleet upgrades, cross-island effects,
  and the steps to get there — is in `docs/MASTER_PLAN.md`.

Ground tiles are plain and shared (sand, grass, rock, ice, mud; water shallow / mid / deep). Coral,
kelp and mangroves are plants on top.

Each region introduces: **one new ecosystem + several animals + one major environmental problem + one new gameplay mechanic.**

## Ocean cleanup

One of the first activities. Floating items: 🧴 bottle, 🥫 can, 🛍️ plastic bag, 🪢 rope, 🎣 fishing line, 🛞 old tyre, 🪵 driftwood. Interact to collect.

Tiny optional facts ("Plastic can remain in the ocean for hundreds of years") — but don't interrupt gameplay constantly; use the journal instead.

## Ocean Journal

Every discovery goes into the journal. Example entry:

> **🐢 Green Sea Turtle**
> Habitat: Tropical & subtropical oceans
> Diet: Seagrass and algae
> Threats: Plastic pollution, fishing gear, habitat loss
> How we can help: Keep beaches clean, reduce plastic use, protect nesting beaches
> Did you know? *A fun fact.*

## "How Can I Help?" menu

| Topic | In the game | In real life |
|---|---|---|
| 🐢 Turtles | Protect nesting beaches | Reduce plastic waste |
| 🪸 Coral | Restore coral reefs | Reduce pollution, support reef conservation |
| 🐋 Whales | Protect migration routes | Support responsible ocean practices |

Transitions the player from "this is fun" to "oh, I can actually do something."

## Funding system

Money doesn't simply appear because you rescued an animal. Build a simple conservation economy — things you create generate funding:

Eco-tour (visitors pay to see restored reef) → wildlife photography (research funding) → research station (scientists pay for facilities) → education centre (schools visit) → conservation grants (successful projects unlock grants) → more funding → more conservation.

Message: **conservation needs resources.**

## Building

Keep construction extremely simple. Four categories:

- 🏠 **Facilities** — Ranger Hut, Research Centre, Visitor Centre, Wildlife Clinic
- 🌱 **Nature** — Coral Nursery, Mangrove Nursery, Seagrass Garden, Turtle Nest Area
- ⚓ **Infrastructure** — Dock, Boat Shed, Research Vessel, Solar Station
- 🎓 **Education** — Aquarium, Ocean Museum, Observation Tower, Discovery Centre

### Sustainable infrastructure
The island becomes progressively more sustainable: 🔌 generator → ☀️ solar panels → 💧 water tank → ♻️ recycling centre → 🌊 wave-energy generator. Eventually a miniature sustainable community.

## Art style

- 16-bit / modern pixel art — SNES-era inspiration + modern cozy readability. Not ultra-retro NES.
- 16×16 / 32×32 tiles, larger character sprites.
- Chunky pixel characters, hand-drawn-looking UI, bright turquoise water, warm sandy islands, expressive animals, subtle environmental storytelling.
- Not hyper-realistic. Something a parent could happily play with their child.

### Colour as feedback

- **Damaged environment** (muted): dark blue, grey, brown, desaturated green
- **Healthy environment** (vibrant): turquoise, ocean blue, coral pink, tropical green, yellow, purple

## Player character

Large head, small body, backpack, hat, boots. Customizable: shirt, hat, backpack, clothes, boat appearance. No complicated stats — a conservation ranger, not a superhero.

## Animal design

Cute but biologically recognizable. Turtle: small, chunky shell, expressive eyes. States: healthy 🐢✨, nesting 🐢 → 🥚🥚🥚, hatchlings 🐢🐢🐢🐢.

### Behaviour

- **Turtles:** swim → eat → rest → nest
- **Dolphins:** travel in groups → jump → investigate boat
- **Seals:** swim → beach → play
- **Whales:** travel → surface → dive
- **Birds:** fly → fish → nest

## The ocean changes

Possibly the strongest mechanic. Actions visibly affect the surrounding water.

| Level | State |
|---|---|
| 0 | Dark water, debris, dead coral |
| 1 | Cleaner water, a few fish |
| 2 | Clear water, fish |
| 3 | Coral returns, turtles |
| 4 | Many fish, colourful coral, turtles, octopus |
| 5 | Thriving ecosystem ✨ |

### Before & After button
Press it to briefly show the area before vs. after restoration. Makes the player's work visible.

## Progression — Ocean Impact

No character levels. Overall **Ocean Impact** (e.g. 14%), broken into:

- 🌊 Ocean Health
- 🪸 Reef Health
- 🐢 Wildlife Protection
- 🌱 Habitat Restoration
- ♻️ Waste Reduction
- 🎓 Ocean Knowledge

## Achievements

Fun, not competitive.

**Beginner**
- 🧹 First Cleanup — Collect your first piece of ocean waste.
- 🐢 Turtle Friend — Help your first turtle.
- 🌱 Green Thumb — Plant your first mangrove.
- 🪸 Reef Builder — Restore your first coral.

**Exploration**
- 🔭 First Discovery — Discover your first new species.
- 🗺️ Explorer — Visit every region.
- 🐋 Giant of the Sea — Encounter your first whale.
- 🐙 Eight Arms — Discover an octopus.

**Conservation**
- 🐢 Turtle Guardian — Protect 10 turtle nests.
- 🪸 Reef Keeper — Restore 100 coral fragments.
- 🌳 Mangrove Maker — Plant 100 mangroves.
- ♻️ Waste Not — Remove 1,000 pieces of waste.

**Big**
- 🌊 Ocean Guardian — Restore your first complete ecosystem.
- 🏝️ Sanctuary Island — Fully develop your island.
- 🐋 Ocean Protector — Establish protection across the open ocean.
- 💙 Blue Planet — Achieve maximum ecosystem health.

**Secret**
- 🦀 Crab Walk — Follow a crab for 30 seconds.
- 🐬 Hello! — Get a dolphin to follow your boat.
- 🐢 Slow Down — Stand still while a turtle swims past.
- 🐙 What's That? — Discover a hidden octopus.
- 🐋 Splash Zone — Get splashed by a whale.
- 🦜 Bird Watcher — Find every bird species.

## Difficulty

No traditional difficulty setting. Modes: **Relaxed** (no time pressure), **Standard** (normal progression), **Challenge** (optional goals, resource limits). Default is very forgiving — never "You failed because you didn't save enough turtles", instead "The beach needs more protection." The player can simply try again.

## Kids and adults — three layers

1. **Kids:** explore + collect + build + animals. Sail around → collect plastic → rescue turtles → build things.
2. **Older children:** ecosystems + resources + conservation decisions. "If I damage this habitat, these animals disappear."
3. **Adults:** optimization + funding + interconnected ecosystems. E.g. restoring mangroves increases fish populations → improves the local ecosystem → increases eco-tourism revenue.

Same game, different depth, no complicated controls.

## Educational content

No mandatory quizzes. Use **Discovery Cards**:

> **🐢 SEA TURTLE — Found!**
> Sea turtles can travel thousands of kilometres during their lives.
> Threat discovered: Plastic pollution
> Protection unlocked: Turtle beach cleanup

## Sound

The soundscape grows richer as ecosystems improve.

- **Damaged:** soft waves, wind, sparse music
- **Healthy:** waves, birds, dolphin clicks, underwater sounds, gentle music

**Music:** cozy tropical exploration — marimba, soft guitar, ukulele, piano, light percussion, ocean ambience. Each region gets its own music.

## Platform

PC, Mac, Nintendo Switch, tablet, mobile. Design controls around touch/controller simplicity first.

## No combat

No guns, enemies, killing, boss fights, or combat stats. Challenge comes from exploration, problems, resources, restoration, discovery. The player's "weapons": cleanup tools, science, boats, restoration, care.

## Real-world conservation

Potentially partner with real organizations ("This month's Ocean Project"), and part of revenue could support real ocean conservation — transparent and optional, not a marketing gimmick.

## Decisions (from the feature concept art)

`docs/feature_reference.jpg` adds: avatar creator, turtle rescue → care → release, build & upgrade, region unlocks, Real Impact page. Adopted with these changes:

- **Art stays pixel art** (`docs/art_reference.webp`); the concept image is for features, not style.
- **No player levels / XP.** Regions unlock through Ocean Impact.
- **No gems or premium currency.** One currency: conservation funding.
- **No in-game donate button.** A "Real Impact" page with links for parents instead.
- **Rescue & care:** care meters (health, hunger, injury, happiness) are fine, but animals only get better — they never die or decline.
- **Avatar creator:** skin tone, face, hair style & colour, eye colour, outfit, gear, accessories.

## Home base, automation & caring for animals (owner's direction, Sep 2026)

### Home base grows from a tent
- You start with a **tent** that you **place wherever you like** on the island.
- Collected materials + **funding** (visitor donations, grants) upgrade it: tent → **house**, then a **dock** for boats.
- **All buildings are placed by the player** in valid spots (e.g. the sanctuary on any beach) — no fixed build sites.
- **Sleep:** interact with your tent/house at night to sleep until morning (Minecraft-style).
- **Menu bar:** a **Build** menu (what you can build now, and what unlocks later), a **Journal** collecting every animal you've discovered and what you've learned about it, and **Change look**.

### Automating the cleanup
- Litter keeps **washing in** over time, so cleaning is ongoing.
- **Patrol boats** (built at the dock): you draw/choose an **area**; the boat patrols it and collects any litter that appears there.
- Later: **net boats** — two boats with a net between them sweeping back and forth.
- Goal per island: automate its cleanup "to a certain degree" → then set out to the next region.

### Regions, each with its own mechanic
Discovered warmer (**Mangrove Coast** → **Tropical Reef**, save the fish) or colder (**Kelp Forest** → **Deep Sea** → **Polar Ocean**) — see "World map". Each region has different ways of saving that area.

### Sanctuaries are places, not props
- The turtle sanctuary is **not** a turtle spawner. The **existing turtle comes to the protected beach and lays eggs**; the eggs hatch and hatchlings reach the sea → more turtles.
- Later you can **go inside sanctuaries** for mini-games, e.g. caring for and **rehabilitating** injured sea turtles, then releasing them.

### Interacting with wild animals — kindly
- Animals shouldn't simply flee. Approaching **slowly and calmly** keeps them relaxed (and curious ones come closer); rushing at them makes them swim off.
- Kind interactions: **observe** quietly (fills in Journal details), **photograph** them (research funding), and **help** when needed — e.g. **free a turtle tangled** in fishing line, or bring an injured one to the sanctuary.
- Never touching, chasing, riding or feeding wild animals — which also teaches the real-world rule: *watch wildlife from a respectful distance and let trained rescuers handle injured animals.*

## Ultimate goal

Not "complete all missions" but **🌊 Make the Ocean Thrive.** Start: "There's a lot of work to do." End: "Look at what you've helped create." The player can continue indefinitely.

## First 30 minutes

- **0–5 min:** Arrive on the island. Meet the old conservation ranger: "The ocean around this island used to be full of life." Receive 🛶 boat, 🧹 cleanup tool, 🏚️ shack.
- **5–10 min:** Find plastic floating near the island. Collect it. A turtle appears — discover 🐢 Sea Turtle.
- **10–15 min:** Discover a nesting beach. Clean it. Build a small turtle protection area.
- **15–20 min:** First turtle hatchlings reach the ocean. First major emotional reward.
- **20–30 min:** First visitors arrive. Earn 💰 conservation funding. Choose 🪸 Coral Nursery or 🌱 Mangrove Nursery — the game opens up.

## Long-term loop

```
🌊 EXPLORE → 🔎 DISCOVER → 🧹 HELP → 🌱 RESTORE → 🐢 ANIMALS → 🏝️ SANCTUARY
→ 👨‍👩‍👧 VISITORS → 💰 FUNDING → 🏗️ EXPAND → 🌍 NEW REGION → 🌊 EXPLORE …
```

## Chapters

1. **My Island** — learn the basics. One island, turtles, coral, cleanup.
2. **My Ocean** — manage multiple ecosystems. Open ocean, mangroves, kelp, whales, dolphins, sharks.
3. **Our Ocean** — the conservation network connects to other islands, shipping routes, fisheries, coastal cities, marine reserves. From "save my island" to "help protect an ocean."

## Core message

> The ocean isn't something we need to conquer. It's something we're part of — and something we can help.

## Next steps

Expand into a full GDD: final game name, player character, first island map, 20–30 animals, 10 ecosystems, building tree, currencies/resources, missions, progression levels, 50+ achievements, UI screens, tutorial, monetization approach, complete pixel-art asset list.
