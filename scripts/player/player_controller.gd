class_name Player
extends ControlledBody
## The ranger on foot. Hidden and paused while aboard the boat.

@onready var _camera: Camera2D = $Camera2D


## Only ever on land or a deck: can't step off the end of a jetty into the sea.
func _physics_process(delta: float) -> void:
	var before := global_position
	super(delta)
	if not Terrain.walkable(get_tree(), global_position):
		global_position = before


func set_aboard(aboard: bool) -> void:
	stop()
	controlled = not aboard
	visible = not aboard
	process_mode = PROCESS_MODE_DISABLED if aboard else PROCESS_MODE_INHERIT
	if not aboard:
		_camera.make_current()
