class_name Nest
extends Node2D
## Eggs buried in a protected beach. Once incubated they hatch at night and the
## hatchlings crawl to the sea. As many stay as the protected areas have room for
## (BuildingData.animal_capacity); the rest swim off into the open ocean. Every
## hatchling counts in the Journal either way.

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
	var room := capacity(get_tree(), species) - population(get_tree(), species)
	var world := get_parent()
	for i in species.hatchlings:
		var baby: Node2D = load(ANIMAL_SCENE).instantiate()
		baby.set("data", species)
		baby.set("young", true)
		baby.set("leaving", i >= room)
		baby.position = position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		world.add_child(baby)
		baby.call("crawl_to_sea")
	Journal.record_hatch(species, species.hatchlings)
	queue_free()


## How many of `species` the protected areas it nests in can hold.
static func capacity(tree: SceneTree, species: AnimalData) -> int:
	var total := 0
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.id == species.nest_building:
			total += building.data.animal_capacity
	return total


## How many of `species` live here now (not counting ones heading out to sea).
static func population(tree: SceneTree, species: AnimalData) -> int:
	return tree.get_nodes_in_group("animals").filter(
		func(a: Node) -> bool: return a.get("data") == species and not a.get("leaving")).size()
