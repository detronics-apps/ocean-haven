extends SceneTree
## Save, "restart" (wipe everything), load into a fresh world: inventory,
## discoveries, collected litter, built sanctuary, positions and boat all come
## back. A damaged save is set aside as .bad, never overwritten.
## Run: godot --headless --path . --script res://tests/test_save.gd

const PATH := "user://test_save.json"

# Autoloads looked up at runtime: --script compiles before autoloads exist.
var _save: Node
var _inventory: Node
var _journal: Node
var _failed := false


func _initialize() -> void:
	await process_frame  # let the tree start, so added worlds get _ready()
	_save = root.get_node("SaveGame")
	_inventory = root.get_node("Inventory")
	_journal = root.get_node("Journal")
	for f in [PATH, PATH + ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	# --- Play a bit, then save ---
	var world := _new_world()
	_inventory.add(load("res://data/items/plastic_bottle.tres"), 7)
	_journal.discover(load("res://data/animals/green_turtle.tres"))
	var debris := world.get_node("Debris1")
	_save.mark_collected(debris)
	debris.free()
	_expect(world.get_node("TurtleSanctuarySite").build(), "built the sanctuary (uses 5 of 7)")
	(world.get_node("Player") as Node2D).global_position = Vector2(-100, 50)
	(world.get_node("Boat") as Node2D).global_position = Vector2(16, 300)
	world.get_node("Boat").restore_aboard()
	var clock := root.get_node("GameClock")
	clock.day = 4
	clock.time_of_day = 0.8
	_expect(_save.save_to(world, PATH), "saved")
	world.free()

	# --- "Restart": empty state, fresh world, load ---
	_inventory.restore({})
	_journal.restore([])
	clock.day = 1
	clock.time_of_day = 0.3
	world = _new_world()
	_expect(_save.load_from(world, PATH), "loaded")
	_expect(clock.day == 4 and absf(clock.time_of_day - 0.8) < 0.01, "day and time restored")
	_expect(_inventory.count(&"plastic_bottle") == 2, "inventory restored (2 bottles)")
	_expect(_journal.has(&"green_turtle"), "discovery restored")
	_expect(world.get_node("Debris1").is_queued_for_deletion(), "collected litter stays gone")
	_expect(world.get_node("TurtleSanctuarySite").is_built, "sanctuary stays built")
	_expect(_count_animals(world) == 2, "sanctuary's turtle is back")
	_expect((world.get_node("Player") as Node2D).global_position == Vector2(-100, 50), "ranger position restored")
	_expect((world.get_node("Boat") as Node2D).global_position == Vector2(16, 300), "boat position restored")
	_expect(world.get_node("Boat").controlled and not world.get_node("Player").visible, "still aboard")
	world.free()

	# --- A damaged save is kept aside, not overwritten ---
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	world = _new_world()
	_expect(not _save.load_from(world, PATH), "damaged save not loaded")
	_expect(FileAccess.file_exists(PATH + ".bad") and not FileAccess.file_exists(PATH), "damaged save kept as .bad")
	world.free()

	for f in [PATH, PATH + ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _new_world() -> Node:
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	return world


func _count_animals(world: Node) -> int:
	var n := 0
	for child in world.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path == "res://scripts/animals/animal.gd":
			n += 1
	return n


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
