class_name KelpBed
extends Node2D
## A patch of kelp forest on shallow or mid water (placed by KelpEcosystem). Its `health`
## (0..1) is drawn as how many fronds stand and how green they are; its sea urchins graze
## it and show as purple dots at its foot. Boats pass over it. Close by (on foot or in the
## boat) the ranger can photograph its urchins, or move the bed: it follows the ranger until
## it's put down on the island's open water, away from other beds.

const FRONDS := 7
const BARREN := Color(0.45, 0.4, 0.32)
const HEALTHY := Color(0.36, 0.7, 0.3)
const URCHIN := Color(0.5, 0.25, 0.62)
## At most this many urchins are drawn (the rest are counted, not shown).
const URCHIN_DOTS := 12

## 0 = bare (an "urchin barren"), 1 = dense forest.
var health := 0.5:
	set(value):
		health = clampf(value, 0.0, 1.0)
		queue_redraw()
## Sea urchins here (a float so grazing and eating change it gradually; shown rounded).
var urchins := 0.0:
	set(value):
		urchins = maxf(value, 0.0)
		queue_redraw()
## Kelp restoration planted here: extra regrowth until then (GameClock.now()).
var restored_until := -1.0
## Its health yesterday morning (to tell recovering beds from declining ones).
var health_yesterday := -1.0
## How much this bed suits urchins compared with the island's average (0.7..1.3).
var urchin_share := 1.0
## Damaged by heavy swell and not yet recovered.
var storm_hit := false
var _sway := randf() * TAU
## Being moved: it follows the ranger until put down.
var carried := false
## Day the ranger last photographed urchins here (one photo a day).
static var _urchin_photo_day := -1
const REACH := 70.0
## Kept this far from other beds when put down.
const SPACING := 64.0


func _enter_tree() -> void:
	add_to_group("kelp_beds")
	add_to_group("interactables")


func _ready() -> void:
	z_index = -1  # under boats, animals and the ranger; over the sea floor


func urchin_count() -> int:
	return roundi(urchins)


## How hard urchins are grazing here, 0 (none) .. 1 (overgrazed).
func pressure(overgrazed_at: float) -> float:
	return clampf(urchins / overgrazed_at, 0.0, 1.0)


## For the action bar: photograph its urchins, move it, or put it down.
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return []
	if carried:
		var problem := place_problem(ranger.global_position)
		return [{"label": "Put kelp bed down here" if problem == "" else problem, "do": put_down}]
	if ranger.global_position.distance_to(global_position) > REACH:
		return []
	var list := []
	if urchin_count() > 0 and _urchin_photo_day != GameClock.day:
		list.append({"label": "Photo: sea urchins", "do": photograph_urchins})
	if not get_tree().get_nodes_in_group("kelp_beds").any(func(b: Node) -> bool: return b.carried):
		list.append({"label": "Move kelp bed", "do": pick_up})
	return list


func photograph_urchins() -> void:
	_urchin_photo_day = GameClock.day
	var urchin: AnimalData = load("res://data/animals/sea_urchin.tres")
	Journal.discover(urchin)
	Journal.photograph(urchin)


func pick_up() -> void:
	carried = true


## Why it can't be put down at `point` ("" = it can): on this island's open water (shallow or
## mid, not land), and not on top of another bed.
func place_problem(point: Vector2) -> String:
	if not _island_water(point):
		return "Kelp needs the island's shallow water"
	if Regions.nearest(point) != Regions.nearest(global_position):
		return "Kelp stays on its own island"
	for other: Node2D in get_tree().get_nodes_in_group("kelp_beds"):
		if other != self and other.global_position.distance_to(point) < SPACING:
			return "Too close to other kelp"
	return ""


## A shallow or mid water tile of an island (kelp can't root in the deep open ocean).
func _island_water(point: Vector2) -> bool:
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		var tile := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(point)))
		if tile:
			return not tile.get_custom_data("walkable") and tile.get_custom_data("terrain") in ["water", ""]
	return false


func put_down() -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or place_problem(ranger.global_position) != "":
		return
	carried = false
	global_position = ranger.global_position


func _process(delta: float) -> void:
	if carried:
		var ranger := ControlledBody.active(get_tree())
		if ranger:
			global_position = ranger.global_position + Vector2(0, 22)  # towed along just behind
	_sway += delta
	if int(_sway * 4.0) != int((_sway - delta) * 4.0):
		queue_redraw()  # a gentle sway, a few times a second


func _draw() -> void:
	var colour := BARREN.lerp(HEALTHY, health)
	draw_circle(Vector2.ZERO, 14.0, Color(colour, 0.25))
	var standing := roundi(health * FRONDS)
	for i in FRONDS:
		var base := Vector2((i - FRONDS / 2.0) * 4.0 + 2.0, 6.0 - float(i % 3) * 3.0)
		if i >= standing:
			draw_rect(Rect2(base + Vector2(-1, -2), Vector2(2, 2)), Color(BARREN, 0.8))  # a stump
			continue
		var height := 14.0 + float((i * 7) % 5) * 2.0
		var lean := roundf(sin(_sway * 1.5 + i) * 1.5)
		draw_line(base, base + Vector2(lean, -height), colour, 2.0)
		draw_rect(Rect2(base + Vector2(lean - 2, -height * 0.6), Vector2(3, 2)), colour.lightened(0.15))
	for i in mini(urchin_count(), URCHIN_DOTS):
		var spot := Vector2(float((i * 5) % 11) * 2.2 - 11.0, 7.0 + float((i * 3) % 4))
		draw_rect(Rect2(spot, Vector2(2, 2)), URCHIN)
