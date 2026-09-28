class_name BuildingData
extends Resource
## One kind of building. Each is a .tres file in data/buildings/ and appears in
## the Build menu (sorted by `order`).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
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
## How much of each storable item (wood, sand) it can keep (0 = not a store).
@export var storage := 0
## Upgrades: how many tiers it has (1 = can't be upgraded). Each tier adds 1 to what
## it does: +1 turtle (animal_capacity), +1 storage, or +1 funding per recycled piece.
@export var max_tier := 1
## What each upgrade costs.
@export var upgrade_funding := 0
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
@export var watch_range := 480.0
## Offers "Move" (palm trees don't: cut them down and plant a sapling instead).
@export var movable := true
## Only one of these can exist (e.g. your home).
@export var unique := false
## At most one on each island (the Exploration Ship: one per island makes it Exploration Ready).
@export var one_per_island := false
## Only once the island's objective is done (RegionData.goals; the Exploration Ship).
@export var needs_objective := false
## Pictures by fleet equipment level (Fleet.level(): 1 = first entry); `texture` below level 1.
@export var fleet_textures: Array[Texture2D] = []
## At most this many can exist (0 = no limit).
@export var max_count := 0
## How many of the animals that nest here it can hold at once (0 = none).
@export var animal_capacity := 0
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
## Funding paid for each piece of litter recycled here (0 = not a recycling centre).
@export var recycle_value := 0
## A walkway over the water (dock planks): the ranger can walk on it, boats bump into it.
@export var deck := false
## Drawbridges: shown (and walk-through for boats) while a sailing boat is close.
@export var open_texture: Texture2D
## Must touch the shore or another deck, so walkways grow out from the land.
@export var connects_to_shore := false
## Must be right next to a building of this kind (the Exploration Ship moors at a dock) ...
@export var must_touch: StringName
## ... touching at least this many tiles of it.
@export var must_touch_count := 1
## Where it goes, for the placement bar (e.g. "in the water, next to 2 dock planks").
@export var placement_hint: String
## What interacting with it does: "" (nothing), "sleep" or "explore" (the Exploration Ship).
@export var action: StringName
## Short, accurate fact shown when it's built.
@export_multiline var fact: String


## "Needs 20 funding + 5 recycled litter + 2 wood." for menus and hints.
func cost_text() -> String:
	return describe_cost(cost_funding, cost_litter, cost_items)


func upgrade_cost_text() -> String:
	return describe_cost(upgrade_funding, 0, upgrade_items)


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
