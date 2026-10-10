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

	# --- S6.N: released, then seen again another day ---
	rescues.restore({"done": {"home_turtle": {"name": "Milo", "day": 10, "met": true, "where": "home_island", "seen": []}}})
	clues.check()
	_expect(clues.is_open(&"s6n_home_turtle"), "released: will I see Milo again?")
	var milo: Node2D = world.place_tagged(load("res://data/rescues/home_turtle.tres"), rescues.done[&"home_turtle"])
	player.global_position = milo.global_position + Vector2(40, 0)
	clues.check()
	_expect(not clues.is_answered(&"s6n_home_turtle"), "not answered on the day it was released")
	clock.day = 12
	clues.check()
	_expect(clues.is_answered(&"s6n_home_turtle") and clues.statement(clues.card(&"s6n_home_turtle")).contains("Milo"), "seen again: answered, by name")
	_expect(not clues.is_open(&"s6t_travel"), "Milo at home says nothing about travelling")

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
	var reef_said: String = clues.statement(clues.card(&"s6s_reef"))
	_expect(clues.is_answered(&"s6s_reef") and reef_said.contains("After boobies") and not reef_said.contains("brought"),
		"S6.S says what was seen, in order, never that the birds brought it: %s" % reef_said)
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
