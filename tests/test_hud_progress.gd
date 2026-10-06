extends SceneTree
## The HUD grows with the game: the minimap comes with the Salvaged Sonar Core, the island
## health bar with a research station on the second island, the water bar once clean water
## can be made; the objective line always says the island's next goal and how to go about it.
## Run: godot --headless --path . --script res://tests/test_hud_progress.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var fleet := root.get_node("Fleet")
	fleet.restore({})
	var hud: Node = world.get_node("HUD")
	var minimap: Control = hud.get_node("Minimap")
	var gauge: Control = hud.get_node("StatusColumn/HealthGauge")
	var water: Control = hud.get_node("StatusColumn/WaterGauge")
	for i in 3:
		await process_frame
	hud.call("_check_unlocks")
	gauge.set("_wait", 0.0)
	water.set("_wait", 0.0)
	await process_frame
	_expect(not minimap.visible and not gauge.visible and not water.visible, "a new game: no minimap, health bar or water bar yet")
	# On the Starting Island, Maya gives the objectives (no Tip button: Tom gives the hints).
	var text: String = hud.objective_text()
	_expect(text.begins_with("Talk to Dr. Maya"), "the Starting Island: talk to Maya first (%s)" % text)
	hud.set("_unlock_check", 0.0)
	await process_frame
	_expect(not hud.get_node("StatusColumn/TipButton").visible, "no Tip button where there are people")

	# An island without its people yet keeps the goal line and the Tip button.
	var otters: Resource = load("res://data/regions/kelp_forest.tres")
	load("res://scripts/world/regions.gd").discover(otters)
	world.get_node("Player").global_position = otters.arrival
	text = hud.objective_text()
	_expect(text.begins_with("Goal: Bring the sea otters back: ") and text.contains("then explore to find a new island"),
		"an island without people yet: bring its animal back, then explore (%s)" % text)
	var tip: String = hud.tip_text()
	_expect(tip.begins_with("Next step towards exploring:"), "one tip, only when asked: the objective's next step (%s)" % tip)
	hud.set("_unlock_check", 0.0)
	await process_frame
	_expect(hud.get_node("StatusColumn/TipButton").visible, "and a Tip button under the goal")
	fleet.complete(otters, false)
	_expect(hud.tip_text().contains("Exploration Ship"), "objective done: the tip is to build the Exploration Ship (%s)" % hud.tip_text())
	world.get_node("Player").global_position = Vector2.ZERO

	# The Sonar Core brings the minimap.
	fleet.restore({"found": ["salvaged_sonar_core"], "installed": ["salvaged_sonar_core"]})
	hud.call("_check_unlocks")
	_expect(minimap.visible, "the Salvaged Sonar Core installed: the minimap appears")

	# A research station on the second island brings the health bar.
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	world.get_node("BuildMode").add_building(load("res://data/buildings/kelp_research_platform.tres"),
		load("res://scripts/world/terrain.gd").cell_of(kelp.arrival))
	hud.call("_check_unlocks")
	gauge.set("_wait", 0.0)
	await process_frame
	_expect(fleet.has_flag(&"health_gauge") and gauge.visible, "a research station on the 2nd island: the health bar appears")

	# Clean water made: the water bar.
	fleet.mark(&"clean_water_made")
	water.set("_wait", 0.0)
	await process_frame
	_expect(water.visible, "clean water can be made: the water bar appears")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
