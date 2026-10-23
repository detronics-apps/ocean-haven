extends SceneTree
## Chasing an animal from one home to another of the same kind (the owner): it moves only if the
## new home has at least as much room as the old one (chasing evens them out, never into a full
## one); the young stay with their parent. Turtles nest at the nearest area with room.
## Run: godot --headless --path . --script res://tests/test_chase.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var mangrove: Resource = load("res://data/regions/mangrove_coast.tres")
	load("res://scripts/world/regions.gd").discover(mangrove)
	root.get_node("Funding").restore({"balance": 50000})
	root.get_node("Inventory").restore({}, {"wood": 100})
	world.get_node("Player").global_position = mangrove.arrival
	for i in 3:
		await process_frame
	var eco: Node = world.get_node("MangroveIsland/Ecosystem")
	var build_mode: Node = world.get_node("BuildMode")
	var habitat: Resource = load("res://data/buildings/crab_habitat.tres")
	var crab: Resource = load("res://data/animals/mangrove_crab.tres")

	# Two Crab Habitats far apart on the mud.
	var homes: Array = []
	var cells: Array = eco.flats()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	for cell: Vector2i in [cells.front(), cells.back()]:
		var at: Vector2i = load("res://scripts/world/terrain.gd").cell_of(eco._world(cell))
		for dx in range(-4, 5):
			for dy in range(-4, 5):
				if homes.size() < 2 and (homes.is_empty() or homes.back().global_position.distance_to(eco._world(cell)) > 200.0) \
						and build_mode.placement_problem(habitat, at + Vector2i(dx, dy)) == "":
					homes.append(build_mode.add_building(habitat, at + Vector2i(dx, dy)))
	_expect(homes.size() == 2, "two Crab Habitats far apart")
	var a: Node2D = homes[0]
	var b: Node2D = homes[1]
	_expect(a.capacity() == 2 and b.capacity() == 2, "room for 2 crabs each")
	for c in eco.living(crab):
		c.queue_free()
	await process_frame
	var crabs: Array = []
	for i in 2:
		var c: Node2D = eco._spawn(crab, a.global_position)
		c.home_area = a
		crabs.append(c)

	var chase := func(c: Node2D, to: Node2D) -> void:  # the ranger chased it right up to `to`
		c.global_position = to.global_position + Vector2(8, 8)
		c._rehome_after_chase()
	chase.call(crabs[0], b)
	_expect(crabs[0].home_area == b and a.animals_here() == 1 and b.animals_here() == 1, "2 and 0: one can be chased over (1 and 1)")
	chase.call(crabs[1], b)
	_expect(crabs[1].home_area == b, "1 and 1 (the same room): one more can go (0 and 2)")
	var third: Node2D = eco._spawn(crab, a.global_position)
	third.home_area = a
	chase.call(third, b)
	_expect(third.home_area == a, "never into a full home")
	chase.call(crabs[1], a)
	_expect(crabs[1].home_area == a, "and back to the one with more room")
	chase.call(third, a)
	_expect(third.home_area == a, "nearer its own home: it stays")
	crabs[0].global_position = b.global_position
	crabs[0].young = true
	chase.call(crabs[0], a)
	_expect(crabs[0].home_area == b, "the young stay with their parent")

	# Turtles nest at the nearest protection area that has room.
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var turtle: Node = null
	for t in get_nodes_in_group("animals"):
		if t.data == turtle_data:
			turtle = t
	_expect(turtle != null, "a turtle to nest")
	var area_data: Resource = load("res://data/buildings/turtle_protection_area.tres")
	var areas: Array = []
	var start: Resource = load("res://data/regions/home_island.tres")
	world.get_node("Player").global_position = start.arrival
	await process_frame
	var sands: Array = []
	var ground: TileMapLayer = world.get_node("StarterIsland/Ground")
	for cell in ground.get_used_cells():
		var tile := ground.get_cell_tile_data(cell)
		if tile and tile.get_custom_data("terrain") == "sand" and (cell.x + cell.y) % 3 == 0:
			sands.append(load("res://scripts/world/terrain.gd").cell_of(ground.to_global(ground.map_to_local(cell))))
	for cell: Vector2i in sands:
		if areas.size() < 2 and (areas.is_empty() or areas[0].global_position.distance_to(Vector2(cell) * 32.0) > 300.0) \
				and build_mode.placement_problem(area_data, cell) == "":
			areas.append(build_mode.add_building(area_data, cell))
	_expect(areas.size() == 2, "two Turtle Protection Areas apart (%d)" % areas.size())
	if areas.size() == 2:
		turtle.home_area = null
		turtle.global_position = areas[0].global_position + Vector2(0, 40)
		_expect(turtle._nest_site() == areas[0], "she nests at the nearest area")
		for i in 4:  # the nearest one fills up
			var other: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
			other.data = turtle_data
			other.home_area = areas[0]
			world.add_child(other)
		await process_frame
		_expect(areas[0].room_for_animals() == 0 and turtle._nest_site() == areas[1], "full: she nests at the nearest one with room")
	_expect(start != null, "the Starting Island")

	print("PASS" if not _failed else "FAIL")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	if not ok:
		_failed = true
