extends SceneTree
## Save, "restart" (wipe everything), load into a fresh world: inventory,
## discoveries, collected litter, built sanctuary, positions and boat all come
## back. A damaged save is set aside as .bad, never overwritten.
## Run: godot --headless --path . --script res://tests/test_save.gd

const PATH := "user://test_save.json"

# Autoloads looked up at runtime: --script compiles before autoloads exist.
var _save: Node
var _inventory: Node
var _journal: Node
var _failed := false


func _initialize() -> void:
	await process_frame  # let the tree start, so added worlds get _ready()
	_save = root.get_node("SaveGame")
	_inventory = root.get_node("Inventory")
	_journal = root.get_node("Journal")
	for f in [PATH, PATH + ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	# --- Play a bit, then save ---
	var world := _new_world()
	load("res://scripts/animals/arrivals.gd").restore(world, ["Dolphin1", "Dolphin3", "Crab2"])  # the pod and crabs of a recovered island
	_inventory.add(load("res://data/items/plastic_bottle.tres"), 7)
	_journal.discover(load("res://data/animals/green_turtle.tres"))
	var debris := world.get_node("Debris1")
	_save.mark_collected(debris)
	debris.free()
	var build_mode := world.get_node("BuildMode")
	build_mode.start(load("res://data/buildings/tent.tres"), true)
	_expect(build_mode.place_at(Vector2i(-1, -1)), "pitched the tent")
	_inventory.restore(_inventory.to_dict(), {"wood": 6})  # in a Ranger House
	# An Exploration Ship at a dock, and one an older version moored with no dock.
	var ship: Resource = load("res://data/buildings/expedition_boat.tres")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-2, 5))
	build_mode.add_building(ship, Vector2i(-3, 6))
	var kelp_mooring: Vector2 = load("res://data/regions/kelp_forest.tres").boat_mooring
	build_mode.add_building(ship, Vector2i((kelp_mooring / 32.0).floor()) + Vector2i(-2, 1))
	build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	_expect(_inventory.take(5) and _inventory.use(&"wood", 2), "built the sanctuary (2 wood; and used 5 of the 7 bottles on something else)")
	var area: Node = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"turtle_protection_area")[0]
	area.add_funds(25)
	area.tier = 2
	area.built_day = 3
	area.damaged = true  # by a storm
	var events := root.get_node("RareEvents")
	events.warn(load("res://data/events/coastal_storm.tres"))
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", turtle_data)
	nest.set("laid_at", 3.9)
	nest.set("protected_until", 5.5)
	nest.set("storm_hit", true)
	nest.position = Vector2(300, 0)
	world.add_child(nest)
	var baby: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	baby.set("data", turtle_data)
	baby.set("young", true)
	baby.position = Vector2(-500, 100)
	world.add_child(baby)
	var grown: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	grown.set("data", turtle_data)
	grown.set("born_at", 1.5)  # hatched here and grown up
	grown.set("last_nest_day", 3)
	grown.set("home_radius", 200.0)
	grown.position = Vector2(-560, 200)
	world.add_child(grown)
	root.get_node("Funding").restore({"balance": 100})
	var missions := root.get_node("Missions")
	missions.send(load("res://data/missions/turtle_monitoring.tres"), load("res://data/regions/home_island.tres"))
	root.get_node("Funding").restore({"balance": 77})
	world.get_node("Dolphin1").tangle(load("res://data/items/fishing_line.tres"))  # caught by litter left about
	world.get_node("GreenTurtle").injure()  # hurt by a storm
	var kelp_bed: Node2D = world.get_node("KelpIsland/Ecosystem/Kelp3")
	kelp_bed.health = 0.77
	kelp_bed.urchins = 4.0
	var cut_tree: Node = world.get_node("StarterIsland/Palm3")
	_save.mark_cut(cut_tree)
	cut_tree.free()
	world.get_node("LitterSpawner").spawn_at(load("res://data/items/plastic_bag.tres"), Vector2(-700, -300), true)
	(world.get_node("Player") as Node2D).global_position = Vector2(-100, 50)
	(world.get_node("Boat") as Node2D).global_position = Vector2(16, 300)
	world.get_node("Boat").restore_aboard()
	var clock := root.get_node("GameClock")
	clock.day = 4
	clock.time_of_day = 0.8
	var profile := root.get_node("RangerProfile")
	profile.set_choice("hair", 3)
	profile.finish_creation()
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	regions.discover(kelp)
	var fleet := root.get_node("Fleet")
	var home: Resource = load("res://data/regions/home_island.tres")
	fleet.complete(home)
	fleet.install(&"salvaged_sonar_core")
	fleet.complete(kelp)
	fleet.install(&"kelp_fibre")
	fleet.add_count(&"shed_kelp", 3)
	root.get_node("Journal").discover_plant(load("res://data/plants/giant_kelp.tres"))
	var arctic: Resource = load("res://data/regions/arctic_ocean.tres")
	regions.discover(arctic)  # without the Cargo Module: locked again on loading
	missions._done["home_island/rescue_boat"] = 3
	world.get_node("MangroveIsland/Ecosystem").set("_silt", {Vector2i(6, 1): 0.6})
	world.get_node("HookIsland/Ecosystem/Sector3").knowledge = 0.45
	world.get_node("HookIsland/Ecosystem/Sector5").dive_marked = true
	world.get_node("PolarIsland/Ecosystem").set("_season", 1.25)
	load("res://scripts/player/controlled_body.gd").water_until = 7.5
	var people := root.get_node("People")
	people.restore({})
	people.talk(load("res://data/people/tom.tres"))
	people.finish_talk()
	root.get_node("Rescues").restore({"current": {"id": "home_turtle", "name": "Milo", "since": 2.0, "stage": 1, "cared": -1}})
	_inventory.picked[&"foam_box"] = 4
	var picked_before: Dictionary = _inventory.picked.duplicate()
	_expect(_save.save_to(world, PATH), "saved")
	load("res://scripts/player/controlled_body.gd").water_until = -1.0
	world.free()

	# --- "Restart": empty state, fresh world, load ---
	regions.restore([])
	fleet.restore({})
	missions.restore({})
	events.restore({})
	root.get_node("People").restore({})
	root.get_node("Rescues").restore({})
	_inventory.restore({})
	_inventory.litter_collected = 0
	_inventory.picked.clear()
	_journal.restore([])
	clock.day = 1
	clock.time_of_day = 0.3
	profile.restore({}, false)
	root.get_node("Funding").restore({})
	world = _new_world()
	_expect(_save.load_from(world, PATH), "loaded")
	_expect(profile.look["hair"] == 3 and profile.created, "avatar look restored")
	_expect(root.get_node("Funding").balance == 77, "funding restored")
	_expect(world.get_node("StarterIsland/Palm3").is_queued_for_deletion(), "a cut-down tree stays cut down")
	_expect(clock.day == 4 and absf(clock.time_of_day - 0.8) < 0.01, "day and time restored")
	_expect(_inventory.count(&"plastic_bottle") == 2, "inventory restored (2 bottles)")
	_expect(_inventory.stored(&"wood") == 4, "stored wood restored (6 - 2 for the sanctuary)")
	_expect(_journal.has(&"green_turtle"), "discovery restored")
	_expect(regions.is_discovered(kelp) and not regions.is_discovered(load("res://data/regions/deep_sea.tres")),
		"discovered islands restored")
	_expect(world.get_node("Debris1").is_queued_for_deletion(), "collected litter stays gone")
	_expect(_inventory.litter_collected == 7, "litter collected ever restored (%d)" % _inventory.litter_collected)
	_expect(_inventory.picked == picked_before, "litter picked up per kind restored (%s)" % [_inventory.picked])
	_expect(fleet.is_installed(&"kelp_fibre") and fleet.level() == 2 and fleet.objective_done(home), "objectives and fleet upgrades restored")
	_expect(fleet.count_of(&"shed_kelp") == 3, "gathered shed kelp restored")
	_expect(root.get_node("Journal").has_plant(&"giant_kelp"), "plants found are restored")
	_expect(not regions.is_discovered(arctic), "an island found without the upgrade it needs is locked again")
	_expect(missions.active != null and missions.active.id == &"turtle_monitoring", "a mission that's out is still out")
	_expect(missions.times_done(load("res://data/missions/rescue_boat.tres"), home) == 3, "how often each mission has run is restored")
	_expect(is_equal_approx(world.get_node("MangroveIsland/Ecosystem").silt_of(Vector2i(6, 1)), 0.6), "silt in the Mangrove Coast's channels is restored")
	_expect(is_equal_approx(world.get_node("HookIsland/Ecosystem/Sector3").knowledge, 0.45) and world.get_node("HookIsland/Ecosystem/Sector5").dive_marked,
		"how well the Deep Sea's dark areas are known, and the area marked for a dive, are restored")
	_expect(is_equal_approx(world.get_node("PolarIsland/Ecosystem").get("_season"), 1.25), "the Polar Ocean's ice season is restored")
	_expect(is_equal_approx(load("res://scripts/player/controlled_body.gd").water_until, 7.5), "the ranger's water is restored")
	_expect(root.get_node("People").has_met(load("res://data/people/tom.tres")), "the people the ranger has met are remembered")
	_expect(root.get_node("Rescues").pet_name() == "Milo", "the young animal in the ranger's care is remembered")
	var caught: Node = world.get_node_or_null("Dolphin1")
	_expect(caught != null and world.get_node_or_null("Crab2") != null, "animals that arrived are back")
	_expect(caught.tangled and caught.tangle_item.id == &"fishing_line", "an animal caught again is still caught")
	var cells := {}
	for b in get_nodes_in_group("buildings"):
		if b.data.id in [&"tent", &"turtle_protection_area"]:
			cells[b.data.id] = b.cell
	_expect(cells == {&"tent": Vector2i(-1, -1), &"turtle_protection_area": Vector2i(14, -1)},
		"buildings restored where they were placed")
	var ships := get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"expedition_boat")
	_expect(ships.size() == 1 and ships[0].cell == Vector2i(-3, 6), "an Exploration Ship with no dock is removed on loading; the docked one stays")
	var restored_area: Node = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"turtle_protection_area")[0]
	_expect(restored_area.tier == 2 and restored_area.capacity() == 5 and restored_area.built_day == 3,
		"upgrade tier and build day restored")
	_expect(restored_area.get_node("Sprite2D").texture == restored_area.data.tier_textures[1], "and its tier's picture")
	_expect(restored_area.damaged and events.is_coming(), "storm damage and a coming storm are saved")
	_expect(restored_area.pending_funds == 25,
		"uncollected donations restored")
	var nests := get_nodes_in_group("nests")
	_expect(nests.size() == 1 and nests[0].position == Vector2(300, 0) and is_equal_approx(nests[0].laid_at, 3.9),
		"nest restored")
	_expect(is_equal_approx(nests[0].protected_until, 5.5) and nests[0].storm_hit, "its protection and storm damage restored")
	_expect(world.get_node("GreenTurtle").injured, "a hurt animal is still hurt after loading (until rescued)")
	var kelp_back: Node2D = world.get_node("KelpIsland/Ecosystem/Kelp3")
	_expect(is_equal_approx(kelp_back.health, 0.77) and is_equal_approx(kelp_back.urchins, 4.0), "the Kelp Forest's beds are restored")
	var babies := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.young)
	_expect(babies.size() == 1 and babies[0].position.distance_to(Vector2(-500, 100)) < 1.0, "hatchling restored")
	var grown_ups := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return not a.young and is_equal_approx(a.born_at, 1.5))
	_expect(grown_ups.size() == 1 and grown_ups[0].position.distance_to(Vector2(-560, 200)) < 1.0
		and grown_ups[0].last_nest_day == 3 and grown_ups[0].home_radius == 200.0, "a grown-up hatchling restored (still grown up)")
	var washed_in := get_nodes_in_group("debris").filter(func(d: Node) -> bool: return d.spawned)
	_expect(washed_in.size() == 1 and washed_in[0].position == Vector2(-700, -300)
		and washed_in[0].item.id == &"plastic_bag", "washed-in litter restored")
	_expect((world.get_node("Player") as Node2D).global_position == Vector2(-100, 50), "ranger position restored")
	_expect((world.get_node("Boat") as Node2D).global_position == Vector2(16, 300), "boat position restored")
	_expect(world.get_node("Boat").controlled and not world.get_node("Player").visible, "still aboard")
	world.free()

	# --- A save code round-trips, even with line breaks pasted in; junk is refused ---
	var text := FileAccess.get_file_as_string(PATH)
	var code: String = _save.encode(text)
	_expect(code.begins_with("BH1:") and code.length() < text.length(), "save code is compact")
	_expect(_save.decode(code.insert(20, "\n ")) == text, "save code decodes to the save")
	_expect(_save.decode("BH1:hello") == "" and _save.decode("hello") == "", "junk code refused")

	# --- An older save: a ship built before its island's objective was done is removed (its
	# funding returned), and islands it found are locked again; the ranger goes home ---
	fleet.restore({})
	regions.restore([])
	root.get_node("Funding").restore({"balance": 0})
	world = _new_world()
	build_mode = world.get_node("BuildMode")
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-1, 6))
	build_mode.add_building(load("res://data/buildings/dock.tres"), Vector2i(-2, 5))
	build_mode.add_building(ship, Vector2i(-3, 6))
	regions.discover(kelp)
	world.get_node("Boat").restore_ashore()
	(world.get_node("Player") as Node2D).global_position = kelp.arrival
	_expect(_save.save_to(world, PATH), "saved an older-style game")
	world.free()
	regions.restore([])
	root.get_node("Funding").restore({"balance": 0})
	world = _new_world()
	_expect(_save.load_from(world, PATH), "loaded it")
	ships = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"expedition_boat")
	_expect(ships.is_empty() and root.get_node("Funding").balance == ship.cost_funding,
		"the unearned ship is gone and its funding returned (%d)" % root.get_node("Funding").balance)
	_expect(not regions.is_discovered(kelp), "the Kelp Forest must be explored again")
	_expect((world.get_node("Player") as Node2D).global_position == home.arrival, "the ranger is back home")
	world.free()

	# --- A damaged save is kept aside, not overwritten ---
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	world = _new_world()
	_expect(not _save.load_from(world, PATH), "damaged save not loaded")
	_expect(FileAccess.file_exists(PATH + ".bad") and not FileAccess.file_exists(PATH), "damaged save kept as .bad")
	world.free()

	for f in [PATH, PATH + ".bad"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _new_world() -> Node:
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	return world



func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
