class_name Arrivals
## Animals arriving as islands recover (RegionData.arrivals): checked every few seconds by
## the world; each arrives once and stays. Saved by SaveGame (the names that have arrived).

## An island counts as healthy for other islands' arrivals at this health.
const HEALTHY := 0.7
## Tree-nesting birds: full-grown trees on the island for each bird to come (the 2nd bird
## at 16, the 3rd at 24...), and to stay (8 keep 2 birds, 12 keep 3...).
const TREES_TO_COME := 8
const TREES_TO_STAY := 4
const ANIMAL_SCENE := preload("res://scenes/animals/animal.tscn")

## Node names of the animals that have arrived.
static var _arrived := {}


## Brings in every animal whose island (and ocean) is now healthy enough. Returns them.
static func check(world: Node) -> Array[Node2D]:
	var tree := world.get_tree()
	var came: Array[Node2D] = []
	var health_of := {}  # (worked out once each: it counts every animal and piece of litter)
	for region: RegionData in Regions.all():
		health_of[region] = IslandHealth.of(tree, region)
	var healthy := Regions.all().filter(func(r: RegionData) -> bool: return health_of[r] >= HEALTHY)
	for region: RegionData in Regions.all():
		var health: float = health_of[region]
		var trees := grown_trees(tree, region)
		var planted := grown_trees(tree, region, true)
		for arrival: ArrivalData in region.arrivals:
			if _arrived.has(arrival.node_name):
				_stay_or_go(world, arrival, trees)
				continue
			if health < arrival.island_health or trees < arrival.needs_trees or planted < arrival.needs_planted:
				continue
			if not Regions.helped(tree, region):
				continue  # only because of something the ranger did
			if healthy.filter(func(r: RegionData) -> bool: return r != region).size() < arrival.healthy_islands:
				continue
			if not Births.can_have(tree, arrival.species, region):
				continue  # its parents' last young are still too little: it comes a little later
			var animal := _bring(world, arrival)
			came.append(animal)
			Births.bring(animal, region, arrival.note)
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
	if not animal or arrival.needs_trees <= 0 or animal.get("unborn"):
		return
	var stays: bool = trees >= (arrival.stay_trees if arrival.stay_trees >= 0 else arrival.needs_trees) or animal.get("tangled") or animal.get("injured")  # never flies off needing help
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
		world.get_tree().call_group("clue_watchers", "bird_left", animal)
	world.get_tree().call_group("hud", "show_toast", "%s back in the trees" % arrival.species.display_name.to_lower() if stays
		else "%s flew off: too few trees" % arrival.species.display_name.to_lower(), false, animal.global_position)


## How many tree-nesting birds `trees` full-grown trees allow, with `now` there already: one
## more once there are TREES_TO_COME for each, and as many as TREES_TO_STAY each keep.
static func birds_for_trees(trees: int, now: int) -> int:
	if trees >= TREES_TO_COME * (now + 1):
		return now + 1
	return mini(now, floori(float(trees) / TREES_TO_STAY))


## Full-grown trees on `region`'s island (seabirds nest in them); `planted`: only those the
## ranger planted.
static func grown_trees(tree: SceneTree, region: RegionData, planted := false) -> int:
	return tree.get_nodes_in_group("plants").filter(func(p: Node2D) -> bool:
		return (not p.is_queued_for_deletion() and p.has_method("stage") and p.stage() == 2
			and (not planted or p.get_parent() is Building)
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
