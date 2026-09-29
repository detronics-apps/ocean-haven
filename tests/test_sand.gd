extends SceneTree
## Moving sand: scoop up the beach tile in front of you (it becomes shallows), place
## sand on a shallow tile (it becomes beach); sand isn't litter; nothing under a
## building; changed tiles are saved.
## Run: godot --headless --path . --script res://tests/test_sand.gd --quit-after 300000

const PATH := "user://test_sand_save.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var inventory := root.get_node("Inventory")  # autoloads: looked up at runtime
	var save := root.get_node("SaveGame")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var shovel: Node = world.get_node("SandShovel")
	var player: Node2D = world.get_node("Player")

	# Standing on the east beach at (14, 0): (15, 0) is sand, (16, -1) shallows.
	player.global_position = Vector2(14 * 32 + 16, 16)
	shovel.selected = Vector2i(15, 0)
	_expect(shovel.actions().is_empty(), "no sand buttons until you pick up the shovel")
	shovel.start()
	shovel.litter_chance = 0.0  # no buried litter until it's tested below
	for i in 30:
		await process_frame  # let the (smoothed) camera settle on the ranger
	_expect(shovel.tiles_around().size() == 8, "the 8 tiles around you can be picked")
	_expect(shovel.what_can_be_done(Vector2i(15, 0)) == "pick_up", "a sand tile next to you: pick up")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	# World -> screen, including the (tiny, headless) window's stretch.
	tap.position = root.get_final_transform() * (root.get_canvas_transform() * Vector2(15 * 32 + 16, 16))
	tap.global_position = tap.position
	Input.parse_input_event(tap)
	await process_frame
	await process_frame
	await process_frame
	_expect(shovel.selected == Vector2i(15, 0), "tapping the tile selects it (%s)" % [shovel.selected])
	shovel.selected = Vector2i(15, 0)
	var labels: Array = shovel.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels == ["Pick up sand", "Put shovel away"], "selected sand tile offers 'Pick up sand' (%s)" % [labels])
	shovel.actions()[0].do.call()
	_expect(_terrain(Vector2(15 * 32 + 16, 16)) == "water", "the beach tile is shallow water now")
	_expect(inventory.count(&"sand") == 1 and inventory.total() == 0, "carrying 1 sand (it isn't litter)")
	_expect(shovel.what_can_be_done(Vector2i(13, 0)) == "", "only one sand at a time")

	player.global_position = Vector2(15 * 32 + 16, -1 * 32 + 16)
	await process_frame
	shovel.selected = Vector2i(16, -1)
	labels = shovel.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels == ["Place sand", "Put shovel away"], "selected shallow tile with sand: 'Place sand' (%s)" % [labels])
	shovel.actions()[0].do.call()
	_expect(_terrain(Vector2(16 * 32 + 16, -1 * 32 + 16)) == "sand", "the shallow tile is beach now")
	_expect(inventory.count(&"sand") == 0, "used the sand")
	# Now and then the sand hides buried litter.
	shovel.litter_chance = 1.0
	var litter_before := get_nodes_in_group("debris").size()
	shovel.pick_up(Vector2i(16, -1))
	var found := get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
		return d.global_position.distance_to(Vector2(16 * 32 + 16, -1 * 32 + 16)) < 1.0)
	_expect(get_nodes_in_group("debris").size() == litter_before + 1 and found.size() == 1 and found[0].item.is_litter,
		"digging sand can turn up buried litter, right there")
	shovel.litter_chance = 0.0
	found[0].free()
	shovel.place(Vector2i(16, -1))  # put the beach back
	shovel.selected = Vector2i(20, 20)
	await process_frame
	_expect(shovel.selected == null, "a tile that isn't next to you can't stay selected")

	# Deep water takes 2 sand: it becomes shallows first, then beach.
	var sand: Resource = load("res://data/items/sand.tres")
	player.global_position = Vector2(18 * 32 + 16, 16)
	_expect(_terrain(Vector2(19 * 32 + 16, 16)) == "", "(19, 0) is open sea")
	inventory.add(sand)
	shovel.selected = Vector2i(19, 0)
	labels = shovel.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels == ["Place sand (makes it shallow)", "Put shovel away"], "deep water: sand makes it shallow (%s)" % [labels])
	shovel.actions()[0].do.call()
	_expect(_terrain(Vector2(19 * 32 + 16, 16)) == "water", "deep water is shallows now")
	inventory.add(sand)
	shovel.place(Vector2i(19, 0))
	_expect(_terrain(Vector2(19 * 32 + 16, 16)) == "sand" and inventory.count(&"sand") == 0, "a second sand makes it beach")

	# Nothing under a building.
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -3))
	player.global_position = Vector2(13 * 32 + 16, -3 * 32 + 16)
	_expect(shovel.what_can_be_done(Vector2i(14, -3)) == "", "can't dig under a building")

	# Saved and restored.
	_expect(save.save_to(world, PATH), "saved")
	world.free()
	world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	_expect(save.load_from(world, PATH), "loaded")
	_expect(_terrain(Vector2(15 * 32 + 16, 16)) == "water" and _terrain(Vector2(16 * 32 + 16, -1 * 32 + 16)) == "sand",
		"the changed tiles are restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

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
