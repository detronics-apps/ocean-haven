extends CanvasModulate
## Tints the world by time of day: warm mornings, bright days, pink sunsets and
## soft blue nights (never too dark to play). The HUD is on its own layer, so it
## stays untinted.

## Tint across the day: 0 = midnight, 0.5 = noon.
@export var colors: Gradient

var _ocean: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
## Each island's ground and its middle (islands don't move).
var _middles := {}


func _process(_delta: float) -> void:
	color = colors.sample(GameClock.time_of_day)
	# The open ocean is the background colour, which CanvasModulate doesn't reach. It takes the
	# health tint of the island in view too, as that island's water tiles do, so the two match.
	var sea := _ocean * color
	var ground := _ground_in_view()
	if ground:
		sea *= ground.modulate
	RenderingServer.set_default_clear_color(sea)


## The island ground nearest the middle of the view.
func _ground_in_view() -> TileMapLayer:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return null
	var at := camera.get_screen_center_position()
	var best: TileMapLayer = null
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		if not _middles.has(ground):
			_middles[ground] = ground.to_global(ground.map_to_local(ground.get_used_rect().get_center()))
		if not best or at.distance_squared_to(_middles[ground]) < at.distance_squared_to(_middles[best]):
			best = ground
	return best
