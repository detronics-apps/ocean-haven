class_name Nest
extends Node2D
## Eggs buried in a protected beach. Once incubated they hatch at night and the
## hatchlings crawl to the sea, where they grow up (AnimalData.grow_days). They join its protection area if there's room
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
## Turtle monitoring protects it until then (GameClock.now()): a storm can't touch it.
@export var protected_until := -1.0
## A storm washed over it while it wasn't protected: only one egg still hatches.
@export var storm_hit := false
## The protection area it's in (found automatically if not set).
var area: Node2D

var _bar: ProgressBar
var _caption: Label
## Where the turtle came up from the sea (her tracks lead there; shown once the ranger has
## learned to look for them: Fleet flag "tracks_noticed", from Tom's story).
var _sea_at := Vector2.INF
var _tracks: Node2D
const TRACKS_FLAG := &"tracks_noticed"
const TRACKS_SEEN := &"tracks_seen"


func _enter_tree() -> void:
	add_to_group("nests")


func _ready() -> void:
	if not area:
		area = _nearest_area()
	_sea_at = Terrain.nearest(get_tree(), global_position, ["water", ""], 8)
	if _sea_at == global_position:
		_sea_at = Vector2.INF
	_tracks = Node2D.new()
	_tracks.name = "Tracks"
	_tracks.z_index = -1  # in the sand, under everything standing on it
	_tracks.draw.connect(_draw_tracks)
	add_child(_tracks)
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


func is_protected() -> bool:
	return protected_until > GameClock.now()


## A storm strikes: an unprotected nest is washed over (one egg still hatches). Returns
## whether it was hit.
func storm() -> bool:
	if is_protected() or storm_hit:
		return false
	storm_hit = true
	return true


## How far along the eggs are, 0.0 (just laid) to 1.0 (ready to hatch at night).
func progress() -> float:
	return clampf((GameClock.now() - laid_at) / species.incubation_days, 0.0, 1.0)


func _process(_delta: float) -> void:
	if GameClock.is_night() and progress() >= 1.0:
		hatch()
		return
	var ranger := ControlledBody.active(get_tree())
	var near := ranger is Player and ranger.global_position.distance_to(global_position) <= SHOW_RANGE
	if Fleet.has_flag(TRACKS_FLAG) and _sea_at != Vector2.INF:
		_tracks.queue_redraw()
		if near and not Fleet.has_flag(TRACKS_SEEN):
			Fleet.mark(TRACKS_SEEN)
			get_tree().call_group("hud", "show_toast", "Turtle tracks! A turtle crawled up from the sea in the night to lay her eggs here, just as Tom said.")
	_bar.visible = near
	_caption.visible = near
	if near:
		_bar.value = progress() * 100.0
		_caption.text = "Ready! They'll hatch tonight" if progress() >= 1.0 else "Turtle eggs"
		if is_protected():
			_caption.text += " (protected)"
		elif storm_hit:
			_caption.text += " (storm-hit: 1 egg left)"


## The mother turtle's tracks: two rows of flipper marks from the sea up to the nest.
func _draw_tracks() -> void:
	if not Fleet.has_flag(TRACKS_FLAG) or _sea_at == Vector2.INF:
		return
	var to := to_local(_sea_at)
	var length := to.length()
	if length < 8.0:
		return
	var along := to / length
	var side := Vector2(-along.y, along.x)
	var mark := Color(0.45, 0.36, 0.25, 0.35)
	var step := 5.0
	var d := 6.0
	var i := 0
	while d < length - 4.0:
		var at := along * d
		var offset := side * (4.0 if i % 2 == 0 else -4.0)
		_tracks.draw_line((at + offset - side * 1.5).round(), (at + offset + side * 1.5).round(), mark, 1.0)
		d += step
		i += 1


func hatch() -> void:
	if is_queued_for_deletion():
		return  # already hatched this frame
	var world := get_parent()
	# Enough hatch to fill the room the island has for them (at least `hatchlings`); those
	# stay, the rest swim off into the open ocean, as most real hatchlings do. A storm-hit
	# nest's one hatchling is swept out too.
	var count := 1 if storm_hit else clampi(island_room(self, species), species.hatchlings, MAX_HATCHLINGS)
	for i in count:
		var stays := not storm_hit and (species.stay_per_nest <= 0 or i < species.stay_per_nest)
		var home := _area_with_room() if stays else null
		var baby: Node2D = load(ANIMAL_SCENE).instantiate()
		baby.set("data", species)
		baby.set("young", true)
		baby.set("born_at", GameClock.now())
		baby.set("leaving", home == null)
		baby.set("home_area", home)  # set before joining the world, so it counts straight away
		baby.position = position + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		world.add_child(baby)
		baby.call("crawl_to_sea")
	Journal.record_hatch(species, count)
	queue_free()


## Most hatchlings one nest can have (when the island has a lot of room for them).
const MAX_HATCHLINGS := 12


## How many more of `species` the nesting areas on `at`'s island can take.
static func island_room(at: Node2D, species: AnimalData) -> int:
	var island := Regions.nearest(at.global_position)
	var room := 0
	for building: Building in at.get_tree().get_nodes_in_group("buildings"):
		if building.data.id == species.nest_building and Regions.nearest(building.global_position) == island:
			room += building.room_for_animals()
	return room


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
