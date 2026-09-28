class_name ArrivalData
extends Resource
## An animal that moves to an island once it's healthy enough (RegionData.arrivals): the
## island starts with few animals, and more arrive as it (and the wider ocean) recovers.
## Once arrived, it stays for good.

@export var species: AnimalData
## Its node name in the world (unique; the save file refers to it).
@export var node_name: String
## Where it settles (its home spot).
@export var position := Vector2.ZERO
@export var home_radius := 220.0
## Island health (0..1) needed before it arrives ...
@export var island_health := 0.0
## ... and how many other islands must be healthy (see Arrivals.HEALTHY) — the ocean
## around them recovering too.
@export var healthy_islands := 0
## Said when it arrives.
@export var note: String
