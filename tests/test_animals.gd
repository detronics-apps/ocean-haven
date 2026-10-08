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
	load("res://scripts/animals/arrivals.gd").restore(world, ["Dolphin1", "Dolphin3", "Crab2"])  # the pod and crabs of a recovered island
	var player: Node2D = world.get_node("Player")
	var dolphins := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"bottlenose_dolphin")
	var crabs := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"ghost_crab")
	_expect(dolphins.size() == 3 and crabs.size() == 2, "a dolphin pod and two crabs live here")
	player.global_position = Vector2(-2000, 2000)  # far away while they wander
	for d in get_nodes_in_group("debris"):
		d.free()  # no litter about, so dolphins don't go guiding yet
	world.get_node("LitterSpawner").set_process(false)
	_expect(world.get_node("Dolphin2").tangled and world.get_node("Crab1").tangled,
		"a dolphin is caught in a ghost net and a crab in a plastic bag")

	# --- 10 s of wandering: each stays in its habitat ---
	var dolphins_at_sea := true
	var crabs_ashore := true
	var dived := false
	var surfaced := false
	for i in 900:
		await physics_frame
		for d in dolphins:
			dolphins_at_sea = dolphins_at_sea and _terrain(d.global_position) in ["", "water"]
			var alpha: float = d.get_node("Sprite2D").modulate.a
			dived = dived or alpha < 0.3
			surfaced = surfaced or (dived and alpha > 0.95)
		for c in crabs:
			crabs_ashore = crabs_ashore and not _terrain(c.global_position) in ["", "water"]
	_expect(dolphins_at_sea, "dolphins stay at sea")
	_expect(dived and surfaced, "dolphins dive (fade to a shadow) and come back up for air")
	var angles := dolphins.map(func(d: Node2D) -> float: return rad_to_deg(d.get("_home").angle()))
	angles.sort()
	_expect(angles[1] - angles[0] > 90.0 and angles[2] - angles[1] > 90.0, "dolphins live spread around the island %s" % [angles])
	_expect(crabs_ashore, "crabs never go into the water")
	_expect(crabs.all(func(c: Node2D) -> bool: return c.get_node("Sprite2D").rotation == 0.0),
		"crabs scuttle sideways (no turning)")

	# --- A boat-speed approach doesn't scare dolphins; they come to look ---
	var dolphin: Node2D = dolphins[0]
	var rowboat: Node2D = world.get_node("Boat")  # untyped: Boat uses autoloads
	rowboat.restore_aboard()  # at sea in the boat (on foot the ranger can't follow a dolphin out)
	rowboat.global_position = dolphin.global_position + Vector2(250, 0)  # from the open sea
	await physics_frame
	var fled := false
	for i in 600:  # until it relaxes (it may swim off a little first)
		if rowboat.global_position.distance_to(dolphin.global_position) > 60.0:
			rowboat.global_position = rowboat.global_position.move_toward(dolphin.global_position, 2.5)  # 150 px/s
		await physics_frame
		fled = fled or dolphin.get("_state") == 2
		if dolphin.is_relaxed():
			break
	_expect(not fled, "dolphins don't flee from a cruising boat")
	_expect(dolphin.is_relaxed(), "dolphin relaxed and curious (%.0f px away, calm %.1f s, state %d)" % [
		rowboat.global_position.distance_to(dolphin.global_position), dolphin.get("_calm"), dolphin.get("_state")])
	rowboat.restore_ashore()
	for i in 5:
		await physics_frame  # settle ashore before the next check moves the ranger

	# --- Rushing at a crab sends it scuttling off ---
	var crab: Node2D = crabs[0]
	crab.global_position = crab.home()  # its spot on the beach (crabs roam, and inland of a roaming crab can be the lagoon)
	crab.set("_state", 0)
	crab.set("_rest_left", 5.0)
	player.global_position = crab.global_position + crab.global_position.direction_to(Vector2.ZERO) * 150.0  # from inland
	await physics_frame
	var crab_fled := false
	for i in 90:
		player.global_position = player.global_position.move_toward(crab.global_position, 3.0)  # 180 px/s
		await physics_frame
		crab_fled = crab_fled or crab.get("_state") == 2
	_expect(crab_fled, "crab dashes off when rushed")

	# --- Two dolphins in reach, one tangled: E helps the tangled one ---
	var healthy: Node2D = world.get_node("Dolphin1")
	var caught: Node2D = world.get_node("Dolphin2")
	caught.global_position = healthy.global_position + Vector2(30, 0)
	player.global_position = healthy.global_position + Vector2(-2000, 0)
	await physics_frame
	player.global_position = healthy.global_position + Vector2(-20, 40)  # one jump, then stay still
	for i in 150:
		# Held in reach: this is about which button comes first, not where they swim.
		healthy.global_position = player.global_position + Vector2(20, -40)
		caught.global_position = player.global_position + Vector2(50, -40)
		await physics_frame
	var journal_before: int = root.get_node("Journal").photos(&"bottlenose_dolphin")
	await process_frame
	var bar: Node = world.get_node("HUD/ActionZone/ActionBar")
	var labels: Array = bar.get_children().filter(func(b: Node) -> bool: return b is Button).map(func(b: Button) -> String: return b.text)
	var info: Label = bar.get_node("Info")
	_expect(info.visible and info.text.begins_with("Bottlenose Dolphin:"), "one info line about the nearest animal (%s)" % info.text)
	_expect("Free the Bottlenose Dolphin" in labels and "Photo: Bottlenose Dolphin" in labels
		and labels[0] == "Free the Bottlenose Dolphin",
		"action bar offers both, helping first: %s" % [labels])
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	root.push_input(e)
	for i in 3:
		await physics_frame
	_expect(not caught.tangled, "E frees the tangled dolphin first")
	_expect(root.get_node("Journal").photos(&"bottlenose_dolphin") == journal_before, "not a photo of the other one")
	await process_frame
	await process_frame
	for button: Node in bar.get_children():
		if button is Button and button.text == "Photo: Bottlenose Dolphin":
			button.pressed.emit()
	_expect(root.get_node("Journal").photos(&"bottlenose_dolphin") == journal_before + 1, "the Photo button takes a photo")

	# --- A trusting dolphin leads you to litter ---
	var guide: Node2D = world.get_node("Dolphin1")
	player.global_position = guide.global_position + Vector2(90, 0)  # arrive (a jump), then stay calm
	var spawner: Node = world.get_node("LitterSpawner")
	var litter: Node2D = spawner.spawn_at(load("res://data/items/plastic_bottle.tres"),
		guide.global_position + Vector2(0, 250), true)
	var journal := root.get_node("Journal")
	for i in 150:
		await physics_frame
	_expect(guide.is_relaxed() and guide.get("_guide_to") == null, "a trusting dolphin waits for you to play before it guides")
	var play_labels: Array = guide.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Play with the Bottlenose Dolphin" in play_labels, "offers to play (%s)" % [play_labels])
	guide.actions().filter(func(a: Dictionary) -> bool: return a.label.begins_with("Play"))[0].do.call()
	var guided := false
	for i in 900:
		await physics_frame
		if guide.global_position.distance_to(litter.global_position) < 40.0:
			guided = true
			break
	_expect(guided, "after playing, the dolphin swims to the litter it spotted")
	_expect(journal.gifts(&"bottlenose_dolphin") >= 1, "the Journal counts it")
	litter.queue_free()  # the ranger picks it up
	await physics_frame
	await physics_frame
	_expect(not guide.played, "after each find, play with it again for the next")

	# --- Crabs dig up buried litter while you watch ---
	var digger: Node2D = world.get_node("Crab2")
	digger.data.dig_chance = 1.0
	player.global_position = digger.global_position + Vector2(0, -60)
	var before_gifts: int = journal.gifts(&"ghost_crab")
	for i in 900:
		await physics_frame
		if player.global_position.distance_to(digger.global_position) > 150.0:
			player.global_position = digger.global_position + Vector2(0, -60)  # keep watching as it roams
		if journal.gifts(&"ghost_crab") > before_gifts:
			break
	var dug := get_nodes_in_group("debris").filter(func(d: Node) -> bool: return not d.floating)
	_expect(journal.gifts(&"ghost_crab") > before_gifts and dug.size() >= 1, "a crab dug up beach litter")
	for i in 20:  # keep trying all day: only 2 finds a day for all crabs together
		player.global_position = digger.global_position + Vector2(0, -60)
		digger._maybe_dig()
	_expect(journal.gifts(&"ghost_crab") == before_gifts + 2, "crabs dig up at most 2 a day (%d)" % (journal.gifts(&"ghost_crab") - before_gifts))
	dug = get_nodes_in_group("debris").filter(func(d: Node) -> bool: return not d.floating)
	_expect(dug.size() < 2 or dug[0].global_position != dug[1].global_position, "dug up in different spots")
	root.get_node("GameClock").day += 1
	player.global_position = digger.global_position + Vector2(0, -60)
	digger._maybe_dig()
	_expect(journal.gifts(&"ghost_crab") == before_gifts + 3, "and more the next day")
	digger.data.dig_chance = 0.08

	# --- Journal knows every species ---
	var screen: Node = world.get_node("JournalScreen")
	screen.open()
	_expect(screen.find_child("Entry_ghost_crab", true, false) == null and screen.find_child("Health_home_island", true, false) != null,
		"the Journal opens on this island's tab: its health, no animals")
	screen.find_child("Tab_animals", true, false).pressed.emit()
	_expect(screen.find_child("Entry_bottlenose_dolphin", true, false) != null
		and screen.find_child("Entry_ghost_crab", true, false) != null, "Journal lists dolphins and crabs")
	screen.close()

	# --- Roamers drift all round the island, not just round their home spot; crabs keep to theirs ---
	var roamer: Node = dolphins[0]
	roamer.tangled = false
	var furthest := 0.0
	for i in 60:
		furthest = maxf(furthest, roamer._pick_target().distance_to(roamer._home))
	_expect(roamer.data.roams and furthest > roamer.home_radius, "a dolphin roams beyond its home area (%.0f px)" % furthest)
	_expect(not crabs[0].data.roams, "crabs keep to their beach")

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
