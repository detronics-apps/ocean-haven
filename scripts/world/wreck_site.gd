class_name WreckSite
extends Node2D
## An old shipwreck on the sea floor with litter caught all around it (the Starting Island's
## discovery). Hidden until a coastal survey finds it (Missions calls reveal()); then its
## litter can be cleared from the boat, and once it's all gone the old sonar unit can be
## recovered (marks "sonar_recovered"). Its pieces are named, so collected ones stay gone.

const DEBRIS_SCENE := preload("res://scenes/world/debris.tscn")
const WRECK_TEXTURE := preload("res://assets/effects/wreck/wreck.svg")

## Litter caught around the wreck (one piece each).
@export var pieces: Array[ItemData] = []
## How far round the wreck its litter lies.
@export var spread := 96.0
## Recovered once all its litter is cleared.
@export var treasure: ItemData
## Progress flags: found (by the survey) and cleared.
@export var found_flag := &"wreck_found"
@export var cleared_flag := &"wreck_cleared"

var _sprite: Sprite2D
var _treasure: Debris


func _enter_tree() -> void:
	add_to_group("wreck_sites")


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = WRECK_TEXTURE
	_sprite.z_index = -1  # under the water's surface things
	add_child(_sprite)
	for i in pieces.size():
		var piece: Debris = DEBRIS_SCENE.instantiate()
		piece.name = "Sunken%d" % (i + 1)
		piece.item = pieces[i]
		piece.position = Vector2.from_angle(TAU * i / pieces.size()) * spread * (0.6 + 0.4 * float(i % 2))
		add_child(piece)
	if treasure:
		_treasure = DEBRIS_SCENE.instantiate()
		_treasure.name = "Treasure"
		_treasure.item = treasure
		add_child(_treasure)
	_show(false)


## Found by a survey: it and its litter appear.
func reveal() -> void:
	Fleet.mark(found_flag)


func is_revealed() -> bool:
	return Fleet.has_flag(found_flag)


## Litter still caught round it.
func litter_left() -> int:
	return get_children().filter(func(n: Node) -> bool:
		return n is Debris and n != _treasure and not n.is_queued_for_deletion()).size()


func _process(_delta: float) -> void:
	# Follows the flags (also after loading a save): hidden, then its litter, then the treasure.
	var revealed := is_revealed()
	if revealed != _sprite.visible:
		_show(revealed)
	if revealed and litter_left() == 0 and not Fleet.has_flag(cleared_flag):
		Fleet.mark(cleared_flag)
		get_tree().call_group("hud", "show_toast", "Wreck cleared")
	if _treasure and is_instance_valid(_treasure):
		_set_active(_treasure, revealed and Fleet.has_flag(cleared_flag))


func _show(revealed: bool) -> void:
	_sprite.visible = revealed
	for child in get_children():
		if child is Debris and child != _treasure:
			_set_active(child, revealed)


## Hidden pieces aren't litter yet: not seen, not collected, not counted.
func _set_active(piece: Debris, active: bool) -> void:
	if piece.is_queued_for_deletion() or piece.visible == active:
		return
	piece.visible = active
	piece.set_deferred("monitoring", active)
	if active:
		piece.add_to_group("debris")
	else:
		piece.remove_from_group("debris")
