extends SceneTree
## Rowboats: every island starts with one; up to 2 more on each island, each moored next to
## a dock plank. The ranger boards the nearest boat. Boats stay where they were left (also
## after loading), and nothing sails along on voyages.
## Run: godot --headless --path . --script res://tests/test_rowboats.gd --quit-after 300000

const PATH := "user://test_rowboats.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	root.get_node("Funding").restore({"balance": 5000})
	root.get_node("Inventory").restore({"plastic_bottle": 99}, {"wood": 99})
	var build_mode: Node = world.get_node("BuildMode")
	var dock: Resource = load("res://data/buildings/dock.tres")
	var rowboat: Resource = load("res://data/buildings/rowboat.tres")
	var player: Node2D = world.get_node("Player")
	var regions: GDScript = load("res://scripts/world/regions.gd")

	# --- Every island starts with its own rowboat ---
	for id in ["home_island", "kelp_forest", "mangrove_coast", "tropical_reef", "deep_sea", "arctic_ocean"]:
		var r: Resource = load("res://data/regions/%s.tres" % id)
		_expect(get_nodes_in_group("boat").any(func(b: Node2D) -> bool: return regions.nearest(b.global_position) == r),
			"%s has a rowboat" % id)
	world.get_node("Boat").global_position = Vector2(16, 300)  # out of the way

	# --- Up to 2 more on each island: 2 dock planks each, then anywhere on the water ---
	var home: Resource = load("res://data/regions/home_island.tres")
	_expect(build_mode.placement_problem(rowboat, Vector2i(22, 3)).contains("dock"), "no extra rowboat before the docks (%s)" % build_mode.placement_problem(rowboat, Vector2i(22, 3)))
	build_mode.start(dock)
	for x in range(16, 18):
		build_mode.place_at(Vector2i(x, 0))
	build_mode.cancel()
	_expect(build_mode.placement_problem(rowboat, Vector2i(22, 3)) == "", "2 planks: one rowboat, anywhere on the water (%s)" % build_mode.placement_problem(rowboat, Vector2i(22, 3)))
	var first: Node = build_mode.add_building(rowboat, Vector2i(22, 3))
	_expect(build_mode.requirement_short(rowboat, home) == 2, "the second needs 2 more planks")
	build_mode.start(dock)
	for x in range(18, 20):
		build_mode.place_at(Vector2i(x, 0))
	build_mode.cancel()
	var second: Node = build_mode.add_building(rowboat, Vector2i(24, 3))
	_expect(first.boat() != null and second.boat() != null, "they're real boats")
	_expect(build_mode.placement_problem(rowboat, Vector2i(17, -1)).contains("as many"), "up to 2 on each island")

	# --- The ranger boards the nearest boat, and leaves it somewhere else ---
	player.global_position = second.global_position + Vector2(0, -30)
	await process_frame
	_expect(second.boat().actions().size() == 1 and first.boat().actions().is_empty(), "only the nearest boat offers 'Board boat'")
	second.boat().call("_board")
	second.boat().global_position = Vector2(700, 200)
	second.boat().restore_ashore()
	var left_at: Vector2 = second.boat().global_position
	for i in 30:
		await physics_frame
	_expect(second.boat().global_position.distance_to(left_at) < 1.0, "it stays where it was left")
	var kelp_boat: Node2D = world.get_node("KelpBoat")
	kelp_boat.global_position += Vector2(40, 0)
	var kelp_left: Vector2 = kelp_boat.global_position

	# --- Saved where they were left ---
	_expect(root.get_node("SaveGame").save_to(world, PATH), "saved")
	world.free()
	world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	_expect(root.get_node("SaveGame").load_from(world, PATH), "loaded")
	await process_frame
	var boats := get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"rowboat")
	_expect(boats.size() == 2 and boats.any(func(b: Node) -> bool: return b.boat().global_position.distance_to(left_at) < 1.0),
		"after loading, the built rowboat is still where it was left")
	_expect(world.get_node("KelpBoat").global_position.distance_to(kelp_left) < 1.0, "and so is the Kelp Forest's own")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	# --- Voyages: nothing sails along ---
	var home_boat: Node2D = world.get_node("Boat")
	var home_spot: Vector2 = home_boat.global_position
	load("res://scripts/ui/voyage_map.gd").arrive(self, load("res://data/regions/kelp_forest.tres"))
	_expect(home_boat.global_position == home_spot and world.get_node("KelpBoat").global_position.distance_to(kelp_left) < 1.0,
		"sailing to the Kelp Forest: every boat stays where it was")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
