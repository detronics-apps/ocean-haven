extends SceneTree
## Paints the six islands (the starter island is refined in place) into scenes/islands/,
## places them in the world, and draws each region's little map for the Map menu.
## Each island is a shape (which cells are land) plus the tiles for its beach, its
## inland and its water; shallows and a band of deep water are worked out from the
## distance to land. Run twice (the maps need importing in between):
##   godot --headless --path . --script res://tools/generate_islands.gd -- islands
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/generate_islands.gd -- regions

const TILESET := "res://assets/tilesets/placeholder_tileset.tres"
const WORLD := "res://scenes/world/ocean_world.tscn"
const INFO := "res://build/islands.json"
## Tile atlas columns (see assets/tilesets/placeholder_tiles.svg).
## Ground: sand, grass, rock, ice, mud. Water: shallow, mid, and deep (the open ocean: no tile).
## Coral, kelp and mangroves will be plants on top, not ground.
enum { SHALLOW, SAND, GRASS, ROCK, ICE, MUD, MID }
## The same tiles' colours, for the region maps.
const COLOURS := ["528b93", "e6d5a4", "7f9a52", "7c858c", "e8f1f5", "7a5e3c", "3a6478"]
## Islands sit in a row east of home, one every SPACING pixels.
const SPACING := 5120


func _initialize() -> void:
	if "regions" in OS.get_cmdline_user_args():
		_regions()
	else:
		_islands()
	quit()


# --- Pass 1: islands ---------------------------------------------------------------

func _islands() -> void:
	var info := {}
	info["home_island"] = _save_island("StarterIsland", "res://scenes/islands/starter_island.tscn", _starter(), 0)
	info["tropical_waters"] = _save_island("TropicalIsland", "res://scenes/islands/tropical_island.tscn", _crescent(), 1)
	info["mangrove_coast"] = _save_island("MangroveIsland", "res://scenes/islands/mangrove_island.tscn", _branching(), 2)
	info["deep_sea"] = _save_island("HookIsland", "res://scenes/islands/hook_island.tscn", _hook(), 3)
	info["coral_kingdom"] = _save_island("RingIsland", "res://scenes/islands/ring_island.tscn", _ring(), 4)
	info["arctic_ocean"] = _save_island("PolarIsland", "res://scenes/islands/polar_island.tscn", _polar(), 5)
	var file := FileAccess.open(INFO, FileAccess.WRITE)
	file.store_string(JSON.stringify(info, "\t"))
	_place_in_world(info)


## The home island: its north half (where the ranger has built) stays as it was; the
## arms curl in around the lagoon, leaving a narrow mouth, with a little pond on the east arm.
func _starter() -> Dictionary:
	var ground: TileMapLayer = load("res://scenes/islands/starter_island.tscn").instantiate().get_node("Ground")
	var land := {}
	for cell in ground.get_used_cells():
		var atlas := ground.get_cell_atlas_coords(cell).x
		if atlas in [SAND, GRASS]:
			land[cell] = atlas
	for x in range(-5, 6):  # arm tips curling in: a 3-tile mouth
		if absi(x) >= 2:
			land[Vector2i(x, 10)] = SAND
			land[Vector2i(x, 11)] = SAND
		if absi(x) in [2, 3, 4]:
			land[Vector2i(x, 12)] = SAND
	for x in [-6, 6]:
		land[Vector2i(x, 11)] = SAND
	var water := {}
	for cell in [Vector2i(10, 3), Vector2i(10, 4)]:  # pond
		land.erase(cell)
		water[cell] = SHALLOW
	return _finish(land, func(cell: Vector2i, d: int) -> int:
		if water.has(cell):
			return water[cell]
		return SHALLOW if d <= 3 else (MID if d <= 5 else -1))


## Tropical Waters: a long thin crescent with wide shallows inside its curve (coral comes later, as plants).
func _crescent() -> Dictionary:
	var inner_centre := Vector2(4, -1)
	var mask := {}
	for x in range(-22, 22):
		for y in range(-22, 22):
			var p := Vector2(x, y)
			if p.length() <= 19.0 and p.distance_to(inner_centre) > 17.0:
				mask[Vector2i(x, y)] = true
	var land := _with_edges(mask, func(_c: Vector2i) -> int: return GRASS, func(_c: Vector2i) -> int: return SAND)
	return _finish(land, func(cell: Vector2i, d: int) -> int:
		if Vector2(cell).distance_to(inner_centre) <= 17.0:  # wide shallows inside the curve
			return SHALLOW if d <= 5 else (MID if d <= 7 else -1)
		return SHALLOW if d <= 2 else (MID if d <= 4 else -1))


