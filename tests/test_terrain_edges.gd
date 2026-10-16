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
	await process_frame

	# Heights (looks only): the sea is 0, a ground touching it stands its own step above it, a
	# patch inside another ground stands on top of it; so beaches are flat with the sea, grass
	# stands above the beach, the Deep Sea's grass above its rock, and no land is ever a pit.
	var beach := Vector2i.MAX
	var bank := Vector2i.MAX  # (a grass cell with sand just south of it)
	for c in ground.get_used_cells():
		if edges.terrain_at(c) == "sand" and edges.terrain_at(c + Vector2i(0, 1)) in ["water", "", "sea"]:
			beach = c
		if edges.terrain_at(c) == "grass" and edges.terrain_at(c + Vector2i(0, 1)) == "sand":
			bank = c
	_expect(beach != Vector2i.MAX and edges.level_at(beach) == 0, "a beach is level with the sea")
	_expect(bank != Vector2i.MAX and edges.level_at(bank) == 5, "the grass stands 5 px above the beach")
	_expect(edges.get("_hangs").get(bank + Vector2i(0, 1), 0) == 5, "with its face hanging over the sand south of it")
	var hook: Node2D = world.get_node("HookIsland/TerrainEdges")
	var hook_ground: TileMapLayer = world.get_node("HookIsland/Ground")
	var cliff := Vector2i.MAX  # (rock rising straight from the sea)
	for c in hook_ground.get_used_cells():
		if hook.terrain_at(c) == "rock" and hook.terrain_at(c + Vector2i(0, 1)) in ["water", ""]:
			cliff = c
	var sea_rock: int = hook.level_at(cliff)
	var holes := 0
	var beside_rock := 0
	var outcrops := 0
	for c in hook_ground.get_used_cells():
		if hook.terrain_at(c) != "grass":
			continue
		for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if hook.terrain_at(c + side) == "rock":
				if hook.level_at(c + side) == sea_rock:
					beside_rock += 1
					holes += 1 if hook.level_at(c) <= sea_rock else 0
				else:
					outcrops += 1 if hook.level_at(c + side) > hook.level_at(c) else 0
	_expect(sea_rock > 0 and beside_rock > 0 and holes == 0, "the Deep Sea's grass stands on top of its rock, never a hole in it (%d / %d)" % [holes, beside_rock])
	_expect(outcrops > 0, "and the rock outcrops on the grass stand above the grass")
	for island in ["StarterIsland", "KelpIsland", "MangroveIsland", "ReefIsland", "HookIsland", "PolarIsland"]:
		var e: Node2D = world.get_node("%s/TerrainEdges" % island)
		var g: TileMapLayer = world.get_node("%s/Ground" % island)
		var pits := 0
		var wet := 0
		var seen := {}
		for c in g.get_used_cells():
			var kind: String = e.terrain_at(c)
			if kind in ["water", "", "sea"]:
				wet += 1 if e.level_at(c) != 0 else 0
				continue
			if seen.has(c):
				continue
			# (the region: this ground's cells side by side; is any ground round it as low or lower?)
			var todo: Array[Vector2i] = [c]
			seen[c] = true
			var lowest_round := 999
			while not todo.is_empty():
				var at: Vector2i = todo.pop_back()
				for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = at + side
					if e.terrain_at(n) == kind:
						if not seen.has(n):
							seen[n] = true
							todo.append(n)
					else:
						lowest_round = mini(lowest_round, e.level_at(n))
			pits += 1 if lowest_round > e.level_at(c) else 0
		_expect(pits == 0 and wet == 0, "%s: no land lower than all the ground round it, water at 0" % island)
	# A tile change: an outcrop of rock in the middle of the grass stands above it, then goes.
	var meadow := Vector2i.MAX
	for c in ground.get_used_cells():
		var all_grass := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				all_grass = all_grass and edges.terrain_at(c + Vector2i(dx, dy)) == "grass"
		if all_grass:
			meadow = c
			break
	var grass_atlas := ground.get_cell_atlas_coords(meadow)
	var rock_atlas := Vector2i(3, 0)
	ground.set_cell(meadow, 0, rock_atlas)
	save.record_tile(ground, meadow, rock_atlas)
	await process_frame
	await process_frame
	_expect(edges.level_at(meadow) == edges.level_at(meadow + Vector2i(0, 1)) + 5, "a rock laid in the meadow stands 5 px above the grass")
	_expect(edges.get("_hangs").get(meadow + Vector2i(0, 1), 0) == 5, "with its face over the grass south of it")
	ground.set_cell(meadow, 0, grass_atlas)
	save.record_tile(ground, meadow, grass_atlas)
	await process_frame
	await process_frame
	_expect(not edges.get("_hangs").has(meadow + Vector2i(0, 1)), "taken away: the face goes too")
	# The sea's moving waves leave the water just under a cliff's face alone.
	var under := hook_ground.to_global(hook_ground.map_to_local(cliff + Vector2i(0, 1)))
	_expect(hook.covers(self, under + Vector2(0, -12)), "no wave crest on a cliff's face")
	_expect(not hook.covers(self, under + Vector2(0, 8)), "but still out in the water below it")
	# The ranger hops a little going up the grass bank from the beach; not walking on the flat.
	var ranger: Node2D = world.get_node("Player")
	ranger.global_position = ground.to_global(ground.map_to_local(bank + Vector2i(0, 1)))
	for i in 30:  # (getting there was a hop down: let it land)
		await physics_frame
	ranger.global_position += Vector2(8, 0)  # (along the beach)
	await physics_frame
	_expect(float(ranger.get("_hop")) >= 1.0, "no hop on the flat beach")
	ranger.global_position = ground.to_global(ground.map_to_local(bank))
	await physics_frame
	_expect(float(ranger.get("_hop")) < 1.0, "a hop up onto the grass")
	# Boats keep out from under a cliff's face (the land's physics layer, as the rowboat's).
	var boat := CharacterBody2D.new()
	boat.collision_mask = 4
	var hull := CollisionShape2D.new()
	hull.shape = CircleShape2D.new()
	(hull.shape as CircleShape2D).radius = 4.0
	boat.add_child(hull)
	world.add_child(boat)
	boat.global_position = under + Vector2(0, 10)
	await physics_frame
	for i in 20:
		boat.move_and_collide(Vector2(0, -1.5))
		await physics_frame
	_expect(boat.global_position.y >= under.y + 2.0, "a boat sailing up to a cliff stops in front of its face (%.1f)" % (boat.global_position.y - under.y))
	boat.queue_free()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
