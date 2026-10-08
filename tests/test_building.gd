extends SceneTree
## Building: the free tent goes anywhere on land; the sanctuary only on the beach,
## costs funding (no litter) and doesn't spawn turtles; no overlaps; the Build menu offers
## what's buildable and shows locked entries; the Journal lists species; sleeping
## skips to morning.
## Run: godot --headless --path . --script res://tests/test_building.gd --quit-after 100000

var _failed := false


func _initialize() -> void:
	await process_frame
	var inventory := root.get_node("Inventory")  # autoloads: looked up at runtime
	var journal := root.get_node("Journal")
	var clock := root.get_node("GameClock")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var build_mode: Node = world.get_node("BuildMode")
	var tent: Resource = load("res://data/buildings/tent.tres")
	var sanctuary: Resource = load("res://data/buildings/turtle_protection_area.tres")

	# --- Asked to place the tent while in the boat: can still go ashore first ---
	var boat: Node2D = world.get_node("Boat")  # untyped: Boat uses autoloads
	boat.restore_aboard()
	build_mode.start(tent, true)
	await physics_frame
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	root.push_input(e)  # delivered straight to the game (parse_input_event isn't flushed here)
	for i in 5:
		await physics_frame
	_expect(not boat.controlled and world.get_node("Player").visible, "can go ashore while the tent waits")
	_expect(build_mode.is_active(), "tent placement still waiting")

	# --- The ghost goes on the side the ranger moves towards (on open land, where
	# a tent fits on every side, so it doesn't need to snap elsewhere) ---
	var player: Node2D = world.get_node("Player")
	var ghost: Node2D = build_mode.get("_ghost")
	player.global_position = Vector2(-12 * 32 + 16, -3 * 32 + 16)
	for side in [Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2.RIGHT]:
		for i in 4:
			player.global_position += side * 2.0  # walking that way
			await process_frame
		var offset: Vector2 = ghost.global_position - player.global_position
		_expect(offset.normalized().dot(side) > 0.7, "ghost on the %s side (offset %s)" % [side, offset])
	player.global_position = Vector2.ZERO

	# --- Tent: free, anywhere on land, not in the sea ---
	_expect(not build_mode.can_place(tent, Vector2i(-20, 0)), "tent can't go in the sea")
	_expect(build_mode.place_at(Vector2i(-1, -1)), "free tent placed on the grass")
	_expect(_count("tent") == 1, "tent exists")

	# --- Move it: a Move button next to it; placing again is free; cancel puts it back ---
	var tent_node: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"tent")[0]
	player.global_position = tent_node.global_position + Vector2(-40, 20)
	await process_frame
	await process_frame
	var labels: Array = world.get_node("HUD/ActionZone/ActionBar").get_children().filter(func(b: Node) -> bool: return b is Button).map(func(b: Button) -> String: return b.text)
	_expect("Move tent" in labels, "a 'Move Tent' button appears in the action bar (%s)" % [labels])
	# A tap just beside the buttons (a near miss) doesn't walk the ranger off.
	var button: Control = world.get_node("HUD/ActionZone/ActionBar").get_children().filter(func(b: Node) -> bool: return b is Button)[0]
	for miss in [button.get_global_rect().position + Vector2(-12, 10), button.get_global_rect().end + Vector2(0, 4)]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = miss
		click.global_position = miss
		root.push_input(click, true)
		var release := click.duplicate()
		release.pressed = false
		root.push_input(release, true)
		await physics_frame
		_expect(not player.get("_has_target"), "a near miss by the action buttons doesn't walk the ranger (%s)" % miss)
	var elsewhere := InputEventMouseButton.new()
	elsewhere.button_index = MOUSE_BUTTON_LEFT
	elsewhere.pressed = true
	elsewhere.position = button.get_global_rect().position - Vector2(120, 120)
	root.push_input(elsewhere, true)
	_expect(player.get("_has_target"), "a tap further away still walks there")
	player.stop()
	# Portrait phones: the bottom UI moves up, clear of the rounded screen corners.
	var minimap: Control = world.get_node("HUD/Minimap")
	var landscape_bottom := minimap.offset_bottom
	var old_size := root.size
	root.size = Vector2i(600, 1200)
	await process_frame
	_expect(minimap.offset_bottom < landscape_bottom - 20.0, "portrait: the minimap moves up (%.0f -> %.0f)" % [landscape_bottom, minimap.offset_bottom])
	root.size = old_size
	await process_frame
	build_mode.start_move(tent_node)
	_expect(build_mode.place_at(Vector2i(-3, -3)), "tent moved to a new spot")
	_expect(tent_node.cell == Vector2i(-3, -3) and tent_node.visible and _count("tent") == 1, "it's there, still just one tent")
	build_mode.start_move(tent_node)
	build_mode.cancel()
	_expect(tent_node.cell == Vector2i(-3, -3) and tent_node.visible and _count("tent") == 1, "cancel leaves it where it was")
	build_mode.start_move(tent_node)
	build_mode.place_at(Vector2i(-1, -1))  # back where the rest of the test expects it
	player.global_position = Vector2.ZERO

	# --- Sanctuary: beach only, costs funding (no litter), no overlaps, no new turtle ---
	var animals_before := _count_animals()
	inventory.restore(inventory.to_dict(), {"wood": 99})  # building wood, kept in storage
	root.get_node("Funding").restore({"balance": 1000})
	build_mode.start(sanctuary)
	inventory.add(load("res://data/items/plastic_bottle.tres"), 3)
	_expect(sanctuary.cost_litter == 0 and sanctuary.cost_funding > 0, "it costs funding, not litter")
	_expect(not build_mode.can_place(sanctuary, Vector2i(-3, -3)), "sanctuary can't go on grass")
	_expect(not build_mode.can_place(sanctuary, Vector2i(-1, -1)), "can't overlap the tent")
	_expect(build_mode.place_at(Vector2i(14, -1)), "sanctuary placed on the east beach")
	_expect(inventory.total() == 3, "the litter is kept")
	_expect(_count_animals() == animals_before, "no turtle spawned by the sanctuary")
	inventory.add(load("res://data/items/plastic_bottle.tres"), 20)
	build_mode.start(sanctuary)
	_expect(build_mode.place_at(Vector2i(-8, 7)), "second protection area")
	build_mode.start(sanctuary)
	_expect(build_mode.place_at(Vector2i(8, 7)), "third protection area")
	build_mode.start(sanctuary)
	_expect(not build_mode.can_place(sanctuary, Vector2i(-4, -10)), "no more than 3 protection areas")
	build_mode.cancel()
	inventory.take(inventory.total())

	# --- Moving a protection area takes its eggs along ---
	var east_area: Node2D = get_nodes_in_group("buildings").filter(
		func(b: Node) -> bool: return b.data.id == &"turtle_protection_area" and b.cell == Vector2i(14, -1))[0]
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", load("res://data/animals/green_turtle.tres"))
	nest.set("laid_at", 1000.0)  # far from hatching
	nest.set("area", east_area)
	nest.global_position = east_area.global_position + Vector2(6, 4)
	world.add_child(nest)
	build_mode.start_move(east_area)
	build_mode.place_at(Vector2i(-15, -1))  # the west beach
	_expect(nest.global_position.distance_to(east_area.global_position + Vector2(6, 4)) < 0.1,
		"the eggs moved with their protection area")
	build_mode.start_move(east_area)
	build_mode.place_at(Vector2i(14, -1))
	nest.free()

	# --- Build menu ---
	var menu: Node = world.get_node("BuildMenu")
	root.get_node("Funding").restore({"balance": 150})
	inventory.add(load("res://data/items/plastic_bottle.tres"), 1)  # a dock plank needs 1
	menu.open()
	_expect(paused, "menu pauses the game")
	_expect(menu.find_child("Entry_dock", true, false).find_child("Build", true, false) != null,
		"affordable building offers Build")
	_expect(_entry_text(menu, "Entry_turtle_protection_area").contains("as many as you can"),
		"protection areas at their limit say so")
	_expect(menu.find_child("Entry_house", true, false).find_child("Build", true, false) == null,
		"house can't be built without the litter it needs")
	_expect(menu.find_child("Entry_tent", true, false).find_child("Build", true, false) == null,
		"only one tent")
	_expect(menu.find_child("Entry_coral_restoration_lab", true, false) == null and menu.find_child("Entry_marine_rescue_station", true, false) != null,
		"only what can be built on this island is listed (no Coral Restoration Lab here)")
	(menu.find_child("TabLand", true, false) as Button).pressed.emit()
	var shown: Array = menu.find_children("Entry_*", "", true, false).map(func(e: Node) -> String: return e.name)
	shown.sort()
	_expect(shown == ["Entry_palm_tree", "Entry_shovel"], "Land tab: trees and the shovel (%s)" % [shown])
	(menu.find_child("TabAll", true, false) as Button).pressed.emit()
	menu.close()
	_expect(not paused, "closing unpauses")

	# --- Journal ---
	var screen: Node = world.get_node("JournalScreen")
	screen.show_tab(&"animals")
	screen.open()
	_expect(_entry_text(screen, "Entry_green_turtle").contains("???"), "undiscovered species shows ???")
	screen.close()
	journal.discover(load("res://data/animals/green_turtle.tres"))
	screen.open()
	_expect(_entry_text(screen, "Entry_green_turtle").contains("no photo yet"), "spotted, but not in the Journal until photographed")
	screen.close()
	journal.photograph(load("res://data/animals/green_turtle.tres"))
	screen.open()
	_expect(_entry_text(screen, "Entry_green_turtle").contains("Green Sea Turtle"), "photographed: in the Journal")
	screen.close()

	# --- Sleep until morning ---
	clock.day = 1
	clock.time_of_day = 0.9
	_expect(clock.is_night(), "late evening is night")
	clock.sleep_until_morning()
	_expect(clock.day == 2 and absf(clock.time_of_day - 0.25) < 0.001, "slept until 6am on Day 2")

	# --- A tent and up to 2 Ranger Houses on every island ---
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	var house: Resource = load("res://data/buildings/house.tres")
	var home_tents := func() -> int:
		return get_nodes_in_group("buildings").filter(func(b: Node) -> bool:
			return b.data.id == &"tent" and not b.is_queued_for_deletion() and b.global_position.length() < 2000.0).size()
	var tents_here: int = home_tents.call()
	var kelp_cell := _land_cell_near(build_mode, tent, kelp.arrival)
	_expect(build_mode.placement_problem(tent, kelp_cell) == "", "a tent can go up on the Kelp Forest too (%s)" % build_mode.placement_problem(tent, kelp_cell))
	build_mode.add_building(tent, kelp_cell)
	_expect(build_mode.placement_problem(tent, _land_cell_near(build_mode, house, kelp.arrival + Vector2(0, 96))) != "", "but only one there")
	root.get_node("Funding").restore({"balance": 1000})
	inventory.restore({"plastic_bottle": 50}, {"wood": 50})
	build_mode.start(house)
	var house_cell := _land_cell_near(build_mode, house, kelp.arrival + Vector2(96, 0))
	_expect(build_mode.place_at(house_cell), "a Ranger House on the Kelp Forest (%s)" % build_mode.placement_problem(house, house_cell))
	await process_frame
	_expect(home_tents.call() == tents_here, "it replaces the tent there, not the one on the Starting Island")
	build_mode.cancel()

	# --- "What is this?": markers always, buildings only when nothing else says what they are ---
	var asks_what := func(b: Node2D) -> Array:
		world.get_node("Player").global_position = b.global_position + Vector2(0, 40)
		return b.actions().filter(func(a: Dictionary) -> bool: return a.label == "What is this?")
	var spot := func(id: String, near: Vector2) -> Vector2i:
		return _land_cell_near(build_mode, load("res://data/buildings/%s.tres" % id), near)
	var refill: Node2D = build_mode.add_building(load("res://data/buildings/refill_bar.tres"), spot.call("refill_bar", kelp.arrival + Vector2(-160, 0)))
	var asks: Array = asks_what.call(refill)
	_expect(asks.size() == 1, "a building with no button of its own (the Refill Bar) offers 'What is this?'")
	asks[0].do.call()
	var info: Node = world.get_parent().find_child("BuildingInfo", true, false)
	var said := info.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_expect(info.visible and said.has(refill.data.description) and said.has(refill.data.fact), "it shows what it's for, and a real-life fact")
	info.close()
	var platform: Node2D = build_mode.add_building(load("res://data/buildings/kelp_research_platform.tres"), spot.call("kelp_research_platform", kelp.arrival + Vector2(160, 96)))
	_expect(asks_what.call(platform).is_empty(), "a building whose own button says what it is (Missions) doesn't")
	var otters: Node2D = build_mode.add_building(load("res://data/buildings/otter_habitat.tres"), spot.call("otter_habitat", kelp.arrival + Vector2(-96, 160)))
	_expect(asks_what.call(otters).size() == 1, "markers and enclosures (an Otter Habitat) always do")
	for id in ["water_gate", "hydrophone_buoy"]:
		_expect(load("res://data/buildings/%s.tres" % id).explains == 2, "%s: always explained" % id)
	for id in ["dock", "drawbridge", "deep_camera", "palm_tree", "rowboat", "patrol_boat"]:
		_expect(load("res://data/buildings/%s.tres" % id).explains == 0, "%s is a built item: never" % id)
	var no_fact: Array = Array(DirAccess.get_files_at("res://data/buildings")).filter(func(f: String) -> bool:
		return f.ends_with(".tres") and f != "shovel.tres" and (load("res://data/buildings/" + f).fact == "" or load("res://data/buildings/" + f).description == ""))
	_expect(no_fact.is_empty(), "every building has a description and a fact (%s)" % [no_fact])

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _count(id: String) -> int:
	return get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == id).size()


func _count_animals() -> int:
	return get_nodes_in_group("animals").size()


func _entry_text(screen: Node, entry_name: String) -> String:
	var text := ""
	for label in screen.find_child(entry_name, true, false).find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


## A cell near `point` where `data` fits (or the nearest one tried).
func _land_cell_near(build_mode: Node, data: Resource, point: Vector2) -> Vector2i:
	var start := Vector2i((point / 32.0).floor())
	for r in range(0, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := start + Vector2i(dx, dy)
				if build_mode.placement_problem(data, c) == "" or (data.id == &"tent" and build_mode.placement_problem(data, c).contains("already")):
					return c
	return start


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