## Mangrove Coast: a central mass with long branching fingers and water between them;
## grass with muddy banks and a muddy middle, sandy tips (mangroves come later, as plants).
func _branching() -> Dictionary:
	var branches := []  # [end, base width]
	for i in 9:
		var angle := deg_to_rad(i * 40.0 + (_noise(Vector2i(i, 7)) - 0.5) * 24.0)
		var length := 13.0 + _noise(Vector2i(i, 3)) * 6.0
		branches.append([Vector2.from_angle(angle) * length, 2.2])
	var mask := {}
	var tips := {}
	for x in range(-24, 25):
		for y in range(-24, 25):
			var p := Vector2(x, y)
			var cell := Vector2i(x, y)
			var is_land := p.length() <= 6.0 + _noise(cell, 2) * 1.2
			for branch: Array in branches:
				var end: Vector2 = branch[0]
				var t := clampf(p.dot(end) / end.length_squared(), 0.0, 1.0)
				var width := lerpf(branch[1], 0.9, t)
				if p.distance_to(end * t) <= width:
					is_land = true
				if p.distance_to(end) <= 2.3:
					is_land = true
					tips[cell] = true
			if is_land:
				mask[cell] = true
	var land := _with_edges(mask,
		func(c: Vector2i) -> int: return MUD if Vector2(c).length() < 2.5 or _noise(c, 4) > 0.8 else GRASS,
		func(c: Vector2i) -> int: return SAND if tips.has(c) else (MUD if _noise(c, 5) > 0.3 else GRASS))
	return _finish(land, func(_cell: Vector2i, d: int) -> int:
		return SHALLOW if d <= 2 else (MID if d <= 4 else -1))


## Deep Sea: a grassy, rocky hook curling round deep water; a beach runs along its inside.
func _hook() -> Dictionary:
	var path := []  # [point, width]
	for i in 78:  # over the top: from the east tip (curled down) round to the west
		var a := deg_to_rad(50.0 - float(i) * 3.0)
		path.append([Vector2(3, -6) + Vector2.from_angle(a) * 9.0, lerpf(1.6, 3.4, minf(i / 20.0, 1.0))])
	for i in 41:  # down the west side to a thin tip
		var t := i / 40.0
		path.append([Vector2(-6, -6).lerp(Vector2(-2, 16), t), lerpf(3.2, 1.0, t)])
	var mask := {}
	for x in range(-14, 18):
		for y in range(-20, 22):
			var p := Vector2(x, y)
			for point: Array in path:
				if p.distance_to(point[0]) <= point[1]:
					mask[Vector2i(x, y)] = true
					break
			if p.distance_to(Vector2(-1, 19)) <= 1.2:
				mask[Vector2i(x, y)] = true  # a little islet off the tip
	var inside := func(c: Vector2i) -> bool: return Vector2(c).distance_to(Vector2(4, 1)) < 11.0
	var land := _with_edges(mask,
		func(c: Vector2i) -> int: return ROCK if _noise(c, 7) > 0.8 else GRASS,
		func(c: Vector2i) -> int:
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not mask.has(c + step) and inside.call(c + step):
					return SAND
			return ROCK)
	return _finish(land, func(cell: Vector2i, d: int) -> int:
		if inside.call(cell):
			return SHALLOW if d <= 2 else (MID if d <= 3 else -1)  # deep water right inside the hook
		return SHALLOW if d <= 1 else (MID if d <= 4 else -1))


## Coral Kingdom: a broken ring of sand and grass round a big shallow lagoon (coral comes later, as plants).
func _ring() -> Dictionary:
	var gaps := [20.0, 75.0, 140.0, 205.0, 262.0, 320.0]
	var radius := func(p: Vector2) -> float: return 18.0 + 1.2 * sin(3.0 * p.angle()) + 0.8 * sin(5.0 * p.angle() + 1.0)
	var mask := {}
	for x in range(-25, 26):
		for y in range(-25, 26):
			var p := Vector2(x, y)
			var in_gap := gaps.any(func(g: float) -> bool: return absf(angle_difference(p.angle(), deg_to_rad(g))) < 0.075)
			if absf(p.length() - radius.call(p)) <= 1.6 and not in_gap:
				mask[Vector2i(x, y)] = true
			if p.distance_to(Vector2(7, -9)) <= 1.3 or p.distance_to(Vector2(10, -5)) <= 1.0:
				mask[Vector2i(x, y)] = true  # islets in the lagoon
	var land := _with_edges(mask,
		func(c: Vector2i) -> int: return GRASS if _noise(c, 8) > 0.5 else SAND,
		func(_c: Vector2i) -> int: return SAND)
	return _finish(land, func(cell: Vector2i, d: int) -> int:
		if Vector2(cell).length() < radius.call(Vector2(cell)):
			return SHALLOW  # the lagoon
		return SHALLOW if d <= 2 else (MID if d <= 4 else -1))


