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
## Each morning, litter that entangles (nets, line, bags) this close to an animal that can
## get caught may catch one: at most this many a day in this area. Clean it up to prevent it.
@export var tangle_range := 320.0
@export var tangles_per_day := 1

var _items: Array[Resource] = DataFiles.load_all("res://data/items").filter(
	func(item: ItemData) -> bool: return item.is_litter)
var _time := 0.0


func _enter_tree() -> void:
	add_to_group("litter_spawner")


func _ready() -> void:
	GameClock.new_day.connect(func(_d: int) -> void: entangle())


## Litter that entangles, left near an animal that can get caught, catches it (at most
## tangles_per_day). The litter is then round the animal: freeing it collects it. Returns
## the animals caught.
func entangle() -> Array[Animal]:
	var caught: Array[Animal] = []
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if caught.size() >= tangles_per_day:
			break
		if not debris.item.entangles or debris.is_queued_for_deletion() or not area.has_point(debris.global_position):
			continue
		var animal := _catchable_near(debris.global_position)
		if animal:
			animal.tangle(debris.item)
			debris.remove()
			caught.append(animal)
			get_tree().call_group("hud", "show_toast", "A %s is caught in a %s!\nFind it and help it (the rescue boat can find it for you)." % [
				animal.data.display_name, debris.item.display_name.to_lower()])
	return caught


func _catchable_near(point: Vector2) -> Animal:
	var best: Animal = null
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if not animal.data.can_tangle or animal.tangled or animal.young or animal.leaving:
			continue
		var distance := animal.global_position.distance_to(point)
		if distance <= tangle_range and (not best or distance < best.global_position.distance_to(point)):
			best = animal
	return best


## A random piece of litter at `spot` (e.g. dug up by a crab), unless there's
## already enough litter about. Returns it, or null.
func wash_up_at(spot: Vector2, floating: bool) -> Debris:
	if _litter_in_area() >= max_litter:
		return null
	return spawn_at(_items.pick_random(), spot, floating)


func _process(delta: float) -> void:
	_time += delta
	if _time >= interval:
		_time = 0.0
		spawn_one()


## Adds one piece of litter somewhere suitable. Returns it, or null if there's
## already enough litter or no spot was found.
func spawn_one() -> Debris:
	if _litter_in_area() >= max_litter:
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


## Litter inside this spawner's area (each island's waters have their own limit).
func _litter_in_area() -> int:
	return get_tree().get_nodes_in_group("debris").filter(
		func(d: Node2D) -> bool: return area.has_point(d.global_position)).size()


## Centres of every beach (sand) tile on the islands — beaches are too small a
## share of the sea to find by random guessing.
func _sand_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			var spot := ground.to_global(ground.map_to_local(cell))
			if area.has_point(spot) and ground.get_cell_tile_data(cell).get_custom_data("terrain") == "sand":
				spots.append(spot)
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
