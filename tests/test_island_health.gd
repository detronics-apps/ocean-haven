extends SceneTree
## Island health (Ocean Impact per island): the Starting Island's health rises as its
## litter is cleaned up, animals are freed and more turtles live there, and its ground
## colours go from muted to vibrant with it. Islands without health factors have none yet.
## The island starts with 1 turtle, 1 crab and 1 dolphin (and plenty of litter); more crabs
## and dolphins arrive as it recovers, and more again once other islands are healthy too.
## Run: godot --headless --path . --script res://tests/test_island_health.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	for island in [&"home_island", &"kelp_forest", &"mangrove_coast", &"tropical_reef", &"deep_sea", &"arctic_ocean"]:
		root.get_node("Inventory").picked_on[island] = 10  # the ranger has helped every island (Regions.helped)
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var home: Resource = load("res://data/regions/home_island.tres")
	var kelp: Resource = load("res://data/regions/arctic_ocean.tres").duplicate()
	kelp.health.clear()  # (an island with no health factors)
	var journal := root.get_node("Journal")
	_expect(health.of(self, kelp) < 0.0, "no health on islands without factors yet")

	var arrivals: GDScript = load("res://scripts/animals/arrivals.gd")
	var count := func(id: StringName) -> int:
		return get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == id).size()
	_expect(count.call(&"ghost_crab") == 1 and count.call(&"bottlenose_dolphin") == 1 and count.call(&"green_turtle") == 1,
		"the island starts with 1 crab, 1 dolphin and 1 turtle")
	world.get_node("LitterSpawner").fill(30)
	_expect(get_nodes_in_group("debris").size() >= 30, "a new game starts with about 30 pieces of litter (%d)" % get_nodes_in_group("debris").size())
	var names := func(list: Array) -> Array: return list.map(func(a: Node) -> String: return String(a.name))
	var clock := root.get_node("GameClock")
	var first: Array = names.call(arrivals.check(world))
	_expect(first.is_empty(), "while it's polluted and nothing's been planted, no new animals come (%s)" % [first])
	var start: float = health.of(self, home)
	_expect(start >= 0.0 and start < 0.3, "the Starting Island starts in poor health (%.2f)" % start)
	# Clean up all its litter.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var cleaned: float = health.of(self, home)
	_expect(cleaned > start, "cleaning up raises its health (%.2f)" % cleaned)
	# Caught animals don't count as living there until they're freed.
	for animal_name in ["GreenTurtle", "Crab1", "Dolphin2", "Seabird0"]:
		world.get_node(animal_name).restore_freed()
	var helped: float = health.of(self, home)
	_expect(helped > cleaned, "freeing animals raises it (%.2f)" % helped)
	var came: Array = names.call(arrivals.check(world))
	_expect("Crab2" in came and count.call(&"ghost_crab") == 2, "a cleaner beach: a second crab arrives (%s)" % [came])
	for i in 11:  # more than full health needs (10): the Journal counts them all
		var turtle: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
		turtle.set("data", load("res://data/animals/green_turtle.tres"))
		turtle.set("young", true)
		turtle.position = Vector2(-500 + i * 20, 100)
		world.add_child(turtle)
	came = names.call(arrivals.check(world))
	_expect(came.is_empty(), "one new arrival a day on each island (%s)" % [came])
	clock.day += 1
	came = names.call(arrivals.check(world))
	_expect("Dolphin1" in came and not "Dolphin3" in came and count.call(&"bottlenose_dolphin") == 2,
		"the next day, cleaner water: a second dolphin (the rest wait for other islands to recover) (%s)" % [came])
	clock.day += 1
	_expect(arrivals.check(world).is_empty() and count.call(&"red_footed_booby") == 1,
		"only the one seabird the island starts with: none more from the island's own palms alone")
	# Seabirds come once the ranger has planted palms (and they've grown): 1, 3, 5.
	for i in 5:
		var sapling: Node = world.get_node("BuildMode").add_building(load("res://data/buildings/palm_tree.tres"), Vector2i(-8 + i * 2, -5))
		sapling.built_day = -10  # full grown
	for i in 3:
		clock.day += 1
		arrivals.check(world)
		load("res://scripts/animals/births.gd").born_now(self)
	_expect(count.call(&"red_footed_booby") == 4, "the palms the ranger planted bring three more seabirds, one a day")
	_expect(is_equal_approx(health.of(self, home), 1.0), "no litter, no hurt or caught animals, fully populated (12 turtles, 4 seabirds, 2 crabs, 2 dolphins): 100 %")
	var hurt: Node = world.get_node("Crab1")
	hurt.injure()
	_expect(health.of(self, home) < 1.0, "a hurt animal doesn't count until it's rescued")
	hurt.recover()

	# Seabirds need full-grown palms: cut too many and one flies off (back when they regrow).
	var palms: Array = world.get_node("StarterIsland").get_children().filter(func(n: Node) -> bool: return n.is_in_group("plants"))
	while arrivals.grown_trees(self, home) >= 14:
		palms.pop_back().free()
	arrivals.check(world)
	var seabird3: Node2D = world.get_node("Seabird3")
	_expect(not seabird3.visible and not seabird3.is_in_group("animals") and count.call(&"red_footed_booby") == 3,
		"fewer than 14 palms: the third seabird flies off")
	_expect(health.of(self, home) < 1.0, "and the island is a little less healthy")
	var planted: Node = world.get_node("BuildMode").add_building(load("res://data/buildings/palm_tree.tres"), Vector2i(-2, -8))
	planted.built_day = -10  # full grown
	arrivals.check(world)
	_expect(seabird3.visible and count.call(&"red_footed_booby") == 4, "a palm grows back: it returns")
	var seabird1: Node2D = world.get_node("Seabird1")
	seabird1.global_position = Vector2(-900, 700)
	var net: Node = world.get_node("LitterSpawner").spawn_at(load("res://data/items/plastic_bottle.tres"), Vector2(-250, -400), true)
	var spots := 0
	for i in 20:
		if seabird1.call("_pick_target").distance_to(net.global_position) < 40.0:
			spots += 1
	_expect(spots == 20, "seabirds circle over floating litter near their home")
	net.free()
	for arrival: Resource in home.arrivals:
		_expect(terrain_ok(arrival), "%s arrives in its habitat" % arrival.node_name)

	# Ground colours follow health.
	var ground: CanvasItem = world.get_node("StarterIsland/Ground")
	health.tint(self)
	_expect(ground.modulate == Color.WHITE, "a healthy island shows its full colours")
	world.get_node("LitterSpawner").spawn_at(load("res://data/items/plastic_bottle.tres"), Vector2(-700, -300), true)
	for i in 11:
		world.get_node("LitterSpawner").spawn_at(load("res://data/items/plastic_bag.tres"), Vector2(-600 + i * 30, -300), true)
	health.tint(self)
	_expect(ground.modulate.r < 1.0 and ground.modulate.b > ground.modulate.r, "litter back: muted colours again")

	# Oil: none until mid-game, when the Deep Sea's Deep-Ocean Outpost brings oil-spill equipment.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var spawner: Node = world.get_node("LitterSpawner")
	spawner.at_sea_chance = 1.0
	spawner.oil_chance = 1.0
	var early_oil := 0
	for i in 6:
		var piece: Node = spawner.spawn_one()
		if piece and piece.item.id == &"oil_patch":
			early_oil += 1
	_expect(early_oil == 0, "no oil patches before the Deep-Ocean Outpost exists")
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var outpost: Resource = load("res://data/buildings/recycling_centre.tres").duplicate()
	outpost.id = &"deep_ocean_outpost"  # stand-in until the Deep Sea's outpost is made
	world.get_node("BuildMode").add_building(outpost, Vector2i(40, 40))

	# Oil on the water: only the ranger's own boat cleans it up, and it's never carried.
	var clean: float = health.of(self, home)
	var oil: Node = spawner.spawn_at(load("res://data/items/oil_patch.tres"), Vector2(-700, -300), true)
	_expect(is_equal_approx(health.of(self, home), clean), "oil isn't part of island health")
	oil._on_body_entered(world.get_node("Player"))
	var patrol := CharacterBody2D.new()
	oil._on_body_entered(patrol)
	patrol.free()
	_expect(not oil.is_queued_for_deletion(), "walking or other boats don't clean oil")
	var inventory := root.get_node("Inventory")
	var carried: int = inventory.total()
	oil._on_body_entered(world.get_node("Boat"))
	_expect(oil.is_queued_for_deletion() and inventory.total() == carried and inventory.count(&"oil_patch") == 0,
		"sailing the boat through it cleans it up (nothing to carry)")
	await process_frame
	_expect(is_equal_approx(health.of(self, home), clean), "health back up")
	spawner.at_sea_chance = 1.0
	spawner.oil_chance = 1.0
	var patches := 0
	for i in 6:
		var piece: Node = spawner.spawn_one()
		if piece and piece.item.id == &"oil_patch":
			patches += 1
	_expect(patches == spawner.max_oil, "oil drifts in now and then, at most %d patches at once (%d)" % [spawner.max_oil, patches])
	for i in 11:
		spawner.spawn_at(load("res://data/items/plastic_bag.tres"), Vector2(-600 + i * 30, -300), true)
	spawner.spawn_at(load("res://data/items/plastic_bottle.tres"), Vector2(-700, -330), true)

	# The Journal shows it.
	var journal_screen: Node = world.get_node("JournalScreen")
	journal_screen.open()
	var text := ""
	for label in journal_screen.find_child("Health_home_island", true, false).find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	_expect(text.contains("island health") and not text.contains("Oil") and text.contains("Dolphins in the pod") and text.contains("Turtles living here: 12 (10 for full health)"),
		"the Journal shows island health and what goes into it")
	journal_screen.close()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func terrain_ok(arrival: Resource) -> bool:
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	return terrain.at(self, arrival.position) in arrival.species.habitat_terrain


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
