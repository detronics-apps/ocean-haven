class_name LitterSpawner
extends Node
## Litter keeps washing in: every `interval` seconds a piece of litter drifts into
## the sea around the island or washes up on a beach, until `max_litter` pieces
## are out there. It always appears away from the ranger, so it never pops up in view.

const DEBRIS_SCENE := preload("res://scenes/world/debris.tscn")

@export var interval := 20.0
@export var max_litter := 15
## Chance that a new piece floats at sea (the rest wash up on beaches).
@export var at_sea_chance := 0.75
## Area searched for spots (the waters around the home island).
@export var area := Rect2(-900, -600, 1800, 1200)
@export var min_distance_from_ranger := 320.0

var _items: Array[Resource] = DataFiles.load_all("res://data/items")
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if _time >= interval:
		_time = 0.0
		spawn_one()


## Adds one piece of litter somewhere suitable. Returns it, or null if there's
## already enough litter or no spot was found.
func spawn_one() -> Debris:
	if get_tree().get_nodes_in_group("debris").size() >= max_litter:
		return null
	var at_sea := randf() < at_sea_chance
	var ranger := ControlledBody.active(get_tree())
	var beach := [] if at_sea else _sand_spots()
	for attempt in 40:
		var spot: Vector2
		if at_sea:
			spot = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			if Terrain.at(get_tree(), spot) not in ["", "water"]:
				continue
		else:
			if beach.is_empty():
				return null
			spot = beach.pick_random()
		if ranger and spot.distance_to(ranger.global_position) < min_distance_from_ranger:
			continue
		return spawn_at(_items.pick_random(), spot, at_sea)
	return null


## Centres of every beach (sand) tile on the islands — beaches are too small a
## share of the sea to find by random guessing.
func _sand_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			if ground.get_cell_tile_data(cell).get_custom_data("terrain") == "sand":
				spots.append(ground.to_global(ground.map_to_local(cell)))
	return spots


## Adds a washed-in piece at an exact spot (also used when loading a save).
func spawn_at(item: ItemData, spot: Vector2, floating: bool) -> Debris:
	var debris: Debris = DEBRIS_SCENE.instantiate()
	debris.item = item
	debris.floating = floating
	debris.spawned = true
	debris.position = spot
	var world := get_parent()
	world.add_child(debris)
	world.move_child(debris, world.get_node("Player").get_index())  # under the ranger and boat
	return debris
