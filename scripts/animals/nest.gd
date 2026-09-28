class_name Nest
extends Node2D
## Eggs buried in a protected beach. Once incubated they hatch at night and the
## hatchlings crawl to the sea. They join its protection area if there's room
## (BuildingData.animal_capacity), otherwise the nearest other protection area with
## room; only when every area is full do they swim off into the open ocean. Every
## hatchling counts in the Journal either way.

# ponytail: all species share one animal scene; give AnimalData a scene when one needs its own.
const ANIMAL_SCENE := "res://scenes/animals/animal.tscn"

## The progress bar shows when the ranger is this close (standing in the protection area).
const SHOW_RANGE := 72.0

@export var species: AnimalData
## GameClock.now() when it was laid.
@export var laid_at := 0.0
## The protection area it's in (found automatically if not set).
var area: Node2D

var _bar: ProgressBar
var _caption: Label


func _enter_tree() -> void:
	add_to_group("nests")


func _ready() -> void:
	if not area:
		area = _nearest_area()
	# Built at 2x size and halved, so text is pixel-crisp under the 2x camera.
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.size = Vector2(320, 24)
	_caption.scale = Vector2(0.5, 0.5)
	_caption.position = Vector2(-80, -44)
	_caption.z_index = 100
	add_child(_caption)
	_bar = ProgressBar.new()
	_bar.size = Vector2(120, 24)
	_bar.scale = Vector2(0.5, 0.5)
	_bar.position = Vector2(-30, -30)
	_bar.z_index = 100
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part in ["background", "fill"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(6)
		box.bg_color = Color(0.1, 0.12, 0.16, 0.85) if part == "background" else Color("58b85c")
		_bar.add_theme_stylebox_override(part, box)
	add_child(_bar)


## How far along the eggs are, 0.0 (just laid) to 1.0 (ready to hatch at night).
func progress() -> float:
	return clampf((GameClock.now() - laid_at) / species.incubation_days, 0.0, 1.0)


func _process(_delta: float) -> void:
	if GameClock.is_night() and progress() >= 1.0:
		hatch()
		return
	var ranger := ControlledBody.active(get_tree())
	var near := ranger is Player and ranger.global_position.distance_to(global_position) <= SHOW_RANGE
	_bar.visible = near
	_caption.visible = near
	if near:
		_bar.value = progress() * 100.0
		_caption.text = "Ready! They'll hatch tonight" if progress() >= 1.0 else "Turtle eggs"


func hatch() -> void:
	if is_queued_for_deletion():
		return  # already hatched this frame
	var world := get_parent()
	for i in species.hatchlings:
		var home := _area_with_room()
		var baby: Node2D = load(ANIMAL_SCENE).instantiate()
		baby.set("data", species)
		baby.set("young", true)
		baby.set("leaving", home == null)
		baby.set("home_area", home)  # set before joining the world, so it counts straight away
		baby.position = position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		world.add_child(baby)
		baby.call("crawl_to_sea")
	Journal.record_hatch(species, species.hatchlings)
	queue_free()


## This nest's own area if it has room, else the nearest other one that does, else null.
func _area_with_room() -> Node2D:
	if area and area.room_for_animals() > 0:
		return area
	var best: Node2D = null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == species.nest_building and building.room_for_animals() > 0 and (not best
				or building.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = building
	return best


func _nearest_area() -> Node2D:
	var best: Node2D = null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == species.nest_building and (not best
				or building.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = building
	return best
