extends SceneTree
## Rescue companions: once the Marine Search & Rescue Station is built, a young turtle found
## tangled and weak comes into the ranger's care. The ranger names it, then for 6 game days
## cares for it on the vet table: comfort it until it's calm enough to eat, feed it until it's
## full, medicine once a day (a hatchling has no wounds). The fed bar empties over a day and a
## bit; then health and calm drop, but never to nothing. Then it goes home tagged, in the shape the
## care left it in, and is seen again some mornings: on its own island, or (a turtle) on the
## Mangrove Coast or the Reef, never the Arctic. Its name shows once the ranger meets it again.
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
	_expect(turtle != null and turtle.species.id == &"green_turtle" and turtle.days == 6, "a young green turtle is found: 6 days of care")
	var player: Node2D = world.get_node("Player")
	player.global_position = station.global_position + Vector2(0, 50)
	var labels := func() -> Array: return station.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Care for the young turtle" in labels.call(), "the station offers its care (%s)" % [labels.call()])

	# --- Naming it ---
	var screen: Node = world.get_parent().find_child("RescueScreen", true, false)
	screen.open_rescue()
	var content: Node = screen.get("_content")
	_expect(screen.visible and content.find_child("NameField", true, false) != null and content.find_child("VetTable", true, false) != null,
		"on the vet table, seen from the front; the first visit asks for a name")
	(content.find_child("NameField", true, false) as LineEdit).text = "Milo"
	(content.find_child("NameIt", true, false) as Button).pressed.emit()
	await process_frame
	_expect(rescues.pet_name() == "Milo" and "Care for Milo" in labels.call(), "it's called Milo now")
	_expect(not rescues.hatched() and not rescues.can_do(&"feed"), "a turtle starts as an egg: nothing to do until it hatches")
	await create_timer(3.5).timeout  # (it hatches on the table once it's named)
	_expect(rescues.hatched(), "it hatches")
	await process_frame

	# --- A hatchling: healthy, no wounds; it eats only once it's calm ---
	content = screen.get("_content")
	_expect(content.find_child("Bars", true, false) != null and content.find_child("Care", true, false).get_child_count() == 4,
		"three bars, and four things to do")
	_expect(rescues.bar(&"health") >= 80 and rescues.wounds_left() == 1 and turtle.egg_damaged,
		"just hatched from its cracked egg: healthy (%d), with one wound on its flipper" % rescues.bar(&"health"))
	_expect(turtle.stage_pictures.size() == 6 and turtle.stage_points.size() == 6 and rescues.stage() == 0,
		"day 1: the first of its six pictures, one for each day in care")
	var vet: Control = content.find_child("VetScene", true, false)
	_expect(vet != null, "the vet room: the turtle hatchling on a towel on the counter")
	var drag := func(scene: Control, from: Vector2, to: Vector2) -> void:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = from
		scene.call("_gui_input", press)
		var move := InputEventMouseMotion.new()
		move.position = to
		scene.call("_gui_input", move)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = to
		scene.call("_gui_input", release)
	_expect(rescues.too_upset_to_eat() and not rescues.can_do(&"feed"), "a little unsettled (calm %d): it won't eat yet" % rescues.bar(&"calm"))
	var calm_before: int = rescues.bar(&"calm")
	(content.find_child("Comfort", true, false) as Button).pressed.emit()
	await process_frame
	_expect(rescues.bar(&"calm") > calm_before, "comforting it: calm goes up (the buttons work too: keyboard / controller)")
	while rescues.can_do(&"comfort"):
		rescues.care(&"comfort")
	_expect(rescues.bar(&"calm") == 100, "comfort it as often as you like, until it's fully calm")
	content = screen.get("_content")
	vet = content.find_child("VetScene", true, false)
	await process_frame  # (laid out)
	var food_at: Vector2 = vet.call("_tool_slot", 0)
	var fed_before: int = rescues.bar(&"fed")
	drag.call(vet, food_at, food_at + Vector2(0, -150))  # dropped somewhere else: nothing happens
	_expect(rescues.bar(&"fed") == fed_before, "food dropped away from its mouth: not fed")
	drag.call(vet, food_at, vet.call("_point", vet.call("_mouth")))
	await process_frame
	_expect(rescues.bar(&"fed") == fed_before + 10 and rescues.can_do(&"feed"), "food dragged to its mouth: +10 fed, and it can have more")
	while rescues.can_do(&"feed"):
		rescues.care(&"feed")
	_expect(rescues.bar(&"fed") == 100, "fed until the bar is full")
	var health_now: int = rescues.bar(&"health")
	rescues.care(&"medicine")
	_expect(rescues.bar(&"health") > health_now and not rescues.can_do(&"medicine"), "medicine: health goes up, once a day")
	await process_frame
	var vet_now: Control = screen.get("_content").find_child("VetScene", true, false)
	await process_frame  # (laid out)
	drag.call(vet_now, vet_now.call("_tool_slot", 2), vet_now.call("_point", vet_now.call("_wound")))
	await process_frame
	_expect(rescues.wounds_left() == 0, "the plaster dragged onto the flipper: patched")
	screen.close()

	# --- Left alone: the fed bar empties, then health and calm drop (never to nothing) ---
	var start_day: int = clock.day
	clock.advance(clock.DAY_LENGTH * 0.5)
	_expect(rescues.bar(&"fed") < 70 and rescues.bar(&"fed") > 40 and not rescues.distressed(), "half a day later it's getting hungry (fed %d)" % rescues.bar(&"fed"))
	_expect(rescues.bar(&"calm") < 100 and rescues.bar(&"calm") >= 50, "calm settles down a little, not below 50 (%d)" % rescues.bar(&"calm"))
	var health_full: int = rescues.bar(&"health")
	var calm_half: int = rescues.bar(&"calm")
	clock.advance(clock.DAY_LENGTH)
	_expect(rescues.bar(&"fed") == 0 and rescues.bar(&"health") < health_full and rescues.bar(&"calm") < calm_half and rescues.distressed(),
		"hungry for too long: health drops, and it gets distressed (health %d, calm %d)" % [rescues.bar(&"health"), rescues.bar(&"calm")])
	clock.advance(clock.DAY_LENGTH * 2)
	_expect(rescues.bar(&"calm") < 50, "distressed: now calm drops below 50 (%d)" % rescues.bar(&"calm"))
	_expect(rescues.bar(&"health") == 20 and rescues.bar(&"calm") >= 10, "but never to nothing: health stays at 20 (%d)" % rescues.bar(&"health"))
	_expect(rescues.too_upset_to_eat(), "first it has to be calmed down again")
	while rescues.can_do(&"comfort"):
		rescues.care(&"comfort")
	while rescues.can_do(&"feed"):
		rescues.care(&"feed")
	var mended: int = rescues.bar(&"health")
	_expect(rescues.bar(&"calm") == 100 and rescues.bar(&"fed") == 100 and mended > 20, "calmed, then fed: health starts to mend (%d)" % mended)
	_expect(clock.day > start_day, "")

	# --- Caring every day until it's ready ---
	for day in 6:
		clock.advance(clock.DAY_LENGTH * 0.5)
		for action in [&"comfort", &"comfort", &"comfort", &"comfort", &"comfort", &"medicine"]:
			rescues.care(action)
		for bite in 10:
			rescues.care(&"feed")
		clock.advance(clock.DAY_LENGTH * 0.5)
		for bite in 10:
			rescues.care(&"comfort")
			rescues.care(&"feed")
	_expect(rescues.is_ready() and "Release Milo" in labels.call(), "after 6 days Milo is ready to go home")
	_expect(rescues.stage() == 5 and turtle.picture(5) == turtle.stage_pictures[5] and turtle.size_at(5) > turtle.size_at(0) * 2.0,
		"grown: its sixth picture, more than twice the size of the first")
	_expect(rescues.shape() > 0.75, "cared for every day: in good shape (%.2f)" % rescues.shape())

	# --- Saved while in care ---
	var fed_saved: int = rescues.bar(&"fed")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(rescues.to_dict()))
	rescues.restore({})
	rescues.restore(saved)
	_expect(rescues.pet_name() == "Milo" and rescues.is_ready() and rescues.bar(&"fed") == fed_saved, "the rescue in care is saved, bars and all (fed %d)" % rescues.bar(&"fed"))

	# --- Release: tagged, on its island ---
	screen.open_rescue()
	content = screen.get("_content")
	(content.find_child("Release", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(rescues.in_care() == null and rescues.done[&"home_turtle"].name == "Milo" and rescues.done[&"home_turtle"].shape > 0.75,
		"released: Milo's story is kept, with the shape it went home in")
	var milo: Node2D = world.get_node_or_null("Rescued_home_turtle")
	_expect(milo != null and milo.data.id == &"green_turtle" and milo.get_node("Sprite2D").get_children().any(func(c: Node) -> bool: return c is TagBand),
		"Milo swims by the station with a bright tag")
	screen.close()

	# --- Where it turns up: its island or the islands it travels to, never the Arctic ---
	for id in ["mangrove_coast", "tropical_reef", "arctic_ocean"]:
		load("res://scripts/world/regions.gd").discover(load("res://data/regions/%s.tres" % id))
	var places := {}
	for i in 200:
		var at: String = rescues.call("_roll_where", turtle, 1.0)
		places[at] = places.get(at, 0) + 1
	_expect(places.has("home_island") and places.has("tropical_reef") and places.has("mangrove_coast") and not places.has("arctic_ocean"),
		"a turtle turns up at home, on the Mangrove Coast and the Reef, never the Arctic (%s)" % [places])
	var away := 0
	for i in 400:
		if rescues.call("_roll_where", turtle, 0.2) == "":
			away += 1
	var away_well := 0
	for i in 400:
		if rescues.call("_roll_where", turtle, 1.0) == "":
			away_well += 1
	_expect(away > away_well, "one that went home in better shape is seen more often (%d vs %d days away)" % [away, away_well])
	rescues.done[&"home_turtle"].met = false
	rescues.done[&"home_turtle"].where = "home_island"
	rescues.place_all()
	await process_frame
	milo = world.get_node("Rescued_home_turtle")
	_expect(not milo.get_node("NameTag").visible, "its name only shows once the ranger has met it again")
	player.global_position = milo.global_position + Vector2(20, 0)
	milo.call("_interact")
	await process_frame
	await process_frame
	_expect(world.get_node("Rescued_home_turtle").get_node("NameTag").visible, "met again (a photo): 'Milo' over it from now on")

	# --- Every island's rescue is complete ---
	for id in ["home_turtle", "kelp_otter", "mangrove_flamingo", "reef_seahorse", "deep_sixgill", "polar_seal"]:
		var one: Resource = load("res://data/rescues/%s.tres" % id)
		_expect(one.days == 6 and one.day_texts.size() == 6 and one.vet_picture != null and one.feed_label != "" and one.medicine_result != "",
			"%s is complete" % id)

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
