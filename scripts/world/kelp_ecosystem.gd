class_name KelpEcosystem
extends Node2D
## The Kelp Forest's food web (MASTER_PLAN "Kelp Forest"): kelp beds on the island's shallow
## and mid water, each with its sea urchins. Every `tick_days` (real elapsed game time, so
## sleeping catches up) urchins graze and multiply, and kelp regrows where grazing is low.
## Kelp is never fixed by planting alone: while urchins are too many, it keeps declining.
## Runs once the island is discovered. Saved by SaveGame (to_dict / restore).

const BED_SCRIPT := preload("res://scripts/world/kelp_bed.gd")
const URCHIN := preload("res://data/animals/sea_urchin.tres")
## The ranger finds the urchins this close to a bed that has some.
const SPOT_RANGE := 72.0

## The region this island belongs to (by id), for health, reach and discovery.
@export var region_id: StringName = &"kelp_forest"
@export var tick_days := 0.25
@export_group("Beds")
## How many beds, and at least how far apart (px).
@export var bed_count := 18
@export var bed_spacing := 96.0
## A new island starts damaged: kelp health and urchins per bed (random in these ranges).
@export var start_health := Vector2(0.15, 0.4)
@export var start_urchins := Vector2(6.0, 10.0)
@export_group("Food web (per bed, per day)")
## Urchins multiply towards urchin_cap, faster where there's kelp to eat.
@export var urchin_growth := 0.5
@export var urchin_cap := 12.0
## Kelp eaten per urchin.
@export var graze := 0.02
## Kelp regrowth towards full (restoration adds `restore_boost`).
@export var regrow := 0.15
@export var restore_boost := 0.25
## Urchins drift in from nearby reefs now and then, so there are always a few.
@export var urchin_drift_in := 0.3
## A bed counts as overgrazed at this many urchins.
@export var overgrazed_at := 8.0

var _last_tick := -1.0


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_place_beds()


func region() -> RegionData:
	return load("res://data/regions/%s.tres" % region_id)


func beds() -> Array[KelpBed]:
	var list: Array[KelpBed] = []
	for child in get_children():
		if child is KelpBed:
			list.append(child)
	return list


## Kelp beds on the island's own water tiles (shallow and mid, not the open ocean),
## spread out, the same every time (so saved beds line up).
func _place_beds() -> void:
	var ground := get_parent().get_node_or_null("Ground") as TileMapLayer
	if not ground:
		return
	var cells: Array[Vector2i] = []
	for cell in ground.get_used_cells():
		var data := ground.get_cell_tile_data(cell)
		if data and not data.get_custom_data("walkable") and data.get_custom_data("terrain") in ["water", ""]:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _noise(a) < _noise(b))
	var spots: Array[Vector2] = []
	for cell in cells:
		if spots.size() >= bed_count:
			break
		var spot := ground.map_to_local(cell) + ground.position - position
		if spots.all(func(s: Vector2) -> bool: return s.distance_to(spot) >= bed_spacing):
			spots.append(spot)
	for i in spots.size():
		var bed: KelpBed = BED_SCRIPT.new()
		bed.name = "Kelp%d" % (i + 1)
		bed.position = spots[i]
		bed.health = lerpf(start_health.x, start_health.y, _noise(Vector2i(i, 7)))
		bed.urchins = roundf(lerpf(start_urchins.x, start_urchins.y, _noise(Vector2i(i, 13))))
		add_child(bed)


static func _noise(c: Vector2i) -> float:
	return fposmod(sin(c.x * 12.9898 + c.y * 78.233) * 43758.5453, 1.0)


func _process(_delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	_spot_urchins()
	var now := GameClock.now()
	if _last_tick < 0.0:
		_last_tick = now
	# Catch up on time that passed (sleeping), but not forever.
	var ticks := 0
	while now - _last_tick >= tick_days and ticks < 32:
		tick(tick_days)
		_last_tick += tick_days
		ticks += 1
	if now - _last_tick >= tick_days:
		_last_tick = now


## Close to a bed with urchins: they're in the Journal.
func _spot_urchins() -> void:
	if Journal.has(URCHIN.id):
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	for bed in beds():
		if bed.urchin_count() > 0 and bed.global_position.distance_to(ranger.global_position) <= SPOT_RANGE:
			Journal.discover(URCHIN)
			return


## One step of the food web, `days` long.
func tick(days: float) -> void:
	for bed in beds():
		var restoring := 1.0 if bed.restored_until > GameClock.now() else 0.0
		var food := 0.3 + 0.7 * bed.health
		var growth := urchin_growth * bed.urchins * (1.0 - bed.urchins / urchin_cap) * food
		bed.urchins += (growth + urchin_drift_in * (1.0 if bed.urchins < 1.0 else 0.0)) * days
		var eaten := graze * bed.urchins
		var grown := (regrow + restore_boost * restoring) * (1.0 - bed.health)
		bed.health += (grown - eaten) * days


## Everything about the forest, 0..1 on average (the kelp's condition).
func kelp_health() -> float:
	var list := beds()
	if list.is_empty():
		return 0.0
	return list.reduce(func(sum: float, b: KelpBed) -> float: return sum + b.health, 0.0) / list.size()


func urchin_total() -> int:
	return beds().reduce(func(sum: int, b: KelpBed) -> int: return sum + b.urchin_count(), 0)


## For the save file: each bed's health and urchins, by name.
func to_dict() -> Dictionary:
	var saved := {"last_tick": _last_tick, "beds": {}}
	for bed in beds():
		saved.beds[String(bed.name)] = [bed.health, bed.urchins, bed.restored_until]
	return saved


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	var saved_beds: Dictionary = saved.get("beds", {})
	for bed in beds():
		var entry: Array = saved_beds.get(String(bed.name), [])
		if entry.size() >= 3:
			bed.health = float(entry[0])
			bed.urchins = float(entry[1])
			bed.restored_until = float(entry[2])
