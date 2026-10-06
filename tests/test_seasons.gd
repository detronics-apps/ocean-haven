extends SceneTree
## Seasons: a 120-day year of four 30-day seasons, shown on the HUD ("Day 42 · Summer, year 1").
## Sea turtles nest in spring (every 4 days; only every 40 days the rest of the year); of each
## nest's hatchlings one stays and the rest swim off into the open ocean (a storm-hit nest's
## one goes too); hatchlings take 8 days to grow up and only nest from the next spring.
## Run: godot --headless --path . --script res://tests/test_seasons.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clock := root.get_node("GameClock")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame

	# --- The calendar ---
	clock.day = 1
	_expect(clock.calendar() == "Day 1 · Spring, year 1", "day 1: spring of year 1 (%s)" % clock.calendar())
	clock.day = 42
	_expect(clock.calendar() == "Day 42 · Summer, year 1" and clock.day_of_season() == 12, "day 42: summer, its 12th day")
	clock.day = 120
	_expect(clock.season() == &"winter", "day 120: the last day of winter")
	clock.day = 121
	_expect(clock.calendar() == "Day 121 · Spring, year 2", "day 121: spring again, year 2")
	_expect(clock.next_season_start(&"spring", 5.5) == 121 and clock.next_season_start(&"spring", 0.5) == 1
		and clock.next_season_start(&"summer", 5.5) == 31, "the next spring after day 5 is day 121")
	clock.day = 3
	await process_frame
	_expect((world.get_node("HUD").get("_clock") as Label).text.begins_with("Day 3 · Spring, year 1"), "the HUD shows the day and season")

	# --- Turtles nest in spring ---
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var turtle: Node = world.get_node("GreenTurtle")
	clock.day = 10
	_expect(turtle.nest_interval() == 4, "in spring a turtle nests every 4 days")
	clock.day = 50
	_expect(turtle.nest_interval() == 40, "the rest of the year only every 40 days")
	_expect(turtle.mature(), "the island's own turtle can nest")

	# --- Young: 8 days to grow up, nesting from the next spring ---
	clock.day = 5
	var young: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	young.set("data", turtle_data)
	young.set("young", true)
	young.set("born_at", 5.0)
	young.position = Vector2(-500, 100)
	world.add_child(young)
	_expect(is_equal_approx(turtle_data.grow_days, 8.0), "hatchlings take 8 days to grow up")
	young.grow_up()
	clock.day = 20
	_expect(not young.mature(), "grown up in spring, it doesn't nest until next spring")
	clock.day = 121
	_expect(young.mature(), "next spring it nests too")

	# --- One hatchling stays, the rest swim off ---
	clock.day = 6
	var area: Node = world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	var babies := func() -> Array:
		return get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data == turtle_data and a.young and a.born_at > 5.5)
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", turtle_data)
	nest.set("laid_at", 5.0)
	nest.position = area.global_position
	world.add_child(nest)
	await process_frame
	nest.hatch()
	var hatched: Array = babies.call()
	_expect(hatched.size() == 3 and hatched.filter(func(a: Node) -> bool: return not a.leaving).size() == 1,
		"3 hatchlings: 1 stays, 2 swim off into the open ocean (%d stay)" % hatched.filter(func(a: Node) -> bool: return not a.leaving).size())
	for baby: Node in hatched:
		baby.free()
	var hit: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	hit.set("species", turtle_data)
	hit.set("laid_at", 5.0)
	hit.set("storm_hit", true)
	hit.position = area.global_position
	world.add_child(hit)
	await process_frame
	hit.hatch()
	hatched = babies.call()
	_expect(hatched.size() == 1 and hatched[0].leaving, "a storm-hit nest: its one hatchling is swept out to sea")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
