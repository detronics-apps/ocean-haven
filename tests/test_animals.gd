extends SceneTree
## Dolphins and crabs: dolphins stay at sea and come to investigate a boat
## cruising by (no fleeing); crabs stay off the water, scuttle sideways and dash
## off when rushed. Every animal matters: one dolphin is caught in a ghost net and
## one crab in a plastic bag; trusting dolphins lead you to litter; crabs dig it
## up. The Journal lists every species.
## Run: godot --headless --path . --script res://tests/test_animals.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var player: Node2D = world.get_node("Player")
	var dolphins := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"bottlenose_dolphin")
	var crabs := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"ghost_crab")
	_expect(dolphins.size() == 3 and crabs.size() >= 4, "a dolphin pod and crabs live here")
	player.global_position = Vector2(-2000, 2000)  # far away while they wander
	for d in get_nodes_in_group("debris"):
		d.free()  # no litter about, so dolphins don't go guiding yet
	world.get_node("LitterSpawner").set_process(false)
	_expect(world.get_node("Dolphin2").tangled and world.get_node("Crab1").tangled,
		"a dolphin is caught in a ghost net and a crab in a plastic bag")

	# --- 10 s of wandering: each stays in its habitat ---
	var dolphins_at_sea := true
	var crabs_ashore := true
	for i in 600:
		await physics_frame
		for d in dolphins:
			dolphins_at_sea = dolphins_at_sea and _terrain(d.global_position) in ["", "water"]
		for c in crabs:
			crabs_ashore = crabs_ashore and not _terrain(c.global_position) in ["", "water"]
	_expect(dolphins_at_sea, "dolphins stay at sea")
	_expect(crabs_ashore, "crabs never go into the water")
	_expect(crabs.all(func(c: Node2D) -> bool: return c.get_node("Sprite2D").rotation == 0.0),
		"crabs scuttle sideways (no turning)")

	# --- A boat-speed approach doesn't scare dolphins; they come to look ---
	var dolphin: Node2D = dolphins[0]
	player.global_position = dolphin.global_position + Vector2(250, 0)  # from the open sea, like a boat
	await physics_frame
	var fled := false
	for i in 150:
		player.global_position = player.global_position.move_toward(dolphin.global_position, 2.5)  # 150 px/s
		await physics_frame
		fled = fled or dolphin.get("_state") == 2
	_expect(not fled, "dolphins don't flee from a cruising boat")
	_expect(dolphin.is_relaxed(), "dolphin relaxed and curious")

	# --- Rushing at a crab sends it scuttling off ---
	var crab: Node2D = crabs[0]
	player.global_position = crab.global_position + Vector2(150, 0)
	await physics_frame
	var crab_fled := false
	for i in 90:
		player.global_position = player.global_position.move_toward(crab.global_position, 3.0)  # 180 px/s
		await physics_frame
		crab_fled = crab_fled or crab.get("_state") == 2
	_expect(crab_fled, "crab dashes off when rushed")

	# --- A trusting dolphin leads you to litter ---
	var guide: Node2D = world.get_node("Dolphin1")
	player.global_position = guide.global_position + Vector2(90, 0)  # arrive (a jump), then stay calm
	var spawner: Node = world.get_node("LitterSpawner")
	var litter: Node2D = spawner.spawn_at(load("res://data/items/plastic_bottle.tres"),
		guide.global_position + Vector2(0, 250), true)
	var journal := root.get_node("Journal")
	var guided := false
	for i in 900:
		await physics_frame
		if guide.global_position.distance_to(litter.global_position) < 40.0:
			guided = true
			break
	_expect(guided, "trusting dolphin swims to the litter it spotted")
	_expect(journal.gifts(&"bottlenose_dolphin") >= 1, "the Journal counts it")

	# --- Crabs dig up buried litter while you watch ---
	var digger: Node2D = world.get_node("Crab2")
	digger.data.dig_chance = 1.0
	player.global_position = digger.global_position + Vector2(0, -60)
	var before_gifts: int = journal.gifts(&"ghost_crab")
	for i in 600:
		await physics_frame
		if journal.gifts(&"ghost_crab") > before_gifts:
			break
	var dug := get_nodes_in_group("debris").filter(func(d: Node) -> bool: return not d.floating)
	_expect(journal.gifts(&"ghost_crab") > before_gifts and dug.size() >= 1, "a crab dug up beach litter")
	digger.data.dig_chance = 0.2

	# --- Journal knows every species ---
	var screen: Node = world.get_node("JournalScreen")
	screen.open()
	_expect(screen.find_child("Entry_bottlenose_dolphin", true, false) != null
		and screen.find_child("Entry_ghost_crab", true, false) != null, "Journal lists dolphins and crabs")
	screen.close()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
