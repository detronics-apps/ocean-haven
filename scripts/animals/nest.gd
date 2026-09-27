class_name Nest
extends Node2D
## Eggs buried in a protected beach. Once incubated they hatch at night and the
## hatchlings crawl to the sea. As many stay as the protected areas have room for
## (BuildingData.animal_capacity); the rest swim off into the open ocean. Every
## hatchling counts in the Journal either way.

# ponytail: all species share one animal scene; give AnimalData a scene when one needs its own.
const ANIMAL_SCENE := "res://scenes/animals/animal.tscn"

## The progress bar shows when the ranger is this close (standing in the protection area).
const SHOW_RANGE := 72.0

@export var species: AnimalData
## GameClock.now() when it was laid.
@export var laid_at := 0.0

var _bar: ProgressBar
var _caption: Label


func _enter_tree() -> void:
	add_to_group("nests")


func _ready() -> void:
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
	var room := capacity(get_tree(), species) - population(get_tree(), species)
	var world := get_parent()
	for i in species.hatchlings:
		var baby: Node2D = load(ANIMAL_SCENE).instantiate()
		baby.set("data", species)
		baby.set("young", true)
		baby.set("leaving", i >= room)
		baby.position = position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		world.add_child(baby)
		baby.call("crawl_to_sea")
	Journal.record_hatch(species, species.hatchlings)
	queue_free()


## How many of `species` the protected areas it nests in can hold.
static func capacity(tree: SceneTree, species: AnimalData) -> int:
	var total := 0
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.id == species.nest_building:
			total += building.data.animal_capacity
	return total


## How many of `species` live here now (not counting ones heading out to sea).
static func population(tree: SceneTree, species: AnimalData) -> int:
	return tree.get_nodes_in_group("animals").filter(
		func(a: Node) -> bool: return a.get("data") == species and not a.get("leaving")).size()
