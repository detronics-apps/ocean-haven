extends StaticBody2D
## A palm tree. The ranger can cut it down (action bar); new ones are planted from
## the Build menu (a "palm_tree" building that holds one of these).

const CUT_RANGE := 44.0

var _wood: ItemData = load("res://data/items/wood.tres")
var _sapling: ItemData = load("res://data/items/sapling.tres")


func _enter_tree() -> void:
	add_to_group("interactables")


## What the ranger can do with it right now, for the action bar: [{label, do}].
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger is Player or ranger.global_position.distance_to(global_position) > CUT_RANGE:
		return []
	if Inventory.room_for(_wood) <= 0:
		return [{"label": "Arms full of wood", "do": get_tree().call_group.bind("hud", "show_toast",
			"You can carry %d wood. Build with it, or store it in your Ranger House." % _wood.carry_limit)}]
	return [{"label": "Cut down palm tree", "do": cut_down}]


## Gives 1 wood and 1-2 saplings to plant elsewhere.
func cut_down() -> void:
	Inventory.add(_wood, 1)
	Inventory.add(_sapling, randi_range(1, 2))
	var planted := get_parent() as Building
	if planted:
		planted.remove_from_group("buildings")  # gone for saving and overlap checks right away
		planted.queue_free()
	else:
		SaveGame.mark_cut(self)
		queue_free()
