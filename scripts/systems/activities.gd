extends Node
## Autoload "Activities": the ranger activities (data/activities/, ActivityData): which story
## plays are done and the personal best time for each level. Replays are only for fun: they
## never give progress, items or funding.

## An activity was finished: `story` = its first (story) play.
signal finished(activity: ActivityData, level: int, seconds: float, story: bool)

## Activity id -> story play done.
var _done := {}
## Activity id -> {level: best seconds}.
var _bests := {}
## Activity id -> {level: deepest metres reached} (Echo Dive: the record until the level's
## bottom is reached, then the time counts).
var _depths := {}
var _all: Array[ActivityData] = []


func all() -> Array[ActivityData]:
	if _all.is_empty():
		for activity: ActivityData in DataFiles.load_all("res://data/activities"):
			_all.append(activity)
	return _all


## The activities played at a kind of building that are open now.
func at(building_id: StringName) -> Array[ActivityData]:
	var list: Array[ActivityData] = []
	for activity: ActivityData in all():
		if activity.building == building_id and is_open(activity):
			list.append(activity)
	return list


func is_open(activity: ActivityData) -> bool:
	if story_done(activity):
		return true
	var someone: PersonData = null
	for person: PersonData in People.all():
		if person.id == activity.person:
			someone = person
	return someone != null and Array(activity.unlock_any).any(func(c: String) -> bool: return People.check(c, someone))


func story_done(activity: ActivityData) -> bool:
	return _done.has(activity.id)


## The best time for `level` (INF = not finished yet).
func best(activity: ActivityData, level: int) -> float:
	return float(_bests.get(activity.id, {}).get(level, INF))


## The deepest `level` has been dived (0 = never tried).
func best_depth(activity: ActivityData, level: int) -> float:
	return float(_depths.get(activity.id, {}).get(level, 0.0))


## Records how deep a dive got. Returns whether it's deeper than ever before.
func reached(activity: ActivityData, level: int, metres: float) -> bool:
	if metres <= best_depth(activity, level):
		return false
	if not _depths.has(activity.id):
		_depths[activity.id] = {}
	_depths[activity.id][level] = metres
	return true


## Levels that can be played: every one finished, and the next.
func open_levels(activity: ActivityData) -> int:
	var count := 1
	while count < activity.levels.size() and best(activity, count - 1) < INF:
		count += 1
	return count


## Records a finished play. The first story play gives its reward. Returns whether it's a new
## personal best.
func finish(activity: ActivityData, level: int, seconds: float) -> bool:
	var story := not story_done(activity)
	var record := seconds < best(activity, level)
	if record:
		if not _bests.has(activity.id):
			_bests[activity.id] = {}
		_bests[activity.id][level] = seconds
	if story:
		_done[activity.id] = true
		if activity.reward_group != &"":
			get_tree().call_group(activity.reward_group, activity.reward_method)
		if activity.reward_mission and activity.region != &"":
			Missions.run_now(activity.reward_mission, load("res://data/regions/%s.tres" % activity.region))
	finished.emit(activity, level, seconds, story)
	return record


func to_dict() -> Dictionary:
	var bests := {}
	for id in _bests:
		var levels := {}
		for level in _bests[id]:
			levels[str(level)] = _bests[id][level]
		bests[String(id)] = levels
	var depths := {}
	for id in _depths:
		var levels := {}
		for level in _depths[id]:
			levels[str(level)] = _depths[id][level]
		depths[String(id)] = levels
	return {"done": _done.keys().map(func(k: StringName) -> String: return String(k)), "bests": bests, "depths": depths}


func restore(saved: Dictionary) -> void:
	_done.clear()
	_bests.clear()
	_depths.clear()
	var depths: Dictionary = saved.get("depths", {})
	for id in depths:
		var levels := {}
		for level in depths[id]:
			levels[int(level)] = float(depths[id][level])
		_depths[StringName(id)] = levels
	for id in saved.get("done", []):
		_done[StringName(id)] = true
	var bests: Dictionary = saved.get("bests", {})
	for id in bests:
		var levels := {}
		for level in bests[id]:
			levels[int(level)] = float(bests[id][level])
		_bests[StringName(id)] = levels
