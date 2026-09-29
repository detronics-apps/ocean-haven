extends SceneTree
## Litter washing in: new pieces appear over time, at sea (floating) or on
## beaches, never close to the ranger, and stop at the maximum.
## Run: godot --headless --path . --script res://tests/test_litter.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var spawner: Node = world.get_node("LitterSpawner")  # untyped: uses autoloads
	var player: Node2D = world.get_node("Player")
	var start := get_nodes_in_group("debris").size()

	# --- Over time ---
	spawner.interval = 0.2
	for i in 60:
		await physics_frame
	_expect(get_nodes_in_group("debris").size() > start, "litter washes in over time (%d -> %d)" % [
		start, get_nodes_in_group("debris").size()])

	# --- Where it lands ---
	var ok_spots := true
	var near_ranger := false
	var at_sea := 0
	var on_beach := 0
	for d in get_nodes_in_group("debris"):
		if not d.spawned:
			continue
		var ground := _terrain(d.global_position)
		if d.floating:
			at_sea += 1
			ok_spots = ok_spots and ground in ["", "water"]
		else:
			on_beach += 1
			ok_spots = ok_spots and ground == "sand"
		near_ranger = near_ranger or d.global_position.distance_to(player.global_position) < 320.0
	_expect(ok_spots, "floating litter is at sea, beach litter on sand (%d at sea, %d on beaches)" % [at_sea, on_beach])
	_expect(not near_ranger, "never appears right next to the ranger")
	var home: Resource = load("res://data/regions/home_island.tres")
	var reachable := get_nodes_in_group("debris").filter(func(d: Node2D) -> bool: return d.spawned).all(
		func(d: Node2D) -> bool: return d.global_position.length() <= home.waters_radius)
	_expect(reachable, "all of it is within the rowboat's reach")

	# --- Litter far out drifts in, and doesn't count against the island until it's in reach ---
	var far: Node2D = spawner.spawn_at(load("res://data/items/plastic_bottle.tres"), Vector2(1050, 800), true)
	var clean: Resource = home.health[0]
	var counted: int = load("res://scripts/systems/island_health.gd").count(self, home, clean)
	far.global_position = Vector2(1050, 800)
	_expect(load("res://scripts/systems/island_health.gd").count(self, home, clean) == counted, "out-of-reach litter doesn't count for island health")
	var start_distance := far.global_position.length()
	for i in 90:
		await process_frame
	_expect(far.global_position.length() < start_distance - 1.0, "it drifts in towards the island (%.0f -> %.0f)" % [
		start_distance, far.global_position.length()])
	far.free()

	# --- Beaches get litter too (ranger out at sea, away from the beaches) ---
	player.global_position = Vector2(-1500, 0)
	for d in get_nodes_in_group("debris"):
		if d.spawned:
			d.free()  # make room below the maximum
	spawner.at_sea_chance = 0.0
	var beach_piece: Node2D = spawner.spawn_one()
	_expect(beach_piece != null and not beach_piece.floating and _terrain(beach_piece.global_position) == "sand",
		"washes up on a beach")
	spawner.at_sea_chance = 0.75

	# --- Stops at the maximum ---
	for i in 120:
		await physics_frame
	_expect(get_nodes_in_group("debris").size() <= spawner.max_litter, "stops at %d pieces" % spawner.max_litter)
	_expect(spawner.spawn_one() == null, "no more once the sea has enough")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _terrain(point: Vector2) -> String:
	for ground: TileMapLayer in get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
