extends SceneTree
## Echo Dive: once Imani asks about the lost cargo module it's at the Deep-Ocean Outpost. The
## sub sinks slowly from the surface and steers in all four directions down the canyon (a bump
## only slows it); the sonar pings light up the dark, lost gear is picked up on the way, past
## the deep's animals at their real depths. The story dive reaches the cargo module at
## 1,000 m (Imani's cargo search); then it's for fun, each level 1,000 m deeper.
## Run: godot --headless --path . --script res://tests/test_echo_dive.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var activities := root.get_node("Activities")
	var fleet := root.get_node("Fleet")
	activities.restore({})
	root.get_node("People").restore({})
	fleet.restore({"flags": ["deep_mapped"]})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var deep: Resource = load("res://data/regions/deep_sea.tres")
	load("res://scripts/world/regions.gd").discover(deep)
	var dive_data: Resource = load("res://data/activities/echo_dive.tres")
	_expect(not activities.is_open(dive_data), "not before Imani asks about the cargo module")
	var imani: Resource = load("res://data/people/imani.tres")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	world.get_node("BuildMode").add_building(load("res://data/buildings/deep_ocean_outpost.tres"), terrain.cell_of(deep.arrival) + Vector2i(-2, 2))
	var people := root.get_node("People")
	people.talk(imani)
	people.talk(imani)
	people.finish_talk()
	_expect(people.check("asked:cargo", imani) and activities.is_open(dive_data), "Imani asks about the cargo: Echo Dive opens")

	var screen: Node = world.get_parent().find_child("EchoDive", true, false)
	screen.open_activity(dive_data)
	screen.call("_begin")
	for i in 90:
		screen.step(1.0 / 30.0, Vector2.ZERO)
	_expect(screen.get("_playing") and screen.depth() > 50.0, "the sub sinks slowly by itself")
	var before: float = screen.depth()
	for i in 30:
		screen.step(1.0 / 30.0, Vector2(0, -1))
	_expect(screen.depth() < before, "holding up rises again (%.0f -> %.0f m)" % [before, screen.depth()])
	var x: float = screen.position_x()
	for i in 10:
		screen.step(1.0 / 30.0, Vector2(1, 0))
	_expect(screen.position_x() > x, "and it moves sideways")
	for i in 120:  # into the left wall: only slowed, pushed back into open water
		screen.step(1.0 / 30.0, Vector2(-1, 0))
	_expect(screen.position_x() - 0.03 >= screen.gap_at(screen.depth()).x - 0.001, "bumping a wall only stops it at the rock")
	var steps := 0
	var echoes := 0
	while screen.get("_playing") and steps < 30000:  # dive down the middle of the canyon, towards the nearest gear
		var gap: Vector2 = screen.gap_at(screen.depth() + 30.0)
		var aim := (gap.x + gap.y) / 2.0
		for piece: Dictionary in screen.gear_left():
			if piece.depth > screen.depth() and piece.depth - screen.depth() < 120.0:
				aim = piece.x
				break
		screen.step(1.0 / 30.0, Vector2(clampf((aim - screen.position_x()) * 8.0, -1.0, 1.0), 1.0))
		if screen.echo() > 0.99:
			echoes += 1
		steps += 1
	_expect(not screen.get("_playing") and screen.depth() >= 1000.0, "down to 1,000 m (%d steps)" % steps)
	_expect(echoes >= 2, "the sonar pings, lighting up the dark now and then (%d)" % echoes)
	_expect(screen.daylight(50.0) > 0.9 and screen.daylight(1000.0) == 0.0, "daylight near the top, none in the deep")
	_expect(screen.gear_got() >= 1, "lost gear picked up on the way (%d)" % screen.gear_got())
	_expect(screen.seen().has("Giant squid") and screen.seen().has("Midnight zone") and screen.seen().has("Bottlenose dolphin"),
		"passing the dolphins, the giant squid's depth and into the midnight zone (%s)" % [screen.seen()])
	_expect(fleet.has_flag(&"cargo_located"), "the story dive found the cargo module")
	var levels: Array = dive_data.levels
	_expect(levels.size() == 5 and levels.map(func(l: Vector3i) -> int: return l.x * 100) == [1000, 2000, 3000, 4000, 5000],
		"each level is 1,000 m deeper, down to 5,000 m")
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
