extends SceneTree
## Travellers: dolphins, sperm whales and green turtles visit other islands, spreading out from
## their home island one island along the chain every few days (a whale from the Deep Sea reaches
## the Tropical Reef last), only where they really live; the first time, that island's people say
## they saw it. A green turtle grazing the Reef's seagrass makes room for more seahorses.
## Run: godot --headless --path . --script res://tests/test_travellers.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var travellers := root.get_node("Travellers")
	var people := root.get_node("People")
	var clock := root.get_node("GameClock")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	travellers.restore({})
	people.restore({})
	for region: Resource in regions.all():
		regions.discover(region)
	var dolphin: Resource = load("res://data/animals/bottlenose_dolphin.tres")
	var whale: Resource = load("res://data/animals/sperm_whale.tres")
	var turtle: Resource = load("res://data/animals/green_turtle.tres")
	var region := func(id: String) -> Resource: return load("res://data/regions/%s.tres" % id)

	_expect(travellers.steps(&"deep_sea", &"kelp_forest") < travellers.steps(&"deep_sea", &"tropical_reef"),
		"a whale from the Deep Sea is further from the Reef than from the Kelp Forest")
	_expect(not "arctic_ocean" in Array(dolphin.travels_to) and not "kelp_forest" in Array(turtle.travels_to),
		"they only go where they really live (no bottlenose dolphins in the Arctic)")
	travellers.morning()
	_expect(travellers.reach(dolphin) == 1, "the Starting Island has dolphins: they start spreading")
	_expect(travellers.can_reach(dolphin, region.call("kelp_forest")) and not travellers.can_reach(dolphin, region.call("tropical_reef")),
		"first to the next islands along the chain, not yet the far ones")
	travellers._since[dolphin.id] = clock.day - travellers.DAYS_PER_STEP
	_expect(travellers.can_reach(dolphin, region.call("tropical_reef")), "a few days later, further along")
	travellers._since[whale.id] = clock.day
	_expect(travellers.can_reach(whale, region.call("kelp_forest")) and not travellers.can_reach(whale, region.call("tropical_reef")),
		"whales reach the Reef last")

	var visitor: Node2D = travellers.visit(dolphin, region.call("kelp_forest"))
	await process_frame
	_expect(visitor.visiting and regions.nearest(visitor.global_position).id == &"kelp_forest", "a dolphin visits the Kelp Forest for the day")
	var finn: Resource = load("res://data/people/finn.tres")
	people.restore({"met": ["finn", "ines"]})
	var said: Array = people.talk(finn).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(said.any(func(t: String) -> bool: return t.contains("dolphins") and t.contains("Starting Island")), "the island's people say they saw it (%s)" % [said])
	travellers.morning()
	await process_frame
	_expect(not is_instance_valid(visitor) or visitor.is_queued_for_deletion(), "next morning it's gone again")

	var reef_eco: Node = world.get_node("ReefIsland/Ecosystem")
	var area: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/seagrass_protection_area.tres"), Vector2i(0, 0))
	area.global_position = reef_eco.patches()[0].global_position + Vector2(60, 0)
	area.built_day = clock.day - 2
	var room: int = reef_eco.seahorses_supported()
	var grazer: Node2D = travellers.visit(turtle, region.call("tropical_reef"))
	grazer.global_position = region.call("tropical_reef").arrival
	await process_frame
	_expect(reef_eco.turtle_grazing() and reef_eco.seahorses_supported() > room, "a green turtle grazing the seagrass makes room for more seahorses")
	var saved: Dictionary = travellers.to_dict()
	travellers.restore({})
	travellers.restore(saved)
	_expect(travellers.reach(dolphin) >= 2, "how far they've spread is saved")

	# --- Seeds: boobies from the Starting Island bring palms to the Reef; terns pines to the Arctic ---
	var booby: Resource = load("res://data/animals/red_footed_booby.tres")
	var palm: Resource = load("res://data/buildings/palm_tree.tres")
	var reef: Resource = region.call("tropical_reef")
	travellers.seeds_from_health = 1.1  # (the Starting Island isn't healthy yet)
	var booby_visitor: Node2D = travellers.visit(booby, reef)
	_expect(travellers.spread_seeds(booby) == null, "no seeds until the boobies' own island is thriving")
	travellers.seeds_from_health = 0.0
	var before: int = travellers.sprouted(palm, reef)
	var sprout: Node = travellers.spread_seeds(booby)
	_expect(before == 0 and sprout != null and regions.nearest(sprout.global_position) == reef
		and load("res://scripts/world/terrain.gd").at(self, sprout.global_position) in ["sand", "grass"]
		and sprout.find_child("PalmTree", true, false).stage() == 0,
		"a booby on the Reef: a little palm sprouts there, the island's first tree")
	for i in 20:
		travellers.spread_seeds(booby)
	_expect(travellers.sprouted(palm, reef) == booby.seeds_max, "up to %d palms (%d)" % [booby.seeds_max, travellers.sprouted(palm, reef)])
	booby_visitor.free()
	var tern: Resource = load("res://data/animals/arctic_tern.tres")
	var pine: Resource = load("res://data/buildings/shore_pine.tres")
	var arctic: Resource = region.call("arctic_ocean")
	var pine_sprout: Node = travellers.spread_seeds(tern)
	_expect(pine_sprout != null and regions.nearest(pine_sprout.global_position) == arctic and pine_sprout.data == pine,
		"terns back from the Deep Sea: a little pine sprouts among the Arctic rocks")
	travellers.seeds_from_health = 0.7

	# --- Arctic trees: snow through the freeze, green again once the ice has melted ---
	var polar: Node = null
	for eco in get_nodes_in_group("ecosystems"):
		if eco.has_method("snow_cover"):
			polar = eco
	var pine_tree: Node = pine_sprout.find_children("*", "StaticBody2D", true, false)[0]
	var depth_at := func(phase: float) -> float:
		polar._season = polar.cycle_days * phase
		pine_tree._process(0.0)
		return pine_tree.get_node("Sprite2D").material.get_shader_parameter("depth")
	var freezing: float = depth_at.call(0.2)
	var frozen: float = depth_at.call(0.45)
	var thawing: float = depth_at.call(0.6)
	var open_water: float = depth_at.call(0.9)
	_expect(freezing > 0.0 and frozen > freezing and thawing < frozen and open_water == 0.0,
		"snow builds up in the freeze (%.1f), deepest frozen (%.1f), melts in the thaw (%.1f), none in open water" % [freezing, frozen, thawing])
	var reef_tree: Node = sprout.find_child("PalmTree", true, false)
	reef_tree._process(0.0)
	_expect(reef_tree.get_node("Sprite2D").material == null, "no snow on the Reef")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
