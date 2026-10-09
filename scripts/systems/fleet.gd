extends Node
## Autoload "Fleet": island objectives and the Exploration Ships' shared equipment.
## Completing an island's objective (RegionData.goals) finds the island's discovery, and
## only then can its Exploration Ship be built (islands with no objective yet: not at all). Installing a discovery at any Exploration Ship
## upgrades every ship: the equipment level is the number installed. Exploring can only
## find an island once the upgrade it needs (RegionData.requires) is installed.

signal objective_completed(region: RegionData, discovery: DiscoveryData)
signal upgraded(discovery: DiscoveryData, level: int)

## Region ids whose objective is done, and discovery ids found / installed.
var _completed := {}
var _obtained := {}
var _installed := {}
## Progress flags (e.g. "wreck_found", "sonar_recovered"): island objectives check them.
var _flags := {}
## Progress counts (e.g. shed kelp gathered): id -> number. Saved.
var _counts := {}


func _ready() -> void:
	Journal.helped.connect(func(_a, _c) -> void: check())
	Inventory.changed.connect(func(_i, _c) -> void: check())


## Completes every discovered island's objective whose goals are all met.
func check() -> void:
	for region: RegionData in Regions.all():
		if not objective_done(region) and Regions.is_discovered(region) and not region.goals.is_empty() \
				and region.goals.all(func(goal: ObjectiveGoal) -> bool: return goal_met(goal)):
			complete(region)


## Done (its discovery found). Never for an island whose objective isn't made yet (no goals).
func objective_done(region: RegionData) -> bool:
	return _completed.has(region.id)


## Why its Exploration Ship can't be built yet ("" = it can).
func ship_problem(region: RegionData) -> String:
	if objective_done(region):
		return ""
	if region.goals.is_empty():
		return "%s's objective is coming soon: no Exploration Ship here yet." % region.display_name
	var done := 0
	var next: ObjectiveGoal = null
	for goal: ObjectiveGoal in region.goals:
		if goal_met(goal):
			done += 1
		elif next == null:
			next = goal
	var who := ""
	for person: PersonData in People.on(region.id):
		if person.role == &"objective":
			who = " %s knows more." % person.short_name
	if next == null:
		return "First: %s (see the Journal).%s" % [region.objective.to_lower(), who]
	return "This island's Exploration Ship comes once its story is done (%d of %d steps). Next: %s.%s" % [
		done, region.goals.size(), next.text, who]


## Marks `region`'s objective done and finds its discovery. `announce`: say so.
func complete(region: RegionData, announce := true) -> void:
	if _completed.has(region.id):
		return
	_completed[region.id] = true
	var found := discovery(region.discovery)
	if found:
		_obtained[found.id] = true
	if announce:
		objective_completed.emit(region, found)


## How far along `goal` is (compare with goal.amount).
func progress(goal: ObjectiveGoal) -> int:
	match goal.kind:
		&"help":
			return Journal.helped_count(goal.target)
		&"litter":
			return Inventory.litter_collected
		&"flag":
			return 1 if _flags.has(goal.target) else 0
		&"count":
			return _counts.get(goal.target, 0)
		&"photos":
			return Journal.photographed_species()
		&"built":
			var built := 0
			for building: Building in get_tree().get_nodes_in_group("buildings"):
				if building.data.id == goal.target and not building.is_queued_for_deletion() \
						and (goal.island == &"" or Regions.nearest(building.global_position).id == goal.island):
					built += 1
			return built
		&"installed":
			return 1 if _installed.has(goal.target) else 0
		&"stopped":
			return 1 if stopped(goal.target) else 0
	return 0


func goal_met(goal: ObjectiveGoal) -> bool:
	return progress(goal) >= goal.amount


## "Free the tangled turtle: done" / "Clean up litter: 12 / 30".
func goal_line(region: RegionData, goal: ObjectiveGoal) -> String:
	if objective_done(region) or goal_met(goal):
		return "%s: done" % goal.text
	if goal.amount > 1:
		return "%s: %d / %d" % [goal.text, progress(goal), goal.amount]
	return goal.text


## Adds to a progress count (ObjectiveGoal "count") and checks the objectives.
func add_count(id: StringName, n := 1) -> void:
	_counts[id] = _counts.get(id, 0) + n
	check()


func count_of(id: StringName) -> int:
	return _counts.get(id, 0)


