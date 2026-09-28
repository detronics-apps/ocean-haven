extends Node
## Autoload "Missions": signature facilities send missions for funding (MissionData), one at
## a time. A mission is away for a few hours, then reports back, and what it found is marked
## on the minimap until the next morning.

signal sent(mission: MissionData)
signal returned(mission: MissionData, found: int)

## The mission that's out (null = none), the island it searches, and when it's back (GameClock.now()).
var active: MissionData
var _region: RegionData
var _back_at := 0.0
## What the last mission found, marked on the minimap until the next morning.
var _marked: Array[Node2D] = []
## The mission whose finds are marked.
var _marks_from: MissionData


func _ready() -> void:
	GameClock.new_day.connect(func(_d: int) -> void: _marked.clear())


func _process(_delta: float) -> void:
	if active and GameClock.now() >= _back_at:
		_finish()


## Every mission `facility` offers, in order.
static func offered_by(facility: StringName) -> Array[MissionData]:
	var list: Array[MissionData] = []
	for mission: MissionData in DataFiles.load_all("res://data/missions"):
		if mission.facility == facility:
			list.append(mission)
	list.sort_custom(func(a: MissionData, b: MissionData) -> bool: return a.order < b.order)
	return list


## Why `mission` can't be sent right now ("" = it can).
func problem(mission: MissionData) -> String:
	if active:
		return "Your %s is still out." % active.display_name.to_lower()
	if Funding.balance < mission.cost:
		return "Needs %d funding." % mission.cost
	return ""


## Pays for and sends `mission` to search `region`. Returns whether it went.
func send(mission: MissionData, region: RegionData) -> bool:
	if problem(mission) != "" or not Funding.spend(mission.cost):
		return false
	active = mission
	_region = region
	_back_at = GameClock.now() + mission.hours / 24.0
	sent.emit(mission)
	return true


## In-game time it's back, e.g. "14:00".
func back_time() -> String:
	var hours := fposmod(_back_at, 1.0) * 24.0
	return "%02d:%02d" % [int(hours), int(fmod(hours, 1.0) * 60.0)]


func _finish() -> void:
	var mission := active
	active = null
	_marked.clear()
	for node: Node2D in get_tree().get_nodes_in_group(mission.finds_group):
		if node.is_queued_for_deletion() or Regions.nearest(node.global_position) != _region:
			continue
		if mission.finds_species != &"" and _species(node) != mission.finds_species:
			continue
		if mission.finds_tangled and not node.get("tangled"):
			continue
		_marked.append(node)
	_marks_from = mission
	returned.emit(mission, _marked.size())


static func _species(node: Node) -> StringName:
	var data: Variant = node.get("data") if node.get("data") != null else node.get("species")
	return data.id if data is Resource else &""


## What's marked on the minimap now: things collected (or animals freed) drop off.
func marked() -> Array[Node2D]:
	var kept: Array[Node2D] = []
	for node in _marked:  # untyped: some may have been freed
		if is_instance_valid(node) and not node.is_queued_for_deletion() \
				and (not _marks_from.finds_tangled or node.get("tangled")):
			kept.append(node)
	_marked = kept
	return _marked


func marker_colour() -> Color:
	return _marks_from.marker_colour if _marks_from else Color.WHITE


## For the save file: the mission that's out.
func to_dict() -> Dictionary:
	if not active:
		return {}
	return {"mission": active.id, "region": _region.id, "back_at": _back_at}


func restore(saved: Dictionary) -> void:
	active = null
	_marked.clear()
	var path := "res://data/missions/%s.tres" % saved.get("mission", "")
	var region_path := "res://data/regions/%s.tres" % saved.get("region", "")
	if saved.has("mission") and ResourceLoader.exists(path) and ResourceLoader.exists(region_path):
		active = load(path)
		_region = load(region_path)
		_back_at = float(saved.get("back_at", 0.0))
