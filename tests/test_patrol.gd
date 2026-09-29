extends SceneTree
## Patrol boat: needs a dock; sets out and collects floating litter inside its
## area (quietly, into the inventory), leaves litter outside it alone, and never
## drives onto land.
## Run: godot --headless --path . --script res://tests/test_patrol.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")  # autoloads: looked up at runtime
	var inventory := root.get_node("Inventory")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	load("res://scripts/animals/arrivals.gd").restore(world, ["Dolphin1", "Dolphin3", "Crab2"])  # the pod and crabs of a recovered island
	for d in get_nodes_in_group("debris"):
		d.free()  # a clean sea, so we know exactly what's out there
	var build_mode: Node = world.get_node("BuildMode")
	var patrol: Resource = load("res://data/buildings/patrol_boat.tres")
	funding.earn(1000, "test")
	root.get_node("Inventory").restore({"plastic_bottle": 99}, {"wood": 99})  # building materials

	build_mode.start(patrol)
	_expect(not build_mode.can_place(patrol, Vector2i(-24, 0)), "needs a dock first")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))
	_expect(build_mode.place_at(Vector2i(-24, 0)), "buoy placed in the open sea")
	var buoy: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"patrol_boat")[0]
	build_mode.cancel()

	# --- Offshore, it can be used from the rowboat: move it ---
	var rowboat: Node2D = world.get_node("Boat")
	var player: Node2D = world.get_node("Player")
	player.global_position = rowboat.global_position
	rowboat.call("_board")
	rowboat.global_position = buoy.global_position + Vector2(60, 0)
	await process_frame
	var boat_labels: Array = buoy.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(boat_labels.any(func(l: String) -> bool: return l.begins_with("Move")), "from the rowboat you can move the buoy (%s)" % [boat_labels])
	build_mode.start_move(buoy)
	_expect(build_mode.place_at(Vector2i(-25, 2)) and buoy.cell == Vector2i(-25, 2), "and place it again from the boat")
	rowboat.restore_ashore()
	player.global_position = Vector2.ZERO
	var boat: Node2D = buoy.get_node("PatrolBoat")
	var hull: Node2D = boat.get_node("Hull")

	var spawner: Node = world.get_node("LitterSpawner")
	spawner.set_process(false)  # only our test litter
	var bag: Resource = load("res://data/items/plastic_bag.tres")
	var inside: Node2D = spawner.spawn_at(bag, buoy.global_position + Vector2(90, 40), true)
	var outside: Node2D = spawner.spawn_at(bag, buoy.global_position + Vector2(400, 0), true)
	var notes := [0]
	inventory.item_added.connect(func(_i, _c) -> void: notes[0] += 1)

	var on_land := false
	for i in 900:
		await physics_frame
		on_land = on_land or _terrain(hull.global_position) in ["sand", "grass"]
		if not is_instance_valid(inside):
			break
	_expect(not is_instance_valid(inside), "collected the litter inside its area")
	_expect(inventory.count(&"plastic_bag") == 1, "the litter went into the inventory")
	_expect(notes[0] == 0, "quietly (no note for each piece)")
	var patrol_note: Label = world.get_node("HUD").find_child("PatrolNote", true, false)
	_expect(patrol_note != null and patrol_note.text == "Patrol boats: +1 litter", "just a small count under the inventory")
	for i in 120:
		await physics_frame
		on_land = on_land or _terrain(hull.global_position) in ["sand", "grass"]
	_expect(is_instance_valid(outside), "left litter outside its area alone")
	_expect(not on_land, "stayed on the water")

	# --- Dolphins keep away from busy boats ---
	var dolphin: Node2D = world.get_node("Dolphin3")
	dolphin.global_position = hull.global_position + Vector2(80, 0)
	dolphin.set("_home", hull.global_position + Vector2(260, 0))
	for i in 3:
		await physics_frame
	_expect(dolphin.get("_state") == 2, "a dolphin swims off from a patrol boat nearby")  # State.FLEE
	var near := 0
	for i in 40:
		if dolphin.call("_pick_target").distance_to(hull.global_position) < 200.0:
			near += 1
	_expect(near < 6, "and mostly doesn't settle near it (%d of 40 spots)" % near)
	var turtle: Node2D = world.get_node("GreenTurtle")
	_expect(turtle.data.boat_shy_distance > 0.0 and turtle.data.boat_shy_distance < 200.0,
		"turtles keep away from patrol boats too (a bit less than dolphins)")

	# --- Up to 6 patrol boats; but if they leave too little quiet water, they hit turtles ---
	_expect(patrol.max_count == 6 and load("res://data/buildings/dolphin_viewing_area.tres").max_count == 3,
		"up to 6 patrol boats and 3 Dolphin Viewing Areas")
	spawner = world.get_node("LitterSpawner")
	var home: Resource = load("res://data/regions/home_island.tres")
	var share: Callable = func() -> float: return load("res://scripts/player/patrol_boat.gd").free_water_share(self, home)
	_expect(share.call() > spawner.min_free_water and spawner.busy_waters(1.0) == null,
		"one patrol boat leaves plenty of quiet water (%d%% free): nobody is hurt" % roundi(share.call() * 100))
	var ground: TileMapLayer = world.get_node("StarterIsland/Ground")
	var water_cells: Array = ground.get_used_cells().filter(func(c: Vector2i) -> bool:
		var t := ground.get_cell_tile_data(c)
		return not t.get_custom_data("walkable") and t.get_custom_data("terrain") in ["water", ""])
	water_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).angle() < Vector2(b).angle())
	for i in 5:
		var cell: Vector2i = water_cells[(i + 1) * water_cells.size() / 6]
		build_mode.add_building(patrol, Terrain_cell(ground, cell))
	await process_frame
	var free_now: float = share.call()
	_expect(free_now < spawner.min_free_water, "6 patrol boats round the island leave little quiet water (%d%% free)" % roundi(free_now * 100))
	var hit: Node = spawner.busy_waters(1.0)
	_expect(hit != null and hit.injured and hit.data.boat_shy_distance > 0.0, "and one hits a turtle or dolphin (hurt, never killed)")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func Terrain_cell(ground: TileMapLayer, cell: Vector2i) -> Vector2i:
	return Vector2i((ground.to_global(ground.map_to_local(cell)) / 32.0).floor())


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
