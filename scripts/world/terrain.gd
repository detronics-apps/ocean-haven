class_name Terrain
## What the ground is at a point in the world: "water", "sand", "grass", or
## "" for open ocean (no tile). Reads the "terrain" custom data on island tiles.

const TILE := 32


static func at(tree: SceneTree, point: Vector2) -> String:
	for ground: TileMapLayer in tree.get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return tile.get_custom_data("terrain")
	return ""


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
