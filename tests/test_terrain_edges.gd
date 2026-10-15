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
	_expect(pool.size() == 4 and edges.piece_count() == before + 4, "a lone water cell in sand becomes a rounded pool (4 corners)")
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

	# Two sand cells touching only at a corner, water in the other two (drawn joined up): the
	# ranger can walk across from one to the other.
	var water_cells := [sand_cell + Vector2i(1, 0), sand_cell + Vector2i(0, 1)]
	var atlases := []
	for c: Vector2i in water_cells:
		atlases.append(ground.get_cell_atlas_coords(c))
		ground.set_cell(c, 0, Vector2i(0, 0))
		save.record_tile(ground, c, Vector2i(0, 0))
	await process_frame
	await physics_frame
	await physics_frame
	var corner_point := ground.to_global(ground.map_to_local(sand_cell) + Vector2(16, 16))
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	_expect(terrain.walkable(self, corner_point + Vector2(3, -3)), "standing in the corner between the two land cells")
	_expect(not terrain.walkable(self, corner_point + Vector2(8, -8)), "but not further into the water")
	var walker := CharacterBody2D.new()
	walker.collision_mask = 1
	var feet := CollisionShape2D.new()
	feet.shape = CircleShape2D.new()
	(feet.shape as CircleShape2D).radius = 5.0
	walker.add_child(feet)
	world.add_child(walker)
	var crossed := func() -> bool:
		walker.global_position = ground.to_global(ground.map_to_local(sand_cell))
		await physics_frame
		for i in 21:
			walker.move_and_collide(Vector2(1.5, 1.5))
			await physics_frame
		return walker.global_position.distance_to(ground.to_global(ground.map_to_local(sand_cell + Vector2i(1, 1)))) < 4.0
	_expect(await crossed.call(), "a walker crosses diagonally to the other land cell")
	walker.queue_free()
	for i in water_cells.size():
		ground.set_cell(water_cells[i], 0, atlases[i])
		save.record_tile(ground, water_cells[i], atlases[i])

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
