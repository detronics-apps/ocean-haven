extends SceneTree
## Sea otters and Otter Habitats (Kelp Forest): a habitat offers conditions, not otters.
## Otters settle (2 a habitat) while the island's kelp can feed them — the first straight
## away — and keep urchins down across the whole island, wherever the habitats are. Too many
## habitats and the otters eat nearly every urchin (out of balance, and the upkeep adds up);
## taking some down fixes it within a few days. Otters move away (never die) when food runs
## short or their habitat goes. They're saved.
## Run: godot --headless --path . --script res://tests/test_otters.gd --quit-after 200000

const PATH := "user://test_otters.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var kelp_region: Resource = load("res://data/regions/kelp_forest.tres")
	regions.discover(kelp_region)
	var funding := root.get_node("Funding")
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var build_mode: Node = world.get_node("BuildMode")
	var habitat_data: Resource = load("res://data/buildings/otter_habitat.tres")
	_expect(habitat_data.max_count == 6 and habitat_data.demolishable and habitat_data.upkeep > 0,
		"Otter Habitats: up to 6, with upkeep, and they can be demolished")
	funding.restore({"balance": 5000})
	root.get_node("Inventory").restore({"plastic_bottle": 100}, {"wood": 100})
	await process_frame
	for animal in ecosystem.otters():  # the island's own struggling otter (see test_kelp): a clean start here
		animal.free()
	var otter_count := func() -> int: return ecosystem.otters().size()
	var clock := root.get_node("GameClock")
	var days := func(n: float) -> void:
		for i in roundi(n / ecosystem.tick_days):
			clock.time_of_day = 0.4  # time passes (homeless otters move away after a day), but not a new morning
			clock.day += 0 if i % 4 else 1
			ecosystem.tick(ecosystem.tick_days)
			load("res://scripts/animals/births.gd").born_now(self)  # (no frames run here: parents can't walk there)
			for pup: Node in ecosystem.otters().filter(func(o: Node) -> bool: return o.young):
				pup._process(0.0)  # (and pups grow up)

	# --- One habitat: the first otter comes straight away, it's full within a day ---
	var cells := _free_cells(build_mode, habitat_data, ecosystem, 6)
	_expect(cells.size() == 6, "room for 6 habitats round the Kelp Forest (%d)" % cells.size())
	var homes: Array = [build_mode.add_building(habitat_data, cells[0])]
	ecosystem.settle_now()
	_expect(otter_count.call() == 1, "the first otter settles straight away (%d)" % otter_count.call())
	days.call(1.0)
	_expect(otter_count.call() == 2 and homes[0].animals_here() == 2, "within a day the habitat has its 2 otters (%d)" % otter_count.call())

	# --- 3 habitats: 6 otters keep the urchins down island-wide; kelp recovers in 3-4 days ---
	for i in range(1, 3):
		homes.append(build_mode.add_building(habitat_data, cells[i]))
	ecosystem.settle_now()
	for d in get_nodes_in_group("debris"):
		if d.global_position.distance_to(kelp_region.center) < kelp_region.waters_radius:
			d.free()
	var predicted: float = health.heading(self, kelp_region)
	var start_health: float = health.of(self, kelp_region)
	days.call(9.0)  # pups come one per parent at a time, so it takes a few days
	var balanced: float = health.of(self, kelp_region)
	_expect(absf(balanced - predicted) < 0.08 and predicted > start_health + 0.1,
		"the gauge showed where it was heading: %d%% predicted, %d%% reached (from %d%%)" % [roundi(predicted * 100), roundi(balanced * 100), roundi(start_health * 100)])
	_expect(otter_count.call() == 6, "3 habitats: 6 otters (%d)" % otter_count.call())
	_expect(ecosystem.kelp_health() > 0.7 and ecosystem.urchin_total() > ecosystem.beds().size() * 0.2,
		"within days the kelp has recovered (%d%%) with some urchins left (%d)" % [roundi(ecosystem.kelp_health() * 100), ecosystem.urchin_total()])

	# --- Overbuilt: 6 habitats, 12 otters eat nearly every urchin; out of balance ---
	for i in range(3, 6):
		homes.append(build_mode.add_building(habitat_data, cells[i]))
	ecosystem.settle_now()
	days.call(20.0)  # 12 otters take a while to come (one pup per parent at a time), then the urchins go
	_expect(otter_count.call() > 6 and ecosystem.urchin_total() < ecosystem.beds().size() * 0.2,
		"6 habitats: %d otters leave almost no urchins (%d)" % [otter_count.call(), ecosystem.urchin_total()])
	_expect(health.of(self, kelp_region) < balanced, "more isn't better: the island is less healthy (%.2f vs %.2f)" % [
		health.of(self, kelp_region), balanced])
	var spawner: Node = world.get_node("KelpLitter")
	spawner.fill(20)
	_expect(health.of(self, kelp_region) < 0.55, "too many otters and litter left about: the island's health drops a long way (%.2f)" % health.of(self, kelp_region))
	for d in get_nodes_in_group("debris"):
		if d.global_position.distance_to(kelp_region.center) < kelp_region.waters_radius:
			d.free()
	var monitoring: Dictionary = ecosystem.run_mission(load("res://data/missions/otter_monitoring.tres"))
	_expect(monitoring.detail.contains("fewer habitats"), "otter monitoring says so (%s)" % monitoring.detail)

	# --- Taking three down: back in balance within a few days ---
	var player: Node2D = world.get_node("Player")
	for i in range(3, 6):
		player.global_position = homes[i].global_position + Vector2(0, 40)
		homes[i].demolish()
		homes[i].demolish()
	await process_frame
	await process_frame
	days.call(4.0)
	_expect(otter_count.call() == 6 and ecosystem.urchin_total() > ecosystem.beds().size() * 0.2,
		"after demolishing 3, their otters move away and urchins come back into balance (%d otters, %d urchins)" % [
		otter_count.call(), ecosystem.urchin_total()])

	# --- A Kelp Discovery Centre counts the island's otters, wherever it stands ---
	var centre_data: Resource = load("res://data/buildings/kelp_discovery_centre.tres")
	var centre: Node2D = build_mode.add_building(centre_data, cells[5])
	await process_frame
	_expect(centre.animals_in_view() == otter_count.call() and centre.visitors_today() > centre_data.visitors,
		"a Kelp Discovery Centre earns more with otters on the island (%d otters, %d funding)" % [centre.animals_in_view(), centre.visitors_today()])
	centre.free()

	# --- Saved and loaded ---
	var save := root.get_node("SaveGame")
	var before: int = otter_count.call()
	_expect(save.save_to(world, PATH), "saved")
	world.free()
	regions.forget(kelp_region)  # (as in a real start: the save decides; nothing moves before it loads)
	world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	_expect(save.load_from(world, PATH), "loaded")
	regions.discover(kelp_region)  # (this test's fleet has no sonar, so loading locked it again)
	await process_frame
	ecosystem = world.get_node("KelpIsland/Ecosystem")
	_expect(ecosystem.otters().size() == before and ecosystem.otters().all(func(o: Node) -> bool: return o.home_area != null),
		"the otters are back, each at its habitat (%d)" % ecosystem.otters().size())

	# --- Otters bring floating litter near them ashore, to be picked up on foot ---
	var carrier: Node2D = ecosystem.otters().filter(func(o: Node) -> bool: return not o.leaving and not o.young and not o.tangled)[0]
	var ground: TileMapLayer = world.get_node("KelpIsland/Ground")
	var shore_cell := Vector2i.MAX
	var out := Vector2i.ZERO
	for c in ground.get_used_cells():
		if ground.get_cell_tile_data(c).get_custom_data("terrain") != "sand":
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var run := true
			for k in range(1, 5):
				var t := ground.get_cell_tile_data(c + d * k)
				run = run and t != null and t.get_custom_data("terrain") in ["water", ""]
			if run and shore_cell == Vector2i.MAX:
				shore_cell = c
				out = d
	var land_at := ground.to_global(ground.map_to_local(shore_cell))
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()  # only this bottle about
	carrier.global_position = land_at + Vector2(out) * 32.0 * 2.5
	var bottle: Node2D = world.get_node("KelpLitter").spawn_at(load("res://data/items/plastic_bottle.tres"),
		land_at + Vector2(out) * 32.0 * 3.5, true)
	for i in 1800:
		await physics_frame
		if not bottle.floating:
			break
	_expect(not bottle.floating and bottle.global_position.distance_to(land_at) < 48.0
		and load("res://scripts/world/terrain.gd").at(self, bottle.global_position) in ["sand", "grass", "rock", "mud"],
		"an otter fetches floating litter near it and leaves it on the shore (%s from the shore)" % roundi(bottle.global_position.distance_to(land_at)))

	# --- No food: otters move away (they never die) ---
	for bed: Node2D in ecosystem.beds():
		bed.urchins = 0.0
		bed.health = 0.0
	ecosystem.settle()
	var leaving := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"sea_otter" and a.leaving)
	_expect(leaving.size() >= 1, "with no food, an otter moves away (%d)" % leaving.size())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


## Up to `count` places for habitats on the Kelp Forest, spread round it.
func _free_cells(build_mode: Node, data: Resource, ecosystem: Node, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for bed: Node2D in ecosystem.beds():
		if cells.size() >= count:
			break
		var start := Vector2i((bed.global_position / 32.0).floor())
		var found := false
		for r in range(1, 8):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var c := start + Vector2i(dx, dy)
					if found or build_mode.placement_problem(data, c) != "":
						continue
					var clear := true
					for o in cells:
						clear = clear and not Rect2i(o, data.size).grow(1).intersects(Rect2i(c, data.size))
					if clear:
						cells.append(c)
						found = true
	return cells


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
