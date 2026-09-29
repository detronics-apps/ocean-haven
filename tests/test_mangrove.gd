extends SceneTree
## The Mangrove Coast: nursery pools cut off by silt, connected by digging through the mud;
## silt settles where water stands (slower where it flows and beside mangroves); water gates
## set the level on the flats, where flamingos feed and build mud-mound nests; young
## snappers need linked pools with mangroves; the Waterworks Station's missions; saved.
## Run: godot --headless --path . --script res://tests/test_mangrove.gd --quit-after 300000

const PATH := "user://test_mangrove.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var clock := root.get_node("GameClock")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var mangrove: Resource = load("res://data/regions/mangrove_coast.tres")
	regions.discover(mangrove)
	root.get_node("Funding").restore({"balance": 5000})
	root.get_node("Inventory").restore({"plastic_bottle": 100}, {"wood": 100})
	var player: Node2D = world.get_node("Player")
	player.global_position = mangrove.arrival
	for i in 3:
		await process_frame
	world.get_node("MangroveLitter").fill(mangrove.arrival_litter)  # the first visit's litter surge
	var eco: Node = world.get_node("MangroveIsland/Ecosystem")
	var ground: TileMapLayer = world.get_node("MangroveIsland/Ground")

	# --- Arriving: every species there but struggling, the pools cut off, health near 0 ---
	_expect(eco.pool_count() == 5 and eco.pools_connected() == 0, "5 nursery pools, all cut off by silt (%d linked)" % eco.pools_connected())
	var crabs: Array = eco.living(load("res://data/animals/mangrove_crab.tres"))
	_expect(crabs.size() == 1 and crabs[0].tangled, "a crab trapped in a plastic bag")
	_expect(eco.living(load("res://data/animals/juvenile_snapper.tres")).size() == 2
		and eco.living(load("res://data/animals/american_flamingo.tres")).size() == 1
		and eco.living(load("res://data/animals/american_crocodile.tres")).size() == 1, "2 young snappers, 1 flamingo, 1 crocodile")
	_expect(not eco.level_right() and eco.nests() == 0, "the flats are too dry: no nests (%s)" % eco.call("_level_word"))
	var start: float = health.of(self, mangrove)
	_expect(start >= 0.0 and start < 0.12, "island health starts near 0 (%d%%)" % roundi(start * 100.0))

	# --- Digging through the silt links a pool to the sea ---
	var shovel: Node = world.get_node("SandShovel")
	var plug := _plug(eco, ground)
	_expect(plug != Vector2i.MAX, "a pool is cut off by a mud plug")
	var plug_world := Vector2i((ground.to_global(ground.map_to_local(plug)) / 32.0).floor())
	shovel.pick_up(plug_world)
	_expect(eco.pools_connected() == 1 and root.get_node("Inventory").count(&"mud") == 1,
		"digging the plug out links the pool, and the ranger keeps the mud")
	_expect(plug in eco.channels(), "the dug tile is a channel now")

	# --- A closed gate across the channel cuts it off again, and raises the water level ---
	var build_mode: Node = world.get_node("BuildMode")
	var gate_data: Resource = load("res://data/buildings/water_gate.tres")
	_expect(build_mode.placement_problem(gate_data, plug_world) == "", "a water gate fits across the narrow channel (%s)" % build_mode.placement_problem(gate_data, plug_world))
	var open_water := Vector2i((mangrove.center / 32.0).floor()) + Vector2i(20, 0)
	_expect(build_mode.placement_problem(gate_data, open_water) != "", "but not out on open water")
	var gate: Node = build_mode.add_building(gate_data, plug_world)
	player.global_position = gate.global_position + Vector2(-40, 0)
	await process_frame
	var labels: Array = gate.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Close the gate" in labels, "a gate can be closed (%s)" % [labels])
	gate.toggle_gate()
	_expect(gate.gate_closed and eco.pools_connected() == 0 and eco.level_right(),
		"closed: the pool is cut off again, but the flats hold water (level %d%%)" % roundi(eco.water_level() * 100.0))
	_expect(eco.nests() >= 1, "the water level is right: the flamingo builds a mud-mound nest")

	# --- Standing water silts up; flowing water much more slowly ---
	for i in 12:  # 3 days
		eco.tick(0.25)
	_expect(eco.silt_of(plug) == 0.0, "a tile with a gate on it doesn't silt")
	gate.toggle_gate()
	gate.demolish()
	gate.demolish()
	await process_frame
	var dug := _plug(eco, ground)
	var dug_world := Vector2i((ground.to_global(ground.map_to_local(dug)) / 32.0).floor())
	player.global_position = ground.to_global(ground.map_to_local(dug)) + Vector2(0, -32)
	shovel.pick_up(dug_world)
	_expect(eco.pools_connected() >= 2, "a second pool linked (%d)" % eco.pools_connected())
	for i in 4:
		eco.tick(0.25)
	var flowing: float = eco.silt_of(dug)
	_expect(flowing > 0.0 and flowing < 0.1, "a linked channel silts slowly (%.2f in a day)" % flowing)
	# Fill in the pool's other side so its channel stands still: silt settles fast.
	root.get_node("Inventory").restore({}, {})
	_expect(eco.silt_of(dug) < 1.0, "(not silted yet)")
	eco.set("_silt", {dug: 0.95})
	eco.set("flowing_silt", 1.0)
	eco.tick(0.25)
	eco.set("flowing_silt", 0.15)
	_expect(ground.get_cell_tile_data(dug).get_custom_data("terrain") == "mud" and eco.pools_connected() < 2,
		"a channel that silts up turns back into mud, cutting the pool off")
	_expect(shovel.material_at(dug_world) != null, "and it can be dug out again: nothing is lost for good")

	# --- Young snappers need linked pools with mangroves ---
	var fish_before: int = eco.fish_supported()
	var linked := _linked_pool(eco)
	var tree_data: Resource = load("res://data/buildings/mangrove_tree.tres")
	var planted := false
	root.get_node("Inventory").add(load("res://data/items/mangrove_propagule.tres"), 3)
	if linked >= 0:
		var centre: Vector2 = eco.get("_pool_marks")[linked].global_position
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var cell := Vector2i((centre / 32.0).floor()) + Vector2i(dx, dy)
				if not planted and build_mode.placement_problem(tree_data, cell) == "" and Vector2(cell * 32).distance_to(centre) < 90.0:
					var planted_tree: Node = build_mode.add_building(tree_data, cell)
					planted_tree.built_day = clock.day - 5  # grown
					planted = true
	await process_frame
	_expect(planted and eco.fish_supported() > fish_before, "a mangrove beside a linked pool makes it a nursery: more young fish (%d -> %d)" % [fish_before, eco.fish_supported()])

	# --- The Waterworks Station's missions ---
	var result: Dictionary = eco.run_mission(load("res://data/missions/water_flow_survey.tres"))
	_expect(result.found.size() >= 3 and result.detail.contains("cut off"), "the water flow survey marks the cut-off pools (%s)" % result.detail)
	result = eco.run_mission(load("res://data/missions/water_level_check.tres"))
	_expect(result.detail.contains("too low") or result.detail.contains("no water gates"), "the water level check says what to change (%s)" % result.detail)
	result = eco.run_mission(load("res://data/missions/wildlife_monitoring.tres"))
	_expect(result.detail.contains("Crabs") and result.found.size() == 1, "wildlife monitoring finds the trapped crab (%s)" % result.detail)
	var station: Resource = load("res://data/buildings/waterworks_station.tres")
	var offered: Array = root.get_node("Missions").offered_by(&"waterworks_station")
	_expect(station.only_on == &"mangrove_coast" and offered.size() == 6, "the Waterworks Station offers 6 missions")

	# --- Crocodile Protection Zones keep patrol boats out ---
	var zone: Node = build_mode.add_building(load("res://data/buildings/crocodile_zone.tres"), open_water)
	var patrol_script: GDScript = load("res://scripts/player/patrol_boat.gd")
	_expect(patrol_script.in_protected_zone(self, zone.global_position + Vector2(60, 0)), "patrol boats keep out of a crocodile zone")
	eco.settle()
	_expect(eco.crocodiles_supported() == 1, "one crocodile per zone")

	# --- Flash flood: silt dumped in the channels, most where water stands ---
	var events := root.get_node("RareEvents")
	var flood_event: Resource = load("res://data/events/flash_flood.tres")
	_expect(flood_event.region == &"mangrove_coast" and flood_event.flood_silt > 0.0, "the Flash Flood hits the Mangrove Coast")
	var channels_before: int = eco.channels().size()
	eco.set("_silt", {})
	var hit: int = eco.flood(2.0)
	_expect(hit >= 1 and eco.channels().size() < channels_before, "a flood silts channels up (%d)" % hit)

	# --- The objective: water flowing again, then resin from fallen branches ---
	var goals: Array = mangrove.goals
	_expect(goals.size() == 2 and goals[0].target == &"mangrove_flowing" and goals[1].target == &"mangrove_resin", "the objective: get the water flowing, then gather resin")
	root.get_node("Fleet").mark(&"mangrove_flowing")
	eco.call("_objective")
	var resin := get_nodes_in_group("debris").filter(func(d: Node) -> bool: return d.item.id == &"resin_branch")
	_expect(resin.size() >= 1, "fallen branches with resin turn up by the mangroves (%d)" % resin.size())
	resin[0].collect()
	_expect(root.get_node("Fleet").count_of(&"mangrove_resin") == 1, "gathering one counts towards the Mangrove Resin")

	# --- The station explains how the water works ---
	var menu: Node = world.get_node_or_null("MissionMenu")
	var station_b: Node = build_mode.add_building(station, Vector2i((mangrove.arrival / 32.0).floor()) + Vector2i(2, -6))
	player.global_position = station_b.global_position
	await process_frame
	if menu:
		menu.open()
		_expect(menu.find_child("Guide", true, false) != null, "the Waterworks Station has a 'How it works' card")
		menu.close()

	# --- Saved ---
	eco.set("_silt", {dug + Vector2i(1, 0): 0.4})
	var saved: Dictionary = eco.to_dict()
	eco.restore({})
	eco.restore(saved)
	_expect(is_equal_approx(eco.silt_of(dug + Vector2i(1, 0)), 0.4), "silt is saved")
	_expect(root.get_node("SaveGame").save_to(world, PATH), "saved the game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


## A mud plug next to a cut-off pool (ground cell), or MAX.
func _plug(eco: Node, ground: TileMapLayer) -> Vector2i:
	var reach: Dictionary = eco.connected()
	for pool: Array in eco.get("_pools"):
		if pool.any(func(c: Vector2i) -> bool: return reach.has(c)):
			continue
		for c: Vector2i in pool:
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				var tile := ground.get_cell_tile_data(n)
				if tile and tile.get_custom_data("terrain") == "mud":
					var beyond := ground.get_cell_tile_data(n + d)
					if beyond and beyond.get_custom_data("terrain") in ["water", ""] and not pool.has(n + d):
						return n
	return Vector2i.MAX


func _linked_pool(eco: Node) -> int:
	var reach: Dictionary = eco.connected()
	for i in eco.pool_count():
		if eco.call("_pool_linked", i, reach):
			return i
	return -1


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
