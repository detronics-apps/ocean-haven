extends SceneTree
## Island health (Ocean Impact per island): the Starting Island's health rises as its
## litter is cleaned up, animals are freed and more turtles live there, and its ground
## colours go from muted to vibrant with it. Islands without health factors have none yet.
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

	var start: float = health.of(self, home)
	_expect(start > 0.0 and start < 0.5, "the Starting Island starts in poor health (%.2f)" % start)
	# Clean up all its litter.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	var cleaned: float = health.of(self, home)
	_expect(cleaned > start, "cleaning up raises its health (%.2f)" % cleaned)
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

	# The Journal shows it.
	var journal_screen: Node = world.get_node("JournalScreen")
	journal_screen.open()
	var text := ""
	for label in journal_screen.find_child("Health_home_island", true, false).find_children("*", "Label", true, false):
		text += (label as Label).text + "\n"
	_expect(text.contains("island health") and text.contains("12 pieces") and text.contains("Turtles living here: 6 / 6"),
		"the Journal shows island health and what goes into it")
	journal_screen.close()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
