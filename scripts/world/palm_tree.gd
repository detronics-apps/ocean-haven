extends StaticBody2D
## A palm tree. The ranger can cut it down (action bar); new ones are planted from
## the Build menu (a "palm_tree" building that holds one of these).

const CUT_RANGE := 44.0


func _enter_tree() -> void:
	add_to_group("interactables")


## What the ranger can do with it right now, for the action bar: [{label, do}].
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger is Player or ranger.global_position.distance_to(global_position) > CUT_RANGE:
		return []
	return [{"label": "Cut down palm tree", "do": cut_down}]


func cut_down() -> void:
	var planted := get_parent() as Building
	if planted:
		planted.remove_from_group("buildings")  # gone for saving and overlap checks right away
		planted.queue_free()
	else:
		SaveGame.mark_cut(self)
		queue_free()
