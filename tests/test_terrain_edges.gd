extends SceneTree
## Rounded terrain edges: a visual layer only. A lone water cell in sand gets 4 rounded sand
## corners (a round pool); coasts get curves; every shape stays inside its own cell's quarter
## (no seams); changing a tile updates only the corners around it; the grid never changes.
## Run: godot --headless --path . --script res://tests/test_terrain_edges.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var edges: Node2D = world.get_node("StarterIsland/TerrainEdges")
	var ground: TileMapLayer = world.get_node("StarterIsland/Ground")
	_expect(edges.piece_count() > 20, "the coast has rounded corners (%d)" % edges.piece_count())
	for island in ["KelpIsland", "MangroveIsland", "ReefIsland", "HookIsland", "PolarIsland"]:
		_expect(world.get_node("%s/TerrainEdges" % island).piece_count() > 0, "%s has rounded edges too" % island)

	# Every shape stays inside one cell's quarter: nothing spills over a boundary (no seams).
	var inside := true
	for corner: Vector2i in edges.get("_pieces"):
		var point := ground.map_to_local(corner) - Vector2(16, 16)  # the grid corner point
		for piece: Array in edges.pieces_at(corner):
			for p: Vector2 in piece[0]:
				inside = inside and p.distance_to(point) <= 16.0 * sqrt(2.0) + 0.01
	_expect(inside, "every rounded piece stays within the quarter of its own cell")

	# A lone water cell in the middle of sand: a round pool (4 sand-coloured corners).
	var sand_cell := Vector2i.MAX
	for c in ground.get_used_cells():
		var all_sand := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				all_sand = all_sand and edges.terrain_at(c + Vector2i(dx, dy)) == "sand"
		if all_sand:
			sand_cell = c
			break
	_expect(sand_cell != Vector2i.MAX, "(a cell in the middle of a beach)")
	var before: int = edges.piece_count()
	var atlas := ground.get_cell_atlas_coords(sand_cell)
	var save := root.get_node("SaveGame")
	ground.set_cell(sand_cell, 0, Vector2i(0, 0))  # shallow water
	save.record_tile(ground, sand_cell, Vector2i(0, 0))  # every gameplay tile change is recorded
	await process_frame
	await process_frame
	var pool := [sand_cell, sand_cell + Vector2i(1, 0), sand_cell + Vector2i(0, 1), sand_cell + Vector2i(1, 1)].filter(
		func(corner: Vector2i) -> bool: return edges.pieces_at(corner).size() == 1)
	_expect(pool.size() == 4 and edges.piece_count() == before + 4, "a lone water cell in sand becomes a round pool (4 corners)")
	_expect(edges.terrain_at(sand_cell) == "water", "the grid cell itself is still plain water: only the look changed")
	ground.set_cell(sand_cell, 0, atlas)
	save.record_tile(ground, sand_cell, atlas)
	await process_frame
	await process_frame
	_expect(edges.piece_count() == before, "put back: the corners go again")

	# Where three terrains meet (e.g. sand, grass and water), the corner is rounded too.
	var three := Vector2i.MAX
	for c in ground.get_used_cells():
		var a: String = edges.terrain_at(c)
		var right: String = edges.terrain_at(c + Vector2i(1, 0))
		var down: String = edges.terrain_at(c + Vector2i(0, 1))
		if a != right and a != down and right != down and "sea" not in [a, right, down]:
			three = c
	if three != Vector2i.MAX:
		_expect(edges.pieces_at(three + Vector2i(1, 1)).size() >= 1, "three terrains meeting: rounded too")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
