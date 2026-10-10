extends SceneTree
## The Clue Board's watched sequences (docs/CLUE_BOARD.md S4.B, S5.G, S7.G, S7.R): litter kept
## coming back after it was cleared, its source was fixed, then mornings with none of it while
## other litter still drifted in; an animal freed, caught again and freed again; a storm that
## damaged buildings, fixed and cleared. Each only in the order it was seen.
## Run: godot --headless --path . --script res://tests/test_clue_setbacks.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	var clock := root.get_node("GameClock")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	clues.set_process(false)
	fleet.restore({})
	clues.restore({})
	regions.restore(["home_island"])
	clock.day = 5
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	world.get_node("Player").global_position = Vector2(0, 40)
	var spawner: Node = world.get_node("LitterSpawner")
	var foam: Resource = load("res://data/items/foam_box.tres")
	var bottle: Resource = load("res://data/items/plastic_bottle.tres")

	# --- S4.B: cleared, back again, fixed at its source, then none while other litter comes ---
	for debris: Node in root.get_tree().get_nodes_in_group("debris"):
		debris.free()
	await process_frame
	clues.check()
	_expect(clues._memo.has("cleared/foam_box@home_island"), "the beach is clear of foam boxes")
	var back: Node2D = spawner.spawn_at(foam, Vector2(-300, 220), false)
	clues.litter_washed_in(back)
	_expect(clues._memo.has("back/foam_box@home_island"), "a foam box drifts back in after it was cleared")
	fleet.mark(&"foam_asked")
	fleet.mark(&"foam_traced")
	fleet.mark(&"rings_traced")
	clues.check()
	_expect(clues.is_answered(&"s4a_sources") and clues.is_open(&"s4b_prevent"), "S4.A answered opens S4.B")
	world.get_node("BuildMode").add_building(load("res://data/buildings/box_return_depot.tres"), Vector2i(-2, 3))
	_expect(fleet.stopped(&"foam_box"), "(the Box Return Depot stops foam at its source)")
	for day in 3:
		clock.day += 1
		clues.litter_washed_in(spawner.spawn_at(bottle, Vector2(-200 - day * 20, 230), false))  # other litter still comes
		clock.day += 1
		clues._morning()
		clues.check()
	var said: String = clues.statement(clues.card(&"s4b_prevent"))
	_expect(clues.is_answered(&"s4b_prevent") and said.contains("foam boxes") and said.contains("though other litter still did"),
		"S4.B: kept coming, fixed, none for 3 mornings while other litter came: %s" % said)
	_expect(not clues._memo.keys().any(func(k: String) -> bool: return k.begins_with("back/plastic_bag")), "(bags were never seen coming back)")

	# --- S7.G: freed, caught again, freed again ---
	var dolphin: Node2D = world.get_node("Dolphin2")
	if dolphin.tangled:
		dolphin._interact()
	dolphin.tangle(load("res://data/items/ghost_net.tres"))
	clues.animal_caught(dolphin)
	_expect(clues._memo.has("caught_again") and not clues._memo.has("freed_again"), "caught again: not yet a recovery")
	dolphin._interact()
	clues.check()
	_expect(clues.is_answered(&"s7g_keep_going") and clues.statement(clues.card(&"s7g_keep_going")).contains("so I freed it again"),
		"S7.G: freed again after it was caught again")

	# --- S7.R: a storm damages a building; fixed and the beach cleared the next day ---
	var storm: Resource = load("res://data/events/coastal_storm.tres")
	clues._event_warned(storm)
	clues.check()
	_expect(clues.is_open(&"s7r_events"), "the warning raises the question")
	var hut: Node = null
	for b: Node in root.get_tree().get_nodes_in_group("buildings"):
		if not b.data.storm_proof:
			hut = b
			break
	hut.damaged = true
	clues._event_struck(storm, 1)
	clues.check()
	_expect(not clues.is_answered(&"s7r_events"), "not answered the day it struck")
	clock.day += 1
	clues.check()
	_expect(not clues.is_answered(&"s7r_events"), "still damaged: no answer")
	hut.damaged = false
	for debris: Node in root.get_tree().get_nodes_in_group("debris"):
		debris.free()
	await process_frame
	clues.check()
	_expect(clues.is_answered(&"s7r_events") and clues.statement(clues.card(&"s7r_events")).contains("I fixed them"),
		"fixed and cleared: S7.R says what happened (%s)" % clues.statement(clues.card(&"s7r_events")))

	# --- S5.G: a bad thing the ranger let happen, a good thing the ranger did ---
	clues.animal_caught(world.get_node("Crab1"))
	clues.check()
	_expect(clues.is_open(&"s5g_choices") and not clues.is_answered(&"s5g_choices"), "a bad result alone isn't the answer")

	# --- The board's memory is saved ---
	var saved: Dictionary = clues.to_dict()
	clues.restore({})
	clues.restore(saved)
	_expect(clues._memo.has("back/foam_box@home_island") and clues.is_answered(&"s4b_prevent"), "what the board watched is saved")

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
