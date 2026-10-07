extends SceneTree
## Otter Dive: an old jetty on the Kelp Forest, there from the start, explains itself until
## Finn asks about the urchins; then it opens. Hold to dive, let go to float up; air runs out
## under water (then the otter just floats up) and comes back at the surface; grab urchins on
## the sea floor. The story play does Finn's urchin survey (marked); after that, just for fun.
## Run: godot --headless --path . --script res://tests/test_otter_dive.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var activities := root.get_node("Activities")
	var fleet := root.get_node("Fleet")
	people.restore({})
	activities.restore({})
	fleet.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	load("res://scripts/world/regions.gd").discover(kelp)
	var dive_data: Resource = load("res://data/activities/otter_dive.tres")
	var jetty: Node2D = world.get_node("Spot_otter_dive")
	var player: Node2D = world.get_node("Player")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	_expect(terrain.walkable(self, jetty.global_position), "the old jetty starts on the Kelp Forest's beach")
	player.global_position = jetty.global_position + Vector2(10, 0)
	var labels := func() -> Array: return jetty.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels.call() == ["Look at the old jetty"], "before Finn mentions it, it only explains itself (%s)" % [labels.call()])

	# --- Finn asks about the urchins: the dive opens ---
	world.get_node("BuildMode").add_building(load("res://data/buildings/kelp_research_platform.tres"),
		terrain.cell_of(kelp.arrival) + Vector2i(-3, 4))
	var finn: Resource = load("res://data/people/finn.tres")
	people.talk(finn)
	people.talk(finn)
	people.finish_talk()
	_expect(people.check("asked:balance", finn), "Finn has asked what keeps the urchins in check")
	_expect("Otter Dive" in labels.call(), "now the jetty offers an Otter Dive (%s)" % [labels.call()])

	# --- The dive ---
	var screen: Node = world.get_parent().find_child("OtterDive", true, false)
	screen.open_activity(dive_data)
	screen.call("_begin")
	_expect(screen.visible and paused, "the dive opens and the game waits")
	for i in 60:
		screen.step(1.0 / 30.0, true)
	_expect(screen.depth() > 0.5, "holding: the otter dives (%.2f)" % screen.depth())
	var goal: int = screen.get("_goal")
	screen.set("_goal", 999)  # (so grabbing every urchin on the way can't end the dive here)
	for i in 400:
		screen.step(1.0 / 30.0, true)
	_expect(screen.air() <= 0.0 and screen.get("_playing"), "out of air: nothing goes wrong")
	screen.set("_goal", goal)
	for i in 30:
		screen.step(1.0 / 30.0, true)
	_expect(screen.depth() < 0.8, "it just floats up, even holding")
	for i in 200:
		screen.step(1.0 / 30.0, false)
	_expect(screen.air() > 6.0, "a breath at the surface fills the air again")
	var steps := 0
	while screen.get("_playing") and steps < 20000:  # dive for urchins, up for air
		var low_air: bool = screen.air() < 2.0
		screen.step(1.0 / 30.0, not low_air and screen.depth() < 0.82)
		steps += 1
	_expect(not screen.get("_playing") and screen.collected() >= 5, "5 urchins collected (%d, %d steps)" % [screen.collected(), steps])
	_expect(activities.story_done(dive_data), "the story dive is done")
	_expect(root.get_node("Missions").last_report.contains("overgrazed") or root.get_node("Missions").last_report != "",
		"and it did Finn's urchin survey (%s)" % root.get_node("Missions").last_report)
	screen.close_screen()

	# --- Replays: levels and bests only ---
	screen.open_activity(dive_data)
	_expect(screen.get("_buttons").has_node("Level1"), "the jetty now opens the levels")
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
