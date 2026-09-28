extends StaticBody2D
## A palm tree. The ranger can cut it down (action bar); new ones are planted from
## the Build menu (a "palm_tree" building that holds one of these). A planted palm
## grows a stage a day: small -> medium -> full grown; the island's own are full grown.

const CUT_RANGE := 44.0
const SMALL := 0
const MEDIUM := 1
const GROWN := 2
## How big it's drawn at each stage.
const STAGE_SIZE: Array[float] = [0.4, 0.7, 1.0]

var _wood: ItemData = load("res://data/items/wood.tres")
var _sapling: ItemData = load("res://data/items/sapling.tres")


func _enter_tree() -> void:
	add_to_group("interactables")


## What the ranger can do with it right now, for the action bar: [{label, do}].
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger is Player or ranger.global_position.distance_to(global_position) > CUT_RANGE:
		return []
	if stage() == SMALL:
		return [{"label": "Dig up sapling", "do": cut_down}]
	if Inventory.room_for(_wood) <= 0:
		return [{"label": "Arms full of wood", "do": get_tree().call_group.bind("hud", "show_toast",
			"You can carry %d wood. Build with it, or store it in your Ranger House." % _wood.carry_limit)}]
	return [{"label": "Cut down palm tree", "do": cut_down}]


## Small: the sapling back. Medium: 1 wood + 1 sapling. Full grown: 1-2 of each.
func cut_down() -> void:
	match stage():
		SMALL:
			Inventory.add(_sapling, 1)
		MEDIUM:
			Inventory.add(_wood, 1)
			Inventory.add(_sapling, 1)
		GROWN:
			Inventory.add(_wood, randi_range(1, 2))
			Inventory.add(_sapling, randi_range(1, 2))
	var planted := get_parent() as Building
	if planted:
		planted.remove_from_group("buildings")  # gone for saving and overlap checks right away
		planted.queue_free()
	else:
		SaveGame.mark_cut(self)
		queue_free()


func stage() -> int:
	var planted := get_parent() as Building
	return clampi(GameClock.day - planted.built_day, SMALL, GROWN) if planted else GROWN


func _process(_delta: float) -> void:
	$Sprite2D.scale = Vector2.ONE * STAGE_SIZE[stage()]
