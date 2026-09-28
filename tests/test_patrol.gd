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
	for i in 120:
		await physics_frame
		on_land = on_land or _terrain(hull.global_position) in ["sand", "grass"]
	_expect(is_instance_valid(outside), "left litter outside its area alone")
	_expect(not on_land, "stayed on the water")

	# --- Dolphins keep away from busy boats ---
	var dolphin: Node2D = world.get_node("Dolphin3")
	dolphin.global_position = hull.global_position + Vector2(80, 0)
	dolphin.set("_home", hull.global_position + Vector2(180, 0))
	for i in 3:
		await physics_frame
	_expect(dolphin.get("_state") == 2, "a dolphin swims off from a patrol boat nearby")  # State.FLEE
	var near := 0
	for i in 40:
		if dolphin.call("_pick_target").distance_to(hull.global_position) < 200.0:
			near += 1
	_expect(near < 6, "and mostly doesn't settle near it (%d of 40 spots)" % near)
	var turtle: Node2D = world.get_node("GreenTurtle")
	_expect(turtle.data.boat_shy_distance == 0.0, "turtles don't mind boats")

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
