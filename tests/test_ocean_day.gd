extends SceneTree
## Ocean Day (People.ocean_day): a year after the ranger came, the first time they're on the
## Starting Island, one person they've met from each other island comes over for the day,
## everyone has a one-year line (said once), every released rescue is out at once, and the
## ranger wears the Ocean Day badge (shown in the creator only once earned).
## Run: godot --headless --path . --script res://tests/test_ocean_day.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	var clock := root.get_node("GameClock")
	var profile := root.get_node("RangerProfile")
	var rescues := root.get_node("Rescues")
	fleet.restore({})
	people.restore({})
	clock.day = 100
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var player: Node2D = world.get_node("Player")
	player.global_position = Vector2(0, 40)  # (the Starting Island)
	for id in ["maya", "tom", "finn", "ines", "rosa"]:
		people._met[StringName(id)] = true
	rescues.restore({"done": {"home_turtle": {"name": "Milo", "day": 50, "met": true, "where": "", "seen": []},
		"kelp_otter": {"name": "Pip", "day": 70, "met": true, "where": "", "seen": []}}})

	_expect(not people.ocean_day(), "not before a year has gone by")
	clock.day = 121
	player.global_position = load("res://data/regions/kelp_forest.tres").center
	await process_frame
	_expect(not people.ocean_day(), "on another island: Ocean Day waits for the ranger")
	player.global_position = Vector2(0, 40)
	await process_frame
	_expect(people.ocean_day() and fleet.has_flag(&"ocean_day"), "a year on, back on the Starting Island: Ocean Day")
	await process_frame
	var guests: Array = get_nodes_in_group("visitors")
	_expect(guests.size() == 2, "one friend from each other island the ranger has met (Kelp Forest, Mangrove Coast): %d" % guests.size())
	_expect(guests.all(func(g: Node) -> bool: return g.data.topics[0].lines[0] == people.all().filter(func(p: Resource) -> bool:
		return p.id == g.data.id)[0].year_line.replace("{island}", "Starting Island")), "the guests say their one-year lines")
	_expect(rescues.done[&"home_turtle"].where == "home_island" and rescues.done[&"kelp_otter"].where == "kelp_forest",
		"every rescue is out at once (at home, or here)")
	_expect(profile.look["badge"] == 1 and profile.pick("badge") != null, "the ranger wears the Ocean Day badge")
	var maya: Resource = load("res://data/people/maya.tres")
	var said := " ".join(people.talk(maya).map(func(l: Dictionary) -> String: return l.text))
	_expect(said.contains("One year"), "Maya's one-year line (%s)" % said)
	said = " ".join(people.talk(maya).map(func(l: Dictionary) -> String: return l.text))
	_expect(not said.contains("One year"), "said once")
	_expect(not people.ocean_day(), "only once a game")
	var saved: Dictionary = people.to_dict()
	people.restore({})
	people.restore(saved)
	_expect(people.is_ocean_day(), "saved: still Ocean Day after loading")
	clock.day += 1
	_expect(not people.is_ocean_day(), "the next day it's over")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
