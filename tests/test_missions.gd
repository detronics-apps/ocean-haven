extends SceneTree
## The Marine Rescue & Research Station (the Starting Island's signature facility): one per
## island, only on the Starting Island. It sends missions for funding, one at a time; each is
## back a few real minutes later and responds to what's happening: rescue (hurt animals
## recover), boat patrol, pollution survey (hidden litter), turtle monitoring (protects
## nests from storms), dolphin tracking (a visiting dolphin). A mission that's out is saved.
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
	var no_icon := []
	for f in DirAccess.get_files_at("res://data/missions"):
		if f.ends_with(".tres") and not load("res://data/missions/" + f).icon:
			no_icon.append(f)
	_expect(no_icon.is_empty(), "every mission has its own picture (%s)" % [no_icon])
	var pic: TextureRect = menu.find_child("Mission_rescue_boat", true, false).find_children("*", "TextureRect", true, false)[0]
	_expect(pic.texture != null, "shown on the left of its card")
	_expect(_card_text(menu, "rescue_boat").contains("Not run yet."), "each card says how often it has been run: not yet")

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
	_expect(missions.time_left() == "2 minutes", "back in 2 real minutes (%s)" % missions.time_left())
	clock.advance(60.0)
	await process_frame
	_expect(missions.active != null and missions.time_left() == "1 minute", "not back after 1 minute")
	clock.advance(61.0)
	await process_frame
	var marked: Array = missions.marked()
	menu.open()
	_expect(_card_text(menu, "rescue_boat").contains("Run once so far.") and _card_text(menu, "pollution_survey").contains("Not run yet."),
		"once it's back: 'Run once so far' (per mission)")
	menu.close()
	_expect(missions.active == null and marked.size() == 3 and marked.all(func(a: Node) -> bool: return a.tangled),
		"back after 2 minutes: marks the 3 animals in distress (%d)" % marked.size())
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

	# --- Pollution survey: turns up 5-10 more pieces of hidden litter, marked until collected ---
	var home: Resource = load("res://data/regions/home_island.tres")
	var litter_before: int = get_nodes_in_group("debris").size()
	missions.send(load("res://data/missions/pollution_survey.tres"), home)
	clock.advance(121.0)
	await process_frame
	var revealed: int = get_nodes_in_group("debris").size() - litter_before
	_expect(revealed >= 5 and revealed <= 10 and missions.marked().size() == revealed,
		"the pollution survey finds %d hidden pieces, even past the usual limit, and marks them" % revealed)
	var piece: Node = missions.marked()[0]
	piece.free()
	_expect(missions.marked().size() == revealed - 1, "collected litter drops off the map")
	clock.sleep_until_morning()
	_expect(missions.marked().size() == revealed - 1, "its marks stay until the litter is collected")

	funding.restore({"balance": 500})
	# --- A storm hurts a few animals and washes over unprotected nests ---
	var events := root.get_node("RareEvents")
	var storm: Resource = load("res://data/events/coastal_storm.tres")
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	var protected_nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	protected_nest.set("species", turtle_data)
	protected_nest.position = Vector2(480, 0)
	world.add_child(protected_nest)
	missions.send(load("res://data/missions/turtle_monitoring.tres"), home)
	clock.advance(181.0)
	await process_frame
	_expect(protected_nest.is_protected() and protected_nest in missions.marked(), "turtle monitoring finds and protects the nest")
	var open_nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	open_nest.set("species", turtle_data)
	open_nest.position = Vector2(-480, 60)
	world.add_child(open_nest)
	var turtle: Node2D = world.get_node("GreenTurtle")
	turtle.set("tangled", false)
	storm.injured_max = 1
	storm.injures = PackedStringArray(["green_turtle"])
	events.strike(storm)
	_expect(turtle.injured, "the storm hurt the turtle (never badly)")
	_expect(not protected_nest.storm_hit and open_nest.storm_hit, "the protected nest came through; the other was washed over")
	var hatched: Array = [0]
	root.get_node("Journal").hatched.connect(func(_a, n: int) -> void: hatched[0] = n)
	open_nest.hatch()
	_expect(hatched[0] == 1, "one egg of the washed-over nest still hatches")
	var ranger: Node2D = world.get_node("Player")
	ranger.global_position = turtle.global_position + Vector2(40, 0)
	await physics_frame
	turtle.set("_calm", 10.0)
	await physics_frame
	_expect(turtle.info.contains("hurt") and turtle.info.contains("Rescue"), "near it: it's hurt, a Rescue mission can help (%s)" % turtle.info)

	# --- Rescue: the hurt animals recover ---
	missions.send(load("res://data/missions/rescue_boat.tres"), home)
	clock.advance(121.0)
	await process_frame
	await process_frame
	_expect(not turtle.injured, "the rescue team helped the turtle recover")

	# --- Boat patrol: for 2 days busy boats don't disturb animals, and storms hurt fewer ---
	missions.send(load("res://data/missions/boat_patrol.tres"), home)
	clock.advance(121.0)
	await process_frame
	await process_frame
	_expect(missions.is_on(&"boat_patrol") and missions.problem(load("res://data/missions/boat_patrol.tres")).begins_with("Still going"),
		"the boat patrol is on (and can't be sent twice)")
	_expect(turtle.call("_nearest_busy_boat", turtle.global_position) == Vector2.INF, "animals aren't disturbed by boats meanwhile")
	events.strike(storm)  # 1 at most, halved
	_expect(not turtle.injured, "a storm hurts fewer animals during a boat patrol")
	clock.advance(clock.DAY_LENGTH * 2.0)
	_expect(not missions.is_on(&"boat_patrol"), "it's over after 2 days")

	# --- Dolphin tracking: a visiting dolphin for 2 days ---
	missions.send(load("res://data/missions/dolphin_tracking.tres"), home)
	clock.advance(181.0)
	await process_frame
	await process_frame
	var visitor: Node2D = world.get_node_or_null("VisitingDolphin")
	_expect(visitor != null and not visitor.leaving, "a visiting dolphin joins the island")
	clock.advance(clock.DAY_LENGTH * 2.0)
	await process_frame
	_expect(visitor.leaving, "after 2 days it swims back out to its pod")

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


func _card_text(menu: Node, id: String) -> String:
	var text := ""
	for label: Label in menu.find_child("Mission_" + id, true, false).find_children("*", "Label", true, false):
		text += label.text + "\n"
	return text


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
