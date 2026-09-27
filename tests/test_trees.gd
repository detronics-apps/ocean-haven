extends SceneTree
## Palm trees: the ranger walks around trunks (can't pass through), nothing can
## be built on top of a tree, and the world sorts by depth so the ranger can
## stand behind a tree while the island ground always stays underneath.
## Run: godot --headless --path . --script res://tests/test_trees.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node2D = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var trees := get_nodes_in_group("plants")
	_expect(trees.size() >= 6, "palm trees grow on the island (%d)" % trees.size())
	var tree: Node2D = trees[0]
	var player: Node2D = world.get_node("Player")

	# --- Can't walk through a trunk ---
	player.global_position = tree.global_position + Vector2(-40, 0)
	await physics_frame
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	_expect(player.global_position.x < tree.global_position.x - 6.0,
		"ranger stops at the trunk (%.0f px short)" % (tree.global_position.x - player.global_position.x))

	# --- Can't build on a tree ---
	var build_mode: Node = world.get_node("BuildMode")
	var tent: Resource = load("res://data/buildings/tent.tres")
	build_mode.start(tent, true)
	var cell := Vector2i((tree.global_position / 32.0).floor())
	_expect(not build_mode.can_place(tent, cell), "can't put a tent on a tree")
	build_mode.set("_free", false)
	build_mode.cancel()

	# --- Depth sorting, ground underneath ---
	_expect(world.y_sort_enabled and world.get_node("StarterIsland").y_sort_enabled, "world sorts by depth")
	_expect((world.get_node("StarterIsland/Ground") as CanvasItem).z_index < 0, "ground always drawn underneath")

	# --- Minimap: things nearby are on the map; a far-away home is pinned to the rim ---
	var minimap: Node = world.get_node("HUD/Minimap")
	var near: Array = minimap.map_point(Vector2(100, 0), Vector2.ZERO)
	var far: Array = minimap.map_point(Vector2(5000, 0), Vector2.ZERO)
	_expect(near[1] and not far[1] and far[0].x > near[0].x and far[0].distance_to(Vector2(64, 64)) <= 64.0,
		"minimap shows nearby things and pins far-away home to the rim")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
