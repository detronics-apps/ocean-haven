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
	var cell := Vector2i.MAX
	for c: Vector2i in eco.get("_ring"):
		if ground.get_cell_atlas_coords(c) == eco.ICE_TILE and ground.get_cell_atlas_coords(c + Vector2i(1, 0)) == eco.ICE_TILE \
				and ground.get_cell_atlas_coords(c + Vector2i(0, 1)) == eco.ICE_TILE and ground.get_cell_atlas_coords(c + Vector2i(1, 1)) == eco.ICE_TILE:
			cell = c
			break
	_expect(cell != Vector2i.MAX, "(found frozen seasonal ice)")
	var at: Vector2 = ground.to_global(ground.map_to_local(cell))
	var house: Resource = load("res://data/buildings/house.tres")
	var build: Node = world.get_node("BuildMode")
	var wcell: Vector2i = terrain.cell_of(at) - Vector2i(0, 0)
	_expect(build.placement_problem(house, wcell) == "" or not build.placement_problem(house, wcell).contains("goes"), "a Ranger House can go on the ice (%s)" % build.placement_problem(house, wcell))
	build.add_building(house, wcell)
	await process_frame
	for i in 8:
		eco.tick(eco.cycle_days / 4.0)
		eco.apply_ice()
	_expect(ground.get_cell_atlas_coords(cell) == eco.ICE_TILE, "a whole year later the ice under it is still there")
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
