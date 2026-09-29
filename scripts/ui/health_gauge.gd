class_name HealthGauge
extends Control
## The island the ranger is on: its health now, and where it's heading if everything is
## left as it is (IslandHealth.heading), on a bar from red (struggling) to green (healthy).
## A white line marks now; a hollow marker, where it's going. Over the 3-4 days a change takes
## to settle, the "now" line moves up (or down) to the marker.

const BAR := Vector2(220, 12)
const REFRESH := 1.0

var now := -1.0
var heading := -1.0
var island := ""
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


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	var ranger := ControlledBody.active(get_tree())
	var region := Regions.nearest(ranger.global_position if ranger else Vector2.ZERO)
	now = IslandHealth.of(get_tree(), region)
	visible = now >= 0.0
	if not visible:
		return
	heading = IslandHealth.heading(get_tree(), region)
	island = region.display_name
	var arrow := "steady" if absf(heading - now) < 0.02 else ("heading up to %d%%" % roundi(heading * 100.0) if heading > now
		else "heading down to %d%%" % roundi(heading * 100.0))
	_label.text = "%s: %d%%, %s" % [island, roundi(now * 100.0), arrow]
	queue_redraw()


## Red to yellow to green along the bar.
static func colour_at(t: float) -> Color:
	if t < 0.5:
		return Color("d9534f").lerp(Color("f2c94c"), t * 2.0)
	return Color("f2c94c").lerp(Color("58b85c"), (t - 0.5) * 2.0)


func _draw() -> void:
	if now < 0.0:
		return
	draw_rect(Rect2(Vector2(-2, -2), BAR + Vector2(4, 4)), Color(0, 0, 0, 0.55))
	var steps := 22
	for i in steps:
		var t := float(i) / steps
		draw_rect(Rect2(Vector2(BAR.x * t, 0), Vector2(BAR.x / steps + 1.0, BAR.y)), colour_at(t + 0.5 / steps))
	# Where it's heading: a hollow marker; now: a solid white line.
	var target_x := BAR.x * clampf(heading, 0.0, 1.0)
	draw_rect(Rect2(Vector2(target_x - 3, -4), Vector2(6, BAR.y + 8)), Color.WHITE, false, 2.0)
	var now_x := BAR.x * clampf(now, 0.0, 1.0)
	draw_rect(Rect2(Vector2(now_x - 1, -3), Vector2(3, BAR.y + 6)), Color.WHITE)
	draw_rect(Rect2(Vector2(now_x - 1, -3), Vector2(3, BAR.y + 6)), Color.BLACK, false, 1.0)
