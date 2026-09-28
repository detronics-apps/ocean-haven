extends Node
## Autoload "RareEvents": each morning, an island's rare event (EventData) may be warned about
## (not within min_gap_days of the last one); a warning_days later it strikes. The ranger
## prepares by securing buildings (Building.secured); afterwards they repair what was damaged
## and clean up the litter. Nothing is ever "failed": it's always recoverable.

signal warned(event: EventData)
signal struck(event: EventData, damaged: int)

## Event id -> day it last struck (none yet: day 0, so the first comes after min_gap_days).
var _last_day := {}
## Warned events waiting to strike: event id -> day they strike.
var _coming := {}


func _ready() -> void:
	GameClock.new_day.connect(_on_new_day)


static func all() -> Array[EventData]:
	var list: Array[EventData] = []
	for event: EventData in DataFiles.load_all("res://data/events"):
		list.append(event)
	return list


func _on_new_day(day: int) -> void:
	for event: EventData in all():
		if _coming.has(event.id):
			if day >= _coming[event.id]:
				strike(event)
		elif day - _last_day.get(event.id, 0) >= event.min_gap_days and randf() < event.chance_per_day:
			warn(event)


## Warns that `event` is coming (it strikes warning_days later).
func warn(event: EventData) -> void:
	_coming[event.id] = GameClock.day + event.warning_days
	warned.emit(event)


## What's coming, for the HUD ("" = nothing).
func warning_text() -> String:
	for event: EventData in all():
		if _coming.has(event.id):
			return event.banner
	return ""


func is_coming() -> bool:
	return not _coming.is_empty()


## It strikes now: unsecured buildings on its island may be damaged, litter washes up, and
## secured buildings are unsecured again. Returns how many were damaged.
func strike(event: EventData) -> int:
	_coming.erase(event.id)
	_last_day[event.id] = GameClock.day
	var damaged := 0
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if Regions.nearest(building.global_position).id != event.region:
			continue
		if not building.secured and not building.data.storm_proof and not building.damaged \
				and randf() < event.damage_chance:
			building.damaged = true
			damaged += 1
		building.secured = false
	for spawner: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(spawner.area.get_center()).id == event.region:
			spawner.wash_up_beaches(event.litter_washed)
	struck.emit(event, damaged)
	return damaged


## The event whose repairs `building` needs (for its repair cost).
static func for_region(region_id: StringName) -> EventData:
	for event: EventData in all():
		if event.region == region_id:
			return event
	return null


## For the save file.
func to_dict() -> Dictionary:
	return {"last_day": _last_day.duplicate(), "coming": _coming.duplicate()}


func restore(saved: Dictionary) -> void:
	_last_day.clear()
	_coming.clear()
	var last: Dictionary = saved.get("last_day", {})
	for id in last:
		_last_day[StringName(id)] = int(last[id])
	var coming: Dictionary = saved.get("coming", {})
	for id in coming:
		_coming[StringName(id)] = int(coming[id])
