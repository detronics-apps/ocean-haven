extends CanvasModulate
## Tints the world by time of day: warm mornings, bright days, pink sunsets and
## soft blue nights (never too dark to play). The HUD is on its own layer, so it
## stays untinted.

## Tint across the day: 0 = midnight, 0.5 = noon.
@export var colors: Gradient

var _ocean: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")


func _process(_delta: float) -> void:
	color = colors.sample(GameClock.time_of_day)
	# The open ocean is the background colour, which CanvasModulate doesn't reach.
	RenderingServer.set_default_clear_color(_ocean * color)
