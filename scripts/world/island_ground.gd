class_name IslandGround
extends TileMapLayer
## An island's ground. Where two land cells touch only at a corner, with water in the other two
## (a checkerboard), the rounded edges draw the land joined up (TerrainEdges), so the ranger can
## walk across there too: the two water cells' collision is cut back at that corner (by CUT px
## along both edges) and Terrain.walkable lets the ranger stand in the cut.

const CUT := 10.0
## Water cell -> the corners it's cut back at (each the direction from its centre to the corner).
var passes := {}


## Whether `point` (local) is in a cut-back corner of a water cell.
func in_pass(cell: Vector2i, point: Vector2) -> bool:
	for towards: Vector2 in passes.get(cell, []):
		var from_corner := (map_to_local(cell) + towards * 16.0 - point).abs()
		if from_corner.x + from_corner.y < CUT:
			return true
	return false


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return passes.has(coords)


func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if tile_data.get_collision_polygons_count(0) == 0:
		return
	var square := [Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]
	var shape := PackedVector2Array()
	for i in square.size():
		var v: Vector2 = square[i]
		if v / 16.0 in passes[coords]:
			var before: Vector2 = square[i - 1]
			var after: Vector2 = square[(i + 1) % square.size()]
			shape.append(v + (before - v).normalized() * CUT)
			shape.append(v + (after - v).normalized() * CUT)
		else:
			shape.append(v)
	tile_data.set_collision_polygon_points(0, 0, shape)
