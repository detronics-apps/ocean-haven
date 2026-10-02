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


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
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
	var cell_size := Terrain.TILE * RADIUS / WORLD_RADIUS + 0.6
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			var point: Array = map_point(ground.to_global(ground.map_to_local(cell)), centre)
			if point[1]:
				var colour: Color = TERRAIN_COLOURS.get(ground.get_cell_tile_data(cell).get_custom_data("terrain"), OCEAN)
				draw_rect(Rect2(point[0] - Vector2.ONE * cell_size / 2.0, Vector2.ONE * cell_size), colour)
	for boat: Node2D in get_tree().get_nodes_in_group("boat"):
		if boat == ranger:
			continue
		var b: Array = map_point(boat.global_position, centre)
		if b[1]:
			draw_rect(Rect2(b[0] - Vector2(3, 2), Vector2(6, 4)), BOAT_COLOUR)
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


## The ranger's home: the building they sleep in (tent or house).
func _home() -> Node2D:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"sleep":
			return building
	return null