## Polar Ocean: a central ice mass among broken floes and bits of ice, with some bare rock.
func _polar() -> Dictionary:
	var floes := []  # [centre, radii, angle]
	for i in 8:
		var a := deg_to_rad(i * 45.0 + (_noise(Vector2i(i, 11)) - 0.5) * 20.0)
		floes.append([Vector2.from_angle(a) * (13.0 + _noise(Vector2i(i, 12)) * 3.0),
			Vector2(2.6 + _noise(Vector2i(i, 13)), 1.7 + _noise(Vector2i(i, 14)) * 0.8), a])
	var mask := {}
	for x in range(-22, 23):
		for y in range(-22, 23):
			var p := Vector2(x, y)
			if p.length() <= 6.0 + 1.5 * sin(4.0 * p.angle()) + _noise(Vector2i(x, y), 15):
				mask[Vector2i(x, y)] = true
			for floe: Array in floes:
				var local: Vector2 = (p - floe[0]).rotated(-floe[2])
				if pow(local.x / floe[1].x, 2) + pow(local.y / floe[1].y, 2) <= 1.0:
					mask[Vector2i(x, y)] = true
	for i in 14:  # small bits of ice
		var a := _noise(Vector2i(i, 16)) * TAU
		mask[Vector2i((Vector2.from_angle(a) * (8.0 + _noise(Vector2i(i, 17)) * 11.0)).round())] = true
	var land := _with_edges(mask,
		func(c: Vector2i) -> int: return ROCK if _noise(c, 18) > 0.86 else ICE,
		func(_c: Vector2i) -> int: return ICE)
	return _finish(land, func(_cell: Vector2i, d: int) -> int:
		return SHALLOW if d <= 1 else (MID if d <= 3 else -1))


## Land cells with a non-land neighbour get `edge`, the rest `interior`.
func _with_edges(mask: Dictionary, interior: Callable, edge: Callable) -> Dictionary:
	var land := {}
	for cell: Vector2i in mask:
		var on_edge := false
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			on_edge = on_edge or not mask.has(cell + step)
		land[cell] = edge.call(cell) if on_edge else interior.call(cell)
	return land


## Land plus water: `water.call(cell, distance to land)` gives each sea cell's tile, or -1 for open ocean.
func _finish(land: Dictionary, water: Callable) -> Dictionary:
	var dist := {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in land:
		dist[cell] = 0
		queue.append(cell)
	var i := 0
	while i < queue.size():  # distance to land, counting diagonal steps as 1
		var cell := queue[i]
		i += 1
		if dist[cell] >= 20:  # far enough to fill the biggest lagoon
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var next := cell + Vector2i(dx, dy)
				if not dist.has(next):
					dist[next] = dist[cell] + 1
					queue.append(next)
	var grid := {}
	for cell: Vector2i in dist:
		var tile: int = land[cell] if land.has(cell) else water.call(cell, dist[cell])
		if tile >= 0:
			grid[cell] = tile
	return grid


func _noise(c: Vector2i, salt := 0) -> float:
	return fposmod(sin(c.x * 12.9898 + c.y * 78.233 + salt * 37.719) * 43758.5453, 1.0)


## Writes the island scene (keeping the starter island's palms, moved onto grass if
## their spot isn't any more) and its map picture. Returns where it is and where you land.
func _save_island(node_name: String, path: String, grid: Dictionary, index: int) -> Dictionary:
	var island: Node2D
	if ResourceLoader.exists(path):
		island = load(path).instantiate()
	else:
		island = Node2D.new()
		island.name = node_name
		island.y_sort_enabled = true
		var ground := TileMapLayer.new()
		ground.name = "Ground"
		ground.z_index = -2
		ground.tile_set = load(TILESET)
		ground.add_to_group("ground", true)
		island.add_child(ground)
		ground.owner = island
	var layer: TileMapLayer = island.get_node("Ground")
	layer.clear()
	for cell: Vector2i in grid:
		layer.set_cell(cell, 0, Vector2i(grid[cell], 0))
	for plant in island.get_children():
		if plant.is_in_group("plants") and grid.get(Vector2i((plant.position / 32.0).floor()), -1) != GRASS:
			plant.position = _nearest(grid, Vector2i((plant.position / 32.0).floor()), [GRASS]) * 32 + Vector2i(16, 24)
	var packed := PackedScene.new()
	packed.pack(island)
	ResourceSaver.save(packed, path)
	_save_map(grid, "res://assets/ui/maps/%s.png" % node_name.to_snake_case())
	# Step ashore on the west side, with the rowboat in the shallows next to you.
	var arrival := Vector2i.ZERO
	var best := 1 << 30
	for cell: Vector2i in grid:
		if grid[cell] in [SAND, GRASS, ICE, MUD] \
				and grid.get(cell + Vector2i.LEFT, -1) == SHALLOW and absi(cell.y) * 4 + cell.x < best:
			best = absi(cell.y) * 4 + cell.x
			arrival = cell
	var offset := Vector2(index * SPACING, 0)
	var extent := 0.0
	for cell: Vector2i in grid:
		extent = maxf(extent, Vector2(cell).length())
	return {"node": node_name, "path": path, "position": [offset.x, offset.y],
		"arrival": [offset.x + arrival.x * 32 + 16, arrival.y * 32 + 16],
		"mooring": [offset.x + (arrival.x - 1) * 32 + 16, arrival.y * 32 + 16],
		"radius": ceilf(extent * 32.0 + 200.0), "map": "res://assets/ui/maps/%s.png" % node_name.to_snake_case()}


func _nearest(grid: Dictionary, from: Vector2i, tiles: Array) -> Vector2i:
	var best := from
	for cell: Vector2i in grid:
		if grid[cell] in tiles and (best == from or Vector2(cell - from).length() < Vector2(best - from).length()):
			best = cell
	return best


## One pixel per tile, doubled, on the open-ocean colour.
func _save_map(grid: Dictionary, path: String) -> void:
	var rect := Rect2i()
	for cell: Vector2i in grid:
		rect = Rect2i(cell, Vector2i.ONE) if rect.size == Vector2i.ZERO else rect.expand(cell).expand(cell + Vector2i.ONE)
	var side := maxi(rect.size.x, rect.size.y)
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color("2b4a5e"))
	var margin := (Vector2i(side, side) - rect.size) / 2
	for cell: Vector2i in grid:
		image.set_pixelv(cell - rect.position + margin, Color(COLOURS[grid[cell]]))
	image.resize(side * 2, side * 2, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)


