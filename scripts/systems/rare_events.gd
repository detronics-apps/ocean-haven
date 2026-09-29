extends Node
## Autoload "RareEvents": each morning, an island's rare event (EventData) may be warned about
## (not within min_gap_days of the last one); a warning_days later it strikes. The ranger
## prepares by securing buildings (Building.secured); afterwards they repair what was damaged
## and clean up the litter. A storm may also hurt a few animals (never badly: a Rescue
## mission helps them recover) and wash over nests turtle monitoring didn't protect.
## Nothing is ever "failed": it's always recoverable.

signal warned(event: EventData)
signal struck(event: EventData, damaged: int)

## Event id -> day it last struck (none yet: day 0, so the first comes after min_gap_days).
var _last_day := {}
## Warned events waiting to strike: event id -> day they strike.
var _coming := {}
## Region id -> GameClock.now() until which visibility underwater is poor (missions slower).
var _murky := {}
## Nothing strikes an island the ranger isn't on, nor in their first `calm_days` back on it
## (the time between events keeps counting while they're away, so one can come soon after).
@export var calm_days := 2
## Region id -> day the ranger last came back to it.
var _back_on := {}
## The island the ranger is on (&"?" = not checked yet: loading isn't coming back).
var _current: StringName = &"?"
var _check := 0.0


func _ready() -> void:
	GameClock.new_day.connect(_on_new_day)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position).id
	if here != _current and _current != &"?":
		_back_on[here] = GameClock.day  # back on this island: calm for a couple of days
	_current = here


## Whether `event` may strike on `day`: the ranger is on its island and has been for calm_days.
func _can_strike(event: EventData, day: int) -> bool:
	return Regions.ranger_on(get_tree(), load("res://data/regions/%s.tres" % event.region)) \
		and day >= int(_back_on.get(event.region, -999)) + calm_days


static func all() -> Array[EventData]:
	var list: Array[EventData] = []
	for event: EventData in DataFiles.load_all("res://data/events"):
		list.append(event)
	return list


func _on_new_day(day: int) -> void:
	for event: EventData in all():
		# Only on the island the ranger is on, and not in their first calm_days back: a warned
		# event waits until then; none is warned for an island they're not on.
		if _coming.has(event.id):
			if day >= _coming[event.id]:
				if _can_strike(event, day):
					strike(event)
				else:
					_coming[event.id] = day + 1
		elif Regions.ranger_on(get_tree(), load("res://data/regions/%s.tres" % event.region)) \
				and Regions.is_discovered(load("res://data/regions/%s.tres" % event.region)):
			var lead := randi_range(event.warning_days, event.warning_days_max)
			var gap: int = day + lead - _last_day.get(event.id, 0)
			# Evenly spread between min_gap_days and max_gap_days (certain once it's overdue).
			if gap >= event.min_gap_days and _can_strike(event, day + lead) \
					and randf() < 1.0 / maxf(event.max_gap_days - gap + 1, 1.0):
				warn(event, lead)


## Warns that `event` is coming: it strikes `lead` days later (default: warning_days).
func warn(event: EventData, lead := -1) -> void:
	_coming[event.id] = GameClock.day + (lead if lead > 0 else event.warning_days)
	warned.emit(event)


## "in 3 days" / "tomorrow" / "today", until `event_id` strikes.
func when(event_id: StringName) -> String:
	var days: int = _coming.get(event_id, GameClock.day) - GameClock.day
	return "today" if days <= 0 else "tomorrow" if days == 1 else "in %d days" % days


## What's coming, for the HUD ("" = nothing).
func warning_text() -> String:
	for event: EventData in all():
		if _coming.has(event.id):
			return event.banner.replace("{when}", when(event.id))
	return ""


func is_coming() -> bool:
	return not _coming.is_empty()


## Whether an event is heading for this island.
func is_coming_to(region_id: StringName) -> bool:
	for event: EventData in all():
		if _coming.has(event.id) and event.region == region_id:
			return true
	return false


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
	# Nests turtle monitoring hasn't protected are washed over (one egg still hatches).
	var nests_hit := 0
	for nest: Nest in get_tree().get_nodes_in_group("nests"):
		if Regions.nearest(nest.global_position).id == event.region and nest.storm():
			nests_hit += 1
	var hurt := injure(event)
	var torn := 0
	if event.kelp_damage > 0.0:
		for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
			if ecosystem.region_id == event.region and ecosystem.has_method("swell"):
				torn += ecosystem.swell(event.kelp_damage, event.kelp_damaged_share)
	if event.flood_silt > 0.0:
		for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
			if ecosystem.region_id == event.region and ecosystem.has_method("flood"):
				torn += ecosystem.flood(event.flood_silt)
	if event.visibility_days > 0.0:
		_murky[event.region] = GameClock.now() + event.visibility_days
	struck.emit(event, damaged)
	if hurt > 0 or nests_hit > 0 or torn > 0:
		var lines: Array[String] = []
		if torn > 0:
			lines.append("%d kelp bed(s) were torn up: a storm damage survey shows which to restore first." % torn)
		if hurt > 0:
			lines.append("%d animal(s) were hurt: send a Rescue mission from your station to help them recover." % hurt)
		if nests_hit > 0:
			lines.append("%d unprotected nest(s) were washed over (turtle monitoring protects them)." % nests_hit)
		get_tree().call_group("hud", "show_toast", "\n".join(lines))
	return damaged


## How much longer missions on `region_id` take right now (poor visibility after heavy swell).
func mission_slowdown(region_id: StringName) -> float:
	if _murky.get(region_id, -1.0) <= GameClock.now():
		return 1.0
	for event: EventData in all():
		if event.region == region_id and event.visibility_days > 0.0:
			return event.slow_missions
	return 1.0


## Hurts a few of the animals `event` can hurt on its island (fewer during a boat patrol).
## Never badly: they're only injured until a Rescue mission helps them. Returns how many.
func injure(event: EventData) -> int:
	if event.injured_max <= 0:
		return 0
	var most := randi_range(1, event.injured_max)
	if Missions.is_on(&"boat_patrol"):
		most = most / 2
	var candidates := get_tree().get_nodes_in_group("animals").filter(func(a: Animal) -> bool:
		return (String(a.data.id) in event.injures and not a.young and not a.leaving and not a.injured
			and not a.tangled and Regions.nearest(a.global_position).id == event.region))
	candidates.shuffle()
	for animal: Animal in candidates.slice(0, most):
		animal.injure()
	return mini(most, candidates.size())


## The event whose repairs `building` needs (for its repair cost).
static func for_region(region_id: StringName) -> EventData:
	for event: EventData in all():
		if event.region == region_id:
			return event
	return null


## For the save file.
func to_dict() -> Dictionary:
	return {"last_day": _last_day.duplicate(), "coming": _coming.duplicate(), "murky": _murky.duplicate(),
		"back_on": _back_on.duplicate()}


func restore(saved: Dictionary) -> void:
	_last_day.clear()
	_coming.clear()
	var last: Dictionary = saved.get("last_day", {})
	for id in last:
		_last_day[StringName(id)] = int(last[id])
	var coming: Dictionary = saved.get("coming", {})
	for id in coming:
		_coming[StringName(id)] = int(coming[id])
	_back_on.clear()
	var back: Dictionary = saved.get("back_on", {})
	for id in back:
		_back_on[StringName(id)] = int(back[id])
	_current = &"?"
	_murky.clear()
	var murky: Dictionary = saved.get("murky", {})
	for id in murky:
		_murky[StringName(id)] = float(murky[id])
