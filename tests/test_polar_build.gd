extends SceneTree
## On the Polar Ocean buildings that go on rock can also go on ice (there isn't much rock), and
## the ice under a building never melts away as the seasons turn. Arctic terns nest on the
## ground: they fly about, then land on rock and sit on their nest (another picture).
## Run: godot --headless --path . --script res://tests/test_polar_build.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var polar: Resource = load("res://data/regions/arctic_ocean.tres")
	regions.discover(polar)
	world.get_node("Player").global_position = polar.arrival
	for i in 3:
		await process_frame
	var eco: Node = world.get_node("PolarIsland/Ecosystem")
	var ground: TileMapLayer = world.get_node("PolarIsland/Ground")
	# Seasonal ice (a ring that freezes and thaws): freeze it, build on it, thaw it.
	eco.tick(eco.cycle_days - fposmod(eco.get("_season"), eco.cycle_days) + eco.cycle_days * 0.45)
	eco.apply_ice()
	var house: Resource = load("res://data/buildings/house.tres")
	var build: Node = world.get_node("BuildMode")
	var kind := func(c: Vector2i) -> String:
		var tile := ground.get_cell_tile_data(c)
		return tile.get_custom_data("terrain") if tile else ""
	var all_ice := Vector2i.MAX
	var with_rock := Vector2i.MAX
	for c: Vector2i in ground.get_used_cells():
		var kinds := [kind.call(c), kind.call(c + Vector2i(1, 0)), kind.call(c + Vector2i(0, 1)), kind.call(c + Vector2i(1, 1))]
		if all_ice == Vector2i.MAX and kinds.all(func(k: String) -> bool: return k == "ice"):
			all_ice = c
		if with_rock == Vector2i.MAX and kinds.has("rock") and kinds.has("ice") and kinds.all(func(k: String) -> bool: return k in ["rock", "ice"]):
			with_rock = c
	var to_world := func(c: Vector2i) -> Vector2i: return terrain.cell_of(ground.to_global(ground.map_to_local(c)))
	_expect(build.placement_problem(house, to_world.call(all_ice)).contains("rock under it"), "all on ice: it needs a tile of rock as a foundation (%s)" % build.placement_problem(house, to_world.call(all_ice)))
	var problem: String = build.placement_problem(house, to_world.call(with_rock))
	_expect(not problem.contains("goes") and not problem.contains("rock under it"), "one rock and the rest ice: fine (%s)" % problem)
	build.add_building(house, to_world.call(with_rock))
	await process_frame
	var ice_cells: Array = [with_rock, with_rock + Vector2i(1, 0), with_rock + Vector2i(0, 1), with_rock + Vector2i(1, 1)].filter(func(c: Vector2i) -> bool: return kind.call(c) == "ice")
	for i in 8:
		eco.tick(eco.cycle_days / 4.0)
		eco.apply_ice()
	_expect(ice_cells.all(func(c: Vector2i) -> bool: return kind.call(c) == "ice"), "a whole year later the ice under it is still there")
	var station: Resource = load("res://data/buildings/polar_research_station.tres")
	_expect("ice" in station.terrain and "ice" in load("res://data/buildings/tent.tres").terrain, "the station and the tent can go on ice too")

	# Terns sit on their nests on the rock.
	var tern_data: Resource = load("res://data/animals/arctic_tern.tres")
	_expect(tern_data.nests_on_ground and tern_data.perched_sprite != null, "terns have a sitting picture")
	var tern: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	tern.set("data", tern_data)
	tern.position = terrain.nearest(self, polar.center, ["rock"]) + Vector2(80, 0)
	world.add_child(tern)
	await process_frame
	tern.set("_fly_left", 0.0)
	var sat := false
	for i in 900:
		await physics_frame
		if is_instance_valid(tern) and tern.perched:
			sat = true
			break
	_expect(sat and terrain.at(self, tern.global_position) == "rock", "it lands on rock and sits on its nest")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
