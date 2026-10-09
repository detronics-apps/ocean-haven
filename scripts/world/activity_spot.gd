class_name ActivitySpot
extends Node2D
## A ranger activity's own place in the world (ActivityData.spot: e.g. the old jetty Finn dives
## from), there from the start; it opens once the activity is (a person introduces it), and
## explains itself until then. Nothing can be built over it.

## How close the ranger must be.
const RANGE := 64.0

@export var activity: ActivityData

var _place: Sprite2D
var _news: Label
var _check := 0.0


func _enter_tree() -> void:
	add_to_group("interactables")
	add_to_group("occupies")


func _ready() -> void:
	name = "Spot_%s" % activity.id
	position = activity.spot
	if activity.place:
		_place = Sprite2D.new()
		_place.texture = activity.place
		_place.centered = false
		_place.position = activity.place_offset
		_place.z_index = -1
		add_child(_place)
	_news = Label.new()
	_news.text = "!"
	_news.add_theme_font_size_override("font_size", 28)
	_news.add_theme_constant_override("outline_size", 8)
	_news.add_theme_color_override("font_color", Color("f6d36b"))
	_news.add_theme_color_override("font_outline_color", Color.BLACK)
	_news.scale = Vector2(0.5, 0.5)
	_news.position = Vector2(-4, -30)
	_news.z_index = 100
	add_child(_news)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	_news.visible = Activities.is_open(activity) and not Activities.story_done(activity)


func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > RANGE:
		return []
	if Activities.is_open(activity):
		return [{"label": activity.verb, "helps": not Activities.story_done(activity),
			"do": get_tree().call_group.bind("activity_" + activity.id, "open_activity", activity)}]
	return []


## What it says while it's closed (the line above the buttons).
func info_line() -> String:
	var ranger := ControlledBody.active(get_tree())
	if Activities.is_open(activity) or not ranger or ranger.global_position.distance_to(global_position) > RANGE:
		return ""
	return activity.closed_note.get_slice("\n", 0).get_slice(". ", 0).left(70)


## What's in the way when building here.
func blocker_name() -> String:
	return "The %s" % activity.place_name


## The tiles it takes up.
func cells() -> Array[Vector2i]:
	var list: Array[Vector2i] = [Terrain.cell_of(global_position)]
	if _place:
		var size := _place.texture.get_size()
		for x in range(int(_place.global_position.x + 4.0), int(_place.global_position.x + size.x - 3.0), Terrain.TILE / 2):
			var cell := Terrain.cell_of(Vector2(x, _place.global_position.y + size.y * 0.5))
			if cell not in list:
				list.append(cell)
	return list
