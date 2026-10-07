class_name BuildingData
extends Resource
## One kind of building. Each is a .tres file in data/buildings/ and appears in
## the Build menu (sorted by `order`).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## What it does, in one short line (the Build menu shows only the name, this and the cost).
@export var summary: String
## Only in the Build menu once this Fleet flag is set (e.g. once the research says what to build).
@export var needs_flag: StringName
## Kinds of litter (item ids) it stops at their source: no more drift in on any island.
@export var stops_litter: PackedStringArray = []
## Position in the Build menu.
@export var order := 0
## The Build menu's button for it: "Build", or "Plant" for trees.
@export var build_verb := "Build"
## Build menu tab: buildings, land (trees, sand) or sea (docks, bridges, boats).
@export var category: StringName = &"buildings"
## Null for buildings that aren't drawn yet ("coming later").
@export var texture: Texture2D
## Footprint in 32x32 tiles.
@export var size := Vector2i(2, 2)
## Ground types every footprint tile must be (tile custom data "terrain").
@export var terrain: PackedStringArray = ["sand", "grass"]
## Pieces of collected litter needed; they're recycled into building materials.
@export var cost_litter := 0
## Conservation funding needed.
@export var cost_funding := 0
## Items needed, by item id (e.g. {wood: 2}, or a sapling for a palm tree).
## Paid from what the ranger carries, then from Ranger House storage.
@export var cost_items: Dictionary[StringName, int] = {}
## How much of each storable item it can keep (0 = not a store).
@export var storage := 0
## Which items it keeps (item ids): a Ranger House keeps wood and saplings, an Exploration Ship
## everything else. What all of one kind hold is shared by every island.
@export var stores: PackedStringArray = []
## A fleet discovery that must be installed before it stores anything (the Exploration Ship's
## hold opens with the Deep Sea's Cargo Module).
@export var storage_needs: StringName = &""
## Upgrades: how many tiers it has (1 = can't be upgraded). Each tier adds 1 to what
## it does: +1 turtle (animal_capacity), +1 funding per recycled piece, or the full `storage`
## again (a Ranger House stores 10 / 20 / 30).
@export var max_tier := 1
## Its picture at each upgrade tier (tier 1 first; empty = `texture` at every tier).
@export var tier_textures: Array[Texture2D] = []
## What each upgrade costs.
@export var upgrade_funding := 0
## Litter each upgrade uses (recycling centres).
@export var upgrade_litter := 0
@export var upgrade_items: Dictionary[StringName, int] = {}
## Building id this one replaces when placed (the house replaces the tent).
@export var replaces: StringName
## Island building kind: "funding" (a funding facility: earns funding each morning from
## visitors), "signature" (the island's one special facility) or "" (shared infrastructure).
@export var facility: StringName
## Funding visitors donate each morning (0 = attracts no visitors) ...
@export var visitors := 0
## ... plus this much for each animal that nests here (or is in view: `watches`) ...
@export var visitors_per_animal := 0
## ... all times (1 + island health x this): a healthier island draws more visitors.
@export var health_bonus := 1.0
## Species visitors come to watch (counted within `watch_range`), e.g. dolphins.
@export var watches: StringName
## How far it can see them (0 = the whole island).
@export var watch_range := 480.0
## Offers "Move" (palm trees don't: cut them down and plant a sapling instead).
@export var movable := true
## Only one of these can exist (e.g. your home).
@export var unique := false
## At most one on each island (the Exploration Ship: one per island makes it Exploration Ready).
@export var one_per_island := false
## Only on this island (region id; "" = any): each island's signature facility is its own.
@export var only_on: StringName
## Only once the island's objective is done (RegionData.goals; the Exploration Ship).
@export var needs_objective := false
## Boats: at most this many on an island (its own rowboat included). Building another is always
## allowed, and one of the others (not the one the ranger is in) is let go at random, e.g. a
## rowboat left stranded far out at sea.
@export var keep_boats := 0
## Pictures by fleet equipment level (Fleet.level(): 1 = first entry); `texture` below level 1.
@export var fleet_textures: Array[Texture2D] = []
## At most this many on each island (0 = no limit); `unique` = one on each island.
@export var max_count := 0
## Rare events (storms) can't damage it (docks, boats, trees).
@export var storm_proof := false
## Nesting beaches need quiet: another building within this many tiles (not docks, not
## planted trees) makes it too busy for animals to nest here (0 = doesn't mind).
@export var needs_quiet := 0
## How many of the animals that nest here it can hold at once (0 = none).
@export var animal_capacity := 0
## The species it gives a home to (its animal_capacity is for them), e.g. "sea_otter".
## A home is a condition, not a supply: animals only settle while the ecosystem supports them.
@export var hosts: StringName
## Funding it costs to look after, every morning (0 = none). Unpaid, it isn't looked after
## that day (see Building.upkeep_paid).
@export var upkeep := 0
## Kelp beds it restores while it stands (a Kelp Restoration Site; 0 = none): the island's
## most damaged ones, wherever it's placed. Planting can't beat overgrazing: where urchins
## are too many, the kelp still declines.
@export var restores_beds := 0
## How far it reaches at each upgrade tier (e.g. a patrol boat's area: 120, 160, 200 px).
@export var range_per_tier: PackedFloat32Array = []
## What it stores of each item at each tier, if not `storage` × tier (Ranger House: 4, 8, 10).
@export var storage_per_tier: PackedInt32Array = []
## Offers "Demolish" (conservation structures that can unbalance an island), returning
## half its wood.
@export var demolishable := false
## Shown in the Build menu but can't be built yet.
@export var locked := false
## Why it's locked / what unlocks it.
@export var unlock_hint: String
## Building id that must already exist before this can be built (e.g. "dock").
@export var requires: StringName
## Added as a child when it's built or loaded (e.g. the patrol buoy's boat).
@export var spawns: PackedScene
## Draw `texture` for the placed building (false when `spawns` draws itself, e.g. a planted tree).
@export var draw_texture := true
## Not placed: choosing it in the Build menu picks up a tool instead ("shovel").
@export var tool: StringName
## Item id spare ones can be given here to a conservation project (e.g. "sapling" at the
## Research Station: coastal replanting), for a grant of the item's grant_value each.
@export var accepts: StringName
## What the project is, for the action and the grant ("coastal replanting").
@export var accepts_for: String
## Funding paid for each piece of litter recycled here (0 = not a recycling centre).
@export var recycle_value := 0
## A walkway over the water (dock planks): the ranger can walk on it, boats bump into it.
@export var deck := false
## Drawbridges: shown (and walk-through for boats) while a sailing boat is close.
@export var open_texture: Texture2D
## Water gates (action "gate"): the picture while closed (`texture` while open).
@export var closed_texture: Texture2D
## Production (Water Treatment Facility): it makes `makes` every morning (`makes_per_morning` per
## hosted animal that's well, or per level if it hosts none); it waits here (up to `stock_max`)
## until the ranger takes it. A capability (Glassworks, no `makes`): the ranger puts in
## `makes_from_count` of `makes_from` once; `make_minutes` later `made_flag` is marked for good.
@export var makes: ItemData
@export var makes_from: StringName
@export var makes_from_count := 1
@export var make_minutes := 1.0
@export var makes_per_morning := 0
@export var stock_max := 10
## Fleet flag marked the first time it makes something (e.g. glass_made).
@export var made_flag: StringName
## Once established, extra `makes_from` dropped off is turned into this much funding a piece
## (the Glassworks sells the glass from extra sand).
@export var makes_from_value := 0
## Shown when a capability is established.
@export var capability_note: String
## Signature facilities: a "how it works" card at the top of its missions screen.
@export_multiline var guide: String
## Boats keep this far out (px): patrol boats won't patrol there (Crocodile Protection Zones).
@export var keeps_boats_out := 0.0
## Only across a narrow channel: land on both sides (left and right, or above and below).
@export var needs_banks := false
## Must touch the shore or another deck, so walkways grow out from the land.
@export var connects_to_shore := false
## Must be right next to a building of this kind (the Exploration Ship moors at a dock) ...
@export var must_touch: StringName
## ... touching at least this many tiles of it.
@export var must_touch_count := 1
## Needs this many `requires` buildings on its island for each one built (extra rowboats:
## 2 dock planks each).
@export var requires_each := 0
## Where it goes, for the placement bar (e.g. "in the water, next to 2 dock planks").
@export var placement_hint: String
## What interacting with it does: "" (nothing), "sleep", "explore" (the Exploration Ship) or
## "missions" (a signature facility: send missions, see Missions).
@export var action: StringName
## Short, accurate fact shown when it's built.
@export_multiline var fact: String


## "Needs 20 funding + 5 recycled litter + 2 wood." for menus and hints.
func cost_text() -> String:
	var text := describe_cost(cost_funding, cost_litter, cost_items)
	return text + (" Upkeep: %d funding a day." % upkeep if upkeep > 0 else "")


func upgrade_cost_text() -> String:
	return describe_cost(upgrade_funding, upgrade_litter, upgrade_items)


static func describe_cost(funding: int, litter: int, items: Dictionary) -> String:
	var parts: Array[String] = []
	if funding > 0:
		parts.append("%d funding" % funding)
	if litter > 0:
		parts.append("%d recycled litter" % litter)
	for item_id in items:
		var item: ItemData = load("res://data/items/%s.tres" % item_id)
		parts.append("%d %s" % [items[item_id], item.display_name.to_lower()])
	return "Needs " + " + ".join(parts) + "." if parts else "Free to build."
