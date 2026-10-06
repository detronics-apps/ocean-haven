extends SceneTree
## Echo Dive: once Imani asks about the lost cargo module it's at the Deep-Ocean Outpost. Hold to
## rise, let go to sink, through a dark canyon lit by sonar pings; walls only slow you; pick up
## lost gear. The story dive finds the cargo module (Imani's cargo search); then it's for fun.
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
	for i in 120:
		screen.step(1.0 / 30.0, false)
	_expect(screen.get("_playing"), "sinking into a wall only slows the sub: nothing goes wrong")
	_expect(screen.echo() >= 0.0 and screen.echo() <= 1.0, "the sonar pings and fades")
	var steps := 0
	while screen.get("_playing") and steps < 30000:  # steer for the gear, or the middle of the canyon
		var x: float = screen.get("_scroll") + screen.SUB_X
		var aim: float = (screen.gap_at(x).x + screen.gap_at(x).y) / 2.0
		for thing: Dictionary in screen.get("_things"):
			if thing.x > x and thing.x < x + 0.4:
				aim = thing.y
				break
		screen.step(1.0 / 30.0, screen.depth() > aim)
		steps += 1
	_expect(not screen.get("_playing") and screen.collected() >= 3, "the lost gear picked up (%d, %d steps)" % [screen.collected(), steps])
	_expect(fleet.has_flag(&"cargo_located"), "the story dive found the cargo module")
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
