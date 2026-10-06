extends SceneTree
## Channel Flow: Rosa's question about the cut-off pools opens it at the Waterworks Station. Turn
## channel pieces so sea water reaches every nursery pool; every board has a way through. The
## story play does Rosa's water flow survey; after that it's for fun.
## Run: godot --headless --path . --script res://tests/test_channel_flow.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var activities := root.get_node("Activities")
	people.restore({})
	activities.restore({})
	root.get_node("Fleet").restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var mangrove: Resource = load("res://data/regions/mangrove_coast.tres")
	load("res://scripts/world/regions.gd").discover(mangrove)
	var flow_data: Resource = load("res://data/activities/channel_flow.tres")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var station: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/waterworks_station.tres"),
		terrain.cell_of(mangrove.arrival) + Vector2i(3, -1))
	var player: Node2D = world.get_node("Player")
	player.global_position = station.global_position + Vector2(0, 40)
	var labels := func() -> Array: return station.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(not "Channel Flow" in labels.call(), "before Rosa asks, no Channel Flow")
	var rosa: Resource = load("res://data/people/rosa.tres")
	people.talk(rosa)
	people.talk(rosa)
	people.finish_talk()
	_expect(people.check("asked:flowing", rosa) and "Channel Flow" in labels.call(), "Rosa asks about the pools: the station offers Channel Flow (%s)" % [labels.call()])

	var screen: Node = world.get_parent().find_child("ChannelFlow", true, false)
	screen.open_activity(flow_data)
	screen.call("_begin")
	_expect(screen.pools().size() == 2 and screen.linked() < 2, "level 1: 2 pools, not all linked yet")
	# The way it was made works: turn every piece back to it.
	var goal: Dictionary = screen.solution()
	for cell: Vector2i in goal:
		var turns := 0
		while screen.get("_playing") and screen.pieces()[cell] != goal[cell] and turns < 4:
			screen.turn(cell)
			turns += 1
	_expect(not screen.get("_playing"), "every pool linked to the sea: done")
	_expect(activities.story_done(flow_data) and root.get_node("Missions").last_report != "", "the story play did Rosa's water flow survey (%s)" % root.get_node("Missions").last_report)
	screen.close_screen()
	# Many random boards: each one has a way through.
	var ok := true
	for i in 30:
		screen.set("_cols", 9)
		screen.set("_rows", 6)
		screen.call("_make", 6)
		var made: Dictionary = screen.solution()
		for cell: Vector2i in made:
			screen.pieces()[cell] = made[cell]
		ok = ok and screen.call("_all_linked")
	_expect(ok, "every board can be solved")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
