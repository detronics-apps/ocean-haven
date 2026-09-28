class_name RegionData
extends Resource
## One region of the ocean (an island and its waters). Each is a .tres file in
## data/regions/ and appears on the Map (sorted by `order`). Regions are discovered
## by exploring warmer or colder with the Exploration Ship (see Regions).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Position on the Map, and within its direction: exploring finds the lowest
## undiscovered `order` in that direction.
@export var order := 0
## "warmer" or "colder" ("" for the starting island, which is always known).
@export var direction: StringName
## What it teaches (shown on the Map).
@export var theme: String
## Middle of the region's island in the world.
@export var center := Vector2.ZERO
## How far from the middle a rowboat can go (its coastal waters).
@export var waters_radius := 1100.0
## Where the ranger steps ashore after sailing here.
@export var arrival := Vector2.ZERO
## Where the rowboat is moored on arrival.
@export var boat_mooring := Vector2.ZERO
## A little picture of the island for the Map (made by tools/generate_islands.gd).
@export var map_icon: Texture2D
## Fleet upgrade (discovery id) needed before exploring can find this island ("" = none).
@export var requires: StringName

## What makes the island healthy (IslandHealth); none = no health shown yet.
@export var health: Array[HealthFactor] = []

@export_group("Objective")
## The island's objective: done once every goal is met; then its Exploration Ship can be
## built and `discovery` is found. No goals = not made yet (no ship there yet).
@export var objective: String
@export var goals: Array[ObjectiveGoal] = []
## Discovery id found when the objective is done.
@export var discovery: StringName
## How it was found, shown when the objective is done.
@export_multiline var discovery_text: String
