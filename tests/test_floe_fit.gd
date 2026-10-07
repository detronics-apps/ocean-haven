extends SceneTree
## Ice Match (activity "floe_fit"): once Sanna asks about the ice core it's at the Polar Research
## Station. Swap neighbouring pieces to make rows of three or more of the same: they clear,
## the rest fall, new ones drop in. A swap with no row swaps back; there's always a move.
## Clearing enough old ice finishes it. The story play is Sanna's drill planning.
## Run: godot --headless --path . --script res://tests/test_floe_fit.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var activities := root.get_node("Activities")
	activities.restore({})
	root.get_node("People").restore({})
	root.get_node("Fleet").restore({"flags": ["polar_balanced"]})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var polar: Resource = load("res://data/regions/arctic_ocean.tres")
	load("res://scripts/world/regions.gd").discover(polar)
	var data: Resource = load("res://data/activities/floe_fit.tres")
	var sanna: Resource = load("res://data/people/sanna.tres")
	var people := root.get_node("People")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	world.get_node("BuildMode").add_building(load("res://data/buildings/polar_research_station.tres"), terrain.cell_of(polar.arrival) + Vector2i(1, -1))
	_expect(not activities.is_open(data), "not before Sanna asks about the ice core")
	people.talk(sanna)
	people.talk(sanna)
	people.finish_talk()
	_expect(people.check("asked:core", sanna) and activities.is_open(data), "Sanna asks about the ice core: Ice Match opens")

	var screen: Node = world.get_parent().find_child("IceMatch", true, false)
	screen.open_activity(data)
	screen.call("_begin")
	_expect(screen.call("_matches").is_empty() and screen.find_move().size() == 2, "a fresh board: no rows ready-made, and a move to make")
	var before: Array = screen.grid.duplicate(true)
	var bad := Vector2i(-1, -1)
	for x in screen.cols - 1:  # a swap that makes no row
		for y in screen.rows:
			screen.call("_exchange", Vector2i(x, y), Vector2i(x + 1, y))
			var none: bool = screen.call("_matches").is_empty()
			screen.call("_exchange", Vector2i(x, y), Vector2i(x + 1, y))
			if none and bad == Vector2i(-1, -1):
				bad = Vector2i(x, y)
	if bad != Vector2i(-1, -1):
		_expect(not screen.swap(bad, bad + Vector2i(1, 0)) and screen.grid == before, "a swap that makes no row swaps back")
	var moves := 0
	while screen.get("_playing") and moves < 2000:
		var move: Array = screen.find_move()
		if move.is_empty():
			break
		screen.swap(move[0], move[1])
		moves += 1
	_expect(not screen.get("_playing") and screen.cleared >= screen.goal, "enough old ice cleared: done (%d moves)" % moves)
	_expect(activities.story_done(data) and root.get_node("Missions").last_report.contains("oldest"), "the story play did the drill planning (%s)" % root.get_node("Missions").last_report)
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
