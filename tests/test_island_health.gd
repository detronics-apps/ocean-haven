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
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var home: Resource = load("res://data/regions/home_island.tres")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	var journal := root.get_node("Journal")
	_expect(health.of(self, kelp) < 0.0, "no health on islands without factors yet")

	var arrivals: GDScript = load("res://scripts/animals/arrivals.gd")
	var count := func(id: StringName) -> int:
		return get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == id).size()
	_expect(count.call(&"ghost_crab") == 1 and count.call(&"bottlenose_dolphin") == 1 and count.call(&"green_turtle") == 1,
		"the island starts with 1 crab, 1 dolphin and 1 turtle")
	world.get_node("LitterSpawner").fill(30)
	_expect(get_nodes_in_group("debris").size() >= 30, "a new game starts with about 30 pieces of litter (%d)" % get_nodes_in_group("debris").size())
	_expect(arrivals.check(world).is_empty(), "nobody new arrives while it's polluted")
	var start: float = health.of(self, home)
	_expect(start > 0.0 and start < 0.5, "the Starting Island starts in poor health (%.2f)" % start)
	# Clean up all its litter.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var cleaned: float = health.of(self, home)
	_expect(cleaned > start, "cleaning up raises its health (%.2f)" % cleaned)
	var came: Array = arrivals.check(world)
	_expect(came.size() == 1 and came[0].name == "Crab2" and count.call(&"ghost_crab") == 2, "a cleaner beach: a second crab arrives")
	_expect(arrivals.check(world).is_empty(), "and only once")
	for id in ["green_turtle", "bottlenose_dolphin", "ghost_crab"]:
		journal.help(load("res://data/animals/%s.tres" % id))
	var helped: float = health.of(self, home)
	_expect(helped > cleaned, "freeing animals raises it (%.2f)" % helped)
	for i in 5:
		var turtle: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
		turtle.set("data", load("res://data/animals/green_turtle.tres"))
		turtle.set("young", true)
		turtle.position = Vector2(-500 + i * 20, 100)
		world.add_child(turtle)
	_expect(is_equal_approx(health.of(self, home), 1.0), "clean, animals freed, 6 turtles: fully healthy")
	came = arrivals.check(world)
	_expect(came.size() == 1 and came[0].name == "Dolphin1" and count.call(&"bottlenose_dolphin") == 2,
		"cleaner water: a second dolphin (the rest wait for other islands to recover)")
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
	_expect(world.get_node("KelpIsland/Ground").modulate == Color.WHITE, "islands without health keep their colours")

	# Oil on the water: only the ranger's own boat cleans it up, and it's never carried.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var spawner: Node = world.get_node("LitterSpawner")
	var clean: float = health.of(self, home)
	var oil: Node = spawner.spawn_at(load("res://data/items/oil_patch.tres"), Vector2(-700, -300), true)
	_expect(health.of(self, home) < clean, "oil on the water lowers the island's health")
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
	_expect(text.contains("island health") and text.contains("Oil patches on the water: 2") and text.contains("Turtles living here: 6 / 6"),
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
