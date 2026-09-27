extends SceneTree
## Nesting: no nesting by day; at night the freed turtle comes ashore at the
## Turtle Protection Area, lays a nest and returns to the sea; the next night the
## nest hatches and the hatchlings crawl into the water.
## Run: godot --headless --path . --script res://tests/test_nesting.gd --quit-after 100000

var _failed := false


func _initialize() -> void:
	await process_frame
	var journal := root.get_node("Journal")  # autoloads: looked up at runtime
	var clock := root.get_node("GameClock")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	var turtle: Node2D = world.get_node("GreenTurtle")  # untyped: Animal uses autoloads
	turtle.restore_freed()
	turtle.global_position = Vector2(590, 16)  # in the water off the east beach
	world.get_node("Player").global_position = Vector2(-600, 400)  # far away

	# --- Daytime: no nesting ---
	clock.day = 1
	clock.time_of_day = 0.5
	for i in 60:
		await physics_frame
	_expect(journal.nests(&"green_turtle") == 0, "no nesting in the daytime")

	# --- Night: comes ashore and lays ---
	clock.time_of_day = 0.85
	var laid := false
	for i in 1500:
		await physics_frame
		clock.time_of_day = 0.85  # hold the clock at night
		if get_nodes_in_group("nests").size() == 1:
			laid = true
			break
	_expect(laid and journal.nests(&"green_turtle") == 1, "laid a nest at night")
	if laid:
		var nest: Node2D = get_nodes_in_group("nests")[0]
		_expect(_terrain(nest.global_position) == "sand", "nest is on the beach")
		# Progress bar: shows when the ranger stands by the nest, hidden when away.
		var bar: ProgressBar = nest.get("_bar")
		world.get_node("Player").global_position = nest.global_position + Vector2(-30, 0)
		await process_frame
		await process_frame  # the frame signal fires before nodes update
		_expect(bar.visible and bar.value < 5.0, "egg progress bar shows at the nest (%.0f%%)" % bar.value)
		clock.time_of_day = 0.35  # next morning: half the incubation gone
		clock.day = 2
		await process_frame
		_expect(bar.value > 40.0 and bar.value < 60.0, "progress goes up with time (%.0f%%)" % bar.value)
		clock.day = 1
		clock.time_of_day = 0.85
		world.get_node("Player").global_position = Vector2(-600, 400)
		await process_frame
		_expect(not bar.visible, "bar hidden when the ranger walks away")
	var back := false
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
		if _terrain(turtle.global_position) in ["water", ""] and turtle.get("_state") != 4:
			back = true
			break
	_expect(back, "turtle returned to the sea")

	# --- Next night: hatchlings crawl to the sea ---
	clock.day = 2
	clock.time_of_day = 0.85
	await physics_frame
	await process_frame
	var young := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.young)
	_expect(young.size() == 3 and journal.hatched_count(&"green_turtle") == 3, "3 hatchlings")
	_expect(get_nodes_in_group("nests").size() == 0, "nest is empty after hatching")
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
	var all_in_sea := young.all(func(a: Node2D) -> bool: return _terrain(a.global_position) in ["water", ""])
	_expect(all_in_sea, "hatchlings reached the sea")

	# --- The area is full (4 turtles): the next hatchlings head out to sea ---
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", turtle_data)
	nest.position = Vector2(480, 0)
	world.add_child(nest)
	nest.hatch()
	await physics_frame
	var leavers := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.leaving)
	_expect(leavers.size() == 3, "no room: all 3 new hatchlings head for the open ocean")
	_expect(journal.hatched_count(&"green_turtle") == 6, "they still count as hatchlings (6)")
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
		if get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.leaving).is_empty():
			break
	var turtles := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data == turtle_data)
	_expect(turtles.size() == 4, "the area keeps 4 turtles; the rest swam out of the play area (%d left)" % turtles.size())

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
