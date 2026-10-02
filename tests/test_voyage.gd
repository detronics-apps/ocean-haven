extends SceneTree
## Voyages: the rowboat can't leave its island's coastal waters. The Map lists every
## region but only sails to discovered ones; islands are discovered by exploring
## warmer or colder with the Exploration Ship, which finds the next undiscovered
## island that way (Colder: Kelp Forest, Deep Sea, Polar Ocean. Warmer: Mangrove
## Coast, Tropical Reef) and brings you ashore. An island is Exploration Ready once it has
## its own Exploration Ship (one per island), which can only be built once the island's
## objective is done. The objective finds the island's discovery; installed at a ship it
## upgrades the whole fleet, and each direction's next island needs the right upgrade.
## Run: godot --headless --path . --script res://tests/test_voyage.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")  # autoloads: looked up at runtime
	var fleet := root.get_node("Fleet")
	var journal := root.get_node("Journal")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame  # the HUD adds the Explore menu
	var player: Node2D = world.get_node("Player")
	var boat: Node2D = world.get_node("Boat")  # untyped: Boat uses autoloads
	var build_mode: Node = world.get_node("BuildMode")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var region := func(id: String) -> Resource: return load("res://data/regions/%s.tres" % id)

	# --- The rowboat stays in its coastal waters ---
	boat.restore_aboard()
	boat.global_position = Vector2(1050, 0)
	Input.action_press("move_right")
	for i in 60:
		await physics_frame
	Input.action_release("move_right")
	_expect(boat.global_position.length() <= 1102.0, "rowboat turns back at the edge of home waters (%.0f)" % boat.global_position.length())
	boat.restore_ashore()
	boat.global_position = Vector2(16, 112)
	player.global_position = Vector2(0, 40)

	# --- Every island: a little map, and you land on land with the rowboat in water ---
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	for r: Resource in regions.all():
		_expect(r.map_icon != null, "%s has a little map" % r.id)
		_expect(terrain.walkable(self, r.arrival) and terrain.at(self, r.boat_mooring) == "water",
			"%s: you step ashore on land, with the rowboat in the water" % r.id)

	# --- At the start, the Map can't take you anywhere new ---
	var map: Node = world.get_node("VoyageMap")
	map.open()
	_expect(_entry(map, "kelp_forest").contains("Not discovered yet"), "undiscovered islands are shown, but locked")
	_expect(map.find_children("Sail", "Button", true, false).is_empty(), "nothing to sail to yet")
	_expect(map.find_children("Explore*", "Button", true, false).is_empty(), "exploring isn't on the Map")
	map.close()

	# --- The island's objective comes first: then the ship can be built ---
	funding.earn(1000, "test")
	root.get_node("Inventory").restore({"plastic_bottle": 99}, {"wood": 99})  # building materials
	var home: Resource = region.call("home_island")
	var ship: Resource = load("res://data/buildings/expedition_boat.tres")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-2, 5))
	build_mode.start(ship)
	_expect(build_mode.placement_problem(ship, Vector2i(-3, 6)).begins_with("First: find and clear"),
		"no ship before the island's objective (%s)" % build_mode.placement_problem(ship, Vector2i(-3, 6)))
	build_mode.cancel()
	var journal_screen: Node = world.get_node("JournalScreen")
	journal_screen.open()
	var objective_text := _texts(journal_screen.find_child("Objective_home_island", true, false))
	_expect(objective_text.contains("Find what's hidden off the coast") and objective_text.contains("old sonar unit"),
		"the Journal shows the objective's goals")
	journal_screen.close()
	fleet.mark(&"wreck_found")
	fleet.mark(&"wreck_cleared")
	_expect(not fleet.objective_done(home), "not done while a goal is left (the sonar unit)")
	fleet.mark(&"sonar_recovered")
	_expect(fleet.objective_done(home) and fleet.has_found(&"salvaged_sonar_core"),
		"objective done: the Salvaged Sonar Core is found")
	_expect(fleet.level() == 0, "found, but not installed yet")

	# --- Build an Exploration Ship (next to 2 dock planks) and explore colder ---
	build_mode.start(ship)
	_expect(not build_mode.can_place(ship, Vector2i(-3, 7)), "one dock plank beside it isn't enough")
	_expect(build_mode.place_at(Vector2i(-3, 6)), "ship moored beside 2 dock planks")
	build_mode.cancel()  # done building (placing keeps going for another)
	var home_ship: Node2D = _ships()[0]
	player.global_position = home_ship.global_position + Vector2(0, -40)
	var labels: Array = home_ship.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Explore" in labels, "walk up to the ship to explore (%s)" % [labels])
	home_ship.actions().filter(func(a: Dictionary) -> bool: return a.label == "Explore")[0].do.call()
	var explore: Node = world.get_node("ExploreMenu")
	_expect(explore.visible and explore.find_child("ExploreWarmer", true, false).disabled
		and explore.find_child("ExploreColder", true, false).disabled, "can't find the way before the Sonar Core is installed")
	_expect(_texts(explore).contains("Current equipment: Level 0") and _texts(explore).contains("Salvaged Sonar Core - found"),
		"the ship shows the next upgrade and what it needs")
	explore.find_child("Upgrade", true, false).pressed.emit()
	await process_frame  # the screen refreshes
	_expect(fleet.level() == 1 and fleet.is_installed(&"salvaged_sonar_core"), "upgraded: fleet Level 1")
	_expect(home_ship.get_node("Sprite2D").texture == ship.fleet_textures[0], "the ship looks its level")
	_expect(not explore.find_child("ExploreWarmer", true, false).disabled
		and not explore.find_child("ExploreColder", true, false).disabled, "explore warmer or colder")
	_expect(regions.next_undiscovered(&"colder") == region.call("kelp_forest")
		and regions.next_undiscovered(&"warmer") == region.call("mangrove_coast"), "colder finds Kelp Forest, warmer Mangrove Coast")
	explore.find_child("ExploreColder", true, false).pressed.emit()
	for i in 240:
		await process_frame
	var kelp: Resource = region.call("kelp_forest")
	_expect(player.global_position == kelp.arrival and world.get_node("KelpBoat").global_position.distance_to(kelp.boat_mooring) < 1.0,
		"arrived at the Kelp Forest, where its own rowboat is moored")
	_expect(regions.is_discovered(kelp), "the Kelp Forest is discovered for good")
	_expect(_ships().size() == 1 and not regions.exploration_ready(self, kelp) and regions.exploration_ready(self, region.call("home_island")),
		"discovering gives no ship: the Kelp Forest isn't Exploration Ready yet")
	map.open()
	_expect(map.find_child("Entry_home_island", true, false).find_child("Compass", true, false) != null
		and map.find_child("Entry_kelp_forest", true, false).find_child("Compass", true, false) == null,
		"the Map shows a compass only on islands with an Exploration Ship")
	map.close()
	_expect(build_mode.placement_problem(ship, Vector2i(-3, 8)).contains("already has"), "one Exploration Ship per island")
	# Establish a ship at the Kelp Forest (in the water by the landing spot) once its objective is done.
	var kelp_cell := Vector2i((kelp.boat_mooring / 32.0).floor()) + Vector2i(-2, 1)
	_expect(build_mode.placement_problem(ship, kelp_cell).begins_with("First: restore the kelp forest"),
		"no ship before the island's objective is done (%s)" % build_mode.placement_problem(ship, kelp_cell))
	var reef_cell := Vector2i((region.call("arctic_ocean").boat_mooring / 32.0).floor()) + Vector2i(-2, 1)
	_expect(build_mode.placement_problem(ship, reef_cell).begins_with("First:"),
		"none on an island whose objective isn't done yet (%s)" % build_mode.placement_problem(ship, reef_cell))
	build_mode.add_building(ship, kelp_cell)
	_expect(regions.exploration_ready(self, kelp), "a ship there makes it Exploration Ready")

	# --- From the Kelp Forest: colder is the Deep Sea (needs Kelp Fibre), warmer leads back home ---
	_expect(regions.next_from(kelp, &"colder") == region.call("deep_sea")
		and regions.next_from(kelp, &"warmer") == region.call("home_island"), "next to the Kelp Forest: the Deep Sea colder, home warmer")
	explore.open()
	_expect(explore.find_child("ExploreColder", true, false).disabled and _texts(explore).contains("Kelp Fibre"),
		"the Deep Sea needs the Kelp Forest's discovery")
	_expect(not regions.can_find_more() and fleet.level() == 1, "Level 1 with 2 islands found: no 3rd yet")
	explore.close()
	explore.explore(&"colder")
	_expect(not regions.is_discovered(region.call("deep_sea")), "no way through without it")
	fleet.complete(kelp)
	fleet.install(&"kelp_fibre")
	_expect(fleet.level() == 2 and home_ship.get_node("Sprite2D").texture == ship.fleet_textures[1],
		"Kelp Fibre installed: Level 2, every ship upgraded")
	# The Deep Sea is ready to explore now (exploring it is tested in test_deep_sea.gd).
	explore.open()
	_expect(not explore.find_child("ExploreColder", true, false).disabled and explore.next_island(&"colder") == region.call("deep_sea"),
		"with Kelp Fibre installed the Deep Sea can be explored")
	_expect(explore.find_child("ExploreWarmer", true, false).disabled and _texts(explore).contains("found it already"),
		"warmer from the Kelp Forest is home: already found")
	explore.close()
	# A ship only finds the island next to its own: from home, colder is the Kelp Forest (found),
	# so the Deep Sea can't be reached from there; warmer is the Mangrove Coast.
	player.global_position = home_ship.global_position + Vector2(0, -40)
	explore.open()
	_expect(explore.find_child("ExploreColder", true, false).disabled and explore.next_island(&"warmer") == region.call("mangrove_coast"),
		"from home: the Kelp Forest is already found (no skipping on to the Deep Sea); warmer is the Mangrove Coast")
	explore.close()
	explore.explore(&"colder")
	_expect(not regions.is_discovered(region.call("deep_sea")), "exploring colder from home doesn't skip ahead to the Deep Sea")
	# One more island than the fleet's level: at Level 2 with 2 islands found, a 3rd is fine.
	_expect(regions.can_find_more(), "Level 2 with 2 islands found: a 3rd can be found")
	explore.explore(&"warmer")
	for i in 240:
		await process_frame
	_expect(regions.is_discovered(region.call("mangrove_coast")), "the Mangrove Coast is found")
	explore.open()
	_expect(explore.find_child("ExploreWarmer", true, false).disabled and not regions.can_find_more(),
		"Level 2 with 3 islands found: help them before finding a 4th")
	explore.close()
	fleet.complete(region.call("mangrove_coast"))
	fleet.install(&"mangrove_resin")
	_expect(explore.next_island(&"warmer") == region.call("tropical_reef"), "from the Mangrove Coast, warmer is the Tropical Reef")
	explore.open()
	_expect(not explore.find_child("ExploreWarmer", true, false).disabled, "the Tropical Reef is ready to explore")
	explore.close()
	explore.explore(&"warmer")
	for i in 240:
		await process_frame
	_expect(regions.is_discovered(region.call("tropical_reef")), "the Tropical Reef is found")

	# --- The Map sails to discovered islands (no ship needed), not to undiscovered ones ---
	map.open()
	_expect(map.find_child("Entry_kelp_forest", true, false).find_child("Sail", true, false) != null, "sail back to the Kelp Forest")
	_expect(map.find_child("Entry_arctic_ocean", true, false).find_child("Sail", true, false) == null, "not to the undiscovered Polar Ocean")
	map.close()
	regions.discover(region.call("arctic_ocean"))  # (e.g. an older save)
	region.call("arctic_ocean").in_development = true  # (pretend it's unfinished)
	map.open()
	_expect(map.find_child("Entry_arctic_ocean", true, false).find_child("Sail", true, false) == null
		and _texts(map).contains("Still under development"), "the Map doesn't sail to an island under development")
	region.call("arctic_ocean").in_development = false
	map.find_child("Entry_home_island", true, false).find_child("Sail", true, false).pressed.emit()
	for i in 240:
		await process_frame
	_expect(player.global_position == Vector2(0, 40), "sailed home again")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _ships() -> Array:
	return get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"expedition_boat")


func _texts(node: Node) -> String:
	var text := ""
	for label in node.find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


func _entry(map: Node, id: String) -> String:
	var text := ""
	for label in map.find_child("Entry_" + id, true, false).find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	return text


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
