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
##
## It also lays the ground's pictures: a second tile layer ("GroundArt", just above Ground, at
## half size) with the 64x64 art of tools/make_terrain_tiles.py, several versions of each ground
## picked per cell (some mirrored), so there's no repeating pattern. Ground itself is hidden: it
## keeps the terrain, walking and saves.

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

const ART := preload("res://assets/tilesets/terrain_art.png")
const ART_SIZE := 64
const ART_VARIANTS := 8
static var _art_set: TileSet
var _art: TileMapLayer

## Decorations (tools/make_ground_details.py), only for looks: grass patches inside 3 x 3 grass,
## shells / tracks / stones / little rocks where 3 in a row are the same ground, one snowman on an
## icy island, waves rolling up the sand and spray on rocky shores (animated tiles).
const DETAILS := preload("res://assets/tilesets/ground_details.png")
const DETAIL_ROWS := {"grass": 0, "sand": 1, "mud": 2, "rock": 3, "ice": 4}
const DETAIL_CHANCE := {"grass": 0.18, "sand": 0.12, "mud": 0.12, "rock": 0.15, "ice": 0.06}
const WAVES_ROW := 5
const SPRAY_ROW := 6
const SNOWMAN := Vector2i(3, 4)
const NO_CELL := Vector2i(-99999, -99999)
## Water above, below, left, right of a shore cell -> the turned version of its wave tile.
const SIDES := {Vector2i(0, -1): 0, Vector2i(0, 1): 1, Vector2i(-1, 0): 2, Vector2i(1, 0): 3}
static var _details_set: TileSet
var _details: TileMapLayer
var _snowman := NO_CELL


func _ready() -> void:
	_ground = get_parent().get_node_or_null("Ground")
	if not _ground:
		return
	position = _ground.position
	z_index = _ground.z_index
	_ground.self_modulate.a = 0.0  # (its plain tiles hidden: the art layer shows the ground)
	_art = TileMapLayer.new()
	_art.name = "GroundArt"
	_art.tile_set = _art_tiles()
	_art.position = _ground.position
	_art.scale = Vector2.ONE * float(_ground.tile_set.tile_size.x) / ART_SIZE
	_art.z_index = _ground.z_index
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_details = TileMapLayer.new()
	_details.name = "GroundDetails"
	_details.tile_set = _detail_tiles()
	_details.scale = _art.scale
	_details.z_index = _ground.z_index
	_details.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_put_art_in.call_deferred()
	_read_colours()
	rebuild()


func _put_art_in() -> void:
	get_parent().add_child(_art)
	get_parent().move_child(_art, _ground.get_index() + 1)
	get_parent().add_child(_details)  # (over the rounded corners)
	get_parent().move_child(_details, get_index() + 1)
	_details.position = position


