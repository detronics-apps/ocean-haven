extends Node
## Autoload "Missions": signature facilities send missions for funding (MissionData), one at
## a time. A mission is away for a few real minutes, then comes back and responds to what's
## happening on the island (MissionData.effect): injured animals recover, a boat patrol calms
## busy waters, hidden litter turns up, nests are protected, a visiting dolphin joins, or the
## coastal survey finds what's hidden. What it found is marked on the minimap until the next
## morning (or, with keep_marks, until it's gone).

signal sent(mission: MissionData)
signal returned(mission: MissionData, found: int)

const VISITOR_NAME := "VisitingDolphin"
const DOLPHIN := "res://data/animals/bottlenose_dolphin.tres"

## The mission that's out (null = none), the island it searches, and when it's back (GameClock.now()).
var active: MissionData
var _region: RegionData
var _back_at := 0.0
## What the last mission found, marked on the minimap.
var _marked: Array[Node2D] = []
## The mission whose finds are marked.
var _marks_from: MissionData
## Lasting effects: effect -> GameClock.now() when it ends (boat_patrol, dolphin_tracking).
var _until := {}
## Tries without success so far: mission id -> count (the coastal survey is sure by its 5th).
var _tries := {}
## What the last mission found out, in words (put into its report as "{detail}").
var detail := ""
## How many times each mission has come back, per island: {"region_id/mission_id": n}.
var _done := {}
## The last mission's report (also shown at the facility, to read again).
var last_report := ""


func _ready() -> void:
	GameClock.new_day.connect(func(_d: int) -> void:
		if not _marks_from or not _marks_from.keep_marks:
			_marked.clear())


func _process(_delta: float) -> void:
	if active and GameClock.now() >= _back_at:
		_finish()
	_keep_visitor()


## Every mission `facility` offers now, in order (not ones whose job is done: hide_flag).
static func offered_by(facility: StringName) -> Array[MissionData]:
	var list: Array[MissionData] = []
	for mission: MissionData in DataFiles.load_all("res://data/missions"):
		if mission.facility == facility and (mission.hide_flag == &"" or not Fleet.has_flag(mission.hide_flag)) \
				and (mission.show_flag == &"" or Fleet.has_flag(mission.show_flag)):
			list.append(mission)
	list.sort_custom(func(a: MissionData, b: MissionData) -> bool: return a.order < b.order)
	return list


## Why `mission` can't be sent right now ("" = it can).
func problem(mission: MissionData) -> String:
	if active:
		return "Your %s is still out." % active.display_name.to_lower()
	if is_on(mission.effect) and mission.effect_days > 0.0:
		return "Still going: %s left." % real_time((_until[mission.effect] - GameClock.now()) * GameClock.DAY_LENGTH)
	if Funding.balance < mission.cost:
		return "Needs %d funding." % mission.cost
	return ""


## Pays for and sends `mission` to search `region`. Returns whether it went.
func send(mission: MissionData, region: RegionData) -> bool:
	if problem(mission) != "" or not Funding.spend(mission.cost):
		return false
	active = mission
	_region = region
	# After heavy swell the water is murky: missions there take longer.
	_back_at = GameClock.now() + mission.minutes * 60.0 / GameClock.DAY_LENGTH * RareEvents.mission_slowdown(region.id) \
		* (1.0 - mission.faster_share if mission.faster_with != &"" and Fleet.is_installed(mission.faster_with) else 1.0)
	sent.emit(mission)
	return true


## Does `mission` on `region` right now, free (e.g. the research a ranger activity's story
## play did): its report and minimap marks as if it had come back. A mission that's out stays out.
func run_now(mission: MissionData, region: RegionData) -> void:
	var out := active
	var out_region := _region
	active = mission
	_region = region
	_finish()
	if out:
		active = out
		_region = out_region


## Whether a lasting effect ("boat_patrol", "dolphin_tracking") is going on now.
func is_on(effect: StringName) -> bool:
	return effect != &"" and _until.get(effect, -1.0) > GameClock.now()


## Real time until it's back, e.g. "2 minutes" (no in-game clock).
func time_left() -> String:
	return real_time(maxf(_back_at - GameClock.now(), 0.0) * GameClock.DAY_LENGTH)


## "less than a minute", "1 minute", "3 minutes".
static func real_time(seconds: float) -> String:
	var mins := ceili(seconds / 60.0 - 0.01)
	if mins <= 0:
		return "less than a minute"
	return "1 minute" if mins == 1 else "%d minutes" % mins


func _finish() -> void:
	var mission := active
	active = null
	var key := _key(mission, _region)
	_done[key] = int(_done.get(key, 0)) + 1
	_marked.clear()
	detail = ""
	var found: Array[Node2D] = []
	var ecosystem := _ecosystem()
	if ecosystem and ecosystem.handles(mission.effect):
		var result: Dictionary = ecosystem.run_mission(mission)
		found.assign(result.get("found", []))
		detail = result.get("detail", "")
	else:
		found = _run(mission)
	for node in found:
		if node.has_method("reveal"):
			node.reveal()  # found by the mission (e.g. the wreck)
	_marked = found
	_marks_from = mission
	var report := mission.report if found.size() > 0 or detail != "" else mission.report_none
	last_report = (report % found.size() if "%d" in report else report).replace("{detail}", detail)
	returned.emit(mission, found.size())


## How many times `mission` has been run (and come back) on `region`.
func times_done(mission: MissionData, region: RegionData) -> int:
	return int(_done.get(_key(mission, region), 0))


