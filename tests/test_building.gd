extends SceneTree
## Building: the free tent goes anywhere on land; the sanctuary only on the beach,
## costs 5 litter and doesn't spawn turtles; no overlaps; the Build menu offers
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

	# --- The ghost goes on the side the ranger moves towards ---
	var player: Node2D = world.get_node("Player")
	var ghost: Node2D = build_mode.get("_ghost")
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

	# --- Sanctuary: beach only, costs litter, no overlaps, no new turtle ---
	var animals_before := _count_animals()
	build_mode.start(sanctuary)
	inventory.add(load("res://data/items/plastic_bottle.tres"), 3)
	_expect(not build_mode.can_place(sanctuary, Vector2i(14, -1)), "not enough litter (3 of 5)")
	inventory.add(load("res://data/items/plastic_bag.tres"), 2)
	_expect(not build_mode.can_place(sanctuary, Vector2i(-3, -3)), "sanctuary can't go on grass")
	_expect(not build_mode.can_place(sanctuary, Vector2i(-1, -1)), "can't overlap the tent")
	_expect(build_mode.place_at(Vector2i(14, -1)), "sanctuary placed on the east beach")
	_expect(inventory.total() == 0, "litter used up")
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

	# --- Build menu ---
	var menu: Node = world.get_node("BuildMenu")
	root.get_node("Funding").restore({"balance": 150})
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
	menu.close()
	_expect(not paused, "closing unpauses")

	# --- Journal ---
	var screen: Node = world.get_node("JournalScreen")
	screen.open()
	_expect(_entry_text(screen, "Entry_green_turtle").contains("???"), "undiscovered species shows ???")
	screen.close()
	journal.discover(load("res://data/animals/green_turtle.tres"))
	screen.open()
	_expect(_entry_text(screen, "Entry_green_turtle").contains("Green Sea Turtle"), "discovered species listed")
	screen.close()

	# --- Sleep until morning ---
	clock.day = 1
	clock.time_of_day = 0.9
	_expect(clock.is_night(), "late evening is night")
	clock.sleep_until_morning()
	_expect(clock.day == 2 and absf(clock.time_of_day - 0.25) < 0.001, "slept until 6am on Day 2")

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


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
