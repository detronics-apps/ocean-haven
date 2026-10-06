extends SceneTree
## Floe Fit: once Sanna asks about the ice core it's at the Polar Research Station. Fit floes into
## the gaps of open water on the ice map; a placed floe can be taken back (never stuck); every
## board has a way to fill it. The story play is Sanna's drill planning; then it's for fun.
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
	var fit_data: Resource = load("res://data/activities/floe_fit.tres")
	var sanna: Resource = load("res://data/people/sanna.tres")
	var people := root.get_node("People")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	world.get_node("BuildMode").add_building(load("res://data/buildings/polar_research_station.tres"), terrain.cell_of(polar.arrival) + Vector2i(1, -1))
	_expect(not activities.is_open(fit_data), "not before Sanna asks about the ice core")
	people.talk(sanna)
	people.talk(sanna)
	people.finish_talk()
	_expect(people.check("asked:core", sanna) and activities.is_open(fit_data), "Sanna asks about the ice core: Floe Fit opens")

	var screen: Node = world.get_parent().find_child("FloeFit", true, false)
	screen.open_activity(fit_data)
	screen.call("_begin")
	_expect(screen.floe_count() > 0 and not screen.filled(), "the ice map has gaps and floes to fit")
	# A floe in the wrong place can be taken back.
	screen.pick(0)
	var wrong := Vector2i(-1, -1)
	for x in 5:
		for y in 4:
			if wrong == Vector2i(-1, -1) and Vector2i(x, y) != screen.cut_at(0) and screen.call("_fits", 0, Vector2i(x, y)):
				wrong = Vector2i(x, y)
	if wrong != Vector2i(-1, -1):
		screen.place(wrong)
		_expect(screen.take_back(wrong + screen.get("_floes")[0][0]), "a floe put in the wrong place can be taken back")
	for floe in screen.floe_count():
		screen.pick(floe)
		screen.place(screen.cut_at(floe))
	_expect(not screen.get("_playing"), "every gap filled: done")
	_expect(activities.story_done(fit_data) and root.get_node("Missions").last_report.contains("oldest"), "the story play did the drill planning (%s)" % root.get_node("Missions").last_report)
	screen.close_screen()
	var ok := true
	for i in 30:
		screen.set("_cols", 9)
		screen.set("_rows", 6)
		screen.set("_playing", true)
		screen.call("_cut", 5)
		for floe in screen.floe_count():
			screen.pick(floe)
			ok = ok and screen.call("_fits", floe, screen.cut_at(floe))
			screen.get("_placed")[floe] = screen.cut_at(floe)
		ok = ok and screen.filled()
	screen.set("_playing", false)
	_expect(ok, "every board can be filled")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