## Marks a progress flag and checks the objectives.
## Clears a flag that comes and goes (e.g. "bear_at_camp").
func unmark(flag: StringName) -> void:
	_flags.erase(flag)


func mark(flag: StringName) -> void:
	if _flags.has(flag):
		return
	_flags[flag] = true
	if flag in [GLASS_MADE, CLEAN_WATER_MADE] and reusable_bottles():
		get_tree().call_group("hud", "show_toast", "Reusable glass bottles unlocked!\nGlass from the reef's sand and clean water from the clams: BlueHaven's facilities no longer use plastic drinking bottles, so no new ones drift in on any island.")
	check()


## The Tropical Reef's circular system: once the first glass and the first clean water have been
## made, reusable glass bottles replace plastic ones everywhere (no new plastic bottles drift in).
const GLASS_MADE := &"glass_made"
const CLEAN_WATER_MADE := &"clean_water_made"


## What stopped litter of kind `id` at its source, in words ("" while it still drifts in).
func stopped_by(id: StringName) -> String:
	if id == &"plastic_bottle" and reusable_bottles():
		return "reusable glass bottles from the Glassworks"
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if String(id) in building.data.stops_litter and not building.is_queued_for_deletion():
			return "your %s" % building.data.display_name
	return ""


## Whether litter of kind `id` has been stopped at its source, so no more of it drifts in on
## any island: plastic bottles by reusable bottles, the rest by a
## building that stops it (BuildingData.stops_litter, e.g. the Weaving Workshop: plastic bags).
func stopped(id: StringName) -> bool:
	if id == &"plastic_bottle" and reusable_bottles():
		return true
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if String(id) in building.data.stops_litter and not building.is_queued_for_deletion():
			return true
	return false


func reusable_bottles() -> bool:
	return has_flag(GLASS_MADE) and has_flag(CLEAN_WATER_MADE)


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


static func discovery(id: StringName) -> DiscoveryData:
	var path := "res://data/discoveries/%s.tres" % id
	return DataFiles.res(path) if id != &"" and ResourceLoader.exists(path) else null


func has_found(id: StringName) -> bool:
	return _obtained.has(id)


func is_installed(id: StringName) -> bool:
	return _installed.has(id)


## Equipment level: one per discovery installed.
func level() -> int:
	return _installed.size()


## Found but not installed yet, in the plan's order.
func ready_to_install() -> Array[DiscoveryData]:
	var ready: Array[DiscoveryData] = []
	for id in _obtained:
		if not _installed.has(id):
			ready.append(discovery(id))
	ready.sort_custom(func(a: DiscoveryData, b: DiscoveryData) -> bool: return a.order < b.order)
	return ready


## Installed ones, in the plan's order.
func installed() -> Array[DiscoveryData]:
	var list: Array[DiscoveryData] = []
	for id in _installed:
		list.append(discovery(id))
	list.sort_custom(func(a: DiscoveryData, b: DiscoveryData) -> bool: return a.order < b.order)
	return list


## Upgrades the whole fleet with a found discovery.
func install(id: StringName) -> void:
	if not _obtained.has(id) or _installed.has(id):
		return
	_installed[id] = true
	upgraded.emit(discovery(id), level())


## The upgrade still needed before exploring can find `region` (null = none).
func missing_for(region: RegionData) -> DiscoveryData:
	if region and region.requires != &"" and not is_installed(region.requires):
		return discovery(region.requires)
	return null


## For the save file.
func to_dict() -> Dictionary:
	return {"completed": _completed.keys(), "found": _obtained.keys(), "installed": _installed.keys(),
		"flags": _flags.keys(), "counts": _counts.duplicate()}


func restore(saved: Dictionary) -> void:
	for into: Dictionary in [_completed, _obtained, _installed, _flags]:
		into.clear()
	for flag in saved.get("flags", []):
		_flags[StringName(flag)] = true
	if _flags.has(&"gear_marking"):  # (older saves: bringing up 3 pieces used to stop the nets by itself)
		_flags.erase(&"gear_marking")
		_flags[&"gear_recovered"] = true
	_counts.clear()
	var counts: Dictionary = saved.get("counts", {})
	for id in counts:
		_counts[StringName(id)] = int(counts[id])
	for id in saved.get("completed", []):
		_completed[StringName(id)] = true
	for id in saved.get("found", []):
		_obtained[StringName(id)] = true
	for id in saved.get("installed", []):
		_installed[StringName(id)] = true
