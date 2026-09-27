class_name AnimalData
extends Resource
## One species. Each is a .tres file in data/animals/; adding an animal = adding a file.

@export var id: StringName
@export var display_name: String
## Top-down sprite, facing right (rotated to the swim direction).
@export var sprite: Texture2D

@export_group("Journal")
@export var habitat: String
@export var diet: String
## Short, accurate fact shown on discovery.
@export_multiline var fact: String
## Shown with the first photo of this species.
@export_multiline var photo_fact: String
## Shown after freeing one that was tangled.
@export_multiline var help_fact: String

@export_group("Behaviour")
## Ground it lives on (tile terrain; "" = open ocean). Sea animals: ["", "water"]; crabs: ["sand"].
@export var habitat_terrain: PackedStringArray = ["", "water"]
## Swimmers turn to face where they're going; crabs scuttle sideways (just flip).
@export var faces_movement := true
@export var swim_speed := 40.0
## Seconds spent resting between swims (random in this range).
@export var rest_min := 2.0
@export var rest_max := 5.0
## Swims away if the ranger comes closer than this while moving fast.
@export var shy_distance := 56.0
## Counts as discovered when the ranger comes closer than this.
@export var discover_distance := 120.0
## Ranger speeds (px/s) above this count as rushing.
@export var calm_speed := 40.0
## Seconds the ranger must stay calm nearby before it relaxes.
@export var calm_time := 1.5
## Swims a little closer to a calm ranger.
@export var curious := true
## How close the ranger must be to observe, photograph or help it.
@export var interact_distance := 80.0
## Seconds of quiet watching (while relaxed) to count as observed.
@export var observe_time := 4.0

@export_group("Nesting")
## Adults come ashore at night to lay eggs in this kind of building ("" = never nest).
@export var nest_building: StringName
## Days between nests for one animal.
@export var nest_interval_days := 2
## In-game days before eggs hatch (they hatch at night). Real green turtle eggs take about two months.
@export var incubation_days := 1.0
## Young that hatch from one nest (a game-sized stand-in for the real clutch).
@export var hatchlings := 3
@export_multiline var nest_fact: String
@export_multiline var hatch_fact: String
