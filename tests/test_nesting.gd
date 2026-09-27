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
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(8, -1))
	var turtle: Node2D = world.get_node("GreenTurtle")  # untyped: Animal uses autoloads
	turtle.restore_freed()
	turtle.global_position = Vector2(400, 16)  # in the water off the east beach
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
