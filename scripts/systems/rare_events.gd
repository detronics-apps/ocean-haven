extends Node
## Autoload "RareEvents": each morning, an island's rare event (EventData) may be warned about
## (not within min_gap_days of the last one); warning_days later is its day. Clouds gather
## beyond the island's rowboat waters on the warning days (StormClouds, the minimap's rim) and
## its people get nervous. On its day, once the ranger has been on the island STRIKE_AFTER
## seconds, it strikes: its weather passes over for STORM_SECONDS (StormWeather), then the
## damage is done. Coming the day after, the ranger catches its end (TAIL_SECONDS). Away for
## both, they come back to the aftermath only. The ranger prepares by securing buildings
## (Building.secured); afterwards they fix what was damaged and clean up the litter. A storm may
## also hurt a few animals (never badly: a Rescue mission helps them recover) and wash over
## nests turtle monitoring didn't protect. Nothing is ever "failed": it's always recoverable.

signal warned(event: EventData)
signal struck(event: EventData, damaged: int)

## Event id -> day it last struck (none yet: the first comes first_gap_min..first_gap_max days
## after the ranger first got to its island).
var _last_day := {}
## Warned events waiting to strike: event id -> day they strike.
var _coming := {}
## Region id -> GameClock.now() until which visibility underwater is poor (missions slower).
var _murky := {}
## On its day, the storm strikes once the ranger has been on its island this long ...
const STRIKE_AFTER := 10.0
## ... and passes over in this long; the day after, they only see its end.
const STORM_SECONDS := 10.0
const TAIL_SECONDS := 5.0
## Real seconds the ranger has been on the island they're on.
var _here_for := 0.0
## Event id -> its weather is passing over now (it strikes when that's done).
var _passing := {}
## Person id -> shaken by the storm on their island: nervous until the ranger talks to them.
var _shaken := {}
## An island's first event comes between these many days after the ranger first gets there
## (later ones: the event's min_gap_days..max_gap_days after the last).
@export var first_gap_min := 15
@export var first_gap_max := 25
## Region id -> the first day the ranger was ever on it: an island's first event never comes
## sooner than first_gap_min days after that (arriving late in the game is no reason for a storm).
var _first_on := {}
## Loaded from a save made before _first_on existed: count the islands found so far from now.
var _fill_first_on := false
## The island the ranger is on (&"?" = not checked yet: loading isn't coming back).
var _current: StringName = &"?"
var _check := 0.0


func _ready() -> void:
	GameClock.new_day.connect(_on_new_day)


func _process(delta: float) -> void:
	_here_for += delta
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position).id
	if _fill_first_on:
		_fill_first_on = false
		for region: Resource in Regions.all():
			if Regions.is_discovered(region) and not _first_on.has(region.id):
				_first_on[region.id] = GameClock.day
	_arrived_day(here)
	if here != _current:
		_here_for = 0.0
	_current = here
	_due_here(here)


## A storm due on the ranger's island: on its day it strikes once they've been here
## STRIKE_AFTER seconds (its weather passes over first); the day after, they see its end at
## once; later still, they've missed it: only the aftermath.
func _due_here(here: StringName) -> void:
	for event: EventData in all():
		if event.region != here or not _coming.has(event.id) or _passing.has(event.id):
			continue
		var late: int = GameClock.day - int(_coming[event.id])
		if late < 0 or (late == 0 and _here_for < STRIKE_AFTER):
			continue
		if late >= 2:
			strike(event)  # missed it
			continue
		var seconds := STORM_SECONDS if late == 0 else TAIL_SECONDS
		_passing[event.id] = true
		var weather := get_tree().get_first_node_in_group("storm_weather")
		if weather:
			weather.play(event, seconds, late > 0)
		get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
			_passing.erase(event.id)
			if _coming.has(event.id):
				strike(event))


## The first day the ranger was on `region_id` (today, if they never were: its timer starts
## now). Any warning that came too soon after it is called off.
func _arrived_day(region_id: StringName) -> int:
	if not _first_on.has(region_id):
		_first_on[region_id] = GameClock.day
		for event: EventData in all():
			if event.region == region_id and _coming.has(event.id) and _too_soon(event, _coming[event.id]):
				_coming.erase(event.id)
	return _first_on[region_id]


## Whether `day` is within first_gap_min days of the ranger first coming to `event`'s island:
## each island's storm timer starts when the ranger first gets there.
func _too_soon(event: EventData, day: int) -> bool:
	return day < int(_first_on.get(event.region, day)) + first_gap_min


## The days between events: the island's first one comes first_gap_min..first_gap_max days
## after the ranger first got there, later ones the event's min_gap_days..max_gap_days apart.
func _window(event: EventData) -> Vector2i:
	if not _last_day.has(event.id):
		return Vector2i(first_gap_min, first_gap_max)
	return Vector2i(event.min_gap_days, event.max_gap_days)


## Whether `event` may be warned for `day`: the ranger is on its island.
func _can_strike(event: EventData, _day: int) -> bool:
	return Regions.ranger_on(get_tree(), load("res://data/regions/%s.tres" % event.region))


