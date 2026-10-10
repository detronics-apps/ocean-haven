# BlueHaven — Clue Board (the specification)

The only specification for the Clue Board (design drafts 1–8 with the owner, Oct 2026). Where the
build differs from it, this file is updated in the same commit.

**Owner's decisions (Oct 2026):** keep the Arctic shore pines (so S2.W is dropped); soften the
seed lines (done: the people's news and the Observatory say what was seen, never that the birds
carried the seed). Decisions 2–7, 9 and 11 are still open; nothing depends on them yet.

## Context

The owner wants a **clue board**: a connected map of the player's growing understanding. It runs
from an opening turtle mystery, through 7 core nodes, to the open question **"Who created all of
this?"** (wonder, never preaching: GAME_OVERVIEW §6.4). This draft replaces all earlier ones; no
superseded entries remain. Nothing is implemented until approval.

**The test for every card:** *could the player point to what they saw or did and explain why this
statement is true?*

**Branch:** the real game is `origin/main-sjr448-5saz0a` (this checkout is 140 commits behind).
All auditing was done there and all work happens there. On approval, step 0 copies this document
to `docs/CLUE_BOARD.md` as the one specification.

---

## 0. Rules

1. **Mechanics are not evidence.** Never used:
   - the litter-finding animals (dolphins, crabs, otters carrying litter ashore, seabirds and the
     skua circling, the reef shark at ghost gear);
   - parrotfish making sand / the Glassworks; clams making Clean Water; the hydrophone and camera
     helpers;
   - health %, funding, limits, the `*_balanced` / `_flowing` / `_restored` / `_mapped` flags
     (all of them mean "health ≥ 70 %"), `upstream_boost`, arrivals that wait for other islands'
     health, the health gates on rescues and sprouts, fixes working on every island.
