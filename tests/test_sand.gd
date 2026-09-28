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

	# Standing on the east beach at (14, 0), facing east: (15, 0) is sand, (16, 0) shallows.
	player.global_position = Vector2(14 * 32 + 16, 16)
	player.facing = Vector2i.RIGHT
	_expect(shovel.actions().is_empty(), "no sand buttons until you pick up the shovel")
	shovel.start()
	var labels: Array = shovel.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels == ["Scoop up sand"], "facing the beach: scoop up sand (%s)" % [labels])
	shovel.actions()[0].do.call()
	_expect(_terrain(Vector2(15 * 32 + 16, 16)) == "water", "the beach tile is shallow water now")
	_expect(inventory.count(&"sand") == 1 and inventory.total() == 0, "carrying 1 sand (it isn't litter)")

	player.global_position = Vector2(15 * 32 + 16, -1 * 32 + 16)
	player.facing = Vector2i.RIGHT  # (16, -1) is shallow water
	labels = shovel.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels == ["Place sand"], "facing the shallows with sand: place sand (%s)" % [labels])
	shovel.actions()[0].do.call()
	_expect(_terrain(Vector2(16 * 32 + 16, -1 * 32 + 16)) == "sand", "the shallow tile is beach now")
	_expect(inventory.count(&"sand") == 0, "used the sand")

	# Nothing under a building.
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -3))
	player.global_position = Vector2(13 * 32 + 16, -3 * 32 + 16)
	player.facing = Vector2i.RIGHT
	_expect(shovel.actions().is_empty(), "can't dig under a building")

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
