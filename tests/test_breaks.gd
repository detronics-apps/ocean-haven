extends SceneTree
## Each island breaks the shared pattern once (docs/ISLAND_RULES.md 9):
## - Kelp Forest: the rescue comes first (Finn found the otter pup; the platform is its vet room).
## - Mangrove Coast: Rosa and Samuel disagree about the gates; the ranger finds the balance.
## - Tropical Reef: beauty first (the last living patch by Leilani's dive spot, fading).
## - Deep Sea: quiet first (the sixgill pup only comes once the water is quiet).
## - Polar Ocean: the bear first (the first visit's litter by the camp draws it in on day one).
## Run: godot --headless --path . --script res://tests/test_breaks.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	people.restore({})
	fleet.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var by_id := {}
	for p: Resource in people.all():
		by_id[p.id] = p

	# --- Kelp: the pup first ---
	var finn_hello: String = " ".join(by_id[&"finn"].topics.filter(func(t: Resource) -> bool: return t.id == &"hello")[0].lines)
	_expect(finn_hello.contains("otter pup alone"), "Finn's first words: an otter pup alone at the jetty")
	var platform: Resource = by_id[&"finn"].topics.filter(func(t: Resource) -> bool: return t.id == &"platform")[0]
	_expect(" ".join(platform.lines).contains("vet room") and " ".join(platform.reminder).contains("pup"), "the platform is wanted for the pup")

	# --- Mangrove: two people, two views ---
	var samuel: Resource = by_id[&"samuel"]
	var ids: Array = samuel.topics.map(func(t: Resource) -> StringName: return t.id)
	_expect(&"gates_argue" in ids and &"gates_agree" in ids and ids.find(&"caught") < ids.find(&"gates_argue"),
		"Samuel disagrees with Rosa about the gates (after any caught-animal alert)")
	var rosa_flowing: Resource = by_id[&"rosa"].topics.filter(func(t: Resource) -> bool: return t.id == &"flowing")[0]
	_expect(" ".join(rosa_flowing.lines).contains("Open every water gate") and " ".join(rosa_flowing.thanks).contains("balance between us"),
		"Rosa wants every gate open, and thanks the ranger for the balance")
	_expect(people.check("!water_right", samuel) or people.check("water_right", samuel), "the water level condition works")

	# --- Reef: beauty first ---
	var reef: Node = null
	for eco: Node in get_nodes_in_group("ecosystems"):
		if eco.get("region_id") == &"tropical_reef":
			reef = eco
	var leilani: Resource = by_id[&"leilani"]
	var nearest: Node2D = null
	for patch: Node2D in reef.get_children().filter(func(c: Node) -> bool: return c.has_method("split")):
		if not nearest or patch.global_position.distance_to(leilani.spot) < nearest.global_position.distance_to(leilani.spot):
			nearest = patch
	_expect(nearest != null and is_equal_approx(nearest.coral, reef.last_healthy_coral) and nearest.planted >= 1.0,
		"the patch by Leilani's dive spot is the last living one (%.2f)" % (nearest.coral if nearest else -1.0))
	_expect(" ".join(leilani.topics.filter(func(t: Resource) -> bool: return t.id == &"hello")[0].lines).contains("last patch of living coral"),
		"Leilani shows it first")

	# --- Deep Sea: quiet first ---
	var sixgill: Resource = load("res://data/rescues/deep_sixgill.tres")
	_expect("quiet>=70" in sixgill.offer_when, "the sixgill pup only comes once the water is quiet")
	var bram: Resource = by_id[&"bram"]
	var quiet_now: bool = people.check("quiet>=0", bram)
	_expect(quiet_now, "the quiet condition reads the Deep Sea's water")

	# --- Polar: the bear first ---
	var polar: Node = null
	for eco: Node in get_nodes_in_group("ecosystems"):
		if eco.get("region_id") == &"arctic_ocean":
			polar = eco
	var arctic: Resource = load("res://data/regions/arctic_ocean.tres")
	_expect(arctic.camp_litter >= 2, "the first visit washes litter up by the camp")
	var spawner: Node = null
	for s: Node in get_nodes_in_group("litter_spawner"):
		if load("res://scripts/world/regions.gd").nearest(s.area.get_center()) == arctic:
			spawner = s
	var sanna: Resource = by_id[&"sanna"]
	var before: int = polar.camp_rubbish()
	for i in arctic.camp_litter:
		spawner.wash_up_near(sanna.spot)
	_expect(polar.camp_rubbish() >= before + arctic.camp_litter, "litter by Sanna's camp counts as rubbish at camp, with nothing built yet")

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
