extends SceneTree
## Sea otters and Otter Habitats (Kelp Forest): a habitat offers conditions, not otters.
## Otters settle only while the kelp around it can feed them, at most 2 a habitat and 3 in
## one stretch of coast (so crowded habitats add upkeep, not otters); they eat urchins, so
## the kelp near them recovers; they move away (never die) when food runs short or their
## habitat is taken down. Otters are saved.
## Run: godot --headless --path . --script res://tests/test_otters.gd --quit-after 200000

const PATH := "user://test_otters.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var kelp_region: Resource = load("res://data/regions/kelp_forest.tres")
	regions.discover(kelp_region)
	var funding := root.get_node("Funding")
	var clock := root.get_node("GameClock")
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var build_mode: Node = world.get_node("BuildMode")
	var habitat_data: Resource = load("res://data/buildings/otter_habitat.tres")
	_expect(habitat_data.max_count == 6 and habitat_data.demolishable and habitat_data.upkeep > 0,
		"Otter Habitats: up to 6, with upkeep, and they can be demolished")

	# --- A habitat on the shore by the kelp ---
	funding.restore({"balance": 1000})
	root.get_node("Inventory").restore({"plastic_bottle": 50}, {"wood": 50})
	var cell := _shore_cell_near_kelp(build_mode, habitat_data, ecosystem)
	_expect(cell != Vector2i.MAX, "there's shore next to the kelp to build on (%s)" % cell)
	var home: Node2D = build_mode.add_building(habitat_data, cell)
	await process_frame
	var near: Array = ecosystem.beds_near(home.global_position, 260.0)
	var urchins_before: float = near.reduce(func(sum: float, b: Node) -> float: return sum + b.urchins, 0.0)
	var otter_count := func() -> int: return ecosystem.otters().size()
	_expect(otter_count.call() == 0, "building it brings no otter by itself")

	# --- Mornings: otters settle while the forest can feed them ---
	funding.restore({"balance": 1000})
	for i in 4:
		clock.time_of_day = 0.9
		clock.sleep_until_morning()
		await process_frame
	_expect(otter_count.call() == 2 and home.animals_here() == 2, "otters settle at it, up to its 2 (%d)" % otter_count.call())
	_expect(funding.balance < 1000, "and it costs upkeep every morning (%d left)" % funding.balance)

	# --- A Kelp Discovery Centre: visitors come to see the otters ---
	var centre_data: Resource = load("res://data/buildings/kelp_discovery_centre.tres")
	var centre: Node2D = build_mode.add_building(centre_data, _free_cell_near(build_mode, centre_data, cell))
	await process_frame
	_expect(centre.animals_in_view() >= 1 and centre.visitors_today() > centre_data.visitors,
		"a Kelp Discovery Centre earns more with otters in view (%d otters, %d funding)" % [centre.animals_in_view(), centre.visitors_today()])
	centre.free()

	# --- A second habitat right beside it: more upkeep, not more otters than the coast can hold ---
	var beside := _free_cell_near(build_mode, habitat_data, cell)
	var second: Node2D = build_mode.add_building(habitat_data, beside)
	for i in 4:
		clock.time_of_day = 0.9
		clock.sleep_until_morning()
		await process_frame
	_expect(otter_count.call() <= ecosystem.crowd_max, "crowded habitats share one stretch of coast: at most %d otters there (%d)" % [
		ecosystem.crowd_max, otter_count.call()])

	# --- They eat the urchins, and the kelp near them grows back ---
	var kelp_before: float = near.reduce(func(sum: float, b: Node) -> float: return sum + b.health, 0.0)
	for i in 40:
		ecosystem.tick(0.25)
	var urchins_after: float = near.reduce(func(sum: float, b: Node) -> float: return sum + b.urchins, 0.0)
	var kelp_after: float = near.reduce(func(sum: float, b: Node) -> float: return sum + b.health, 0.0)
	_expect(urchins_after < urchins_before * 0.5, "the otters eat the urchins near them (%.0f -> %.0f)" % [urchins_before, urchins_after])
	_expect(kelp_after > kelp_before, "and the kelp there grows back (%.2f -> %.2f)" % [kelp_before, kelp_after])

	# --- Saved and loaded ---
	var save := root.get_node("SaveGame")
	var before: int = otter_count.call()
	_expect(save.save_to(world, PATH), "saved")
	world.free()
	world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	_expect(save.load_from(world, PATH), "loaded")
	regions.discover(kelp_region)  # (this test's fleet has no sonar, so loading locked it again)
	await process_frame
	ecosystem = world.get_node("KelpIsland/Ecosystem")
	_expect(ecosystem.otters().size() == before and ecosystem.otters().all(func(o: Node) -> bool: return o.home_area != null),
		"the otters are back, each at its habitat (%d)" % ecosystem.otters().size())

	# --- No food: an otter moves away (it never dies) ---
	for bed: Node2D in ecosystem.beds():
		bed.urchins = 0.0
		bed.health = 0.0
	clock.time_of_day = 0.9
	clock.sleep_until_morning()
	await process_frame
	var leaving := get_nodes_in_group("animals").filter(func(a: Node) -> bool: return a.data.id == &"sea_otter" and a.leaving)
	_expect(leaving.size() >= 1, "with no food around, an otter moves away (%d)" % leaving.size())

	# --- Demolished: its otters move out ---
	var habitats := get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"otter_habitat")
	var gone: Node = habitats[0]
	var player: Node2D = world.get_node("Player")
	player.global_position = gone.global_position + Vector2(0, 40)
	gone.demolish()
	_expect(gone.is_in_group("buildings"), "demolishing asks you to tap again")
	gone.demolish()
	_expect(not gone.is_in_group("buildings"), "then it's taken down")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


## A sand cell on the Kelp Forest where a habitat fits, next to a kelp bed.
func _shore_cell_near_kelp(build_mode: Node, data: Resource, ecosystem: Node) -> Vector2i:
	for bed: Node2D in ecosystem.beds():
		var start := Vector2i((bed.global_position / 32.0).floor())
		for r in range(1, 5):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					var c := start + Vector2i(dx, dy)
					if build_mode.placement_problem(data, c) == "":
						return c
	return Vector2i.MAX


func _free_cell_near(build_mode: Node, data: Resource, from: Vector2i) -> Vector2i:
	for r in range(2, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if build_mode.placement_problem(data, from + Vector2i(dx, dy)) == "":
					return from + Vector2i(dx, dy)
	return from + Vector2i(3, 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
