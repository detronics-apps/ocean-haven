class_name Arrivals
## Animals arriving as islands recover (RegionData.arrivals): checked every few seconds by
## the world; each arrives once and stays. Saved by SaveGame (the names that have arrived).

## An island counts as healthy for other islands' arrivals at this health.
const HEALTHY := 0.7
const ANIMAL_SCENE := preload("res://scenes/animals/animal.tscn")

## Node names of the animals that have arrived.
static var _arrived := {}


## Brings in every animal whose island (and ocean) is now healthy enough. Returns them.
static func check(world: Node) -> Array[Node2D]:
	var tree := world.get_tree()
	var came: Array[Node2D] = []
	var healthy := Regions.all().filter(func(r: RegionData) -> bool: return IslandHealth.of(tree, r) >= HEALTHY)
	for region: RegionData in Regions.all():
		var health := IslandHealth.of(tree, region)
		var trees := grown_trees(tree, region)
		for arrival: ArrivalData in region.arrivals:
			if _arrived.has(arrival.node_name):
				_stay_or_go(world, arrival, trees)
				continue
			if health < arrival.island_health or trees < arrival.needs_trees:
				continue
			if healthy.filter(func(r: RegionData) -> bool: return r != region).size() < arrival.healthy_islands:
				continue
			came.append(_bring(world, arrival))
			tree.call_group("hud", "show_toast", arrival.note)
	return came


## Puts the arrivals from a save back (quietly).
static func restore(world: Node, names: Array) -> void:
	_arrived.clear()
	for region: RegionData in Regions.all():
		for arrival: ArrivalData in region.arrivals:
			if arrival.node_name in names:
				_bring(world, arrival)


## Tree nesters fly off while there aren't enough grown trees, and come back when there are.
static func _stay_or_go(world: Node, arrival: ArrivalData, trees: int) -> void:
	var animal := world.get_node_or_null(arrival.node_name) as Node2D
	if not animal or arrival.needs_trees <= 0:
		return
	var stays: bool = trees >= arrival.needs_trees or animal.get("tangled") or animal.get("injured")  # never flies off needing help
	if stays == animal.visible:
		return
	animal.visible = stays
	animal.process_mode = Node.PROCESS_MODE_INHERIT if stays else Node.PROCESS_MODE_DISABLED
	if stays:
		animal.add_to_group("animals")
		animal.add_to_group("interactables")
	else:
		animal.remove_from_group("animals")
		animal.remove_from_group("interactables")
		if animal.has_method("set_nest_tree"):
			animal.set_nest_tree(null)  # its nest tree is free again
	world.get_tree().call_group("hud", "show_toast", "A %s is back, nesting in your palm trees!" % arrival.species.display_name if stays
		else "A %s has flown off: it needs more full-grown trees to nest in." % arrival.species.display_name)


## Full-grown trees on `region`'s island (seabirds nest in them).
static func grown_trees(tree: SceneTree, region: RegionData) -> int:
	return tree.get_nodes_in_group("plants").filter(func(p: Node2D) -> bool:
		return (not p.is_queued_for_deletion() and p.has_method("stage") and p.stage() == 2
			and Regions.nearest(p.global_position) == region)).size()


static func arrived_names() -> Array:
	return _arrived.keys()


static func _bring(world: Node, arrival: ArrivalData) -> Node2D:
	_arrived[arrival.node_name] = true
	var existing := world.get_node_or_null(arrival.node_name)
	if existing:
		return existing
	var animal: Node2D = ANIMAL_SCENE.instantiate()
	animal.name = arrival.node_name
	animal.set("data", arrival.species)
	animal.set("home_radius", arrival.home_radius)
	animal.position = arrival.position
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())  # under the ranger and boat
	return animal