static func all() -> Array[EventData]:
	var list: Array[EventData] = []
	for event: EventData in DataFiles.load_all("res://data/events"):
		list.append(event)
	return list


func _on_new_day(day: int) -> void:
	for event: EventData in all():
		# Only warned for the island the ranger is on; once warned it comes on its day whether
		# they're there or not (_due_here: the ranger sees it, its end, or only the aftermath).
		if _coming.has(event.id) and _too_soon(event, _coming[event.id]):
			_coming.erase(event.id)  # (warned before the island's timer started: called off)
		elif _coming.has(event.id):
			pass
		elif Regions.ranger_on(get_tree(), load("res://data/regions/%s.tres" % event.region)) \
				and Regions.is_discovered(load("res://data/regions/%s.tres" % event.region)) \
				and (event.needs_building == &"" or IslandHealth.built(get_tree(), event.needs_building)):
			var since: int = day - maxi(_last_day.get(event.id, 0), _arrived_day(event.region))
			var window := _window(event)
			# Warned 3-4 days ahead, but never so late that it strikes after the window.
			var lead := clampi(randi_range(event.warning_days, event.warning_days_max), event.warning_days,
				maxi(window.y - since, event.warning_days))
			var gap: int = since + lead
			# Evenly spread over the window (certain once it's overdue).
			if gap >= window.x and not _too_soon(event, day + lead) and _can_strike(event, day + lead) \
					and randf() < 1.0 / maxf(window.y - gap + 1, 1.0):
				warn(event, lead)


## Warns that `event` is coming: it strikes `lead` days later (default: warning_days).
func warn(event: EventData, lead := -1) -> void:
	_coming[event.id] = GameClock.day + (lead if lead > 0 else event.warning_days)
	warned.emit(event)


## "in 3 days" / "tomorrow" / "today", until `event_id` strikes.
func when(event_id: StringName) -> String:
	var days: int = _coming.get(event_id, GameClock.day) - GameClock.day
	return "today" if days <= 0 else "tomorrow" if days == 1 else "in %d days" % days


## What's coming, for the HUD ("" = nothing; not once its day has gone).
func warning_text() -> String:
	for event: EventData in all():
		if _coming.has(event.id) and int(_coming[event.id]) >= GameClock.day:
			return event.banner.replace("{when}", when(event.id))
	return ""


## Days until the storm heading for `region_id` (-1 = none; 0 = today, not struck yet).
func days_until(region_id: StringName) -> int:
	for event: EventData in all():
		if event.region == region_id and _coming.has(event.id):
			return maxi(int(_coming[event.id]) - GameClock.day, 0)
	return -1


## The event heading for `region_id` (null = none).
func coming_to(region_id: StringName) -> EventData:
	for event: EventData in all():
		if event.region == region_id and _coming.has(event.id):
			return event
	return null


## Whether `person_id` was shaken by a storm and hasn't talked to the ranger since.
func shaken(person_id: StringName) -> bool:
	return _shaken.has(person_id)


func calm_down(person_id: StringName) -> void:
	_shaken.erase(person_id)


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
		if Regions.nearest(spawner.area.get_center()).id == event.region and event.litter_washed > 0:
			spawner.storm_litter(randi_range(event.litter_washed, maxi(event.litter_washed_max, event.litter_washed)),
				event.litter_floating)
	for person: PersonData in People.all():
		if person.region == event.region and person.storm_after != "":
			_shaken[person.id] = true  # they'll want to talk about it
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
	if event.ice_breakup > 0.0:
		for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
			if ecosystem.region_id == event.region and ecosystem.has_method("ice_breakup"):
				ecosystem.ice_breakup(event.ice_breakup)
	if event.oil_patches > 0:
		for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
			if ecosystem.region_id == event.region and ecosystem.has_method("oil_spill"):
				ecosystem.oil_spill(event.oil_patches)
	if event.visibility_days > 0.0:
		_murky[event.region] = GameClock.now() + event.visibility_days
	struck.emit(event, damaged)  # (no note: the island's people say what happened)
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
		"first_on": _first_on.duplicate(), "shaken": _shaken.keys()}


func restore(saved: Dictionary) -> void:
	_last_day.clear()
	_coming.clear()
	var last: Dictionary = saved.get("last_day", {})
	for id in last:
		_last_day[StringName(id)] = int(last[id])
	var coming: Dictionary = saved.get("coming", {})
	for id in coming:
		_coming[StringName(id)] = int(coming[id])
	_first_on.clear()
	var first: Dictionary = saved.get("first_on", {})
	for id in first:
		_first_on[StringName(id)] = int(first[id])
	_fill_first_on = not saved.has("first_on")
	_shaken.clear()
	for id in saved.get("shaken", []):
		_shaken[StringName(id)] = true
	_passing.clear()
	_here_for = 0.0
	_current = &"?"
	_murky.clear()
	var murky: Dictionary = saved.get("murky", {})
	for id in murky:
		_murky[StringName(id)] = float(murky[id])