static func _key(mission: MissionData, region: RegionData) -> String:
	return "%s/%s" % [region.id if region else &"", mission.id]


## The island's own ecosystem (e.g. the Kelp Forest's), if it has one.
func _ecosystem() -> Node:
	for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
		if ecosystem.region_id == _region.id:
			return ecosystem
	return null


## The Marine Search & Rescue Station's missions (and plain "find" missions).
func _run(mission: MissionData) -> Array[Node2D]:
	var found: Array[Node2D] = []
	match mission.effect:
		&"rescue":
			for animal: Animal in _here("animals"):
				if animal.injured:
					animal.recover()
					found.append(animal)
				elif animal.tangled:
					found.append(animal)
		&"boat_patrol":
			_until[mission.effect] = GameClock.now() + mission.effect_days
		&"investigate":  # the research behind a question: what to do about it (the report)
			if mission.marks_flag != &"":
				Fleet.mark(mission.marks_flag)
		&"pollution_survey":
			var spawner := _spawner()
			if spawner:
				found.assign(spawner.reveal_hidden(randi_range(mission.reveal_count.x, mission.reveal_count.y)))
		&"turtle_monitoring":
			for nest: Nest in _here("nests"):
				nest.protected_until = GameClock.now() + mission.effect_days
				found.append(nest)
		&"dolphin_tracking":
			_until[mission.effect] = GameClock.now() + mission.effect_days
			_keep_visitor()
			found.assign(_here("animals").filter(func(a: Animal) -> bool: return a.data.id == &"bottlenose_dolphin"))
		&"coastal_survey":
			var tries: int = _tries.get(mission.id, 0) + 1
			if randf() < mission.find_chance or (mission.sure_by > 0 and tries >= mission.sure_by):
				_tries.erase(mission.id)
				found.assign(_finds(mission))
			else:
				_tries[mission.id] = tries
		_:
			found.assign(_finds(mission))
	return found


## What `mission` finds on its island (MissionData.finds_group / species / tangled).
func _finds(mission: MissionData) -> Array[Node2D]:
	var list: Array[Node2D] = []
	for node: Node2D in _here(mission.finds_group):
		if mission.finds_species != &"" and _species(node) != mission.finds_species:
			continue
		if mission.finds_tangled and not node.get("tangled"):
			continue
		list.append(node)
	return list


## Nodes in `group` on the island the mission searched.
func _here(group: StringName) -> Array[Node2D]:
	var list: Array[Node2D] = []
	if group == &"":
		return list
	for node: Node2D in get_tree().get_nodes_in_group(group):
		if not node.is_queued_for_deletion() and Regions.nearest(node.global_position) == _region:
			list.append(node)
	return list


func _spawner() -> LitterSpawner:
	for spawner: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(spawner.area.get_center()) == _region:
			return spawner
	return null


## Dolphin tracking's visitor: there while it lasts (also after loading), then swims off.
func _keep_visitor() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var world := player.get_parent()
	var visitor: Node2D = world.get_node_or_null(VISITOR_NAME)
	if is_on(&"dolphin_tracking"):
		if not visitor:
			world.add_child(_new_visitor())
	elif visitor and not visitor.leaving:
		visitor.leaving = true  # back out to the open ocean with its pod


func _new_visitor() -> Node2D:
	var visitor: Node2D = load(Nest.ANIMAL_SCENE).instantiate()
	visitor.name = VISITOR_NAME
	visitor.set("visiting", true)
	visitor.set("data", load(DOLPHIN))
	visitor.set("home_radius", 220.0)
	var region: RegionData = _region if _region else Regions.all()[0]
	var spot := region.center + Vector2(region.waters_radius * 0.55, 0)
	# By the Dolphin Viewing Area if there is one, so visitors can see it.
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.watches == &"bottlenose_dolphin" and Regions.nearest(building.global_position) == region:
			spot = Terrain.nearest(get_tree(), building.global_position + Vector2(0, 96), [""])
	visitor.position = spot
	return visitor


static func _species(node: Node) -> StringName:
	var data: Variant = node.get("data") if node.get("data") != null else node.get("species")
	return data.id if data is Resource else &""


## What's marked on the minimap now: things collected (or animals helped) drop off.
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


## For the save file: the mission that's out, lasting effects and tries.
func to_dict() -> Dictionary:
	var saved := {"until": _until.duplicate(), "tries": _tries.duplicate(), "done": _done.duplicate()}
	if active:
		saved.merge({"mission": active.id, "region": _region.id, "back_at": _back_at})
	return saved


func restore(saved: Dictionary) -> void:
	active = null
	_marked.clear()
	_until.clear()
	_tries.clear()
	_done.clear()
	var done: Dictionary = saved.get("done", {})
	for key in done:
		_done[String(key)] = int(done[key])
	var until: Dictionary = saved.get("until", {})
	for effect in until:
		_until[StringName(effect)] = float(until[effect])
	var tries: Dictionary = saved.get("tries", {})
	for id in tries:
		_tries[StringName(id)] = int(tries[id])
	var path := "res://data/missions/%s.tres" % saved.get("mission", "")
	var region_path := "res://data/regions/%s.tres" % saved.get("region", "")
	if saved.has("mission") and ResourceLoader.exists(path) and ResourceLoader.exists(region_path):
		active = load(path)
		_region = load(region_path)
		_back_at = float(saved.get("back_at", 0.0))
