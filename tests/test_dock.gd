extends SceneTree
## Docks: planks must connect to the shore or another plank; placing keeps going for
## the next plank; the ranger walks out along the jetty but never off its end; a
## jetty can reach the open sea; moving a plank puts the water back where it was.
## Run: godot --headless --path . --script res://tests/test_dock.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")  # autoloads: looked up at runtime
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var build_mode: Node = world.get_node("BuildMode")
	var player: Node2D = world.get_node("Player")
	var dock: Resource = load("res://data/buildings/dock.tres")
	funding.earn(1000, "test")

	# --- A jetty into the lagoon (not on top of the moored boat) ---
	build_mode.start(dock)
	var boat: Node2D = world.get_node("Boat")
	_expect(not build_mode.can_place(dock, _cell_of(boat.global_position)), "can't build a plank on the boat")
	boat.global_position = Vector2(16, 300)  # moor it further out
	_expect(not build_mode.can_place(dock, Vector2i(0, 5)), "a floating plank isn't allowed")
	_expect(build_mode.place_at(Vector2i(0, 2)), "first plank at the beach")
	_expect(build_mode.is_active(), "still placing: ready for the next plank")
	_expect(build_mode.place_at(Vector2i(0, 3)) and build_mode.place_at(Vector2i(0, 4)), "two more planks in a row")
	build_mode.cancel()
	player.global_position = Vector2(16, 40)
	await physics_frame
	Input.action_press("move_down")
	for i in 120:
		await physics_frame
	Input.action_release("move_down")
	_expect(player.global_position.y > 130.0, "walked out along the jetty (y %.0f)" % player.global_position.y)
	_expect(player.global_position.y <= 160.0, "stopped at the end, not in the water (y %.0f)" % player.global_position.y)

	# --- Out into the open sea ---
	build_mode.start(dock)
	for x in range(16, 20):
		build_mode.place_at(Vector2i(x, 0))
	build_mode.cancel()
	_expect(_terrain(Vector2(19 * 32 + 16, 16)) == "water", "planks reach past the shallows into the open sea")
	player.global_position = Vector2(15 * 32 + 16, 16)
	await physics_frame
	Input.action_press("move_right")
	for i in 150:
		await physics_frame
	Input.action_release("move_right")
	_expect(player.global_position.x > 18 * 32.0 and player.global_position.x <= 20 * 32.0,
		"walked to the end of the sea jetty (x %.0f)" % player.global_position.x)

	# --- Moving a plank puts the sea back ---
	player.global_position = Vector2(15 * 32 + 16, 16)
	var end: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.cell == Vector2i(19, 0))[0]
	build_mode.start_move(end)
	_expect(not build_mode.can_place(dock, Vector2i(20, 0)), "a moved plank can't hang off its own old spot")
	_expect(build_mode.place_at(Vector2i(16, 1)), "moved beside the jetty")
	_expect(_terrain(Vector2(19 * 32 + 16, 16)) == "", "open sea is back where the plank was")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / 32.0).floor())


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
