extends SceneTree
## The Polar Ocean: a 3-day ice season (freeze, frozen, thaw, open water) grows and melts rings
## of seasonal ice round the old ice; the freeze joins the floes unless boats break the thin ice;
## Seal Pupping Zones on seasonal ice lose their pups when it melts (on old ice they last);
## polar bears stay with a corridor and a Quiet Den Area; cod follow the ice (crowding seals eat
## them down); terns nest in the thaw and visit other healthy islands in the freeze; the skua
## circles trouble; breakups break old ice off until the next freeze; drilling on old ice at 70 %
## gives the Ice Core; everything is saved.
## Run: godot --headless --path . --script res://tests/test_polar.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var fleet := root.get_node("Fleet")
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var polar: Resource = load("res://data/regions/arctic_ocean.tres")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	fleet.restore({})
	regions.discover(polar)
	var player: Node2D = world.get_node("Player")
	player.global_position = polar.arrival
	for i in 3:
		await process_frame
	world.get_node("PolarLitter").fill(polar.arrival_litter)
	var eco: Node = world.get_node("PolarIsland/Ecosystem")
	var ground: TileMapLayer = world.get_node("PolarIsland/Ground")
	var build_mode: Node = world.get_node("BuildMode")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var place := func(id: StringName, cell: Vector2i) -> Node:
		return build_mode.add_building(load("res://data/buildings/%s.tres" % id), terrain.cell_of(ground.to_global(ground.map_to_local(cell))))
	var seal_data: Resource = load("res://data/animals/ringed_seal.tres")
	var bear_data: Resource = load("res://data/animals/polar_bear.tres")
	var tern_data: Resource = load("res://data/animals/arctic_tern.tres")
	var ice := func() -> int:
		return ground.get_used_cells().filter(func(c: Vector2i) -> bool: return ground.get_cell_atlas_coords(c) == eco.ICE_TILE).size()
	var old_ice: Array = eco._base.keys().filter(func(c: Vector2i) -> bool: return eco._base[c] == eco.ICE_TILE)
	var rocks: Array = eco._base.keys().filter(func(c: Vector2i) -> bool: return terrain.at(self, ground.to_global(ground.map_to_local(c))) == "rock")
	var seasonal: Array = eco._ring.keys().filter(func(c: Vector2i) -> bool: return eco._ring[c] == 1)

	# --- Arriving: open water, every species there but struggling ---
	_expect(not polar.in_development and eco.phase_name() == &"open", "the Polar Ocean is playable, and it's open water")
	_expect(eco.living(seal_data).size() == 1 and eco.living(seal_data)[0].tangled, "a ringed seal caught in a net")
	_expect(eco.living(bear_data).size() == 1 and eco.living(tern_data).size() == 1, "one polar bear and one tern")
	_expect(health.of(self, polar) < 0.12, "health starts near 0 (%d%%)" % roundi(health.of(self, polar) * 100.0))
	_expect(eco.status_note().begins_with("Open water"), "the HUD gauge says where the season is (%s)" % eco.status_note())
	eco.living(seal_data)[0].restore_freed()
	var open_ice: int = ice.call()

	# --- The freeze: rings of ice spread out and join the floes ---
	var boat: Node2D = world.get_node("PolarBoat")
	boat.global_position = polar.center + Vector2(-900, 320)  # out of the way
	for i in 3:
		eco.tick(eco.cycle_days / 8.0)
	_expect(eco.phase_name() == &"freezing" and ice.call() > open_ice, "the ice spreads out in the freeze (%d -> %d cells)" % [open_ice, ice.call()])
	while eco.phase_name() != &"frozen":
		eco.tick(eco.cycle_days / 24.0)
	_expect(eco.corridor_score() >= 0.99, "frozen: the ice joins the floes (%d%%)" % roundi(eco.corridor_score() * 100.0))
	var peak: int = ice.call()

	# --- The thaw: back to the old ice ---
	while eco.phase_name() != &"open":
		eco.tick(eco.cycle_days / 24.0)
	_expect(ice.call() < peak and ice.call() <= open_ice, "the seasonal ice melts back to the old ice")

	# --- Boats break thin ice while it freezes ---
	while eco.phase_name() != &"freezing":
		eco.tick(eco.cycle_days / 24.0)
	for x in range(-640, 640, 24):
		boat.global_position = polar.center + Vector2(x, 16 + 200 * sin(x * 0.01))
		eco._break_ice()
	boat.global_position = polar.center + Vector2(-900, 320)
	while eco.phase_name() != &"frozen":
		eco.tick(eco.cycle_days / 24.0)
	_expect(eco.corridor_score() < 0.9, "rowing across the channels in the freeze breaks the corridor (%d%%)" % roundi(eco.corridor_score() * 100.0))
	var report: Dictionary = eco.run_mission(load("res://data/missions/corridor_check.tres"))
	_expect(report.detail.contains("joined"), "the corridor check explains it")

	# --- Pupping zones: old ice lasts, seasonal ice melts away ---
	var good: Node = place.call(&"seal_pupping_zone", old_ice[old_ice.size() / 2])
	var bad: Node = place.call(&"seal_pupping_zone", seasonal[0])
	_expect(eco.on_old_ice(good) and not eco.on_old_ice(bad), "one zone on old ice, one on seasonal ice")
	_expect(eco.planning() < 0.6, "a zone on seasonal ice counts against planning (%d%%)" % roundi(eco.planning() * 100.0))
	while eco.phase_name() != &"open":
		eco.tick(eco.cycle_days / 24.0)
	_expect(eco._failed.has(eco._key(bad)) and not eco._failed.has(eco._key(good)), "the thaw melted the seasonal zone's ice: its pups went early")
	report = eco.run_mission(load("res://data/missions/ice_survey.tres"))
	_expect(bad in report.found, "the ice survey marks the zone on seasonal ice")
	bad.demolish()
	bad.demolish()
	await process_frame
	await process_frame
	_expect(eco.planning() >= 0.99, "with every zone on old ice, planning is full")

	# --- Bears: a den and a corridor; terns: nesting areas in the thaw ---
	place.call(&"quiet_den_area", rocks[0])
	eco._corridor = eco._possible
	for i in 6:
		eco.settle()
	_expect(eco.bears_supported() == 2, "a Quiet Den Area and a joined freeze: a second bear (%d)" % eco.bears_supported())
	place.call(&"tern_nesting_area", rocks[rocks.size() / 2])

	# --- Crowding: too many seals eat the cod down ---
	eco._peak_ice = 600
	var cod_before: int = eco.cod_supported()
	for i in 12:
		eco._spawn(seal_data, polar.center)
	_expect(eco.cod_supported() < cod_before, "crowded seals eat the cod down (%d -> %d)" % [cod_before, eco.cod_supported()])
	_expect(eco.planning() < 1.0, "and crowded ice raises fewer pups")
	for seal: Node in eco.living(seal_data).slice(1):
		seal.queue_free()
	await process_frame

	# --- Terns fly south in the freeze and visit the ranger's healthy islands ---
	var home: Resource = load("res://data/regions/home_island.tres")
	var start_health: float = health.of(self, home)
	while eco.phase_name() != &"freezing":
		eco.tick(eco.cycle_days / 24.0)
	var visitors: Array = get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data == tern_data and a.visiting and not a.leaving)
	if start_health >= eco.balanced_at:
		_expect(visitors.size() >= 1, "terns visit a healthy island on their way south")
	_expect(eco.living(tern_data).is_empty() and eco.terns_counted() >= 1, "the terns are away, and health remembers them")

	# --- The skua circles trouble ---
	var caught: Node = eco._spawn(seal_data, polar.center + Vector2(40, 0))
	caught.tangle(load("res://data/items/ghost_net.tres"))
	_expect(eco.trouble().distance_to(caught.global_position) < 1.0, "the skua circles a caught seal")
	caught.restore_freed()

	# --- Breakup: old ice breaks off until the next freeze ---
	var broken: int = eco.ice_breakup(0.35)
	_expect(broken > 0, "a breakup breaks off %d cells of old ice" % broken)
	while eco.phase_name() != &"frozen":
		eco.tick(eco.cycle_days / 24.0)
	_expect(eco.broken_count() == 0, "it freezes back at the next freeze")

	# --- Objective: 70 %, then drill on old ice for 3 days ---
	fleet.mark(&"polar_balanced")
	var spot: Vector2 = eco._oldest_ice()
	build_mode.add_building(load("res://data/buildings/ice_core_drill.tres"), terrain.cell_of(spot))
	for i in 26:
		eco.tick(eco.cycle_days / 24.0)
	_expect(fleet.has_flag(&"ice_core_drilled") and fleet.objective_done(polar), "drilling 3 days on old ice gives the Ice Core")

	# --- Saved and restored ---
	var saved: Dictionary = eco.to_dict()
	var season: float = eco._season
	eco._season = 0.0
	eco.restore(saved)
	_expect(is_equal_approx(eco._season, season), "the ice season is saved")
	var event: Resource = load("res://data/events/ice_breakup.tres")
	_expect(event.min_gap_days == 30 and event.max_gap_days == 60 and event.ice_breakup > 0.0, "ice breakups come 30-60 days apart")

	# --- Rubbish near camp draws a polar bear in; cleared, it wanders back to the ice ---
	var tent: Node2D = build_mode.add_building(load("res://data/buildings/tent.tres"), terrain.cell_of(terrain.nearest(self, polar.arrival, ["rock", "ice"])))
	player.global_position = tent.global_position + Vector2(0, 40)
	var spawner: Node = world.get_node("PolarLitter")
	var bottle: Resource = load("res://data/items/plastic_bottle.tres")
	for d in get_nodes_in_group("debris").filter(func(d: Node2D) -> bool: return d.global_position.distance_to(tent.global_position) < 260.0):
		d.free()
	eco.check_camp()
	_expect(not fleet.has_flag(&"bear_at_camp"), "a clean camp: no bear")
	var litter: Array = []
	for i in 2:
		litter.append(spawner.spawn_at(bottle, tent.global_position + Vector2(40 + i * 20, 30), false))
	eco.check_camp()
	var sanna: Resource = load("res://data/people/sanna.tres")
	var people := root.get_node("People")
	_expect(fleet.has_flag(&"bear_at_camp") and eco.camp_rubbish() == 2, "rubbish by the tent draws a polar bear to camp")
	var bear: Node2D = eco.living(bear_data)[0]
	var camp_home: Vector2 = bear.get("_home")
	_expect(camp_home.distance_to(tent.global_position) < 150.0, "it heads for camp")
	_expect(people.nervous(sanna) and people.has_news(sanna), "the researchers are nervous (a red '!')")
	var said: Array = people.talk(sanna).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(said[0].contains("polar bear right by camp"), "Sanna says so first (%s)" % said[0])
	_expect(eco.trouble().distance_to(bear.global_position) < 1.0, "the skua circles the bear")
	for d in litter:
		d.free()
	eco.check_camp()
	_expect(not fleet.has_flag(&"bear_at_camp") and not people.nervous(sanna), "cleared: the bear wanders back to the ice, and everyone calms down")
	_expect(bear.get("_home").distance_to(camp_home) > 10.0, "back towards its den")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
