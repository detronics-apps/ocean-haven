extends SceneTree
## Rescue companions: once the Marine Search & Rescue Station is built, a young turtle found
## tangled and weak comes into the ranger's care. The ranger names it and helps it each day
## with a care moment (the wrong choice only explains why not); it recovers over 30 days in
## stages (the staff care for it while the ranger is away; it never gets worse); then it's
## released and lives on the island with its name. One at a time; saved.
## Run: godot --headless --path . --script res://tests/test_rescue.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var rescues := root.get_node("Rescues")
	var clock := root.get_node("GameClock")
	rescues.restore({})
	root.get_node("People").restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	clock.day = 3
	clock.time_of_day = 0.4
	rescues.call("_offer")
	_expect(rescues.in_care() == null, "no rescue before there's a rescue station")

	# --- The station is built: a young turtle comes into the ranger's care ---
	var station: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/marine_rescue_station.tres"), Vector2i(-6, -6))
	rescues.call("_offer")
	var turtle: Resource = rescues.in_care()
	_expect(turtle != null and turtle.species.id == &"green_turtle", "a young green turtle is found and brought to the station")
	var player: Node2D = world.get_node("Player")
	player.global_position = station.global_position + Vector2(0, 50)
	var labels := func() -> Array: return station.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Care for the young turtle" in labels.call(), "the station offers its care (%s)" % [labels.call()])

	# --- Naming it ---
	var screen: Node = world.get_parent().find_child("RescueScreen", true, false)
	screen.open_rescue()
	var content: Node = screen.get("_content")
	_expect(screen.visible and content.find_child("NameField", true, false) != null, "the first visit asks for a name")
	(content.find_child("NameField", true, false) as LineEdit).text = "Milo"
	(content.find_child("NameIt", true, false) as Button).pressed.emit()
	await process_frame
	_expect(rescues.pet_name() == "Milo" and "Care for Milo" in labels.call(), "it's called Milo now")

	# --- Today's care moment: the wrong choice only explains, the right one counts ---
	content = screen.get("_content")
	_expect(rescues.can_care(), "there's a care moment today")
	(content.find_child("Other", true, false) as Button).pressed.emit()
	await process_frame
	_expect(rescues.can_care(), "the other choice only explains why not: try again")
	content = screen.get("_content")
	(content.find_child("Right", true, false) as Button).pressed.emit()
	await process_frame
	_expect(not rescues.can_care(), "the right one: Milo is cared for today")
	screen.close()

	# --- It recovers in stages over 30 days, cared for or not ---
	var stages: Array = []
	rescues.stage_reached.connect(func(_r: Resource, stage: int) -> void: stages.append(stage))
	for day in 30:
		clock.advance(clock.DAY_LENGTH)
		rescues.call("_process", 2.0)
	_expect(stages == [1, 2, 3, 4, 5], "eating, swimming, exploring, wild again, ready: one stage after another (%s)" % [stages])
	_expect(rescues.is_ready() and "Release Milo" in labels.call(), "after 30 days Milo is ready to go home")

	# --- Saved while in care ---
	var saved: Dictionary = rescues.to_dict()
	rescues.restore({})
	rescues.restore(JSON.parse_string(JSON.stringify(saved)))
	_expect(rescues.pet_name() == "Milo" and rescues.is_ready(), "the rescue in care is saved")

	# --- Release: a milestone; Milo lives on the island ---
	screen.open_rescue()
	content = screen.get("_content")
	(content.find_child("Release", true, false) as Button).pressed.emit()
	await process_frame
	_expect(rescues.in_care() == null and rescues.done.has(&"home_turtle") and rescues.done[&"home_turtle"].name == "Milo",
		"released: Milo's story is kept")
	var milo: Node2D = world.get_node_or_null("Rescued_home_turtle")
	_expect(milo != null and milo.data.id == &"green_turtle" and load("res://scripts/world/terrain.gd").at(self, milo.global_position) in ["water", ""],
		"Milo swims in the island's waters")
	screen.close()
	rescues.call("_offer")
	_expect(rescues.in_care() == null, "no second rescue on the same island")
	_expect(world.get_node("HUD") != null, "(HUD)")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
