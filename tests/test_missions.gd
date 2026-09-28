extends SceneTree
## The Marine Rescue & Research Station (the Starting Island's signature facility): one per
## island, only on the Starting Island. It sends missions for funding, one at a time; each is
## back a few hours later and marks what it found on the minimap until the next morning
## (the rescue boat: animals in distress, dropping off once freed). A mission that's out is saved.
## Run: godot --headless --path . --script res://tests/test_missions.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")
	var clock := root.get_node("GameClock")
	var missions := root.get_node("Missions")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var build_mode: Node = world.get_node("BuildMode")
	var station: Resource = load("res://data/buildings/marine_rescue_station.tres")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")

	# --- Building it: a signature facility, only on the Starting Island, one per island ---
	_expect(station.facility == &"signature", "it's a signature facility")
	funding.restore({"balance": 500})
	root.get_node("Inventory").restore({"plastic_bottle": 20}, {"wood": 20})
	build_mode.start(station)
	_expect(build_mode.placement_problem(station, Vector2i((kelp.arrival / 32.0).floor())).contains("belongs on the Starting Island"),
		"not on other islands")
	_expect(build_mode.place_at(Vector2i(-6, -4)), "built on the Starting Island (%s)" % build_mode.placement_problem(station, Vector2i(-6, -4)))
	build_mode.cancel()
	_expect(build_mode.placement_problem(station, Vector2i(-10, -4)).contains("already has"), "one per island")
	var building: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"marine_rescue_station")[0]

	# --- Spare saplings go to coastal replanting, for a grant ---
	var inventory := root.get_node("Inventory")
	inventory.add(load("res://data/items/sapling.tres"), 9)
	_expect(inventory.count(&"sapling") == 5, "you can carry 5 saplings")
	var funds_before: int = funding.balance
	building.give_away()
	_expect(inventory.available(&"sapling") == 0 and funding.balance == funds_before + 25, "5 saplings given away for 25 funding")

	# --- The mission screen ---
	var player: Node2D = world.get_node("Player")
	player.global_position = building.global_position + Vector2(0, 50)
	var labels: Array = building.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Missions" in labels, "walk up to it to send missions (%s)" % [labels])
	var menu: Node = world.get_node("MissionMenu")
	menu.open()
	for id in ["rescue_boat", "pollution_survey", "turtle_monitoring", "dolphin_tracking"]:
		_expect(menu.find_child("Mission_" + id, true, false) != null, "offers the %s" % id)
	_expect((menu.find_child("Status", true, false) as Label).text.contains("health"), "shows the island's health")

	# --- The rescue boat: finds the tangled dolphin (and the turtle and crab) ---
	clock.day = 1
	clock.time_of_day = 0.4
	var before: int = funding.balance
	menu.find_child("Mission_rescue_boat", true, false).find_child("Send", true, false).pressed.emit()
	_expect(missions.active != null and funding.balance == before - 20, "sent for 20 funding")
	_expect(not menu.visible, "the screen closes")
	menu.open()
	_expect(menu.find_child("Mission_pollution_survey", true, false).find_child("Send", true, false).disabled, "one mission at a time")
	menu.close()
	clock.advance(clock.DAY_LENGTH * 1.0 / 24.0)
	await process_frame
	_expect(missions.active != null, "not back after 1 hour")
	clock.advance(clock.DAY_LENGTH * 1.5 / 24.0)
	await process_frame
	var marked: Array = missions.marked()
	_expect(missions.active == null and marked.size() == 3 and marked.all(func(a: Node) -> bool: return a.tangled),
		"back after 2 hours: marks the 3 animals in distress (%d)" % marked.size())
	var dolphin: Node = world.get_node("Dolphin2")
	dolphin.restore_freed()
	_expect(missions.marked().size() == 2 and not dolphin in missions.marked(), "a freed animal drops off the map")

	# --- Fishing gear left in the water catches an animal again (one a morning) ---
	dolphin.global_position = Vector2(950, -700)  # away from the other animals
	var spawner: Node = world.get_node("LitterSpawner")
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()  # only the litter placed here
	var net: Node2D = spawner.spawn_at(load("res://data/items/ghost_net.tres"), dolphin.global_position + Vector2(60, 0), true)
	var bottle: Node2D = spawner.spawn_at(load("res://data/items/plastic_bottle.tres"), dolphin.global_position + Vector2(-40, 0), true)
	var caught: Array = spawner.entangle()
	_expect(caught == [dolphin] and dolphin.tangled and dolphin.tangle_item.id == &"ghost_net" and net.is_queued_for_deletion(),
		"a ghost net left near a dolphin catches it")
	_expect(not bottle.is_queued_for_deletion(), "bottles don't entangle")
	_expect(spawner.entangle().is_empty(), "nothing else to catch it")
	await process_frame
	_expect(root.get_node("SaveGame")._tangled_animals(world).get("Dolphin2") == &"ghost_net", "saved as tangled")

	# --- Surveys find litter; marks last until the next morning ---
	missions.send(load("res://data/missions/pollution_survey.tres"), load("res://data/regions/home_island.tres"))
	clock.advance(clock.DAY_LENGTH * 2.5 / 24.0)
	await process_frame
	var litter: int = get_nodes_in_group("debris").size()
	_expect(missions.marked().size() == litter and litter > 0, "the pollution survey marks every piece of litter (%d)" % litter)
	var piece: Node = missions.marked()[0]
	piece.free()
	_expect(missions.marked().size() == litter - 1, "collected litter drops off the map")
	clock.sleep_until_morning()
	_expect(missions.marked().is_empty(), "marks clear the next morning")

	# --- Not enough funding: can't send ---
	funding.restore({"balance": 5})
	_expect(missions.problem(load("res://data/missions/rescue_boat.tres")).contains("Needs 20"), "needs its funding")

	# --- A mission that's out is saved ---
	funding.restore({"balance": 100})
	missions.send(load("res://data/missions/dolphin_tracking.tres"), load("res://data/regions/home_island.tres"))
	var saved: Dictionary = missions.to_dict()
	missions.restore({})
	_expect(missions.active == null, "cleared")
	missions.restore(saved)
	_expect(missions.active != null and missions.active.id == &"dolphin_tracking", "restored from the save")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
