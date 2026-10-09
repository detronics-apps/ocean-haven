extends SceneTree
## The Coastal Storm (the Starting Island's rare event): warned 2 days ahead (clouds gather
## beyond the island's waters, its people get nervous); on its day it passes over 10 s after
## the ranger is there (10 s of storm), the day after only its end (5 s), later only the
## aftermath. Secured buildings come through fine; unsecured ones may be damaged (a warning
## sign; closed to visitors, no nesting; only "Fix": funding + wood); 20-35 litter all over the
## island and some at sea; its people talk about it. An island's first comes 15-25 days after
## the ranger gets there, then 30-60 days apart.
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

	# --- Never in the first 15 days on an island; then now and then ---
	clock.day = 1
	for i in 10:  # the first can only strike from day 16 (warned 3-4 days ahead)
		clock.time_of_day = 0.9
		clock.sleep_until_morning()
	_expect(not events.is_coming(), "no storm in the first 15 days")
	events.restore({"first_on": {"home_island": 1}})

	# --- Warned days ahead: secure what you can ---
	clock.day = 40
	events.warn(storm, 2)
	_expect(events.is_coming() and world.get_node("HUD/StatusColumn/EventNote").text == "", "warned (the HUD note shows next frame)")
	await process_frame
	_expect((world.get_node("HUD/StatusColumn/EventNote") as Label).text.contains("Storm in 2 days on the Starting Island"), "the HUD says a storm is coming, when, and where")
	var player: Node2D = world.get_node("Player")
	player.global_position = area.global_position + Vector2(0, 50)
	var secure: Array = area.actions().filter(func(a: Dictionary) -> bool: return a.label == "Secure")
	_expect(secure.size() == 1, "offers to secure the protection area")
	secure[0].do.call()
	_expect(area.secured and area.stats().contains("Secured"), "secured")
	player.global_position = dock.global_position + Vector2(0, -40)
	_expect(dock.actions().filter(func(a: Dictionary) -> bool: return a.label.begins_with("Secure")).is_empty(), "docks are storm-proof")

	var clouds: GDScript = load("res://scripts/ui/storm_clouds.gd")
	_expect(clouds.nearness(&"home_island") > 0.0 and clouds.nearness(&"home_island") < clouds.nearness(&"kelp_forest") + 0.5,
		"clouds gather beyond the island's waters, thin two days ahead")
	var people := root.get_node("People")
	var maya: Resource = load("res://data/people/maya.tres")
	_expect(people.nervous(maya) and people.storm_line(maya) == maya.storm_worry, "Maya is nervous: a storm is coming")

	# --- On its day: 10 s after the ranger is there, it passes over (10 s), then strikes ---
	storm.damage_chance = 1.0
	var litter: int = get_nodes_in_group("debris").size()
	events._coming[&"coastal_storm"] = clock.day
	_expect(clouds.nearness(&"home_island") == 1.0, "on its day the clouds are as close as they get")
	events.call("_process", 1.0)
	events.set("_here_for", 3.0)
	events.call("_process", 1.0)
	var weather: Node = world.get_node("HUD/StormWeather")
	_expect(not weather.is_playing(), "not in the ranger's first 10 seconds there")
	events.set("_here_for", 11.0)
	events.call("_process", 1.0)
	_expect(weather.is_playing() and weather.get("_seconds") == 10.0 and events.is_coming(), "then it passes over: 10 s of storm")
	await process_frame
	await process_frame
	_expect(weather.closed() > 0.0 and weather.get("_kind").rain > 0, "the storm closes in round the ranger: driving rain")
	await create_timer(10.5).timeout
	_expect(not events.is_coming() and not weather.is_playing(), "the storm has passed")
	_expect(load("res://data/events/hurricane.tres").weather == &"hurricane" and load("res://data/events/underwater_storm.tres").weather == &"swell"
		and load("res://data/events/flash_flood.tres").weather == &"flood" and load("res://data/events/ice_breakup.tres").weather == &"blizzard"
		and load("res://data/events/oil_spill.tres").weather == &"oil", "each island's event has its own weather")
	_expect(people.nervous(maya) and people.storm_line(maya) == maya.storm_after, "afterwards Maya wants to talk about it")
	people.talk(maya)
	_expect(not people.nervous(maya), "talked it over")
	_expect(not area.damaged and not area.secured, "the secured protection area is fine")
	_expect(viewing.damaged and viewing.visitors_today() == 0 and viewing.stats() == "Damaged"
		and viewing.get_node("DamageIcon").visible, "the unsecured viewing area is damaged (a warning sign) and closed to visitors")
	_expect(not dock.damaged, "the dock is fine")
	var washed: int = get_nodes_in_group("debris").size() - litter
	_expect(washed >= storm.litter_washed and washed <= storm.litter_washed_max + storm.litter_floating,
		"litter all over the island, and some at sea (%d)" % washed)
	var off_sand := get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
		return not d.floating and load("res://scripts/world/terrain.gd").at(self, d.global_position) == "grass")
	_expect(not off_sand.is_empty(), "not only on the beaches")

	# --- Fix ---
	player.global_position = viewing.global_position + Vector2(0, 50)
	inventory.restore({}, {})
	var funding := root.get_node("Funding")
	funding.balance = 100
	viewing.repair()
	_expect(viewing.damaged, "fixing needs wood")
	inventory.add(load("res://data/items/wood.tres"), 1)
	var actions: Array = viewing.actions()
	_expect(actions.size() == 1 and actions[0].label.begins_with("Fix"), "only one thing to do: Fix (%s)" % [actions.map(func(a: Dictionary) -> String: return a.label)])
	actions[0].do.call()
	_expect(not viewing.damaged and viewing.visitors_today() > 0 and inventory.available(&"wood") == 0
		and funding.balance == 100 - storm.repair_funding and not viewing.get_node("DamageIcon").visible,
		"fixed with %d funding + 1 wood: open again" % storm.repair_funding)

	# --- The day after its day: the ranger only catches its end ---
	events._coming[&"coastal_storm"] = clock.day - 1
	events.set("_here_for", 0.0)
	events.call("_process", 1.0)
	_expect(weather.is_playing() and weather.get("_seconds") == 5.0, "coming the day after: a quick 5 s of its end")
	await create_timer(5.5).timeout
	_expect(not events.is_coming(), "then it's passed")
	# --- Two days after: missed it, only the aftermath ---
	events._coming[&"coastal_storm"] = clock.day - 2
	events.call("_process", 1.0)
	_expect(not events.is_coming() and not weather.is_playing(), "missed it: only the aftermath")

	# --- A damaged protection area: no nesting until it's repaired ---
	area.damaged = true
	var turtle: Node2D = world.get_node("GreenTurtle")
	_expect(turtle.call("_nest_site") == null, "turtles won't nest at a damaged area")
	area.damaged = false
	_expect(turtle.call("_nest_site") == area, "repaired: they will again")

	# --- Not again for 30 days ---
	# --- The next one: at a random time 30-60 days after the last, warned 3-4 days ahead ---
	var strikes := []
	var leads := []
	for run in 20:
		var last: int = clock.day
		events.restore({"last_day": {"coastal_storm": last}, "first_on": {"home_island": 1}})
		for i in 70:
			clock.day += 1
			events.call("_on_new_day", clock.day)
			if events.is_coming():
				strikes.append(events._coming[&"coastal_storm"] - last)
				leads.append(events._coming[&"coastal_storm"] - clock.day)
				break
	_expect(strikes.size() == 20 and strikes.all(func(d: int) -> bool: return d >= 30 and d <= 60)
		and strikes.max() - strikes.min() >= 8, "a storm comes 30-60 days after the last, never at a set time (%s)" % [strikes])
	_expect(leads.all(func(d: int) -> bool: return d == 2), "warned 2 days ahead (%s)" % [leads])
	var saved: Dictionary = events.to_dict()
	events.restore({})
	events.restore(saved)
	_expect(events.is_coming(), "a coming storm is saved")

	# --- An island's first event comes 15-25 days after first arriving there ---
	events.restore({"first_on": {"home_island": 55}})
	for day in range(56, 66):
		clock.day = day
		events.call("_on_new_day", day)
	_expect(not events.is_coming_to(&"home_island"), "arriving on day 55: no storm warned before day 66 (so none strikes before day 70)")
	events.restore({"first_on": {"home_island": 55}, "coming": {"coastal_storm": 60}})
	events.call("_on_new_day", 56)
	_expect(not events.is_coming_to(&"home_island"), "a warning from before the island's timer started is called off")
	events.restore({"first_on": {"home_island": 55}})
	var firsts := []
	for run in 12:
		events.restore({"first_on": {"home_island": 55}})
		for day in range(56, 130):
			if events._coming.get(&"coastal_storm", -1) == day:
				firsts.append(day - 55)
				break
			clock.day = day
			events.call("_on_new_day", day)
	_expect(firsts.size() == 12 and firsts.all(func(d: int) -> bool: return d >= 15 and d <= 26),
		"the island's first storm comes 15-25 days after arriving (%s)" % [firsts])

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
