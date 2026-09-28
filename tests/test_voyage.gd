extends SceneTree
## Voyages: the rowboat can't leave its island's coastal waters; the voyage map
## lists every region; Tropical Waters unlocks once home has a patrol boat; with an
## Expedition Boat you set sail and arrive ashore there with your rowboat; and back.
## Run: godot --headless --path . --script res://tests/test_voyage.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")  # autoloads: looked up at runtime
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var player: Node2D = world.get_node("Player")
	var boat: Node2D = world.get_node("Boat")  # untyped: Boat uses autoloads
	var build_mode: Node = world.get_node("BuildMode")
	var tropical: Resource = load("res://data/regions/tropical_waters.tres")

	# --- The rowboat stays in its coastal waters ---
	boat.restore_aboard()
	boat.global_position = Vector2(1050, 0)
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	_expect(boat.global_position.length() <= 1102.0, "rowboat turns back at the edge of home waters (%.0f)" % boat.global_position.length())
	boat.restore_ashore()
	boat.global_position = Vector2(16, 112)
	player.global_position = Vector2(0, 40)

	# --- The map before you can sail ---
	var map: Node = world.get_node("VoyageMap")
	map.open()
	_expect(_entry(map, "tropical_waters").contains("Patrol Boat"), "Tropical Waters: build a patrol boat first")
	_expect(_entry(map, "coral_kingdom").contains("Coming later"), "later regions are shown as coming later")
	_expect(map.find_children("Sail", "Button", true, false).is_empty(), "no sailing without an Expedition Boat")
	map.close()

	# --- Expedition Boat (needs the dock) + a patrol boat unlocks Tropical Waters ---
	funding.earn(1000, "test")
	var expedition: Resource = load("res://data/buildings/expedition_boat.tres")
	build_mode.start(expedition)
	_expect(not build_mode.can_place(expedition, Vector2i(-3, 7)), "expedition boat needs a dock first")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))
	_expect(not build_mode.can_place(expedition, Vector2i(-4, 8)), "expedition boat must moor next to a dock")
	_expect(not build_mode.can_place(expedition, Vector2i(-3, 6)), "one dock plank beside it isn't enough")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-2, 5))
	_expect(build_mode.place_at(Vector2i(-3, 6)), "expedition boat moored beside 2 dock planks")
	build_mode.add_building(load("res://data/buildings/patrol_boat.tres"), Vector2i(-24, 0))

	# --- Set sail ---
	map.open()
	var sail: Button = map.find_child("Entry_tropical_waters", true, false).find_child("Sail", true, false)
	_expect(sail != null, "Tropical Waters is ready to visit")
	if sail:
		sail.pressed.emit()
		for i in 240:
			await process_frame
		_expect(player.global_position == tropical.arrival, "arrived ashore at Tropical Waters")
		_expect(boat.global_position == tropical.boat_mooring, "rowboat moored beside you")
		_expect(_terrain(player.global_position) == "sand" and _terrain(boat.global_position) == "water",
			"standing on its beach, boat in the shallows")
		_expect(player.visible and not boat.controlled, "on foot")

		# --- And home again ---
		map.open()
		var home_sail: Button = map.find_child("Entry_home_island", true, false).find_child("Sail", true, false)
		home_sail.pressed.emit()
		for i in 240:
			await process_frame
		_expect(player.global_position == Vector2(0, 40), "sailed home again")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _entry(map: Node, id: String) -> String:
	var text := ""
	for label in map.find_child("Entry_" + id, true, false).find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
