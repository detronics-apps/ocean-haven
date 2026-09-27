class_name Player
extends ControlledBody
## The ranger on foot. Hidden and paused while aboard the boat.

@onready var _camera: Camera2D = $Camera2D


func set_aboard(aboard: bool) -> void:
	stop()
	visible = not aboard
	process_mode = PROCESS_MODE_DISABLED if aboard else PROCESS_MODE_INHERIT
	if not aboard:
		_camera.make_current()
