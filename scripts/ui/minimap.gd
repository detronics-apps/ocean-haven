class_name Minimap
extends Control
## Round minimap (bottom-left, Minecraft-style): the land around the ranger, the
## boat, and a dot for home. When home is off the map its dot stays pinned to the
## rim, pointing the way back.

const RADIUS := 64.0
## How much of the world (in pixels from the ranger) the map shows.
const WORLD_RADIUS := 800.0
const OCEAN := Color("2b4a5e")
const TERRAIN_COLOURS := {"water": Color("5aa0b0"), "sand": Color("e6d5a4"), "grass": Color("6f9a55"),
	"rock": Color("8e8477"), "ice": Color("e8f1f5"), "mud": Color("7a5e3c")}
const HOME_COLOUR := Color("f28c38")
const BOAT_COLOUR := Color("8a5a36")


## The islands' ground as one small picture, a pixel a tile (drawn round the ranger, cut to a
## circle by CIRCLE): building it from every tile each frame cost several ms. Rebuilt when a
## tile changes (SaveGame.tile_changed) and now and then (loading).
var _land: ImageTexture
var _land_origin := Vector2i.ZERO
var _land_dirty := true
var _land_age := 0.0
const REBUILD_EVERY := 10.0
const CIRCLE := preload("res://assets/effects/minimap/circle.gdshader")


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var circle := ShaderMaterial.new()
	circle.shader = CIRCLE
	circle.set_shader_parameter("centre", Vector2(RADIUS, RADIUS))
	circle.set_shader_parameter("radius", RADIUS + 3.0)
	material = circle
	SaveGame.tile_changed.connect(func() -> void: _land_dirty = true)


func _build_land() -> void:
	var cells := {}
	var low := Vector2i(1 << 30, 1 << 30)
	var high := -low
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			var terrain: String = ground.get_cell_tile_data(cell).get_custom_data("terrain")
			if not TERRAIN_COLOURS.has(terrain):
				continue
			var at := Terrain.cell_of(ground.to_global(ground.map_to_local(cell)))
			cells[at] = TERRAIN_COLOURS[terrain]
			low = Vector2i(mini(low.x, at.x), mini(low.y, at.y))
			high = Vector2i(maxi(high.x, at.x), maxi(high.y, at.y))
	if cells.is_empty():
		return
	var image := Image.create_empty(high.x - low.x + 1, high.y - low.y + 1, false, Image.FORMAT_RGBA8)
	for at: Vector2i in cells:
		image.set_pixelv(at - low, cells[at])
	_land_origin = low
	if _land and _land.get_size() == Vector2(image.get_size()):
		_land.update(image)
	else:
		_land = ImageTexture.create_from_image(image)


func _process(delta: float) -> void:
	_land_age += delta
	if _land_age >= REBUILD_EVERY:
		_land_age = 0.0
		_land_dirty = true
	queue_redraw()


## Where a world position appears on the map (local to this control), and whether
## it's actually on the map (false = pinned to the rim).
func map_point(world_pos: Vector2, centre: Vector2) -> Array:
	var offset := (world_pos - centre) * (RADIUS / WORLD_RADIUS)
	if offset.length() <= RADIUS - 5.0:
		return [Vector2(RADIUS, RADIUS) + offset, true]
	return [Vector2(RADIUS, RADIUS) + offset.normalized() * (RADIUS - 5.0), false]


func _draw() -> void:
	var middle := Vector2(RADIUS, RADIUS)
	draw_circle(middle, RADIUS + 3.0, Color(0.08, 0.1, 0.14, 0.9))
	draw_circle(middle, RADIUS, OCEAN)
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var centre := ranger.global_position
	if _land_dirty:
		_land_dirty = false
		_build_land()
	if _land:
		var tiles := WORLD_RADIUS / Terrain.TILE  # tiles from the ranger to the rim
		var from := centre / Terrain.TILE - Vector2(_land_origin) - Vector2(tiles, tiles)
		draw_texture_rect_region(_land, Rect2(Vector2.ZERO, Vector2(RADIUS, RADIUS) * 2.0),
			Rect2(from, Vector2(tiles, tiles) * 2.0))
	for boat: Node2D in get_tree().get_nodes_in_group("boat"):
		if boat == ranger:
			continue
		var b: Array = map_point(boat.global_position, centre)
		if b[1]:
			draw_rect(Rect2(b[0] - Vector2(3, 2), Vector2(6, 4)), BOAT_COLOUR)
	_draw_storm(middle, Regions.nearest(centre))
	# What the last mission found (until the next morning); pinned to the rim when off the map.
	for node: Node2D in Missions.marked():
		var m: Array = map_point(node.global_position, centre)
		draw_circle(m[0], 3.5, Color.BLACK)
		draw_circle(m[0], 2.5, Missions.marker_colour())
	var home := _home()
	if home:
		var h: Array = map_point(home.global_position, centre)
		draw_circle(h[0], 5.0, Color.WHITE)
		draw_circle(h[0], 3.5, HOME_COLOUR)
	# The ranger: a small white arrow-ish dot in the middle.
	draw_circle(middle, 3.5, Color.BLACK)
	draw_circle(middle, 2.5, Color.WHITE)


## A storm gathering (StormClouds): its clouds round the map's rim, thicker and further in
## the nearer it is.
func _draw_storm(middle: Vector2, region: RegionData) -> void:
	var event := RareEvents.coming_to(region.id)
	var near := StormClouds.nearness(region.id)
	if not event or near <= 0.0:
		return
	var colour := StormWeather.cloud_colour(event.weather)
	var time := Time.get_ticks_msec() / 1000.0
	var puffs := 28
	for i in puffs:
		var angle := TAU * i / puffs + time * 0.05
		var wobble := sin(i * 2.3 + time * 0.8) * 0.5 + 0.5
		var depth := 4.0 + 14.0 * near * (0.7 + 0.3 * wobble)
		var at := middle + Vector2.from_angle(angle) * (RADIUS - depth * 0.5)
		draw_circle(at, depth * 0.6 + 2.0, Color(colour, 0.55 + 0.35 * near))


## The ranger's home on the island they're on: the building they sleep in (tent or house).
## None on this island: no dot (a home on another island isn't pinned to the rim).
func _home() -> Node2D:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return null
	var here := Regions.nearest(ranger.global_position)
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"sleep" and not building.is_queued_for_deletion() and Regions.nearest(building.global_position) == here:
			return building
	return null
