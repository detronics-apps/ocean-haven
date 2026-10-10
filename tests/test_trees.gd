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
	_expect("Cut down" in labels, "a tree next to you can be cut down")
	var count_before := get_nodes_in_group("plants").size()
	first.actions()[0].do.call()
	await process_frame
	_expect(get_nodes_in_group("plants").size() == count_before - 1, "the tree is gone")
	var inventory := root.get_node("Inventory")
	_expect(inventory.count(&"wood") in [2, 3] and inventory.count(&"sapling") in [1, 2],
		"a full-grown island palm gives 2-3 wood and 1-2 saplings (%d, %d)" % [inventory.count(&"wood"), inventory.count(&"sapling")])
	inventory.add(load("res://data/items/wood.tres"), 6)
	player.global_position = get_nodes_in_group("plants")[0].global_position + Vector2(-30, 10)
	_expect(get_nodes_in_group("plants")[0].actions().is_empty() and get_nodes_in_group("plants")[0].info_line().begins_with("Arms full"),
		"can't cut with 6 wood in your arms: no button, the line above says so")
	inventory.take_item(&"wood", 6)
	var palm: Resource = load("res://data/buildings/palm_tree.tres")
	build_mode.start(palm)
	_expect(build_mode.place_at(Vector2i(-12, -3)), "planted a new palm")
	build_mode.cancel()
	await process_frame
	_expect(get_nodes_in_group("plants").size() == count_before, "the new palm grows there")
	var planted: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"palm_tree")[0]
	var trunk: Node2D = planted.get_child(planted.get_child_count() - 1)
	player.global_position = trunk.global_position + Vector2(-30, 0)
	await process_frame
	var palm_labels: Array = planted.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(not "Move palm" in palm_labels, "palms can't be moved: cut down and replant (%s)" % [palm_labels])
	var clock := root.get_node("GameClock")
	_expect(trunk.stage() == 0 and trunk.actions()[0].label == "Dig up", "a new palm is small: dig it up")
	var palm_sprite: Sprite2D = trunk.get_node("Sprite2D")
	_expect(palm_sprite.texture == trunk.stage_textures[0], "a sapling has its own picture (a sprouting coconut)")
	clock.day += 1
	await process_frame
	_expect(trunk.stage() == 1 and palm_sprite.texture == trunk.stage_textures[1], "a day later it's a young palm, with its own picture")
	clock.day += 1
	await process_frame
	_expect(trunk.stage() == 2 and palm_sprite.scale == Vector2.ONE and not palm_sprite.texture in trunk.stage_textures, "another day: full grown")
	var saplings: int = inventory.count(&"sapling")
	trunk.actions()[0].do.call()
	await process_frame
	_expect(not is_instance_valid(planted) or planted.is_queued_for_deletion(), "a planted palm can be cut down too")
	_expect(inventory.count(&"wood") in [2, 3] and inventory.count(&"sapling") - saplings in [1, 2],
		"a full-grown palm gives 2-3 wood and 1-2 saplings")

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
		_expect(inventory.count(&"sapling") == saplings + 1 and (inventory.count(&"wood") == 0 if grown_days == 0 else inventory.count(&"wood") in [1, 2]),
			"%s palm gives %s wood and its sapling back" % ["small" if grown_days == 0 else "medium", "no" if grown_days == 0 else "1-2"])
		inventory.take_item(&"wood", inventory.count(&"wood"))

	# --- Seabirds nest in full-grown palms: one tree each, and stand on their nest ---
	var bird: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	bird.set("data", load("res://data/animals/red_footed_booby.tres"))
	bird.name = "TestBooby"
	bird.set("home_radius", 300.0)
	var palms := get_nodes_in_group("plants").filter(func(p: Node) -> bool: return p is StaticBody2D and p.stage() == 2)
	bird.position = palms[0].global_position + Vector2(60, -60)
	world.add_child(bird)
	bird.set("_fly_left", 0.0)
	player.global_position = Vector2(-1500, 0)  # out of the way: nothing startles it
	var perched := false
	for i in 600:
		await physics_frame
		if bird.perched:
			perched = true
			break
	var nest_palm: Node2D = bird.nest_tree
	_expect(nest_palm != null and nest_palm.nest_of == bird and nest_palm.get_node("Nest").visible,
		"the booby picks a full-grown palm for its nest, and the nest shows in the tree")
	_expect(perched and bird.global_position.distance_to(nest_palm.perch_point()) < 1.0
		and bird.get_node("Sprite2D").texture == bird.data.perched_sprite, "it flies to its nest and stands on it (a standing picture)")
	# Caught in litter: it flies back to its nest and waits there to be freed.
	bird.take_off()
	bird.set("_fly_left", 999.0)
	bird.tangle(load("res://data/items/plastic_bag.tres"))
	var waited := 0
	for i in 900:
		await physics_frame
		if bird.perched:
			waited += 1
	_expect(bird.perched and waited > 600, "a caught booby goes to its nest and stays there until it's freed")
	bird.restore_freed()
	_expect(bird.perched and bird.get("_perch_left") > 0.0, "freed, it stands on its nest a while as usual")
	var nests := get_nodes_in_group("plants").filter(func(p: Node) -> bool: return p is StaticBody2D and p.has_nest())
	var birds := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.nests_in_trees)
	_expect(nests.size() == birds.size() and nests.filter(func(p: Node) -> bool: return p.nest_of == bird).size() == 1,
		"one nest per bird (%d nests, %d birds)" % [nests.size(), birds.size()])
	player.global_position = nest_palm.global_position + Vector2(-30, 10)
	await process_frame
	var tree_labels: Array = nest_palm.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(tree_labels == ["Move nest"], "a tree with a nest can't be cut: move the nest first (%s)" % [tree_labels])
	nest_palm.cut_down()
	await process_frame
	_expect(is_instance_valid(nest_palm) and not nest_palm.is_queued_for_deletion(), "cutting it doesn't work while the nest is there")
	nest_palm.move_nest()
	_expect(not nest_palm.has_nest() and bird.nest_tree != nest_palm and bird.nest_tree.nest_of == bird and not bird.perched,
		"the nest moves to another full-grown palm (the bird takes off)")
	tree_labels = nest_palm.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(tree_labels == ["Cut down"], "then the tree can be cut down (%s)" % [tree_labels])
	_expect(root.get_node("SaveGame")._tree_nests().get("TestBooby", []) == [bird.nest_tree.global_position.x, bird.nest_tree.global_position.y],
		"which tree has its nest is saved")
	bird.free()
	player.global_position = Vector2.ZERO

	# --- The Kelp Forest has coastal trees: their own saplings, planted only there ---
	var coastal: Node2D = world.get_node("KelpIsland/Tree1")
	var kelp_inventory := root.get_node("Inventory")
	kelp_inventory.restore({}, {})
	player.global_position = coastal.global_position + Vector2(-30, 10)
	await process_frame
	_expect(coastal.sapling.id == &"coastal_sapling", "the Kelp Forest's trees are coastal trees")
	var kelp_cell := Vector2i((coastal.global_position / 32.0).floor())
	coastal.cut_down()
	await process_frame
	_expect(kelp_inventory.count(&"coastal_sapling") >= 1 and kelp_inventory.count(&"sapling") == 0,
		"cutting one gives coastal saplings (not palm saplings)")
	var bm: Node = world.get_node("BuildMode")
	var coastal_data: Resource = load("res://data/buildings/coastal_tree.tres")
	var palm_data: Resource = load("res://data/buildings/palm_tree.tres")
	_expect(bm.placement_problem(coastal_data, kelp_cell) == "", "a coastal sapling can be planted back there (%s)" % bm.placement_problem(coastal_data, kelp_cell))
	_expect(bm.placement_problem(palm_data, kelp_cell) != "", "palms belong on the Starting Island")

	# --- The Mangrove Coast has red mangroves: grown from propagules, only in the mud ---
	var mangrove: Node2D = world.get_node("MangroveIsland/Mangrove1")
	kelp_inventory.restore({}, {})
	player.global_position = mangrove.global_position + Vector2(-30, 10)
	await process_frame
	_expect(mangrove.sapling.id == &"mangrove_propagule", "the Mangrove Coast's trees are mangroves")
	var mud_cell := Vector2i((mangrove.global_position / 32.0).floor())
	mangrove.cut_down()
	await process_frame
	_expect(kelp_inventory.count(&"mangrove_propagule") >= 1 and kelp_inventory.count(&"wood") >= 1,
		"cutting one gives wood and propagules")
	var mangrove_data: Resource = load("res://data/buildings/mangrove_tree.tres")
	_expect(bm.placement_problem(mangrove_data, mud_cell) == "", "a propagule can be planted back in the mud (%s)" % bm.placement_problem(mangrove_data, mud_cell))
	_expect(bm.placement_problem(coastal_data, mud_cell) != "", "other islands' trees don't grow here")
	var ground: TileMapLayer = world.get_node("MangroveIsland/Ground")
	var not_mud := Vector2i.MAX
	for c in ground.get_used_cells():
		var t := ground.get_cell_tile_data(c)
		if t.get_custom_data("terrain") in ["grass", "sand"]:
			not_mud = Vector2i((ground.to_global(ground.map_to_local(c)) / 32.0).floor())
			if bm.placement_problem(mangrove_data, not_mud) != "":
				break
	_expect(bm.placement_problem(mangrove_data, not_mud) != "", "mangroves only grow in mud, not on sand or grass")
	player.global_position = Vector2.ZERO

	# --- Plants go in the Journal the first time you come close ---
	var journal := root.get_node("Journal")
	var palm_near: Node2D = get_nodes_in_group("plants").filter(func(n: Node) -> bool: return Regions_home(n))[0]
	player.global_position = palm_near.global_position + Vector2(-40, 10)
	await process_frame
	await process_frame
	_expect(journal.has_plant(&"coconut_palm") and not journal.has_plant(&"giant_kelp"), "a palm close by: the Coconut Palm is in the Journal")
	var screen: Node = world.get_node("JournalScreen")
	screen.show_tab(&"plants")
	screen.open()
	var texts := ""
	for label in screen.find_child("Plant_coconut_palm", true, false).find_children("*", "Label", true, false):
		texts += label.text
	_expect(texts.contains("Coconut Palm") and screen.find_child("Plant_giant_kelp", true, false) != null,
		"the Plants tab shows it, and ??? for plants still to find")
	var fleet := root.get_node("Fleet")
	var all_ids := []
	for d in DirAccess.get_files_at("res://data/discoveries"):
		if d.ends_with(".tres"):
			all_ids.append(d.get_basename())
	fleet.restore({"found": all_ids, "installed": all_ids})
	screen.refresh()
	_expect(screen.find_child("Tab_ocean", true, false) == null and screen.find_child("OceanTotals", true, false) == null,
		"no Ocean page in the Journal, even with all 6 upgrades: the Global Ocean Observatory shows the whole ocean")
	screen.close()
	fleet.restore({})
	player.global_position = Vector2.ZERO

	# --- Minimap: things nearby are on the map; a far-away home is pinned to the rim ---
	var minimap: Node = world.get_node("HUD/Minimap")
	var near: Array = minimap.map_point(Vector2(100, 0), Vector2.ZERO)
	var far: Array = minimap.map_point(Vector2(5000, 0), Vector2.ZERO)
	_expect(near[1] and not far[1] and far[0].x > near[0].x and far[0].distance_to(Vector2(64, 64)) <= 64.0,
		"minimap shows nearby things and pins far-away home to the rim")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func Regions_home(n: Node) -> bool:
	return n is StaticBody2D and (n as Node2D).global_position.length() < 1200.0 and n.get("plant") == null


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