2. **Observed, not internal.** 🔭 conditions read what is drawn on screen, recorded only while
   the ranger is on that island (islands the ranger isn't on are paused anyway).
3. **Story triggers.** People's lines and questions, or things that happen in the world; never
   thresholds or menu unlocks.
4. **Templates.** Statements are filled only from the evidence that answered them.
5. **Testimony vs observation.** People's lines can support story facts (whose net it was);
   ecological claims need observations.
6. **Action pairs.** Where a card claims "I did X → Y happened", the action and its result are
   recorded as a linked pair (the same building, pool, patch, animal or beach).
7. **The board is read-only for the game.** The ending (`final_chapter()`, the Observatory) never
   reads the board, so no ending prerequisite depends on any clue. The final card appears on
   `flag:observatory_opened`. Open cards simply stay questions.

## 1. The board

- **Spine:** 9 fixed slots ◯ → 1…7 → ★, always drawn in reading order and lit in **any** order;
  cards in clusters across the spine.
- **Threads** (drawn only when both ends are visible): *led to* (solid) · *evidence from* (dotted)
  · *planted → payoff* (gold dashed arc).
- **Reflow:** abstract `main` / `cross` coordinates. Landscape main → x (left to right); portrait
  main → y (top to bottom; 2 cards per row). Same cards, threads and states; the focused card stays
  centred when the phone turns.
- **Zoom:** fixed steps with + / − (no pinch), tap and drag. Overview (pins, coloured tokens,
  threads) → Node (card text) → Focus panel (side panel in landscape, bottom sheet in portrait:
  text, evidence, "Came from / Leads to" chips that pan the map). An optional List toggle. A Clues
  tab in the Journal; a quiet HUD note.
- **Godot:** `ClueMap` (Control, `_draw`) + `ClueDetail`; orientation = width > height.

## 2. States

hidden → **clue discovered** (pinned note) · **question visible** (cream "?" card) · **evidence
added** (a line under the card; count shown, never "still needed") · **answered** (blue statement
+ "You wondered: …") · **deeper question** (a new card on a *led to* thread) · **final** (gold,
never blue). Only forward; nothing is removed by storms. Evidence that happens before its card
activates is recorded and appears with the card. Hint-givers can mention open questions.

## 3. Model

`ClueData`: id, node, order, kind (question | clue | final), question, statement variants
(templates + their conditions), picture, `activate` (alternatives; the first wins), `evidence`
(id, when, text, `pair_key` for linked pairs), `answer_groups` (ids + how many are needed; all
groups must hold), `leads_to` / `evidence_for`, `guarantee`.

**Guarantee classes** (strict):
- **G** — certain for every player who reaches the ending;
- **RT** — G, but its timing depends on the route;
- **L** — likely: a person nudges towards it, but nothing forces it;
- **O** — optional: chance or a player choice.

Notation: `A + B` = both groups; `2 of [...]`; `…_k` = the same k throughout (pair key).
🔭 = observable; 🆕 = new flag, line or field.

---

## 4. The strings

### ◯ Opening
**O1 · Where did all the turtles go?** (L)
- Activate: `met:maya` · `met:tom` · 🆕 the ranger reaches the tangled turtle
- Evidence:
  - `caught`: the first turtle freed from the net
  - `quiet_nest`: 🔭 a nest at a protection area with no building within 2 tiles
- Answer: `caught + quiet_nest`
- Statement: *Litter can catch turtles. On quiet, protected sand, a turtle nested on our beach.*

**O2 · The net tag** (clue → question; L)
- Clue: 🆕`net_tag_found` when the first turtle is freed (new games: its net is a ghost net with a
  worn tag, a hook-shaped mark and "…OOK"; old saves: "Tom kept the tag from your first turtle's
  net").
- Question *Where is the hook-shaped place?* activates on: 🔭 the Map open with the hook-shaped
  Deep Sea greyed out · any second island found. (Since `8909dbe` the Map button only appears
  once an Exploration Ship is built, so this comes with the first exploration, not earlier.)
- Evidence:
  - `tag`: `net_tag_found` (the clue itself)
  - `hook_seen`: the hook seen on the Map (O)
  - `at_hook`: `found:deep_sea`
  - `bram_tag`: Bram's 🆕 `tag` topic, written to match his existing want ("My old crew lost
    nets out here, years ago, and we never went back for them"): "That's the Hook's mark, my old
    trawler. A storm tore that net off us out here, years ago, and we never went back for it.
    And it drifted all the way to your beach."
  - `nudge` (O): Imani's 🆕 line "That mark's old. Ask Bram: he fished here forty years."
  - Note: Bram's existing `nets` line says "a net with your boat's mark on it, you don't lose".
    The tagged net *was* lost, so this needs a one-word fix (decision 9).
- Answer: `tag + at_hook + bram_tag`
- Statement: *The tag's mark belonged to the Hook, Bram's old trawler. He lost a net in the Deep Sea years ago, and it was this net, found on our beach.*
- Leads to: S4.C

### 1 — There's more out there
**S1.1 · Is there more out there than our island?** (G)
- Activate: `asked:wreck` · `heard:wreck`
- Evidence:
  - `wreck_found`, `sonar_lifted`, `sonar_fitted` (shown, not required)
  - `island_found`: `found:kelp_forest` or `found:mangrove_coast`
- Answer: `island_found`
- Statement: *There are other islands out there. Our island isn't the whole ocean.*

### 2 — Living things depend on each other
Each specific card is activated by its island's first "it used to be…" hello.

**S2.K · Why did the kelp disappear?** (L) — all on bed set B
- Evidence:
  - `otters_few`: 🔭 ≤ 1 otter on the island at activation
  - `grazed_B`: the first urchin count (Otter Dive story play / urchin survey) **marks beds B as overgrazed**, and 🔭 B are drawn thin or bare
  - `otters_back`: 🔭 ≥ 2 otters
  - `fewer_B`: a later count **over the same beds B**, lower
  - `kelp_back_B`: 🔭 ≥ 3 of B dense
- Answer: all five
- Statement: *There were hardly any otters, and urchins had grazed these beds bare. When the otters came back, the urchins in these beds grew fewer and the kelp grew again.*
- Build check: the survey must report per bed; if it only reports island-wide, B = all beds and the statement says "the forest".
- Source for the relationship (before dialogue is written): Estes & Palmisano 1974, *Sea otters:
  their role in structuring nearshore communities*, Science 185:1058–1060
  ([USGS record](https://pubs.usgs.gov/publication/1007670)). Islands with otters had few urchins
  and healthy kelp; where otters were gone, grazing destroyed the kelp. The card states only what
  the player observed; the source makes sure that observation matches real ecology.

**S2.M · Why are Rosa's nets empty?** (L) — all on pool p
- Evidence:
  - `cut_p`: 🔭 pool p not linked to the sea, with 0 young snappers in it (recorded)
  - `linked_p`: 🔭 p linked
  - `fish_p`: 🔭 young snappers living in p afterwards
- Answer: all three, for the same p
- Statement: *This nursery pool was cut off from the sea and had no young fish. After the water flowed in again, young fish were living in it.*
- The game doesn't show snappers swimming in, so there is no movement claim.

**S2.R · Why is the reef grey?** (L) — all on patch p
- Evidence:
  - `planted_p`: coral planted on p
  - `fish_at_p`: 🔭 parrotfish at p while its coral was returning
  - `regrown_p`: 🔭 p's coral grown back
  - optional: `grazing_p` (🔭 parrotfish seen grazing at p, if drawn) + `algae_down_p` (🔭 p's seaweed drawn less afterwards)
- Answer: `planted_p + fish_at_p + regrown_p`
- Statement:
  - only with **both** `grazing_p` and `algae_down_p`: *Coral grew back on the patch I planted. Parrotfish grazed there, and the seaweed on it shrank.*
  - otherwise: *Coral grew back on the patch I planted. Parrotfish were there as the coral returned.*
- Neither version claims the fish caused the change.

**S2.P · What does a seal pup need?** (L)
- Evidence (pup k, old-ice area z):
  - `born_k_z`: 🔭 pup k born on old ice z
  - `stayed_k_z`: 🔭 k recorded on z at every check from the thaw's start to its end (tracked by node)
  - `young_ice_melts`: 🔭 seasonal ice melting in that thaw
  - `pup_moved_j` (O): 🔭 a pup j on seasonal ice moving when its ice melted
- Answer: `born_k_z + stayed_k_z + young_ice_melts`
- Statement: *A seal pup was born on old ice and stayed on it through the whole thaw, while seasonal ice melted away.* With `pup_moved_j`, add: *A pup on seasonal ice had to move when its ice melted.*
- If per-pup tracking isn't possible (build check), the answer is `born_k_z + present at the thaw's end + young_ice_melts`, and the statement is *A seal pup was born on old ice and was still there when the thaw ended. Seasonal ice melted away.*

**S2.W · How can a tree live on the ice?** (O) — **only if decision 1 swaps the Arctic tree to polar willow**
- The seed feature already exists (`de0438d`): terns bring **shore pines** to the Arctic rocks,
  and the pines get snow caps through the freeze.
- Shore pines on high-Arctic rock aren't real, so with pines this card is **dropped**. The snow
  cap is then just a visual, and the board makes no adaptation claim about it.
- With willow: evidence 🔭 `sprout` · `under_snow` · `out_again` (the same plant); statement *Polar
  willows grow only a few centimetres tall, flat to the ground. In winter they're often covered by
  snow, and they grow again when it melts.*

**S2.G · Why does a whole place change when one thing goes missing?** (L)
- Eligible examples:
  - `ex_K`: S2.K answered
  - `ex_M`: S2.M answered
  - `ex_P`: S2.P answered **and** its `pup_moved_j` recorded. The template rejects the Polar example otherwise: S2.P answered alone is never eligible.
- Answer: `2 of [ex_K, ex_M, ex_P]`
- Statement: *On the {islandA}, {clauseA}. On the {islandB}, {clauseB}. Living things depend on each other, and on the place they live.*

| Example | island | clause (what was observed; never implies the player caused the loss) |
|---|---|---|
| ex_K | Kelp Forest | "with hardly any otters, urchins had grazed the kelp bare" |
| ex_M | Mangrove Coast | "while a nursery pool was cut off from the sea, no young fish lived in it" |
| ex_P | Polar Ocean | "when seasonal ice melted, a pup living on it had to move" |

### 3 — Watch first
**S3.D · What lives in the dark?** (L)
- Activate: `met:imani`
- Evidence:
  - `mapped`: 🔭 a dark area mapped
  - `new_X`: 🆕 species X **added to the Journal for the first time** after this card appeared (the Journal records each species' first photo once: `Journal.has` turns true then). X ∈ {sperm whale, anglerfish, sixgill shark, giant squid}
- Answer: `mapped + 2 of [new_*]`
- Statement: *The dark water held animals new to my Journal: the {X1} and the {X2}. Mapping it and watching helped me find them.*
- It doesn't claim the player had never seen them, only that they were new to the Journal.

**S3.G · How can we help if we don't know what's wrong?** (L)
- Activate: the first prediction asked
- Evidence `watched_t` = the player's guess (`People.chose`, saved) + its 🔭 observed outcome:

| t | observed outcome |
|---|---|
| nest | a nest |
| kelp | S2.K's `otters_back` + `kelp_back_B` |
| pools | S2.M's `fish_p` |
| parrotfish | S2.R's `regrown_p` |
| whales | whales present in quiet water for a day |
| pups | S2.P's `born_k_z` + `stayed_k_z` |

- Shown as *"I guessed {guess}. What happened: {outcome text}."* There is **no right answer**:
  the board never judges or scores the guess.
- Answer: `2 of [watched_*]`, on 2 islands
- Statement: *Twice I made a guess, then watched. {watched1}. {watched2}. Watching showed me what really happens.*

### 4 — Stop it where it starts
**S4.A · Where does the litter come from?** (G)
- Activate: any source question asked · `heard:litter`
- Evidence (Trace reports): `src_rings` · `src_bags` · `src_foam` · `src_gear` · `src_fibres`.
  Each is recorded when its Investigate mission sets its flag (`trace_rings` → `rings_traced`,
  `trace_bags` → `bags_traced`, `trace_foam` → `foam_traced`, `trace_gear` → `gear_traced` (new
  since `2d8b8a4`), `study_fibres` → `fibres_traced`). The phrase is taken from that mission's report.
- Answer: `2 of [src_*]`
- **Why G:** `final_chapter()` requires `stopped:` for bags, rings, foam boxes, ghost nets and
  microfibres. Each fix building has `needs_flag` = its `*_traced` flag, which only its report
  sets (the Net Return Point needs `gear_traced`). So every player who reaches the ending has all
  five reports.
- Statement: *Litter doesn't come from nowhere: {src1}, and {src2}.*

| Source | phrase |
|---|---|
| rings | "the plastic rings came from the harbour cafe's cans" |
| bags | "the plastic bags came from the fish market" |
| foam | "the foam boxes came from fishing boats that used them once" |
| gear | "the lost nets and line came from fishing boats: none of it marked, and nowhere to take old nets" |
| fibres | "the tiny threads came off clothes in the wash and went down the drain to the sea" |

(The fibres phrase is narrowed to the report: it says nothing about "far away".)

**S4.B · If we stop it where it starts, does it stop coming?** (L)
- X ∈ {rings, bags, foam, nets}:
  - **nets are now included**: since `2d8b8a4` they have a traced source ("unmarked, and nowhere
    to take old nets") and a fix that addresses it (the Net Return Point takes old nets and marks
    new ones). X = nets covers `ghost_net` + `fishing_line`, both stopped by it;
  - **bottles are excluded** (no source is traced; the fix is a general alternative);
  - **fibres are excluded** (they can't be picked up).
- **Verified in the data:** each fix is `only_on` its source's island and `needs_flag` that
  source's trace:
  - Refill Bar: Kelp Forest + `rings_traced`;
  - Weaving Workshop: Mangrove Coast + `bags_traced`;
  - Box Return Depot: Starting Island + `foam_traced`;
  - Net Return Point: Deep Sea + `gear_traced`.

  So `stopped:X` means the traced source was addressed where it starts.
- Evidence, per X, on island I and beach area b on I:
  - `traced_X`: `src_X`
  - `cleared_X_b`: 🔭 b cleared of X (none left there)
  - `reappeared_X_b`: 🔭 new X washed up in b after that, **before** the fix
  - `fixed_X`: `stopped:X`
  - `seen_X_b`: 🆕 3 mornings on I after the fix with no new X in b, while other litter still washed up in b
- Answer: `1 of { X, b : traced_X + cleared_X_b + reappeared_X_b + fixed_X + seen_X_b }` (the same X, I and b; the order is enforced: cleared → reappeared → fixed → seen)
- The player has observed the full sequence: clean up → more of the same kind arrives → the source
  is fixed → that kind stops while other litter still comes.
- Statement: *I kept picking up {kind} on the {I}, and more kept coming. Then {source} changed: {fix}. After that, no new {kind} washed up there, though other litter still did. Stopping it where it started did what cleaning up couldn't.*

| X | source | fix |
|---|---|---|
| rings | the harbour cafe | "it serves drinks from kegs now" |
| bags | the fish market | "it sends fish home in woven baskets now" |
| foam | the fishing boats | "they use boxes that come back now" |
| nets | the fishing boats | "old nets go to the Net Return Point now, and new ones carry their boat's mark" |

**S4.C · Can we tell where a lost net came from?** (L)
- Activate: O2 answered · `asked:gear` (Imani's question, now the start of the gear story)
- Evidence:
  - `traced`: O2 answered
  - `unmarked`: `thanked:gear` — the three deep pieces brought up, "not one with a name or a mark
    on it" (Imani, after the player's own recovery)
  - `netpoint`: the Net Return Point built (`stopped:ghost_net`)
- Answer: all three
- Statement: *Bram's net could be traced back to his boat because it carried a mark. The nets I brought up from the deep had none. Now new nets get their boat's mark, and old ones go to the Net Return Point.*
- No claim that lost nets are recovered.

**S4.D · How did plastic get into the polar ice?** (RT)
- Activate: `asked:fibres_asked` (Sanna's objective topic after the Ice Core: required)
- Evidence: `report` (the "Look at the fibres" report: required) · `filter` (`stopped:microfibres`: required)
- Answer: both
- Statement: *Tiny plastic threads come off clothes in the wash, go down the drain and out to sea, and the freezing sea ice trapped them here. A filter in the washing machine can catch some of them first.*
- The report (`study_fibres.tres`) says exactly this chain; it doesn't establish a distance, so none is claimed.

### 5 — What we do matters
**S5.A · Can helping go wrong?** (O) — action pairs
- Answer: `1 of { busy_k + nested_k, boats_k + settled_k, noise_k + stayed_k, bait_k + drifted_k }`
- Statement: *Something I built or did to help disturbed wildlife: {cause}. When I changed it, {recovery}.*

| Pair | cause (the player's) | recovery (observed after the change) |
|---|---|---|
| busy (area k) | "my {building} right beside the turtle area" | "a turtle nested there once the sand beside it was quiet" |
| boats (island k) | "my patrol boats crowded the {animal}s' water" | "no more were hurt once there were fewer boats" |
| noise (dive k) | "when I sent the submarine down, its noise drove a whale away" | "once the dive was over and the water was quiet, whales stayed" |
| bait (camera k) | "the bait at my camera drew in too many sharks" | "they drifted off once the bait was gone" |

- **The noise pair, exactly** (`deep_ecosystem.gd`). A submarine dive (`dive_noise` 1.5 for a
  day) is the identifiable action. It counts only if:
  1. at launch, `quiet() ≥ whale_quiet` and ≥ 1 whale was there (whales were staying);
  2. 🔭 a whale left during that dive's noisy day (`noise_k`);
  3. then, after the noise ended, whales were present with `quiet() ≥ whale_quiet` (`stayed_k`).

  Other noise (lamps, buoys, patrol boats) never counts as `noise_k`. If the record can't be made,
  the noise example is removed. The real-world concern (sperm whales avoid sonar, Curé 2016) is
  context only; the card states only the in-game sequence the player saw.

**S5.G · Does what I do change what happens?** (L) — linked pairs only

| Good: action_k → result_k | Bad: action_k → result_k |
|---|---|
| `g_area`: the player built (or cleared the buildings around) turtle area k → a nest at k afterwards | `b_litter`: litter piece k left near an animal for a morning → that animal caught in k |
| `g_channel`: the player's dig or gate links pool p → young snappers in p afterwards | `b_palm`: the player cut palm k with a nest → its booby left |
| `g_coral`: the player planted patch p → p regrew | `b_help`: any S5.A cause |

- Answer: `1 of [g_*] + 1 of [b_*]`
- Statement: *When I {good action}, {good result}. When I {bad action}, {bad result}. What I do changes what happens.*

### 6 — One ocean
**Recognitions** (pinned clues; each records visitor, origin, place):

| Recognition | Visitor | Origin (how it's known) | Phrase |
|---|---|---|---|
| **R-name** (O) | {name}, a released rescue, seen away from home | its TagBand | "{name}, the {species} I rescued on the {home}, turned up at the {place}" |
| **R-tern** (L) | Arctic terns on another island in the freeze | only after `journal:arctic_tern` was taken on the Polar Ocean, while the Polar terns are away | "Arctic terns, like those that nest on the Polar Ocean, rested at the {place} while the Polar terns were away" |
| **R-visitor** (L) | the first visitor of a travelling species on an island (`Travellers.visit`, since `bd1cbec` / `de0438d`): bottlenose dolphins and green turtles (from the Starting Island), sperm whales (from the Deep Sea), red-footed boobies (Starting Island → Reef) | the game names it on arrival ("{species} visiting from the {home}") and the island's people say so (`travel_news`). The origin is part of the world's story, like a person's testimony; one recognition per species | "{species} from the {home} visited the {place}" |

The draft 7 **R-booby (leg band) is replaced by R-visitor**, because the game now shows each
visitor's origin itself; decision 8 (bands) is dropped. Dolphins spread from the Starting Island
one island every 8 days once they live there, so R-visitor is likely early in every order.

**S6.N · Will I see {name} again?** (O) — activated at release; answered by any re-sighting. Only about the animal.

**S6.T · Can animals travel between islands?** (O)
- Activate: the first recognition · `heard:terns`
- Answer: `2 of [R-name, R-tern, R-visitor_*]` (two different species)
- Statement: *Animals travel between islands, like I do: {phrase1}; {phrase2}. Animals from other islands can use an island I look after.*
- Every recognition is, by definition, seen away from its origin, on one of the ranger's islands.

**S6.S · How did a tree start growing here?** (O) — rewritten for the existing seed feature (`de0438d`)
- **The game's mechanic:**
  - Reef: once the Starting Island is ≥ 70 %, visiting boobies make palms sprout there (up to 6).
  - Polar Ocean: terns back from a healthy Deep Sea make shore pines sprout.
  - The people's news says the birds "must have brought the seed".
- **The draft 7 coconut chain is dropped:** there are no coconuts in the game.
- **Rule 0 applies:** the board never claims the birds carried the seed. Seabirds don't spread
  palm or pine seeds, so that claim would be an invented mechanic presented as fact. The card
  states only the sequence the player saw.
- Evidence (per receiving island I = the Reef or the Polar Ocean, tree t):
  - `no_trees_I`: 🔭 no trees on I when the ranger first arrived (both islands start treeless)
  - `birds_I`: the birds seen on I first (Reef: R-visitor boobies; Polar: terns back in the thaw)
  - `sprout_t`: 🔭 tree t sprouted on I after that
  - `grown_t` (optional): t full-grown
- Answer: `no_trees_I + birds_I + sprout_t`, all on the same island, in that order
- Statement:
  - Reef: *The Reef had no trees. After boobies from the Starting Island began visiting, a little palm came up: the Reef's first tree.*
  - Polar: *The Polar Ocean had no trees. After the terns came back from the Deep Sea, a little pine came up among the rocks.*
- It says "after", never "because": the order is observed, the cause isn't. The seed claim in the
  people's lines and the Observatory is decision 10.

**S6.G · Does what happens on one island reach another?** (L)
- Activate (first wins, once): O2 answered · S4.D's `report` recorded · the first recognition (R-name / R-tern / R-visitor)
- Evidence:
  - `net`: O2 answered (the tag + Bram's testimony that it was lost in the Deep Sea + the turtle on our beach)
  - `threads`: S4.D's `report` (wash → drain → sea → trapped in the polar ice)
  - `animals`: S6.T answered, or R-tern
- Answer: all three
- Statement: *It's all one ocean. A net lost in the Deep Sea ended up on our beach; threads from washing clothes went out to sea and were trapped in the polar ice; and animals travel between islands.*
- Each clause is exactly what its evidence establishes; "far" isn't claimed for the threads.

### 7 — We're part of it
**S7.R · What happens when something big undoes my work?** (O)
- Activate: the first warning of any rare event · Answer: `damaged_e + (repaired_e) + recovered_e`
- Statements (only visible outcomes):

| Event | Statement | Short form (for S7.G) |
|---|---|---|
The statements are rewritten from the rebuilt storms (`95a2c7e`). Every event now leaves
visible aftermath to act on: damaged buildings show a warning sign and offer only Fix (20 funding
+ 1 wood); 20–35 litter washes up on any ground (none for the oil spill); each event's own damage
is in its `aftermath` text. Each clause needs its own 🔭 evidence; a clause whose evidence is
missing (e.g. no building damaged) is left out.

| Event | Statement (clauses as observed) | Short form (for S7.G) |
|---|---|---|
| Coastal Storm | *The storm damaged {n} building(s) and washed litter ashore. I fixed them and cleared the litter.* | "the storm damaged my buildings, and I fixed them" |
| Heavy Swell | *The swell tore up kelp{, damaged {n} building(s)} and washed litter round. {I fixed what broke, and} the torn beds grew dense again.* | "the swell tore up the kelp, and it grew back" |
| Flash Flood | *The flood silted the channels and cut pools off{, and damaged {n} building(s)}. I dug them out, and the pools joined the sea again.* | "the flood cut the pools off, and I dug them out" |
| Hurricane | *The hurricane broke coral{, damaged {n} building(s)} and washed litter up. {I fixed what broke, and} the broken patches grew back.* | "the hurricane broke the coral, and it grew back" |
| Oil Spill | *Oil came up in the deep. We traced it, contained it, and I cleaned up the oil I could see.* | "oil came up, and we contained it and cleaned up what we could see" |
| Ice Breakup | *A big piece of ice broke away. I moved what had gone into the water onto solid ice, and in the next freeze the ice froze back over.* (as drawn) | "the ice broke up, and it froze back over in the next freeze" |

- Guarantee: still **O**. An island's first warning comes only 15–25 days after the ranger first
  got there, and only on a morning the ranger is on it (certain once overdue). A player who never
  spends such a morning on an island can miss every event. If it strikes while the ranger is away,
  they still come back to its aftermath, so S7.R activates on the warning **or** on the first sight
  of the aftermath.
- `prepared_e` is unchanged: "Secure" still exists (`Building.secured`), so the storm and
  hurricane contrast holds.

- `prepared_e` adds *What I got ready came through better* only with a contrast in the same event:
  secured undamaged + unsecured damaged (storm, hurricane), or pools behind set gates still linked
  while others silted (flood).

**S7.G · What do we do when things go wrong?** (L)
- `G1 = litter_back_b + cleaned_again_b` (the same beach area b, cleared to none → new litter → cleared again)
- `G2 = caught_again_a + freed_again_a` (the same animal a)
- `G3 = S7.R answered`
- Answer: `1 of [G1, G2, G3]`
- Statement:
  - G1: *Setbacks happen: litter washed back onto the {beach} after I'd cleaned it, so I cleaned it again. I kept going.*
  - G2: *Setbacks happen: the {animal} I'd freed got caught again, so I freed it again. I kept going.*
  - G3: *Setbacks happen: {S7.R short form}. I kept going.*
- **Likely, not guaranteed:** G1 needs the player to clear an area completely before new litter
  arrives, and after all six fixes some kinds stop. No route is certain.

**S7.Me · What is my part in all this?** (L)
- Activate: the fix thanks lines (Finn, Maya, Sanna) · Answer: `S4.B + S5.G + S7.G`
- Statement: *I'm part of this ocean too. What I choose can help it come back.*

### ★ Final
**F · Who created all of this?** (G) — on `flag:observatory_opened`, after the motto. It is never
answered and never blue; faint threads run to every lit pin.

---

## 5. Guarantees (one table; no other section restates them)

| Class | Strings |
|---|---|
| **G** | S1.1, S4.A, F |
| **RT** | S4.D (asked, reported and fixed are all ending prerequisites; colder-first completes it 6th) |
| **L** | O1, O2, S2.K, S2.M, S2.R, S2.P, S2.G, S3.D, S3.G, S4.B, S4.C, S5.G, S6.G, S6.T, S7.G, S7.Me |
| **O** | S2.W (only with willow), S5.A, S6.N, S6.S, S7.R |

- S6.T moves from O to L: travelling dolphins, turtles and whales spread by themselves along the
  chain, and only one more kind is needed.

- S2.M and S2.R are L, not RT: the island objective needs health, not that specific pool or
  patch pair.
- No ending prerequisite depends on any clue (rule 7).

## 6. Exploration orders

| Order | Notes |
|---|---|
| Colder first (S, K, D, P, M, R) | S2.G: K + P(`pup_moved`), else waits for M · O2 at the 3rd island · S4.A from rings + foam/fibres · S4.D completes 6th · R-visitor (dolphins) from the 2nd island, R-tern from the 4th, so S6.T can answer before the warmer islands · S6.S Polar pine before the Reef palm · S4.B nets possible from the 3rd |
| Warmer first (S, M, R, K, D, P) | S2.G: M + K (5th) or M + P · O2 waits until the 5th · S4.A from bags + foam · S4.D right after the Ice Core |
| Alternating (S, K, M, D, R, P) | S2.G: K + M from the 3rd · otherwise as above |

Warmer first: R-visitor (dolphins / turtles at the Mangrove Coast) early; S6.S Reef palm needs the
Starting Island ≥ 70 %; the Polar pine comes last. Alternating: both S6.S cards are possible
mid-game.

Evidence before activation is kept (the birds seen on an island before any sprout; the wreck found
before Maya asks; a pool's "0 fish" recorded when its card activates, or at the first moment the
ranger sees it cut off, whichever is first). No string depends on one route.

## 7. Observable conditions (🔭) — all drawn on screen

- Kelp: otter counts · bed density · urchin counts (reports the player reads).
- Mangrove: pools linked / unlinked · snappers in a pool.
- Reef: patch coral · parrotfish at a patch · patch seaweed (if drawn).
- Polar: pups on old ice · ice melting / forming · willow sprouts and snow.
- Deep Sea: photographed deep species · the hook on the Map.
- Starting Island: nests and the buildings near them · tags and bands.
- World: trees on an island (none → a sprout → grown) · visiting birds · storm damage · beds, pools, patches, oil and ice
  after events · litter on a beach area.

None is a renamed health flag. **Build step 1 confirms:**
1. whether parrotfish grazing and patch seaweed are drawn (else S2.R always uses its second
   statement);
2. whether a pup moving off melting ice is visible (else `pup_moved` is dropped, and with it ex_P);
3. whether a pup can be tracked through a thaw (else S2.P uses its narrow statement);
4. whether the urchin count is per bed (else B = the whole forest);
5. ~~booby band~~ (not needed: R-visitor);
6. whether the dive → whale-left → whales-stayed sequence can be recorded (else the noise pair is
   dropped).

## 8. The seed feature — already built (`de0438d`); nothing to build here

| Element | In the game now | Board may say |
|---|---|---|
| Boobies visit the Reef | travellers from the Starting Island (`travel_home` → `tropical_reef`) | R-visitor |
| Reef palms | sprout while boobies are there and the Starting Island is ≥ 70 % (up to 6; `palm_tree`, cuttable) | S6.S, sequence only |
| Arctic shore pines | sprout while terns are back and the Deep Sea is ≥ 70 % (`shore_pine`) | S6.S, sequence only (S2.W only with willow) |
| Snow caps | build up through the freeze, gone by open water (`PolarEcosystem.snow_cover`) | nothing with pines |

**Ripple to flag (not a board change):** `shore_pine.tres` gives 2–3 wood when cut, so
seed-sprouted pines on the Polar Ocean may undo MASTER_PLAN's "Polar: no trees, bring wood with
you". Decision 11.

The build step "6. Seeds" is removed from §10.

## 9. Facts and decisions

**Sources checked:**
- Sperm whales avoid sonar and interrupt feeding
  ([Curé 2016](https://research-repository.st-andrews.ac.uk/handle/10023/9758)).
- Plastic fibres in Arctic ice ([URI](https://plastics.uri.edu/?p=442),
  [AWI](https://openpolar.no/Record/ftawi:oai:epic.awi.de:41047)).
- Laundry filters catch about 35–80 %
  ([PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7304565/),
  [Plymouth](https://www.sciencefocus.com/news/microplastics-laundry-filters-dramatically-reduce-fibres)).
- Tern stopovers are at sea ([Egevang 2010](https://pmc.ncbi.nlm.nih.gov/articles/PMC2836663/)).
- Coconuts stay viable for about 3–4 months afloat
  ([NZPCN](https://btsnew.nzpcn.org.nz/site/assets/files/22807/abj58_1_2003-80-83-coconut.pdf)).
  No longer used (the game has no coconuts); kept for decision 10's wording.
- The polar willow is a prostrate dwarf shrub, often snow-covered in leaf
  ([theferns](https://temperate.theferns.info/plant/Salix+polaris),
  [Bjerke 2018](https://brage.nina.no/nina-xmlui/handle/11250/2580534)).
- Otters → urchins → kelp: [Estes & Palmisano 1974](https://pubs.usgs.gov/publication/1007670).
- Still to cite before any text is written (well established): mangrove
  nurseries; parrotfish grazing; ringed seal pups on stable ice; boobies nest in trees; disturbance
  and turtle nesting; ghost nets drifting; FAO gear marking.

**Owner decisions:**
1. Arctic seed tree: keep the built **shore pines** (S2.W dropped) or swap that one data link to a
   **polar willow** (real; S2.W kept; the snow caps work the same).
2. Reword Sanna's "caught in every wash" (e.g. "Filters catch a lot of the fibres, wash after wash").
3. Reword or drop the Observatory's kelp link.
4. Accept the game's terns resting on islands as a simplification.
5. Kai's parrotfish-sand outcome stays in the Journal only.
6. Kai's filter-law line still needs verifying.
7. Bram's `tag` topic and Imani's nudge (wording in O2).
8. ~~Leg bands for boobies~~ — no longer needed (R-visitor; the game shows each visitor's origin).
9. Bram's existing `nets` line: "a net with your boat's mark on it, you don't **lose**" →
   "…you don't **dump**", so it doesn't contradict the tagged net his crew lost in a storm.
   Marking really does discourage dumping.
10. The seed claim outside the board: the people's news ("The boobies … must have brought the
    seed"; "the terns … brought a seed back") and the Observatory link ("Boobies carried seeds from
    the Starting Island") present bird-carried palm and pine seeds as fact. Keep them as game
    fiction, or soften them ("I wonder where it came from?"). The board itself stays neutral
    either way.
11. Polar shore pines give wood when cut (see §8): intended, or make the seed-sprouted ones uncuttable?

## 10. Build steps after approval (each one playable, tested, committed)

0. `git switch main-sjr448-5saz0a`; copy this document to `docs/CLUE_BOARD.md` (the only spec;
   nothing superseded); add rule 0 to `docs/ISLAND_RULES.md` §9 and a Milestones entry to
   `CLAUDE.md`.
1. Conditions: a shared static `People.check` (`@island`, any island) + the 🔭 conditions; resolve
   the 4 confirmations in §7.
2. `ClueData` / `ClueEvidence` (`pair_key`) / `EvidenceGroup` + the `Clues` autoload (first wins;
   evidence kept before activation; templates; answers stick) + `data/clues/*.tres` + saving
   (`tests/test_save.gd`). `tests/test_clue_board.gd`:
   - first trigger wins; idempotent; evidence before activation;
   - pairs must share a key; specific never answers general;
   - a template fills only from evidence; no blue card without its evidence;
   - S4.A / S4.B data check: each report phrase matches its mission's `report` text; a trace, its
     cleared / reappeared / fixed / seen observations all use the same litter id, island and area
     (a mismatch never answers);
   - the 3 orders; an old save.
3. The 🆕 flags and the action-pair recording at their event sites.
4. `ClueMap` + `ClueDetail` + the tab + the HUD note; reflow; zoom steps.
5. The net tag + its lines.
6. (Seeds already exist: only decision 1's data swap, if chosen.)
7. The final card, placed after the motto in the Observatory's "What we hope you have learned"
   section (rewritten in `387dd1b` / `bdc68cc`); publish once 1–7 have landed.

**Verification:** every test headless
(`godot --headless --path . --script res://tests/<name>.gd --quit-after 200000`). In the web
preview, check desktop, 375×812 and 812×375 (same cards and threads; focus kept on rotate). Play a
new game to the first quiet nest (O1 blue, O2 pinned). Load a far-along save (fills in, no
duplicates, no blue card without its evidence).

---

## As built (Oct 2026)

**Code:** `scripts/systems/clue_data.gd` (ClueData), `scripts/systems/clues.gd` (the `Clues`
autoload: checks every 2 s, watches the world, saved as `"clues"` with its `_memo`),
`scripts/ui/clue_map.gd` (ClueMap, the Journal's Clues tab), cards in `data/clues/` (30).
Tests: `test_clue_board`, `test_clue_map`, `test_net_tag`, `test_clue_ocean`, `test_clue_islands`,
`test_clue_setbacks` (plus a check in `test_save`).

**Card ids:** o1_turtles, o2_net_tag · s1_beyond · s2k_kelp, s2m_pools, s2r_reef, s2p_pups,
s2g_balance · s3d_deep, s3g_watch · s4a_sources, s4b_prevent, s4c_nets, s4d_fibres ·
s5a_too_much, s5g_choices · s6t_travel, s6g_ocean, s6s_reef, s6s_polar, s6n_<rescue> (6) ·
s7r_events, s7g_keep_going, s7me_part · final_who.

**Build checks (§7), as resolved:**
1. Parrotfish grazing and patch seaweed aren't drawn → S2.R uses its second statement ("Parrotfish
   were there as the coral returned"). A patch counts only if the ranger planted it (Fleet flag
   `coral_planted_<patch>`, set by ReefPatch.plant).
2. A pup moving off melting ice isn't tracked → `pup_moved` and the Polar example in S2.G are dropped.
3. Pups aren't tracked one by one → S2.P uses its narrow statement (born on old ice, still there
   when the thaw ended).
4. The urchin count isn't per bed → S2.K is about the whole forest ("grazed the forest bare").
5. Booby bands: not needed (R-visitor).
6. The dive → whale left → whales stayed sequence is recorded (Clues._watch_deep).

**Other choices made while building:**
- S4.B's "area" is the island's rowboat reach. Only litter that drifts in counts (LitterSpawner's
  drift): a storm or a dig can still bring up an old piece of a stopped kind.
- O1 opens on meeting Maya or Tom, or freeing the first turtle (no "saw it tangled" flag).
- S4.C opens on O2 answered, or hearing about the lost gear (`heard:gear`).
- S5.A "boats" recovers once the patrol boats leave the island's water ≥ 65 % free
  (`PatrolBoat.free_water_share`, LitterSpawner.min_free_water) with no hits for 3 mornings.
- S7.R's recovery, per event, as seen:
  - storm: buildings fixed, litter in reach ≤ 3;
  - swell: as many dense beds as before the warning;
  - flood: as many linked pools as before;
  - hurricane: the reef's coral back to 95 % of before;
  - oil: no oil patches left;
  - ice breakup: frozen again.
- The game tells the board through the group `clue_watchers` (litter_washed_in, animal_caught,
  animal_freed, patrol_hit, bird_left) and through RareEvents' and Missions' signals.
- Conditions the board adds to People's: clue:, open:, guessed:, visited:, sprouted:, released:,
  rescue_here:, rescue_away:, visitor_here:, no_trees:, memo:, prevented:, kept_coming:, and the
  island observations kelp_overgrazed(_max):N, kelp_dense:N, pools_linked(_max):N, reef_regrown,
  pup_old_ice, polar_phase:X, deep_mapped:N. People gained `helped:species`.

**Look (owner's picture, Oct 2026):** a cork pin board in a wooden frame, a "BLUEHAVEN — CLUE BOARD"
title plank and a "CLUES JOURNAL" plank. Notes are paper, tilted a little, with a brass pin each:
cream = a question (in capitals), blue = answered, tan = a field note (a planted clue), ochre = the
final question. The node titles are tan paper tags. Red string runs pin to pin, sagging a little,
over the notes. Zoom buttons are bottom right. The details panel is a sheet of paper.

**Layout (owner's sections, Oct 2026; replaces the 7-node spine of §1):** the notes, triggers and
evidence above are unchanged; each note sits in one of the owner's sections (ClueData.section):
People (story threads that start or end with a person), Trash, Animals, Places, Storms, Plants,
Land & Water, Disturbance and Better ways. The sections sit round the globe ("It's all connected",
the loading screen's globe, big, in the middle, over the string; `tools/make_globe.py`), Animals at
the top, so the turtle's question (ClueData.big: a bigger note and turtle) starts the board. A
section shows only once it holds a note (no placeholders). "Who created all of this?" hangs off the
globe on one string, from when the end credits start (Fleet flag "credits_rolled").

| Section | Notes |
|---|---|
| People | S3.G guesses · S7.Me my part |
| Trash | O2 net tag · S4.A sources · S4.D fibres |
| Animals | O1 turtles · S2.R reef · S2.G one thing missing · S3.D the dark · S6.T travel · S6.N seen again (6 cards, one note) |
| Places | S1.1 more out there · S6.G one ocean |
| Storms | S7.R big events · S7.G setbacks |
| Plants | S2.K kelp · S6.S new trees (2 cards, one note) |
| Land & Water | S2.M pools · S2.P pups |
| Disturbance | S5.A helping harms · S5.G choices |
| Better ways | S4.B stop it · S4.C marked nets |

**Each section is a cluster:** a bigger heading with its notes round it, in a grid of spots
around the heading (the spot facing away from the globe first, then beside, the side facing the
globe last). The circle is as small as it can be with clear cork (90 px) between sections.

**Strings:** a note's links (ClueData.links) to the other sections its story touches. Zoomed right
out, one string per two sections with anything in common (tag to tag); closer in, each note's own
strings. Every section is strung to the globe. All strings are the same red, 3.5 px on screen at
every zoom. A "Strings: simple / detailed" button (by the zoom buttons; kept while the game runs)
chooses: simple shows only the section-to-section strings at every zoom; detailed shows each note's
own strings once zoomed in. The string is solid only zoomed right out; closer in it fades (40 %
down to 18 % at the closest step) so the words on the notes read through it.

**Notes say little:** a short question (ClueData.title) and a short answer (ClueData.short); the
full sentences are in the details on a tap. Pictures say the rest: one card per thing seen
(ClueData.evidence_pictures: evidence id -> the game's own picture), fanned like a hand of cards,
growing as the ranger finds more. Notes in one group (ClueData.group: "trees", "seen_again") show
as one note. The net-tag note is a luggage tag with the hook island on it.

**Zoom:** "everything fits", then steps of about 1.5x up to 1.15x (no big jump).

**Showing the board at the start:** after the first talk with Tom the Journal opens on the Clue
Board (once; Fleet flag "clue_board_shown"). When the first turtle is freed (the tag: O2's
`opens_board`) it opens again, with a note pinned at the top: "As you go on with your journey, you
can always find the clues here. The Clue Board won't open by itself again." (If the turtle came
first, Tom's opening is skipped.) The big turtle note and the globe keep their words even zoomed
right out. Tapping a note shows one short sentence (the question, or the answer once it's blue)
and what was seen, nothing said twice. The tag's picture is the hook island's black logo
(`tools/make_hook_logo.gd`). Maya's first question asks for photos of the animals (one photo).

**Not built yet:** the optional List toggle (§1).
