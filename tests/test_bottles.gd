extends SceneTree
## Reusable glass bottles: once the first glass and the first clean water have been made, no new
## plastic bottles drift in on any island (less litter everywhere); old ones can still be dug up
## or washed ashore by a storm.
## Run: godot --headless --path . --script res://tests/test_bottles.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var fleet := root.get_node("Fleet")
	fleet.restore({})
	var spawner: Node = world.get_node("LitterSpawner")
	for d in get_nodes_in_group("debris"):
		d.free()
	var made := _drift(spawner, 400)
	_expect(made.has(&"plastic_bottle"), "plastic bottles drift in at first")
	fleet.mark(&"glass_made")
	_expect(not fleet.reusable_bottles(), "glass alone isn't enough")
	fleet.mark(&"clean_water_made")
	_expect(fleet.reusable_bottles(), "glass and clean water: reusable bottles unlocked")
	for d in get_nodes_in_group("debris"):
		d.free()
	made = _drift(spawner, 400)
	_expect(not made.has(&"plastic_bottle") and not made.is_empty(), "no new plastic bottles drift in (other litter still does: %s)" % [made.keys()])
	var dug := {}
	for i in 60:
		var d: Node = spawner.dig_up_at(Vector2(200, 40))
		dug[d.item.id] = true
	_expect(dug.has(&"plastic_bottle"), "old bottles can still be dug up")
	_expect(fleet.to_dict() is Dictionary and fleet.has_flag(&"clean_water_made"), "(saved with the fleet's flags)")
	fleet.restore({})
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _drift(spawner: Node, tries: int) -> Dictionary:
	var kinds := {}
	for i in tries:
		var d: Node = spawner.spawn_one()
		if d:
			kinds[d.item.id] = true
			d.free()
	return kinds


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
