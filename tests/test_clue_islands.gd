extends SceneTree
## The Clue Board's island cards (docs/CLUE_BOARD.md nodes 2 and 3), from what the ranger sees
## while on the island, never from health flags: the kelp chain (few otters, grazed beds, otters
## back, fewer grazed beds, thick kelp), the Mangrove pools cut off, a reef patch the ranger
## planted grown back with parrotfish there, S2.G from two islands, and S3.G from two guesses
## and what was then seen (no right answer).
## Run: godot --headless --path . --script res://tests/test_clue_islands.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	var people := root.get_node("People")
	var journal := root.get_node("Journal")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	clues.set_process(false)
	fleet.restore({})
	clues.restore({})
	people.restore({})
	journal.restore([])
	regions.restore(["home_island", "kelp_forest", "mangrove_coast", "tropical_reef"])
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var player: Node2D = world.get_node("Player")
	var kelp_region: Resource = load("res://data/regions/kelp_forest.tres")
	var kelp: Node = world.get_node("KelpIsland/Ecosystem")

	# --- S2.K on the Kelp Forest ---
	player.global_position = kelp_region.arrival
	for i in 5:
		await process_frame
	kelp.set_process(false)  # (the forest holds still while the test changes it)
	clues.check()
	_expect("few" in clues._state.get(&"s2k_kelp", {}).get("ev", []), "hardly any otters: seen before Finn asks (kept)")
	people.talk(load("res://data/people/finn.tres"))
	people._guesses["finn/guess_kelp"] = "It grows back!"
	for bed in kelp.beds():
		bed.urchins = 8.0
		bed.health = 0.1
	clues.check()
	_expect(clues.is_open(&"s2k_kelp") and not "grazed" in clues._state[&"s2k_kelp"].ev, "grazed beds count only once a count was read")
	root.get_node("Missions").returned.emit(load("res://data/missions/urchin_pressure_survey.tres"), 1)
	clues.check()
	_expect("grazed" in clues._state[&"s2k_kelp"].ev, "the urchin count shows the beds grazed bare")
	for bed in kelp.beds():
		bed.urchins = 1.0
		bed.health = 0.9
	clues.check()
	_expect(not clues.is_answered(&"s2k_kelp"), "fewer urchins and thick kelp without otters back: no answer")
	var otter_data: Resource = load("res://data/animals/sea_otter.tres")
	for i in 2:
		kelp._spawn(otter_data, kelp.beds()[i].global_position)
	clues.check()
	_expect(clues.is_answered(&"s2k_kelp"), "otters back, then fewer urchins and thick kelp: answered")

	# --- S2.M: the pools cut off, seen on the Mangrove Coast ---
	player.global_position = load("res://data/regions/mangrove_coast.tres").arrival
	for i in 5:
		await process_frame
	clues.check()
	_expect("cut" in clues._state.get(&"s2m_pools", {}).get("ev", []), "the cut-off pools and few young fish are seen")
	_expect(not clues.is_open(&"s2m_pools"), "(no question until Rosa asks)")

	# --- S2.R: a patch the ranger planted, grown back, parrotfish there ---
	var reef_region: Resource = load("res://data/regions/tropical_reef.tres")
	player.global_position = reef_region.arrival
	for i in 5:
		await process_frame
	var reef: Node = world.get_node("ReefIsland/Ecosystem")
	reef.set_process(false)
	people.talk(load("res://data/people/kai.tres"))
	var patch: Node2D = reef.patches()[0]
	patch.coral = 0.9
	clues.check()
	_expect(not clues.is_answered(&"s2r_reef"), "a patch the ranger didn't plant doesn't count")
	fleet.mark(StringName("coral_planted_" + patch.name))
	reef._spawn(load("res://data/animals/parrotfish.tres"), patch.global_position)
	clues.check()
	var reef_said: String = clues.statement(clues.card(&"s2r_reef"))
	_expect(clues.is_answered(&"s2r_reef") and reef_said.contains("Parrotfish were there") and not reef_said.contains("because"),
		"planted, grown back, parrotfish there: answered, no cause claimed (%s)" % reef_said)

	# --- S2.G from two islands ---
	clues._state[&"s2m_pools"] = {"open": 1, "ev": ["cut", "linked", "fish"], "done": 1, "text": "(pools)"}
	clues.check()
	var said: String = clues.statement(clues.card(&"s2g_balance"))
	_expect(clues.is_answered(&"s2g_balance") and said.contains("In the Kelp Forest") and said.contains("Mangrove Coast")
		and not said.contains("everything"), "S2.G names its two islands: %s" % said)

	# --- S3.G: two guesses, and what was seen ---
	people._guesses["maya/guess_nest"] = "Nothing, yet."
	journal._nests[&"green_turtle"] = 1
	player.global_position = kelp_region.arrival
	await process_frame
	clues.check()
	var watched: String = clues.statement(clues.card(&"s3g_watch"))
	_expect(clues.is_answered(&"s3g_watch") and watched.contains("Nothing, yet.") and watched.contains("It grows back!"),
		"S3.G keeps both guesses, right or not, beside what happened: %s" % watched)

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
