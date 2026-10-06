extends SceneTree
## Nesting: no nesting by day; at night the freed turtle comes ashore at the
## Turtle Protection Area, lays a nest and returns to the sea; the next night the
## nest hatches and the hatchlings crawl into the water. Not next to other buildings.
## Run: godot --headless --path . --script res://tests/test_nesting.gd --quit-after 100000

var _failed := false


func _initialize() -> void:
	await process_frame
	var journal := root.get_node("Journal")  # autoloads: looked up at runtime
	var clock := root.get_node("GameClock")
	# How areas fill and hatchlings grow, with every hatchling staying and quick growing-up
	# (the real seasonal numbers, 1 staying per nest and 8 days, are tested in test_seasons).
	var species: Resource = load("res://data/animals/green_turtle.tres")
	species.stay_per_nest = 0
	species.grow_days = 2.0
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	var turtle: Node2D = world.get_node("GreenTurtle")  # untyped: Animal uses autoloads
	turtle.restore_freed()
	turtle.global_position = Vector2(590, 16)  # in the water off the east beach
	world.get_node("Player").global_position = Vector2(-600, 400)  # far away

	# --- A busy beach: no nesting next to other buildings (docks and trees are fine) ---
	var nest_area: Node = get_nodes_in_group("buildings")[0]
	var build_mode: Node = world.get_node("BuildMode")
	var dock: Node = build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(16, 1))
	_expect(nest_area.too_busy() == null and turtle.call("_nest_site") == nest_area, "a dock beside it is fine")
	dock.free()
	var centre: Node = build_mode.add_building(load("res://data/buildings/recycling_centre.tres"), Vector2i(17, -1))
	_expect(nest_area.too_busy() == centre and turtle.call("_nest_site") == null, "a recycling centre next to it: too busy to nest")
	centre.free()
	_expect(nest_area.too_busy() == null and turtle.call("_nest_site") == nest_area, "moved away: quiet again")

	# --- Daytime: no nesting ---
	clock.day = 1
	clock.time_of_day = 0.5
	for i in 60:
		await physics_frame
	_expect(journal.nests(&"green_turtle") == 0, "no nesting in the daytime")

	# --- Night: comes ashore and lays ---
	clock.time_of_day = 0.85
	var laid := false
	for i in 1500:
		await physics_frame
		clock.time_of_day = 0.85  # hold the clock at night
		if get_nodes_in_group("nests").size() == 1:
			laid = true
			break
	_expect(laid and journal.nests(&"green_turtle") == 1, "laid a nest at night")
	if laid:
		var nest: Node2D = get_nodes_in_group("nests")[0]
		_expect(_terrain(nest.global_position) == "sand", "nest is on the beach")
		# Progress bar: shows when the ranger stands by the nest, hidden when away.
		var bar: ProgressBar = nest.get("_bar")
		world.get_node("Player").global_position = nest.global_position + Vector2(-30, 0)
		await process_frame
		await process_frame  # the frame signal fires before nodes update
		_expect(bar.visible and bar.value < 5.0, "egg progress bar shows at the nest (%.0f%%)" % bar.value)
		clock.time_of_day = 0.35  # next morning: half the incubation gone
		clock.day = 2
		await process_frame
		_expect(bar.value > 40.0 and bar.value < 60.0, "progress goes up with time (%.0f%%)" % bar.value)
		clock.day = 1
		clock.time_of_day = 0.85
		world.get_node("Player").global_position = Vector2(-600, 400)
		await process_frame
		_expect(not bar.visible, "bar hidden when the ranger walks away")
	var back := false
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
		if _terrain(turtle.global_position) in ["water", ""] and turtle.get("_state") != 4:
			back = true
			break
	_expect(back, "turtle returned to the sea")

	# --- Next night: hatchlings crawl to the sea ---
	clock.day = 2
	clock.time_of_day = 0.85
	await physics_frame
	await process_frame
	var young := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.young)
	_expect(young.size() == 3 and journal.hatched_count(&"green_turtle") == 3, "3 hatchlings")
	_expect(get_nodes_in_group("nests").size() == 0, "nest is empty after hatching")
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
	var all_in_sea := young.all(func(a: Node2D) -> bool: return _terrain(a.global_position) in ["water", ""])
	_expect(all_in_sea, "hatchlings reached the sea")
	var area: Node2D = get_nodes_in_group("buildings")[0]
	_expect(area.animals_here() == 4, "mother + 3 hatchlings belong to this area (%d)" % area.animals_here())
	world.get_node("Player").global_position = area.global_position + Vector2(-40, 20)
	await process_frame
	await process_frame
	_expect(area.get_node("Hint").visible and area.get_node("Hint").text.contains("Turtles 4/4") and area.get_node("Hint").text.begins_with("Lv 1/3"),
		"the area shows 'Turtles 4/4' (%s)" % area.get_node("Hint").text)
	world.get_node("Player").global_position = Vector2(-600, 400)

	# --- Hatchlings grow bigger, then grow up and move out to spots of their own ---
	var baby: Node2D = young[0]
	var small: float = baby.get_node("Sprite2D").scale.x
	clock.day = 3
	clock.time_of_day = 0.3
	await process_frame
	_expect(baby.young and baby.get_node("Sprite2D").scale.x > small, "a day later it's bigger (%.2f -> %.2f)" % [
		small, baby.get_node("Sprite2D").scale.x])
	clock.day = 5
	clock.time_of_day = 0.4
	await process_frame
	await process_frame
	_expect(young.all(func(a: Node) -> bool: return not a.young), "after %d days the hatchlings are grown up" % turtle_days())
	var homes: Array = young.map(func(a: Node) -> Vector2: return a.home())
	var spread := true
	for i in homes.size():
		for j in range(i + 1, homes.size()):
			spread = spread and homes[i].distance_to(homes[j]) > 60.0
	_expect(spread, "the grown-ups live at spots of their own, spread out (%s)" % [homes])
	_expect(area.animals_here() == 4, "they still belong to their protection area (%d)" % area.animals_here())
	clock.day = 2
	clock.time_of_day = 0.85

	# --- The area is full (4 turtles): the next hatchlings head out to sea ---
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", turtle_data)
	nest.position = Vector2(480, 0)
	world.add_child(nest)
	nest.hatch()
	await physics_frame
	var leavers := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.leaving)
	_expect(leavers.size() == 3, "no room: all 3 new hatchlings head for the open ocean")
	_expect(journal.hatched_count(&"green_turtle") == 6, "they still count as hatchlings (6)")
	for i in 900:
		await physics_frame
		clock.time_of_day = 0.85
		if get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.leaving).is_empty():
			break
	var turtles := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data == turtle_data)
	_expect(turtles.size() == 4, "the area keeps 4 turtles; the rest swam out of the play area (%d left)" % turtles.size())

	# --- With an empty second protection area, new hatchlings move in there instead ---
	var second: Node2D = world.get_node("BuildMode").add_building(
		load("res://data/buildings/turtle_protection_area.tres"), Vector2i(-8, 7))
	var nest2: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest2.set("species", turtle_data)
	nest2.position = Vector2(480, 0)  # at the full first area
	world.add_child(nest2)
	nest2.hatch()
	await physics_frame
	var leaving_now := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.leaving).size()
	_expect(second.animals_here() == 3 and leaving_now == 0,
		"hatchlings fill the empty second area first (%d there, %d leaving)" % [second.animals_here(), leaving_now])

	# --- Loading a save re-links turtles to areas with room, not all to the nearest one ---
	var areas := get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"turtle_protection_area")
	var first: Node2D = areas.filter(func(b: Node) -> bool: return b != second)[0]
	var linked := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data == turtle_data and not a.leaving)
	for t in linked:
		t.home_area = null
		t.global_position = first.global_position + Vector2(0, 40)  # all right by the first area
	for t in linked:
		t.link_to_nearest_area()
	_expect(first.animals_here() <= 4 and second.animals_here() <= 4 and first.animals_here() + second.animals_here() == linked.size(),
		"after loading, no area is over full (%d/4 and %d/4)" % [first.animals_here(), second.animals_here()])

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func turtle_days() -> int:
	return int(load("res://data/animals/green_turtle.tres").grow_days)


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