## Adds the new islands to the world (the starter and tropical islands are already there).
func _place_in_world(info: Dictionary) -> void:
	var world: Node = load(WORLD).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for region: String in info:
		var entry: Dictionary = info[region]
		if world.has_node(NodePath(entry.node)):
			continue
		var island: Node2D = load(entry.path).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		island.name = entry.node
		island.position = Vector2(entry.position[0], entry.position[1])
		world.add_child(island)
		island.owner = world
		world.move_child(island, world.get_node("TropicalIsland").get_index() + 1)
	var tropical: Dictionary = info["tropical_waters"]
	(world.get_node("TropicalLitter") as Node).set("area", Rect2(tropical.position[0] - tropical.radius,
		-tropical.radius, tropical.radius * 2, tropical.radius * 2))
	var packed := PackedScene.new()
	packed.pack(world)
	ResourceSaver.save(packed, WORLD)


# --- Pass 2: regions (after the maps are imported) ---------------------------------

func _regions() -> void:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	for id: String in info:
		var entry: Dictionary = info[id]
		var path := "res://data/regions/%s.tres" % id
		var region: RegionData = load(path)
		region.map_icon = load(entry.map)
		if id != "home_island":
			region.center = Vector2(entry.position[0], entry.position[1])
			region.arrival = Vector2(entry.arrival[0], entry.arrival[1])
			region.boat_mooring = Vector2(entry.mooring[0], entry.mooring[1])
			region.waters_radius = entry.radius
		if DETAILS.has(id):
			var details: Array = DETAILS[id]
			region.display_name = details[0]
			region.order = details[1]
			region.description = details[2]
			# ponytail: open to visit (like Tropical Waters) while their wildlife is still to come;
			# give them their own unlock goals once they have something to restore.
			region.locked = false
			region.requires_building = &"patrol_boat"
			region.unlock_hint = "Automate your home island first: build a Patrol Boat."
		ResourceSaver.save(region, path)
	var kelp: RegionData = load("res://data/regions/kelp_forest.tres")
	kelp.order = 6
	ResourceSaver.save(kelp, "res://data/regions/kelp_forest.tres")


## New regions: [name, map order, description].
const DETAILS := {
	"mangrove_coast": ["Mangrove Coast", 2, "A maze of mangrove fingers and muddy channels, where young fish hide and grow. (Wildlife coming soon.)"],
	"deep_sea": ["Deep Sea", 3, "A rugged hook of rock curling round a deep, dark trench. (Wildlife coming soon.)"],
	"coral_kingdom": ["Coral Kingdom", 4, "A broken ring of coral round a huge turquoise lagoon. (Wildlife coming soon.)"],
	"arctic_ocean": ["Polar Ocean", 5, "Floes of ice and bare rock in cold, quiet water. (Wildlife coming soon.)"],
}
