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


## World-grid cell containing a point (all islands share the 32x32 grid).
static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / TILE).floor())


## World position of a cell's centre.
static func centre_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
