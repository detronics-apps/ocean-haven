extends SceneTree
## The end of the story (the owner): every island's objective done, the fleet at its top level and
## every kind of litter stopped at its source: the Clue Board opens by itself, the globe is placed,
## then "Who created all of this?", and a moment later the end credits roll.
## Run: godot --headless --path . --script res://tests/test_ending_sequence.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var fleet := root.get_node("Fleet")
	var clues := root.get_node("Clues")
	root.get_node("People").restore({})
	fleet.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var all_six := ["salvaged_sonar_core", "kelp_fibre", "mangrove_resin", "reef_limestone", "cargo_module", "ice_core"]
	var flags := ["sonar_recovered", "kelp_balanced", "mangrove_flowing", "reef_restored", "deep_mapped", "polar_balanced",
		"gear_recovered", "fibres_traced", "gear_traced"]
	fleet.restore({"installed": all_six, "flags": flags})
	var regions: GDScript = load("res://scripts/world/regions.gd")
	for region: Resource in regions.all():
		regions.discover(region)
	var build: Node = world.get_node("BuildMode")
	var spots := {"refill_bar": Vector2i(-12, -12), "weaving_workshop": Vector2i(-16, -12), "box_return_depot": Vector2i(-20, -12),
		"filter_workshop": Vector2i(-24, -12), "net_return_point": Vector2i(-32, -12)}
	var hud: Node = world.get_node("HUD")
	_expect(not fleet.has_flag(&"ending_started"), "(not yet)")
	for id in spots:
		build.add_building(load("res://data/buildings/%s.tres" % id), spots[id])
	if not fleet.stopped(&"plastic_bottle"):  # (reusable bottles: stood in for here)
		var data: Resource = load("res://data/buildings/box_return_depot.tres").duplicate()
		data.stops_litter = PackedStringArray(["plastic_bottle"])
		build.add_building(data, Vector2i(-28, -12))
	await process_frame
	_expect(load("res://scripts/ui/observatory_screen.gd").final_chapter(), "every island helped, the fleet at its top, every source stopped")
	var journal: Node = world.find_child("JournalScreen", true, false)
	for i in 120:  # (the HUD looks every second)
		await process_frame
		if journal.visible:
			break
	_expect(fleet.has_flag(&"ending_started") and journal.visible and journal.get("tab") == journal.CLUES,
		"the Clue Board opens by itself")
	await create_timer(1.5).timeout
	_expect(clues.is_found(&"conclusion_globe") and not clues.is_open(&"final_who"), "the globe goes down first")
	await create_timer(2.6).timeout
	_expect(clues.is_open(&"final_who"), "then the question: who created all of this?")
	var credits: Node = world.find_child("ObservatoryScreen", true, false).credits()
	_expect(not credits.is_playing(), "a pause before the credits")
	await create_timer(2.8).timeout
	_expect(credits.is_playing() and not journal.visible and fleet.has_flag(&"credits_seen"), "then the end credits roll")
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
