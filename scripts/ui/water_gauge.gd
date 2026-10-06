class_name WaterGauge
extends Control
## The clean water stored at home (ControlledBody.water_bottles), a blue bar under the island's
## health bar. It shows once the ranger can make clean water (the Tropical Reef's Marine Water
## Treatment Facility); storing bottles at the tent or house fills it, and it uses 2 a day.

const BAR := Vector2(220, 8)
const REFRESH := 0.5
const UNLOCK := &"clean_water_made"

var level := 0.0
var _wait := 0.0
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(BAR.x, BAR.y + 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.position = Vector2(0, BAR.y + 2)
	_label.size = Vector2(BAR.x, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	level = ControlledBody.water_level(get_tree())
	var bottles := ControlledBody.water_bottles(get_tree())
	visible = Fleet.has_flag(UNLOCK) or bottles > 0
	_label.text = ("Water at home: %d bottle%s (faster)" % [bottles, "" if bottles == 1 else "s"]) if bottles > 0 \
		else "Water: store clean water at your tent or house"
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2, -2), BAR + Vector2(4, 4)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(Vector2.ZERO, BAR), Color(0.16, 0.24, 0.34))
	draw_rect(Rect2(Vector2.ZERO, Vector2(BAR.x * level, BAR.y)), Color("4fb3ff"))
