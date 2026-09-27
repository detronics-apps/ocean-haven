class_name BuildingData
extends Resource
## One kind of building. Each is a .tres file in data/buildings/ and appears in
## the Build menu (sorted by `order`).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Position in the Build menu.
@export var order := 0
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
## Building id this one replaces when placed (the house replaces the tent).
@export var replaces: StringName
## Funding visitors donate each morning (0 = attracts no visitors) ...
@export var visitors := 0
## ... plus this much for each animal that nests here.
@export var visitors_per_animal := 0
## Only one of these can exist (e.g. your home).
@export var unique := false
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
## A walkway over the water (dock planks): the ranger can walk on it, boats bump into it.
@export var deck := false
## Must touch the shore or another deck, so walkways grow out from the land.
@export var connects_to_shore := false
## What interacting with it does: "" (nothing) or "sleep".
@export var action: StringName
## Short, accurate fact shown when it's built.
@export_multiline var fact: String
