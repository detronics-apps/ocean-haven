class_name TerrainEdges
extends Node2D
## Rounded coastlines and terrain boundaries: a visual layer over an island's Ground (a sibling,
## drawn just above it). The grid itself never changes: every cell keeps its terrain type,
## placement, walking and saves exactly as they are. Only how the corners look changes.
##
## Each corner point of the grid is shared by 4 cells. Where one of those 4 is different from
## the other 3 (its two neighbours beside it and the one diagonally across are the same terrain),
## that cell's corner is rounded off: the area outside a small quarter circle (RADIUS) is painted
## in the neighbours' colour. So a lone water cell in sand gets rounded corners, a lone sand cell
## in water a rounded islet, and every L-shaped coast corner gets a curve. Because each shape is
## decided at the shared corner and stays inside one cell's own quarter, the cells on both sides
## always agree: no gaps, overlaps or seams. The arc meets the cell edges at right angles, so
## curves and straight coast join smoothly.
##
## Worked out once when the island loads (and after loading a save), and again only around
## cells that change (every gameplay tile change goes through SaveGame.record_tile, which calls
## cell_changed). Nothing is calculated per frame.

const HALF := 16.0
const ARC_STEPS := 6
## How far a rounded corner reaches into its cell (half of the half-cell: a gentle curve).
const RADIUS := 8.0
## Edge styles by terrain pair (both orders); anything not listed is "soft". Room for later:
## rock and ice could get harder, more broken edges.
const STYLES := {}
## Which terrain stays joined up where two cross diagonally (land above water, shallow above deep).
const PRIORITY := {"rock": 6, "grass": 5, "mud": 4, "ice": 4, "sand": 3, "water": 2, "": 1, "sea": 0}

var _ground: TileMapLayer
## Terrain of every cell last time it was looked at, and the pieces to draw per corner point.
var _terrain := {}
var _pieces := {}
var _colours := {}


func _ready() -> void:
	_ground = get_parent().get_node_or_null("Ground")
	if not _ground:
		return
	position = _ground.position
	z_index = _ground.z_index
	_read_colours()
	rebuild()


func _enter_tree() -> void:
	add_to_group("terrain_edges")


## The colour of each terrain, from the middle of its tile in the tileset's picture.
func _read_colours() -> void:
	var source := _ground.tile_set.get_source(0) as TileSetAtlasSource
	var image := source.texture.get_image() if source and source.texture else null
	for cell in _ground.get_used_cells():
		var kind := terrain_at(cell)
		if _colours.has(kind) or not image:
			continue
		var region := source.get_tile_texture_region(_ground.get_cell_atlas_coords(cell))
		_colours[kind] = image.get_pixelv(region.position + region.size / 2)


## A cell's terrain ("sea" = open ocean: no tile).
func terrain_at(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


## Works out every rounded corner on the island.
func rebuild() -> void:
	_terrain.clear()
	_pieces.clear()
	var corners := {}
	for cell in _ground.get_used_cells():
		_terrain[cell] = terrain_at(cell)
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			corners[cell + d] = true
	for corner: Vector2i in corners:
		_shape_corner(corner)
	queue_redraw()


## A tile changed (SaveGame.record_tile tells every TerrainEdges): only the 4 corners of that
## cell are worked out again, which covers every neighbour whose look it can change.
func cell_changed(ground: TileMapLayer, cell: Vector2i) -> void:
	if ground != _ground:
		return
	_terrain[cell] = terrain_at(cell)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_shape_corner(cell + d)
	queue_redraw()


## The corner point `corner` is the top-left corner of cell `corner`. Decides whether one of the
## 4 cells around it gets a rounded quarter, and stores the shape to draw.
func _shape_corner(corner: Vector2i) -> void:
	_pieces.erase(corner)
	# The 4 cells around the point, and for each the direction from its centre to the point.
	var around := [[corner + Vector2i(-1, -1), Vector2(1, 1)], [corner + Vector2i(0, -1), Vector2(-1, 1)],
		[corner + Vector2i(-1, 0), Vector2(1, -1)], [corner, Vector2(-1, -1)]]
	for entry: Array in around:
		var cell: Vector2i = entry[0]
		var towards: Vector2 = entry[1]
		var mine := terrain_at(cell)
		var beside_x := terrain_at(cell + Vector2i(int(towards.x), 0))
		var beside_y := terrain_at(cell + Vector2i(0, int(towards.y)))
		var across := terrain_at(cell + Vector2i(int(towards.x), int(towards.y)))
		if beside_x == mine or beside_y == mine:
			continue  # a straight edge or an inside corner: nothing to round here
		# The colour that rounds into this corner: the neighbours' terrain if they agree; where
		# three terrains meet, the one diagonally across if it's one of them, else the higher.
		var fill := beside_x
		if beside_x != beside_y:
			fill = across if across in [beside_x, beside_y] else (beside_x if PRIORITY.get(beside_x, 0) >= PRIORITY.get(beside_y, 0) else beside_y)
		elif across == mine and PRIORITY.get(mine, 0) > PRIORITY.get(fill, 0):
			continue  # a checkerboard: the higher terrain stays joined up, only the lower rounds
		if fill == "sea" or not _colours.has(fill):
			continue
		if not _pieces.has(corner):
			_pieces[corner] = []
		_pieces[corner].append([_quarter(cell, towards, style(mine, fill)), _colours[fill]])


## The polygon filling `cell`'s corner towards `towards` outside a rounded corner of radius
## RADIUS (half a cell's half, so curves stay small and neighbouring corners never run together).
func _quarter(cell: Vector2i, towards: Vector2, kind: StringName) -> PackedVector2Array:
	var point := _ground.map_to_local(cell) + towards * HALF
	var radius := RADIUS * (0.85 if kind == &"hard" else 1.0)
	var centre := point - towards * radius
	var start := Vector2(towards.x, 0.0)
	var end := Vector2(0.0, towards.y)
	var shape := PackedVector2Array([point])
	for i in range(ARC_STEPS + 1):
		var t := float(i) / ARC_STEPS
		shape.append(centre + start.slerp(end, t).normalized() * radius)
	return shape


## How the boundary between two terrains looks (all "soft" for now).
static func style(a: String, b: String) -> StringName:
	return STYLES.get([a, b], STYLES.get([b, a], &"soft"))


## How many rounded corners there are (for tests and the editor).
func piece_count() -> int:
	var n := 0
	for corner: Vector2i in _pieces:
		n += (_pieces[corner] as Array).size()
	return n


func pieces_at(corner: Vector2i) -> Array:
	return _pieces.get(corner, [])


func _process(_delta: float) -> void:
	if _ground and modulate != _ground.modulate:
		modulate = _ground.modulate  # the island's health tint, as on the ground


func _draw() -> void:
	for corner: Vector2i in _pieces:
		for piece: Array in _pieces[corner]:
			draw_colored_polygon(piece[0], piece[1])
