class_name Nest
extends Node2D
## Eggs buried in a protected beach. Once incubated they hatch at night; the
## hatchlings crawl to the sea and join the population (up to its maximum).

# ponytail: all species share one animal scene; give AnimalData a scene when one needs its own.
const ANIMAL_SCENE := "res://scenes/animals/animal.tscn"

@export var species: AnimalData
## GameClock.now() when it was laid.
@export var laid_at := 0.0


func _enter_tree() -> void:
	add_to_group("nests")


func _process(_delta: float) -> void:
	if GameClock.is_night() and GameClock.now() - laid_at >= species.incubation_days:
		hatch()


func hatch() -> void:
	var count := clampi(species.hatchlings, 0, species.max_population - _population())
	var world := get_parent()
	for i in count:
		var baby: Node2D = load(ANIMAL_SCENE).instantiate()
		baby.set("data", species)
		baby.set("young", true)
		baby.position = position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		world.add_child(baby)
		baby.call("crawl_to_sea")
	Journal.record_hatch(species, count)
	queue_free()


func _population() -> int:
	return get_tree().get_nodes_in_group("animals").filter(
		func(a: Node) -> bool: return a.get("data") == species).size()
