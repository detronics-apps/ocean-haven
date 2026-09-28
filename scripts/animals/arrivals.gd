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
		for arrival: ArrivalData in region.arrivals:
			if _arrived.has(arrival.node_name) or health < arrival.island_health:
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
