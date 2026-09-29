extends SceneTree
## The Starting Island's objective: a coastal survey (from the Marine Rescue & Research
## Station) finds an old wreck off the coast; its litter appears and is cleared from the
## boat; then its old sonar unit can be recovered, which completes the objective (the
## Salvaged Sonar Core). Before the survey the wreck and its litter are hidden.
## Run: godot --headless --path . --script res://tests/test_wreck.gd --quit-after 200000

const PATH := "user://test_wreck.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var fleet := root.get_node("Fleet")
	var missions := root.get_node("Missions")
	var clock := root.get_node("GameClock")
	var save := root.get_node("SaveGame")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var home: Resource = load("res://data/regions/home_island.tres")
	var wreck: Node2D = world.get_node("Wreck")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	_expect(terrain.at(self, wreck.global_position) == "" and wreck.global_position.length() < 1000.0,
		"the wreck lies in open water the rowboat can reach")

	# --- Hidden until surveyed ---
	var pieces: Array = wreck.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Sunken"))
	_expect(pieces.size() == 8 and pieces.all(func(p: Node) -> bool: return not p.visible and not p.is_in_group("debris")),
		"its 8 pieces of litter are hidden (not litter yet)")
	root.get_node("Funding").restore({"balance": 500})
	var survey: Resource = load("res://data/missions/coastal_survey.tres")
	_expect(is_equal_approx(survey.find_chance, 0.2) and survey.sure_by == 5, "a coastal survey has a 20% chance, and is sure by the 5th try")
	survey.find_chance = 0.0  # unlucky every time...
	for i in 4:
		missions.send(survey, home)
		clock.advance(301.0)  # 5 real minutes
		await process_frame
		await process_frame
	_expect(not fleet.has_flag(&"wreck_found") and missions.active == null, "4 unlucky surveys: nothing found yet")
	missions.send(survey, home)  # ... but the 5th always finds it
	clock.advance(301.0)
	await process_frame
	await process_frame
	survey.find_chance = 0.2
	_expect(fleet.has_flag(&"wreck_found") and wreck in missions.marked(), "the coastal survey finds it (marked on the minimap)")
	_expect(pieces.all(func(p: Node) -> bool: return p.visible and p.is_in_group("debris")), "its litter appears")
	_expect(not survey in missions.offered_by(&"marine_rescue_station"), "no more coastal surveys once it's found")
	var treasure: Node2D = wreck.get_node("Treasure")
	_expect(not treasure.visible, "the sonar unit is buried under the litter")

	# --- Clear it (some now, save, the rest after loading) ---
	for i in 3:
		pieces[i].collect()
	await process_frame
	_expect(wreck.litter_left() == 5 and not fleet.has_flag(&"wreck_cleared"), "5 pieces left")
	_expect(save.save_to(world, PATH), "saved")
	world.free()
	fleet.restore({})
	world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	_expect(save.load_from(world, PATH), "loaded")
	await process_frame
	wreck = world.get_node("Wreck")
	_expect(fleet.has_flag(&"wreck_found") and wreck.litter_left() == 5, "still found, with 5 pieces left after loading")
	for piece: Node in wreck.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Sunken") and not n.is_queued_for_deletion()):
		piece.collect()
	await process_frame
	await process_frame
	treasure = wreck.get_node("Treasure")
	_expect(fleet.has_flag(&"wreck_cleared") and treasure.visible, "all cleared: the sonar unit can be recovered")
	_expect(not fleet.objective_done(home), "not done until it's recovered")
	treasure.call("_on_body_entered", world.get_node("Player"))
	_expect(not treasure.is_queued_for_deletion(), "it has to be lifted into the boat")
	treasure.call("_on_body_entered", world.get_node("Boat"))
	_expect(fleet.has_flag(&"sonar_recovered") and fleet.objective_done(home) and fleet.has_found(&"salvaged_sonar_core"),
		"recovered: objective done, the Salvaged Sonar Core is found")
	_expect(root.get_node("Inventory").count(&"old_sonar_unit") == 0, "(it isn't carried like litter)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
