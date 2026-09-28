extends SceneTree
## The Coastal Storm (the Starting Island's rare event): warned a day ahead; secured
## buildings come through fine; unsecured ones may be damaged (closed to visitors, no
## nesting) until repaired with wood; litter washes up. Never within 30 days of the last one.
## Its state is saved.
## Run: godot --headless --path . --script res://tests/test_storm.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var events := root.get_node("RareEvents")
	var clock := root.get_node("GameClock")
	var inventory := root.get_node("Inventory")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var storm: Resource = load("res://data/events/coastal_storm.tres")
	var build_mode: Node = world.get_node("BuildMode")
	var area: Node2D = build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	var viewing: Node2D = build_mode.add_building(load("res://data/buildings/dolphin_viewing_area.tres"), Vector2i(-6, -4))
	var dock: Node2D = build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))

	# --- Never in the first 30 days; then now and then ---
	clock.day = 1
	for i in 28:
		clock.time_of_day = 0.9
		clock.sleep_until_morning()
	_expect(not events.is_coming(), "no storm in the first 30 days")
	events.restore({})

	# --- Warned a day ahead: secure what you can ---
	clock.day = 40
	events.warn(storm)
	_expect(events.is_coming() and world.get_node("HUD/EventNote").text == "", "warned (the HUD note shows next frame)")
	await process_frame
	_expect((world.get_node("HUD/EventNote") as Label).text.contains("Storm tomorrow"), "the HUD says a storm is coming")
	var player: Node2D = world.get_node("Player")
	player.global_position = area.global_position + Vector2(0, 50)
	var secure: Array = area.actions().filter(func(a: Dictionary) -> bool: return a.label == "Secure for the storm")
	_expect(secure.size() == 1, "offers to secure the protection area")
	secure[0].do.call()
	_expect(area.secured and area.stats().contains("Secured"), "secured")
	player.global_position = dock.global_position + Vector2(0, -40)
	_expect(dock.actions().filter(func(a: Dictionary) -> bool: return a.label.begins_with("Secure")).is_empty(), "docks are storm-proof")

	# --- It strikes the next morning ---
	storm.damage_chance = 1.0
	var litter: int = get_nodes_in_group("debris").size()
	clock.time_of_day = 0.9
	clock.sleep_until_morning()
	_expect(not events.is_coming(), "the storm has passed")
	_expect(not area.damaged and not area.secured, "the secured protection area is fine")
	_expect(viewing.damaged and viewing.visitors_today() == 0 and viewing.stats() == "Damaged",
		"the unsecured viewing area is damaged and closed to visitors")
	_expect(not dock.damaged, "the dock is fine")
	_expect(get_nodes_in_group("debris").size() == litter + storm.litter_washed, "litter washed up on the beaches")

	# --- Repair ---
	player.global_position = viewing.global_position + Vector2(0, 50)
	inventory.restore({}, {})
	viewing.repair()
	_expect(viewing.damaged, "repairing needs wood")
	inventory.add(load("res://data/items/wood.tres"), 1)
	var repair: Array = viewing.actions().filter(func(a: Dictionary) -> bool: return a.label.begins_with("Repair"))
	_expect(repair.size() == 1, "offers a repair")
	repair[0].do.call()
	_expect(not viewing.damaged and viewing.visitors_today() > 0 and inventory.available(&"wood") == 0, "repaired with 1 wood: open again")

	# --- A damaged protection area: no nesting until it's repaired ---
	area.damaged = true
	var turtle: Node2D = world.get_node("GreenTurtle")
	_expect(turtle.call("_nest_site") == null, "turtles won't nest at a damaged area")
	area.damaged = false
	_expect(turtle.call("_nest_site") == area, "repaired: they will again")

	# --- Not again for 30 days ---
	events.restore({"last_day": {"coastal_storm": clock.day}})
	storm.chance_per_day = 1.0
	for i in 29:
		clock.time_of_day = 0.9
		clock.sleep_until_morning()
	_expect(not events.is_coming(), "no storm within 30 days of the last")
	clock.time_of_day = 0.9
	clock.sleep_until_morning()
	_expect(events.is_coming(), "after that it can come again")
	var saved: Dictionary = events.to_dict()
	events.restore({})
	events.restore(saved)
	_expect(events.is_coming(), "a coming storm is saved")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
