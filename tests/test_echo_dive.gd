extends SceneTree
## Echo Dive: once Imani asks about the lost cargo module it's at the Deep-Ocean Outpost. The
## sub sinks straight down from the surface; steer round the ledges (a bump only slows it),
## past the deep's animals at their real depths. The story dive reaches the cargo module at
## 1,000 m (Imani's cargo search); then it's for fun, deeper each level.
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
		screen.step(1.0 / 30.0, 0.0)
	_expect(screen.get("_playing") and screen.depth() > 50.0, "the sub sinks from the surface by itself; bumping a ledge only slows it")
	var steps := 0
	while screen.get("_playing") and steps < 30000:  # steer away from the next ledge's side
		var ledge: Dictionary = screen.next_ledge()
		var steer := 0.0
		if not ledge.is_empty():
			steer = 1.0 if ledge.side < 0 else -1.0
		screen.step(1.0 / 30.0, steer)
		steps += 1
	_expect(not screen.get("_playing") and screen.depth() >= 1000.0, "down to 1,000 m (%d steps)" % steps)
	_expect(screen.seen().has("Giant squid") and screen.seen().has("Midnight zone"), "passing the giant squid's depth, into the midnight zone (%s)" % [screen.seen()])
	_expect(fleet.has_flag(&"cargo_located"), "the story dive found the cargo module")
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
