extends SceneTree
## Sonar Sweep, the first ranger activity: Maya introduces it with the wreck question; it's
## played at the Marine Search & Rescue Station. Pings show how many hidden things are around
## (each adds a second; a wrong mark a few); the story play finds the wreck; after that it's for
## fun: levels and personal bests, nothing else. Bests and the story are saved.
## Run: godot --headless --path . --script res://tests/test_sonar_sweep.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	var activities := root.get_node("Activities")
	people.restore({})
	fleet.restore({})
	activities.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var sweep_data: Resource = load("res://data/activities/sonar_sweep.tres")
	var station: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/marine_rescue_station.tres"), Vector2i(-6, -6))
	var player: Node2D = world.get_node("Player")
	player.global_position = station.global_position + Vector2(0, 50)
	var labels := func() -> Array: return station.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(not "Sonar Sweep" in labels.call(), "before Maya mentions it, there's no Sonar Sweep")

	# --- Maya asks about the old chart: the sweep opens at her station ---
	var maya: Resource = load("res://data/people/maya.tres")
	for id in ["green_turtle", "ghost_crab", "bottlenose_dolphin"]:
		root.get_node("Journal").photograph(load("res://data/animals/%s.tres" % id))
	people.talk(maya)  # photos done (and the station is up): she asks about the wreck
	people.talk(maya)
	people.finish_talk()
	_expect(people.check("asked:wreck", maya), "Maya has asked about the wreck")
	_expect("Sonar Sweep" in labels.call(), "now the station offers a Sonar Sweep (%s)" % [labels.call()])

	# --- The story play: find everything, the wreck is found ---
	var screen: Node = world.get_parent().find_child("SonarSweep", true, false)
	station.actions().filter(func(a: Dictionary) -> bool: return a.label == "Sonar Sweep")[0].do.call()
	_expect(screen.visible and paused, "the sweep opens and the game waits")
	screen.get_node_or_null(".")
	screen.call("_begin")
	var things: Array = screen.hidden_cells()
	_expect(things.size() == 3, "level 1: 3 things hidden off the coast")
	var empty := Vector2i(-1, -1)
	for x in 6:
		for y in 5:
			if not Vector2i(x, y) in things and screen.around(Vector2i(x, y)) > 0 and empty == Vector2i(-1, -1):
				empty = Vector2i(x, y)
	screen.tap(empty)
	_expect(is_equal_approx(screen.seconds, 1.0) or screen.seconds > 1.0, "a ping adds a second")
	screen.set_marking(true)
	var before: float = screen.seconds
	for cell: Vector2i in things:
		screen.tap(cell)
	_expect(screen.seconds - before < 1.0, "marking the right squares costs nothing")
	_expect(fleet.has_flag(&"wreck_found"), "the story sweep finds the wreck")
	_expect(activities.story_done(sweep_data) and activities.best(sweep_data, 0) < INF, "the story play is done, with a time")
	screen.close_screen()
	_expect(not paused, "closed: the game goes on")

	# --- After that: for fun, levels and bests only ---
	var flags_before: Array = fleet.to_dict().flags
	screen.open_activity(sweep_data)
	_expect(screen.get("_buttons").get_child_count() >= 1 and screen.get("_buttons").has_node("Level1"), "now it opens the levels")
	_expect(activities.open_levels(sweep_data) == 2, "level 2 is open after level 1")
	screen.call("_show_start", 0, "")
	for cell: Vector2i in screen.hidden_cells():
		screen.tap(cell)  # pinging a hidden thing finds it too
	_expect(fleet.to_dict().flags == flags_before, "replays give no progress")
	var record: bool = activities.finish(sweep_data, 0, 0.5)
	_expect(record and is_equal_approx(activities.best(sweep_data, 0), 0.5), "a faster time: a new personal best")
	_expect(not activities.finish(sweep_data, 0, 9.0), "a slower one isn't")
	screen.close_screen()

	# --- Saved ---
	var saved: Dictionary = activities.to_dict()
	activities.restore({})
	activities.restore(JSON.parse_string(JSON.stringify(saved)))
	_expect(activities.story_done(sweep_data) and is_equal_approx(activities.best(sweep_data, 0), 0.5), "the story and bests are saved")

	# --- An older save where the wreck was already found: open straight away ---
	activities.restore({})
	people.restore({})
	_expect("Sonar Sweep" in labels.call(), "wreck already found: the sweep is open at the station")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
