class_name PalmTree
extends StaticBody2D
## A land tree: the Starting Island's palms, the Kelp Forest's coastal trees (a scene each,
## with its own picture and `sapling`). The ranger can cut it down (action bar); new ones are
## planted from the Build menu (a "palm_tree" / "coastal_tree" building that holds one). A planted palm
## grows a stage a day: small -> medium -> full grown; the island's own are full grown.
## A full-grown palm can hold one seabird's nest (shown in its crown): a tree with a nest
## can't be cut down until the ranger moves the nest to another full-grown palm.

const CUT_RANGE := 44.0
const SMALL := 0
const MEDIUM := 1
const GROWN := 2
## How big it's drawn at each stage.
const STAGE_SIZE: Array[float] = [0.4, 0.7, 1.0]
## Where a nest sits in a full-grown palm's crown (a bird perches just above it).
const CROWN := Vector2(2, -42)
const NEST_TEXTURE := preload("res://assets/animals/seabird/tree_nest.svg")

## The seabird nesting in it (null = none).
var nest_of: Node2D:
	set(value):
		nest_of = value
		if _nest:
			_nest.visible = has_nest()
var _nest: Sprite2D

## The sapling it grows from and gives back (each island's land trees have their own).
@export var sapling: ItemData

var _wood: ItemData = load("res://data/items/wood.tres")
@onready var _sapling: ItemData = sapling if sapling else load("res://data/items/sapling.tres")


func _enter_tree() -> void:
	add_to_group("interactables")


func _ready() -> void:
	_nest = Sprite2D.new()
	_nest.name = "Nest"
	_nest.texture = NEST_TEXTURE
	_nest.position = CROWN
	_nest.z_index = 1
	_nest.visible = has_nest()
	add_child(_nest)


func has_nest() -> bool:
	return is_instance_valid(nest_of) and not nest_of.is_queued_for_deletion()


## Where a nesting bird stands.
func perch_point() -> Vector2:
	return global_position + CROWN + Vector2(0, -7)


## The nearest full-grown palm on the same island as `point` without a nest (not `except`), or null.
static func free_grown_near(tree: SceneTree, point: Vector2, except: Node = null) -> PalmTree:
	var region := Regions.nearest(point)
	var best: PalmTree = null
	for palm: Node in tree.get_nodes_in_group("plants"):
		if not palm is PalmTree or palm == except or palm.is_queued_for_deletion():
			continue
		if palm.stage() != GROWN or palm.has_nest() or Regions.nearest(palm.global_position) != region:
			continue
		if not best or palm.global_position.distance_to(point) < best.global_position.distance_to(point):
			best = palm
	return best


## Moves its nest to the nearest other full-grown palm, so this one can be cut down.
func move_nest() -> void:
	if not has_nest():
		return
	var other := free_grown_near(get_tree(), global_position, self)
	if not other:
		get_tree().call_group("hud", "show_toast",
			"There's no other full-grown palm for the nest.\nPlant more palms and let them grow first.")
		return
	var bird := nest_of
	bird.set_nest_tree(other)
	get_tree().call_group("hud", "show_toast",
		"You carefully moved the %s's nest to another palm.\nNow this one can be cut down." % bird.data.display_name)


## What the ranger can do with it right now, for the action bar: [{label, do}].
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger is Player or ranger.global_position.distance_to(global_position) > CUT_RANGE:
		return []
	if stage() == SMALL:
		return [{"label": "Dig up sapling", "do": cut_down}]
	if has_nest():
		return [{"label": "Move the nest", "do": move_nest}]
	if Inventory.room_for(_wood) <= 0:
		return [{"label": "Arms full of wood", "do": get_tree().call_group.bind("hud", "show_toast",
			"You can carry %d wood. Build with it, or store it in your Ranger House." % _wood.carry_limit)}]
	return [{"label": "Cut down tree", "do": cut_down}]


## Small: the sapling back. Medium: 1 wood + 1 sapling. Full grown: 1-2 of each.
func cut_down() -> void:
	if has_nest():
		return  # move the nest first
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
