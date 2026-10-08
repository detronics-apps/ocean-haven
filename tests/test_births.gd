extends SceneTree
## Births: a new animal is never just there. The island still decides when and how many (same
## triggers and limits), but the newcomer is born: a grown one of its kind goes to where it
## belongs, the young one appears beside it there, follows it while it grows up (its young
## pictures, or just its size), and then goes its own way. Fish, clams and squid drift in from
## the island's edge instead.
## Run: godot --headless --path . --script res://tests/test_births.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var births: GDScript = load("res://scripts/animals/births.gd")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var clock := root.get_node("GameClock")
	var home: Resource = load("res://data/regions/home_island.tres")
	var crab_data: Resource = load("res://data/animals/ghost_crab.tres")
	var parent: Node2D = world.get_node("Crab1")
	parent.recover()  # (free of its bag)
	parent.tangled = false
	var spot: Vector2 = load("res://scripts/world/terrain.gd").nearest(self, parent.global_position + Vector2(90, 0), ["sand"], 12)

	# --- Born: the parent goes there, the young one appears beside it ---
	var newcomer: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	newcomer.set("data", crab_data)
	newcomer.position = spot
	world.add_child(newcomer)
	births.bring(newcomer, home, "A test.")
	_expect(newcomer.young and newcomer.unborn and not newcomer.visible and newcomer.parent == parent,
		"a new crab is a young one, not born yet, with the island's crab as its parent")
	_expect(parent.is_expecting() and parent.home().distance_to(spot) < 1.0, "the parent heads to where it belongs")
	var cheer: Node = world.find_child("ProgressCheer", true, false)
	_expect(cheer == null or (cheer.get("_cards") as Array).is_empty() and cheer.find_child("ReturnCard", true, false) == null,
		"no card until it's born")
	parent.give_birth_now()
	_expect(newcomer.visible and not newcomer.unborn and newcomer.global_position.distance_to(parent.global_position) < 20.0,
		"born beside its parent")
	_expect(cheer == null or cheer.find_child("ReturnCard", true, false) != null or not (cheer.get("_cards") as Array).is_empty(),
		"then the card: it has joined the island")

	# --- Growing up: its own pictures, following its parent, then off on its own ---
	var sprite: Sprite2D = newcomer.get_node("Sprite2D")
	if crab_data.young_sprites.size() >= 2:
		newcomer._pose()
		_expect(sprite.texture == crab_data.young_sprites[0] and newcomer.stage() == 0, "day 1: the baby picture")
		clock.day += 5
		newcomer.born_at = clock.now() - crab_data.grow_days * 0.6
		newcomer._pose()
		_expect(sprite.texture == crab_data.young_sprites[1] and newcomer.stage() == 1, "then the young picture")
	var follow: Vector2 = newcomer._pick_target()
	_expect(follow.distance_to(parent.global_position) < 30.0, "it keeps close to its parent")
	clock.day += 5
	newcomer.born_at = clock.now() - crab_data.grow_days - 0.1
	newcomer._process(0.1)
	_expect(not newcomer.young and newcomer.parent == null and sprite.texture == crab_data.sprite
		and newcomer.home().distance_to(spot) < 1.0, "grown (day 3 for a crab): the grown picture, and its own spot")

	# --- Growth groups: fast 3 days, medium 5, slow 7 ---
	var groups := {2.0: ["ghost_crab", "mangrove_crab", "arctic_tern", "arctic_skua"],
		4.0: ["red_footed_booby", "double_crested_cormorant", "american_flamingo", "sea_otter", "ringed_seal", "bottlenose_dolphin"],
		6.0: ["green_turtle", "american_crocodile", "polar_bear", "sperm_whale"]}
	var wrong: Array = []
	for days: float in groups:
		for id: String in groups[days]:
			if not is_equal_approx(load("res://data/animals/%s.tres" % id).grow_days, days):
				wrong.append(id)
	_expect(wrong.is_empty(), "grown on day 3 (crabs, terns, skuas), 5 (boobies, cormorants, flamingos, otters, seals, dolphins) or 7 (turtles, crocodiles, bears, whales) (%s)" % [wrong])

	# --- Drifting in: fish come in from the island's edge ---
	var fish_data: Resource = load("res://data/animals/parrotfish.tres")
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	var fish: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	fish.set("data", fish_data)
	var fish_spot: Vector2 = reef.center + Vector2(60, 40)
	fish.position = fish_spot
	world.add_child(fish)
	births.bring(fish, reef, "A test.")
	_expect(fish_data.drifts_in and not fish.young and fish.visible and fish.global_position.distance_to(reef.center) > reef.waters_radius * 0.6
		and fish.home().distance_to(fish_spot) < 1.0, "a parrotfish drifts in from the edge to where it belongs")
	_expect(regions != null, "")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	if what != "":
		print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
