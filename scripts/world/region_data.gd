class_name RegionData
extends Resource
## One region of the ocean (an island and its waters). Each is a .tres file in
## data/regions/ and appears on the voyage map (sorted by `order`).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var order := 0
## Middle of the region's island in the world.
@export var center := Vector2.ZERO
## How far from the middle a rowboat can go (its coastal waters).
@export var waters_radius := 1100.0
## Where the ranger steps ashore after sailing here.
@export var arrival := Vector2.ZERO
## Where the rowboat is moored on arrival.
@export var boat_mooring := Vector2.ZERO
## Building that must exist before you can sail here (e.g. "patrol_boat": automate first).
@export var requires_building: StringName
## Shown on the map but can't be visited yet.
@export var locked := false
## What unlocks it.
@export var unlock_hint: String
