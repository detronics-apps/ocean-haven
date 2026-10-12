extends SceneTree
## The Clue Board's "One ocean" node (docs/CLUE_BOARD.md node 6): a named rescue seen again
## (S6.N, about that animal only), animals from other islands in sight (S6.T needs two), the
## Reef's first tree after the boobies came (S6.S: what was seen, never "the birds brought it"),
## and S6.G joining the net, the threads and the travellers.
## Run: godot --headless --path . --script res://tests/test_clue_ocean.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	var rescues := root.get_node("Rescues")
	var travellers := root.get_node("Travellers")
	var clock := root.get_node("GameClock")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	clues.set_process(false)
	fleet.restore({})
	clues.restore({})
	travellers.restore({})
	rescues.restore({})
	regions.restore(["home_island", "tropical_reef", "mangrove_coast"])
	clock.day = 10
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var player: Node2D = world.get_node("Player")
	var reef: Resource = load("res://data/regions/tropical_reef.tres")

	# --- S6.S and S6.T on the Reef ---
	player.global_position = reef.arrival
	await process_frame
	clues.check()
	_expect("bare" in clues._state.get(&"s6s_reef", {}).get("ev", []), "the Reef's bare island is noted before any tree (kept for later)")
	var booby: Node2D = travellers.visit(load("res://data/animals/red_footed_booby.tres"), reef)
	booby.global_position = reef.arrival + Vector2(60, 0)
	clues.check()
	_expect(clues.is_open(&"s6t_travel") and not clues.is_answered(&"s6t_travel"), "one kind of visitor raises the question, isn't enough")
	travellers.seeds_from_health = 0.0
	var sprout: Node = travellers.spread_seeds(load("res://data/animals/red_footed_booby.tres"))
	_expect(sprout != null, "(a palm sprouts while the boobies are there)")
	clues.check()
	_expect(not clues.is_answered(&"s6s_reef") and root.get_node("Fleet").has_flag(&"sprouted_tropical_reef"), "a palm came up: Leilani will say why it matters")
	var people := root.get_node("People")
	people._heard["leilani/booby_trees"] = true  # (she told the ranger: boobies nest in trees)
	clues.check()
	var reef_said: String = clues.statement(clues.card(&"s6s_reef"))
	_expect(clues.is_answered(&"s6s_reef") and reef_said.contains("Pisonia seeds are sticky") and reef_said.contains("hold their nests"),
		"S6.S: the boobies brought sticky Pisonia seeds (true for Pisonia): %s" % reef_said)
	travellers._told["bottlenose_dolphin/mangrove_coast"] = true
	clues.check()
	var travel_said: String = clues.statement(clues.card(&"s6t_travel"))
	_expect(clues.is_answered(&"s6t_travel") and travel_said.contains("boobies") and travel_said.contains("dolphins"),
		"two kinds of visitor: answered, naming both: %s" % travel_said)

	# --- S6.G needs the net, the threads and the travellers ---
	_expect(clues.is_open(&"s6g_ocean") and not clues.is_answered(&"s6g_ocean"), "S6.G opens with the travellers, waits for the rest")
	fleet.mark(&"fibres_traced")
	clues.check()
	_expect(not clues.is_answered(&"s6g_ocean"), "still waits for the net")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