## The details' tile set, made once: each picture and a mirrored one; the waves and the spray
## animate (each tile starting at its own moment) and are turned to face the water.
static func _detail_tiles() -> TileSet:
	if _details_set:
		return _details_set
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(ART_SIZE, ART_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = DETAILS
	source.texture_region_size = Vector2i(ART_SIZE, ART_SIZE)
	tiles.add_source(source, 0)
	for row in DETAIL_ROWS.size():
		for v in 4:
			var at := Vector2i(v, row)
			source.create_tile(at)
			source.get_tile_data(at, source.create_alternative_tile(at)).flip_h = true
	for row in [WAVES_ROW, SPRAY_ROW]:
		var at := Vector2i(0, row)
		source.create_tile(at)
		source.set_tile_animation_columns(at, 4)
		source.set_tile_animation_frames_count(at, 4)
		source.set_tile_animation_mode(at, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
		for f in 4:
			source.set_tile_animation_frame_duration(at, f, 0.45 if row == WAVES_ROW else 0.3)
		var below := source.get_tile_data(at, source.create_alternative_tile(at))
		below.flip_v = true
		var left := source.get_tile_data(at, source.create_alternative_tile(at))
		left.transpose = true
		var right := source.get_tile_data(at, source.create_alternative_tile(at))
		right.transpose = true
		right.flip_h = true
	_details_set = tiles
	return tiles


## The cell's decoration, if any (picked from the cell, so it stays put).
func _decorate(cell: Vector2i) -> void:
	var kind := terrain_at(cell)
	var pick := absi(hash(cell + Vector2i(7, 13)))
	if kind == "sand" or (kind == "rock" and pick % 2 == 0):
		for side: Vector2i in SIDES:
			if terrain_at(cell + side) in ["water", "", "sea"]:
				_details.set_cell(cell, 0, Vector2i(0, WAVES_ROW if kind == "sand" else SPRAY_ROW), SIDES[side])
				return
	if cell == _snowman:
		_details.set_cell(cell, 0, SNOWMAN)
		return
	if DETAIL_ROWS.has(kind) and _fits(cell, kind) and pick % 1000 < int(DETAIL_CHANCE[kind] * 1000):
		var versions := 3 if kind == "ice" else 4  # (the ice's 4th is the snowman)
		_details.set_cell(cell, 0, Vector2i((pick / 1000) % versions, DETAIL_ROWS[kind]), (pick / 7) % 2)
		return
	_details.erase_cell(cell)


## Grass: all 8 around it grass too; the rest: the same ground on both sides, across or down.
func _fits(cell: Vector2i, kind: String) -> bool:
	if kind == "grass":
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if terrain_at(cell + Vector2i(dx, dy)) != kind:
					return false
		return true
	return (terrain_at(cell + Vector2i(-1, 0)) == kind and terrain_at(cell + Vector2i(1, 0)) == kind) 		or (terrain_at(cell + Vector2i(0, -1)) == kind and terrain_at(cell + Vector2i(0, 1)) == kind)


## One snowman on an icy island: the ice cell with ice all round it that its hash picks.
func _place_snowman() -> void:
	_snowman = NO_CELL
	var best := -1
	for cell: Vector2i in _terrain:
		if _terrain[cell] != "ice":
			continue
		var all_ice := true
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				all_ice = all_ice and _terrain.get(cell + Vector2i(dx, dy), "") == "ice"
		var h := absi(hash(cell + Vector2i(3, 5)))
		if all_ice and (best < 0 or h < best):
			best = h
			_snowman = cell


## The art's tile set, made once: a tile per picture, and a mirrored one of each.
static func _art_tiles() -> TileSet:
	if _art_set:
		return _art_set
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(ART_SIZE, ART_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = ART
	source.texture_region_size = Vector2i(ART_SIZE, ART_SIZE)
	tiles.add_source(source, 0)
	for row in ART.get_height() / ART_SIZE:
		for v in ART_VARIANTS:
			var at := Vector2i(v, row)
			source.create_tile(at)
			source.get_tile_data(at, source.create_alternative_tile(at)).flip_h = true
	_art_set = tiles
	return tiles


## The cell's picture: its ground's row, a version (and mirrored or not) picked from the cell.
func _paint(cell: Vector2i) -> void:
	var ground := _ground.get_cell_atlas_coords(cell)
	if ground.x < 0:
		_art.erase_cell(cell)
		return
	var pick := absi(hash(cell))
	_art.set_cell(cell, 0, Vector2i(pick % ART_VARIANTS, ground.x), (pick / ART_VARIANTS) % 2)


func _enter_tree() -> void:
	add_to_group("terrain_edges")


## The colour of each terrain: its tile's average (the tiles are textured: grains, tufts, cracks).
func _read_colours() -> void:
	var source := _ground.tile_set.get_source(0) as TileSetAtlasSource
	var image := source.texture.get_image() if source and source.texture else null
	for cell in _ground.get_used_cells():
		var kind := terrain_at(cell)
		if _colours.has(kind) or not image:
			continue
		var region := source.get_tile_texture_region(_ground.get_cell_atlas_coords(cell))
		var sum := Color(0, 0, 0, 0)
		for y in region.size.y:
			for x in region.size.x:
				sum += image.get_pixel(region.position.x + x, region.position.y + y)
		_colours[kind] = sum / float(region.size.x * region.size.y)


## A cell's terrain ("sea" = open ocean: no tile).
func terrain_at(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


## Works out every rounded corner on the island.
func rebuild() -> void:
	_terrain.clear()
	_pieces.clear()
	var corners := {}
	_art.clear()
	for cell in _ground.get_used_cells():
		_terrain[cell] = terrain_at(cell)
		_paint(cell)
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			corners[cell + d] = true
	for corner: Vector2i in corners:
		_shape_corner(corner)
	_details.clear()
	_place_snowman()
	for cell: Vector2i in _terrain:
		_decorate(cell)
	queue_redraw()


## A tile changed (SaveGame.record_tile tells every TerrainEdges): only the 4 corners of that
## cell are worked out again, which covers every neighbour whose look it can change.
func cell_changed(ground: TileMapLayer, cell: Vector2i) -> void:
	if ground != _ground:
		return
	_terrain[cell] = terrain_at(cell)
	_paint(cell)
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_shape_corner(cell + d)
	for dx in [-1, 0, 1]:  # (its own decoration and its neighbours': their rules look at it)
		for dy in [-1, 0, 1]:
			_decorate(cell + Vector2i(dx, dy))
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
		if across == mine:
			# The same terrain diagonally across: the two stay joined through the point and the
			# other two cells round into them. In a pure checkerboard the higher terrain stays
			# joined up and only the lower rounds.
			if beside_x != beside_y or PRIORITY.get(mine, 0) > PRIORITY.get(fill, 0):
				continue
		elif beside_x != beside_y:
			fill = across if across in [beside_x, beside_y] else (beside_x if PRIORITY.get(beside_x, 0) >= PRIORITY.get(beside_y, 0) else beside_y)
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
		_art.modulate = _ground.modulate
		_details.modulate = _ground.modulate


func _draw() -> void:
	for corner: Vector2i in _pieces:
		for piece: Array in _pieces[corner]:
			draw_colored_polygon(piece[0], piece[1])
