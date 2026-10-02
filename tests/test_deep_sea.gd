extends SceneTree
## The Deep Sea: 8 dark areas mapped by instruments (hydrophones, cameras, submarine dives),
## island-wide; light and noise drive whales and anglerfish away (never below 1); bait draws
## sixgills in (too many); mapped areas reveal lost gear (collected by boat: three recovered
## brings gear marking, so no new nets or line drift in anywhere); the giant squid appears to a
## patient camera in quiet water; the cargo search floats up the cargo module; oil spills spread
## until contained; everything is saved.
## Run: godot --headless --path . --script res://tests/test_deep_sea.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var clock := root.get_node("GameClock")
	var fleet := root.get_node("Fleet")
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var deep: Resource = load("res://data/regions/deep_sea.tres")
	fleet.restore({})
	load("res://scripts/world/regions.gd").discover(deep)
	var player: Node2D = world.get_node("Player")
	player.global_position = deep.arrival
	for i in 3:
		await process_frame
	world.get_node("DeepLitter").fill(deep.arrival_litter)
	var eco: Node = world.get_node("HookIsland/Ecosystem")
	var build_mode: Node = world.get_node("BuildMode")
	var sectors: Array = eco.sectors()
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var place := func(id: StringName, at: Vector2) -> Node:
		return build_mode.add_building(load("res://data/buildings/%s.tres" % id), terrain.cell_of(at))
	var whale_data: Resource = load("res://data/animals/sperm_whale.tres")
	var angler_data: Resource = load("res://data/animals/anglerfish.tres")
	var shark_data: Resource = load("res://data/animals/sixgill_shark.tres")

	# --- Arriving: every area dark, every species there but struggling ---
	_expect(not deep.in_development, "the Deep Sea is playable")
	_expect(sectors.size() == 8 and sectors.all(func(s: Node) -> bool: return s.knowledge == 0.0 and s.cells.size() > 10),
		"8 dark areas, each veiling its deep water")
	var whales: Array = eco.living(whale_data)
	_expect(whales.size() == 1 and whales[0].tangled, "a sperm whale caught in lost fishing line")
	_expect(eco.living(angler_data).size() == 1 and eco.living(shark_data).size() == 1 and not eco.squid_found(),
		"one anglerfish, one sixgill, and the giant squid unseen")
	_expect(health.of(self, deep) < 0.12, "health starts near 0 (%d%%)" % roundi(health.of(self, deep) * 100.0))
	whales[0].restore_freed()

	# --- Hydrophones map the deep slowly, island-wide; whales speed them up ---
	var buoy: Node = place.call(&"hydrophone_buoy", sectors[1].global_position)
	var rate: float = eco.knowledge_rate()
	_expect(rate > 0.1 and rate < 0.2, "a hydrophone learns a little a day (%.2f)" % rate)
	_expect(eco.quiet() > 0.95, "hydrophones are nearly silent")
	eco.learn(1.0)
	var first: Node = sectors.filter(func(s: Node) -> bool: return s.known())[0]
	_expect(eco.known_count() == 1, "a whole area's knowledge maps one area (%s)" % first.describe())

	# --- Mapping reveals lost gear; collecting it counts towards gear marking ---
	var gear_sector: Node = sectors[2]
	eco.learn(1.0, gear_sector)
	_expect(gear_sector.known() and gear_sector.gear_found and eco._gear_debris(gear_sector) != null,
		"mapping an area with lost gear floats it up to collect")
	var left_before: int = eco.gear_left()
	eco._gear_debris(gear_sector).collect()
	await process_frame
	eco.tick(0.01)
	_expect(eco.gear_left() == left_before - 1 and fleet.count_of(&"deep_gear") == 1, "collected gear is gone for good")
	for s: Node in sectors:
		if s.gear_item != &"":
			eco.learn(1.0, s)
			var piece: Node = eco._gear_debris(s)
			if piece:
				piece.collect()
	await process_frame
	eco.tick(0.01)
	_expect(fleet.has_flag(&"gear_marking"), "three pieces recovered: gear marking")
	var spawner: Node = world.get_node("LitterSpawner")
	var nets := 0
	for i in 60:
		var d: Node = spawner.spawn_one()
		if d and d.item.id in [&"ghost_net", &"fishing_line"]:
			nets += 1
	_expect(nets == 0, "with gear marking, no new nets or line drift in on any island")

	# --- Cameras: faster, but their light drives anglerfish off; bait draws sharks ---
	var cams: Array = []
	for i in 4:
		cams.append(place.call(&"deep_camera", sectors[3 + i].global_position))
	_expect(eco.knowledge_rate() > rate + 0.6, "cameras learn faster")
	_expect(eco.light() > eco.angler_light_max and eco.anglers_supported() == 1, "four lamps are too bright for anglerfish (never below 1)")
	for c: Node in cams:
		c.toggle_bait()
	_expect(eco.sharks_supported() >= 7, "bait draws sixgills in from far away (%d)" % eco.sharks_supported())
	for i in 8:
		eco.settle()
	var shark_factor: Resource = deep.health.filter(func(f: Resource) -> bool: return f.target == &"sixgill_shark")[0]
	_expect(health.score(self, deep, shark_factor) < 0.5, "too many sharks crowding the bait scores lower")
	_expect(eco.quiet() < eco.whale_quiet and eco.whales_supported() == 1, "all that light and bait: too noisy for more whales")
	for c: Node in cams:
		c.demolish()
		c.demolish()
	await process_frame
	await process_frame
	for i in 8:
		eco.settle()
	_expect(eco.living(shark_data).size() <= 3, "bait gone: the visiting sharks drift away (%d)" % eco.living(shark_data).size())

	# --- A submarine dive goes to the marked area ---
	var outpost: Node = place.call(&"deep_ocean_outpost", sectors[4].global_position + Vector2(0, 60))
	var dark: Array = sectors.filter(func(s: Node) -> bool: return not s.known())
	var target: Node = dark.back()
	player.global_position = target.global_position
	var labels: Array = target.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Mark for the next submarine dive" in labels, "close to a dark area, the ranger can mark it (%s)" % [labels])
	target.mark_for_dive()
	var report: Dictionary = eco.run_mission(load("res://data/missions/deep_dive.tres"))
	_expect(target.knowledge >= eco.dive_reveal - 0.01 and report.found == [target], "the dive revealed the marked area")
	_expect(eco.disturbance() >= eco.dive_noise, "dives are noisy for a day")
	_expect(load("res://data/missions/deep_dive.tres").faster_with == &"reef_limestone", "the Reef's Habitat Mapping System makes dives faster")

	# --- The giant squid: a camera watching the known canyon in quiet water ---
	clock.advance(clock.DAY_LENGTH * 1.1)  # the dive's noise fades
	await process_frame
	eco.learn(1.0, sectors[0])
	var cam: Node = place.call(&"deep_camera", sectors[0].global_position)
	_expect(eco.quiet() >= eco.squid_quiet, "quiet enough for the squid (%d%%)" % roundi(eco.quiet() * 100.0))
	for i in 9:
		eco.tick(0.25)
	_expect(eco.squid_found() and eco.living(load("res://data/animals/giant_squid.tres")).size() == 1, "after 2 quiet days the camera films a giant squid")

	# --- Objective: map 6 areas at 70 % -> cargo search -> tow the module in ---
	var cargo := load("res://data/missions/cargo_search.tres")
	report = eco.run_mission(cargo)
	_expect(not fleet.has_flag(&"cargo_located") and report.detail.contains("map at least"), "no cargo search before the deep is mapped")
	for s: Node in sectors:
		eco.learn(1.0, s)
	fleet.mark(&"deep_mapped")
	report = eco.run_mission(cargo)
	var module: Array = get_nodes_in_group("debris").filter(func(d: Node) -> bool: return d.item.id == &"lost_cargo_module")
	_expect(fleet.has_flag(&"cargo_located") and module.size() == 1, "the cargo search floats the module up")
	module[0].collect()
	_expect(fleet.has_flag(&"cargo_recovered") and fleet.objective_done(deep), "towing it in completes the objective")

	# --- Oil spill: spreads every morning until the source is contained ---
	var oil := func() -> int:
		return get_nodes_in_group("debris").filter(func(d: Node) -> bool: return d.item.id == &"oil_patch" and not d.is_queued_for_deletion()).size()
	var before: int = oil.call()
	eco.oil_spill(4)
	var after_strike: int = oil.call()
	_expect(after_strike >= before + 3 and eco.spill_active(), "the spill brings oil up (%d patches)" % (after_strike - before))
	eco._spread_oil()
	_expect(oil.call() > after_strike, "it spreads each morning while it runs")
	report = eco.run_mission(load("res://data/missions/contain_spill.tres"))
	var contained: int = oil.call()
	eco._spread_oil()
	_expect(not eco.spill_active() and oil.call() == contained, "contained: no more oil comes up")
	var event: Resource = load("res://data/events/oil_spill.tres")
	_expect(event.min_gap_days == 30 and event.max_gap_days == 60 and event.needs_building == &"deep_ocean_outpost",
		"oil spills come 30-60 days apart, once the Outpost can respond")

	# --- Saved and restored ---
	var saved: Dictionary = eco.to_dict()
	sectors[1].knowledge = 0.0
	eco.restore(saved)
	_expect(sectors[1].known() and eco.squid_found(), "areas, squid and spill are saved")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
