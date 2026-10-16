class_name SeaWaves
extends Node2D
## Gentle waves on the water: little crests of light that rise, drift a few pixels and fade,
## scattered on a fixed grid in the world (so they stay put as the camera moves). Drawn just
## above the islands' ground, only where it's water (shallows, mid water, open ocean); the
## day/night tint reaches them like the rest of the world. Only the crests around the camera
## are drawn.

## Space between crests, how long one takes to rise and fade, and how far it drifts.
@export var spacing := 60.0  # (the owner: more of them)
@export var period := Vector2(3.5, 6.5)
@export var drift := 10.0
@export var colour := Color(0.85, 0.95, 1.0, 0.22)


## A very faint speckle over the open ocean (tools/make_terrain_tiles.py), drawn under the
## islands and fixed to the world, so even the deep water isn't flat (the owner).
const DEEP := preload("res://assets/tilesets/deep_water.png")
var _speckle: Node2D
## Each grid cell's crest, worked out once: [spot, width, seconds, phase], or [] where it would
## be on land or under a cliff's face (forgotten when a tile changes). Was worked out every frame
## for every crest in view: the phone's slowest thing to draw.
var _crests := {}


func _ready() -> void:
	SaveGame.tile_changed.connect(func() -> void: _crests.clear(), CONNECT_DEFERRED)  # (after the faces are redone)
	z_index = -3  # just above every island's Ground (-4), under swimming animals (-2)
	_speckle = Node2D.new()
	_speckle.z_index = -5  # (under the islands' ground)
	_speckle.z_as_relative = false
	_speckle.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_speckle.draw.connect(_draw_speckle)
	add_child(_speckle)


func _process(_delta: float) -> void:
	queue_redraw()
	_speckle.queue_redraw()


## The speckle over the view, at half size (a pixel is half a game pixel, like the ground art),
## its tiles on fixed world spots.
func _draw_speckle() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var view := Rect2(camera.get_screen_center_position() - half, half * 2.0).grow(64.0)
	var from := (view.position / 32.0).floor() * 32.0
	_speckle.draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	_speckle.draw_texture_rect(DEEP, Rect2(from * 2.0, (view.end - from) * 2.0), true)


func _draw() -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var half := get_viewport_rect().size / camera.zoom / 2.0
	var view := Rect2(camera.get_screen_center_position() - half, half * 2.0).grow(spacing)
	var time := Time.get_ticks_msec() / 1000.0
	var from := Vector2i((view.position / spacing).floor())
	var to := Vector2i((view.end / spacing).ceil())
	if _crests.size() > 20000:  # (a long voyage: forget the ones far behind)
		_crests.clear()
	for gx in range(from.x, to.x):
		for gy in range(from.y, to.y):
			_crest(Vector2i(gx, gy), time)


## One crest in grid cell `cell`: its own spot, size and timing, from a hash of the cell.
func _crest(cell: Vector2i, time: float) -> void:
	var crest: Variant = _crests.get(cell)
	if crest == null:
		crest = _make_crest(cell)
		_crests[cell] = crest
	if crest.is_empty():
		return
	var phase := fposmod(time / crest[2] + crest[3], 1.0)
	var alpha := sin(phase * PI)
	alpha *= alpha
	if alpha < 0.02:
		return
	var at: Vector2 = (crest[0] + Vector2(drift * phase, 0)).round()
	var width: int = crest[1]
	var tint := Color(colour, colour.a * alpha)
	# A small pixel-art crest: a line with its ends a pixel lower.
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(width - 2, 1)), tint)
	draw_rect(Rect2(at + Vector2(0, 1), Vector2(1, 1)), tint)
	draw_rect(Rect2(at + Vector2(width - 1, 1), Vector2(1, 1)), tint)


## A cell's crest from a hash of the cell; none unless all of its drift is on the water (and not
## just under a cliff's face).
func _make_crest(cell: Vector2i) -> Array:
	var h := hash(cell)
	var r1 := float(h & 0xff) / 255.0
	var r2 := float((h >> 8) & 0xff) / 255.0
	var r3 := float((h >> 16) & 0xff) / 255.0
	var spot := (Vector2(cell) + Vector2(r1, r2) * 0.8) * spacing
	for end: Vector2 in [spot.round(), (spot + Vector2(drift, 0)).round()]:
		if not Terrain.at(get_tree(), end) in ["", "water"] or TerrainEdges.covers(get_tree(), end):
			return []
	return [spot, roundi(lerpf(6.0, 12.0, r2)), lerpf(period.x, period.y, r3), r1]
