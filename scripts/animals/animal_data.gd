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
