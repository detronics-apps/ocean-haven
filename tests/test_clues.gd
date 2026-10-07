extends SceneTree
## Hint-givers never just repeat themselves: when the ranger keeps coming back to the same
## advice (stuck), they say what's holding the island back most right now and what to do,
## e.g. Bram on the Deep Sea: patrol boats over the dark areas are the loudest thing there.
## Run: godot --headless --path . --script res://tests/test_clues.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	people.restore({})
	root.get_node("Fleet").restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var deep: Resource = load("res://data/regions/deep_sea.tres")
	regions.discover(deep)
	world.get_node("Player").global_position = deep.arrival
	var eco: Node = world.get_node("HookIsland/Ecosystem")
	for i in 3:
		var sector: Node2D = eco.sectors()[i + 1]
		world.get_node("BuildMode").add_building(load("res://data/buildings/patrol_boat.tres"), terrain.cell_of(sector.to_global(sector.cells[0])))
	for s: Node in eco.sectors():
		s.knowledge = 1.0
	for i in 3:
		await process_frame
	var bram: Resource = load("res://data/people/bram.tres")
	var talk := func() -> String:
		var text := " ".join(people.talk(bram).map(func(l: Dictionary) -> String: return l.text))
		people.finish_talk()
		return text
	talk.call()  # meeting him
	var first: String = talk.call()
	var again: String = talk.call()
	_expect(first != again, "the second time round he doesn't say the same thing (%s)" % again)
	var clues := [again, talk.call(), talk.call()]
	_expect(clues.any(func(t: String) -> bool: return t.contains("patrol boat")), "among the things he points at: the patrol boats over the dark areas (%s)" % [clues])
	_expect(clues[0] != clues[1], "each visit a different clue")

	# --- Back home with Tom: past the island's own clues, he points at what's open elsewhere ---
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	regions.discover(reef)
	world.get_node("Player").global_position = Vector2.ZERO
	var tom: Resource = load("res://data/people/tom.tres")
	var heard: Array = []
	for i in 8:
		heard.append(" ".join(people.talk(tom).map(func(l: Dictionary) -> String: return l.text)))
		people.finish_talk()
	_expect(heard.any(func(t: String) -> bool: return t.contains("Kai") and t.contains("Tropical Reef")),
		"Tom: someone on the Tropical Reef would like to meet you (%s)" % [heard])
	_expect(heard.any(func(t: String) -> bool: return t.contains("Imani") or t.contains("Bram")) or heard.any(func(t: String) -> bool: return t.contains("Deep Sea")),
		"and the Deep Sea, still open")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
