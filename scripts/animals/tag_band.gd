class_name TagBand
extends Node2D
## The bright tag on a rescued animal (a flipper tag, a leg band): easy to spot from the boat,
## so the ranger knows it's one of theirs wherever it turns up.

const COLOUR := Color("ff7a1a")
const EDGE := Color(0.1, 0.1, 0.1, 0.9)


func _ready() -> void:
	z_index = 1
	position = Vector2(-4, 4)


func _draw() -> void:
	draw_rect(Rect2(-3, -2, 6, 4), EDGE)
	draw_rect(Rect2(-2, -1, 4, 2), COLOUR)
