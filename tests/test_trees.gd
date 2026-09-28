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

	# --- Cut a tree down; plant a new one; cut that too ---
	var first: Node2D = get_nodes_in_group("plants")[0]
	player.global_position = first.global_position + Vector2(-30, 10)
	var labels: Array = first.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Cut down palm tree" in labels, "a tree next to you can be cut down")
	var count_before := get_nodes_in_group("plants").size()
	first.actions()[0].do.call()
	await process_frame
	_expect(get_nodes_in_group("plants").size() == count_before - 1, "the tree is gone")
	var inventory := root.get_node("Inventory")
	_expect(inventory.count(&"wood") in [1, 2] and inventory.count(&"sapling") in [1, 2],
		"a full-grown island palm gives 1-2 wood and 1-2 saplings (%d, %d)" % [inventory.count(&"wood"), inventory.count(&"sapling")])
	inventory.add(load("res://data/items/wood.tres"), 2)
	player.global_position = get_nodes_in_group("plants")[0].global_position + Vector2(-30, 10)
	_expect(get_nodes_in_group("plants")[0].actions()[0].label == "Arms full of wood", "can't cut with 3 wood in your arms")
	inventory.take_item(&"wood", 3)
	var palm: Resource = load("res://data/buildings/palm_tree.tres")
	build_mode.start(palm)
	_expect(build_mode.place_at(Vector2i(-12, -3)), "planted a new palm")
	build_mode.cancel()
	await process_frame
	_expect(get_nodes_in_group("plants").size() == count_before, "the new palm grows there")
	var planted: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"palm_tree")[0]
	var trunk: Node2D = planted.get_child(planted.get_child_count() - 1)
	player.global_position = trunk.global_position + Vector2(-30, 0)
	var clock := root.get_node("GameClock")
	_expect(trunk.stage() == 0 and trunk.actions()[0].label == "Dig up sapling", "a new palm is small: dig it up")
	clock.day += 1
	_expect(trunk.stage() == 1, "a day later it's medium")
	clock.day += 1
	await process_frame
	_expect(trunk.stage() == 2 and trunk.get_node("Sprite2D").scale == Vector2.ONE, "another day: full grown")
	var saplings: int = inventory.count(&"sapling")
	trunk.actions()[0].do.call()
	await process_frame
	_expect(not is_instance_valid(planted) or planted.is_queued_for_deletion(), "a planted palm can be cut down too")
	_expect(inventory.count(&"wood") in [1, 2] and inventory.count(&"sapling") - saplings in [1, 2],
		"a full-grown palm gives 1-2 wood and 1-2 saplings")

	# --- Small gives the sapling back; medium 1 wood + 1 sapling ---
	inventory.take_item(&"wood", inventory.count(&"wood"))
	for grown_days: int in [0, 1]:
		build_mode.start(palm)
		build_mode.place_at(Vector2i(-12, -3))
		build_mode.cancel()
		var young: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"palm_tree")[0]
		young.built_day = clock.day - grown_days
		saplings = inventory.count(&"sapling")
		young.get_child(young.get_child_count() - 1).cut_down()
		await process_frame
		_expect(inventory.count(&"sapling") == saplings + 1 and inventory.count(&"wood") == grown_days,
			"%s palm gives %d wood and its sapling back" % ["small" if grown_days == 0 else "medium", grown_days])

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
