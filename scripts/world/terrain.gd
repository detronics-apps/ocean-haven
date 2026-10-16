class_name Terrain
## What the ground is at a point in the world: "water", "sand", "grass", or
## "" for open ocean (no tile). Reads the "terrain" custom data on island tiles.

const TILE := 32


static func at(tree: SceneTree, point: Vector2) -> String:
	var ground := island_ground(tree, point)
	if ground:
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


## Whether the ranger can stand at `point`: land, or a deck built over the water.
static func walkable(tree: SceneTree, point: Vector2) -> bool:
	var ground := island_ground(tree, point)
	if ground:
		var cell := ground.local_to_map(ground.to_local(point))
		var tile := ground.get_cell_tile_data(cell)
		if tile:
			# (or across the corner where two land cells touch: IslandGround.passes)
			return tile.get_custom_data("walkable") or (ground is IslandGround
				and (ground as IslandGround).in_pass(cell, ground.to_local(point)))
	return false


## The ground of the island nearest `point` (islands lie far apart, so it's the only one that can
## have a tile there). Called all the time (every animal's every step, every wave crest), so the
## grounds and their middles are kept, not looked up each time (the phone: much faster).
static func island_ground(tree: SceneTree, point: Vector2) -> TileMapLayer:
	if _grounds.size() != tree.get_node_count_in_group("ground"):
		_keep_grounds(tree)
	var best := -1
	var best_d := INF
	for i in _grounds.size():
		var d := _middles[i].distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return null
	if not is_instance_valid(_grounds[best]):  # (a world taken down and made again: look again)
		_keep_grounds(tree)
		return island_ground(tree, point) if not _grounds.is_empty() else null
	return _grounds[best]


static func _keep_grounds(tree: SceneTree) -> void:
	_grounds.clear()
	_middles.clear()
	for ground: TileMapLayer in tree.get_nodes_in_group("ground"):
		_grounds.append(ground)
		_middles.append(ground.to_global(ground.map_to_local(ground.get_used_rect().get_center())))


static var _grounds: Array[TileMapLayer] = []
static var _middles := PackedVector2Array()


## The island ground layer covering `point`, or close to it (for building out over the sea).
static func ground_near(tree: SceneTree, point: Vector2) -> TileMapLayer:
	var ground := island_ground(tree, point)
	if ground and ground.get_used_rect().grow(6).has_point(ground.local_to_map(ground.to_local(point))):
		return ground
	return null


## Centre of the nearest tile (searching outwards from `point`) whose terrain is
## one of `kinds` ("" = open ocean). Returns `point` if none is close.
static func nearest(tree: SceneTree, point: Vector2, kinds: Array, max_rings := 12) -> Vector2:
	var start := cell_of(point)
	for ring in max_rings + 1:
		var best := Vector2.INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var centre := centre_of(start + Vector2i(dx, dy))
				if at(tree, centre) in kinds and centre.distance_to(point) < best.distance_to(point):
					best = centre
		if best != Vector2.INF:
			return best
	return point


## World-grid cell containing a point (all islands share the 32x32 grid).
static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / TILE).floor())


## World position of a cell's centre.
static func centre_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
