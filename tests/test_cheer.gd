extends SceneTree
## Progress feedback (ProgressCheer): sparkles when the island the ranger is on gets 5 %
## healthier than it has been (not when they arrive, nor for going back up to where it was),
## a card with the animal's picture when one comes back (bigger the first time for a
## species), and a "+N" when funding comes in. Nothing to tap: it never gets in the way.
## Run: godot --headless --path . --script res://tests/test_cheer.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var fleet := root.get_node("Fleet")
	fleet.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var cheer: Control = world.find_child("ProgressCheer", true, false)
	_expect(cheer != null, "the HUD has the progress feedback")
	_expect(cheer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "taps go through it")
	var home: Resource = load("res://data/regions/home_island.tres")

	# --- Health: a baseline on arrival, then a sparkle per new 5 % step ---
	var best: Dictionary = cheer.get("_best")
	best.clear()
	cheer.call("_check_health")
	_expect(best.has(&"home_island") and (cheer.get("_sparks") as Array).is_empty(), "arriving sets where the island is, no sparkle")
	best[&"home_island"] = int(best[&"home_island"]) - 1  # as if it had just got 5 % healthier
	cheer.call("_check_health")
	_expect(not (cheer.get("_sparks") as Array).is_empty(), "a new 5 % step of health sparkles")
	(cheer.get("_sparks") as Array).clear()
	best[&"home_island"] = int(best[&"home_island"]) + 1  # back down and up again to the best: no repeat
	cheer.call("_check_health")
	_expect((cheer.get("_sparks") as Array).is_empty(), "no sparkle for going back up to where it was")

	# --- An animal comes back: a card with its picture ---
	var dolphin: Resource = load("res://data/animals/bottlenose_dolphin.tres")
	world.get_node("HUD").animal_returned(dolphin, "The water is cleaner.", home)
	var card: Control = cheer.find_child("ReturnCard", true, false)
	_expect(card != null, "a card shows the animal that came back")
	if card:
		var labels: Array = card.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
		_expect(labels.any(func(t: String) -> bool: return t.contains("has come to the island") or t.contains("has joined the island")), "it says the animal came or joined, never \"the first\" (%s)" % [labels])
		_expect(labels.any(func(t: String) -> bool: return t.contains("here now:")), "it says how many there are now")
		_expect(card.find_children("*", "TextureRect", true, false).size() == 1, "with its picture")
		_expect(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "and can't be tapped (never in the way)")
	_expect(fleet.has_flag(&"returned_bottlenose_dolphin"), "the first return is remembered (saved with the fleet's flags)")
	world.get_node("HUD").animal_returned(dolphin, "Another one.", home)
	_expect((cheer.get("_cards") as Array).size() == 1, "a second card waits for the first to go")
	_expect(not (cheer.get("_cards") as Array)[0].first, "and is not a first any more")

	# --- Funding: "+N" rising from the money ---
	var before := cheer.get_children().filter(func(c: Node) -> bool: return c is Label).size()
	root.get_node("Funding").earn(12, "test")
	var floats := cheer.get_children().filter(func(c: Node) -> bool: return c is Label and c.text == "+12")
	_expect(floats.size() == 1, "funding coming in rises as +12 (%d labels before)" % before)

	world.free()
	fleet.restore({})
	_finish()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		print("FAIL: ", what)


func _finish() -> void:
	print("FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
