extends Node
## Autoload "Activities": the ranger activities (data/activities/, ActivityData): which story
## plays are done and the personal best time for each level. Replays never give progress or
## items; the first one each day pays its research grant (ActivityData.daily_grant), whatever
## the score.

## An activity was finished: `story` = its first (story) play.
signal finished(activity: ActivityData, level: int, seconds: float, story: bool)

## Activity id -> story play done.
var _done := {}
## Activity id -> {level: best seconds}.
var _bests := {}
## Activity id -> {level: deepest metres reached} (Echo Dive: the record until the level's
## bottom is reached, then the time counts).
var _depths := {}
## Activity id -> {"level/key": most} (endless plays: urchins collected, seconds lasted).
var _most := {}
## Activity id -> GameClock.day its last research grant was paid.
var _granted := {}
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


## The most of `key` in one play of `level` (e.g. Otter Dive: "urchins", "seconds"; 0 = none yet).
func most(activity: ActivityData, level: int, key: String) -> float:
	return float(_most.get(activity.id, {}).get("%d/%s" % [level, key], 0.0))


## Records `value` of `key` for a play of `level`. Returns whether it's a new most.
func record_most(activity: ActivityData, level: int, key: String, value: float) -> bool:
	if value <= most(activity, level, key):
		return false
	if not _most.has(activity.id):
		_most[activity.id] = {}
	_most[activity.id]["%d/%s" % [level, key]] = value
	return true


## Whether `level` has been done (finished, or for endless plays its "cleared" record), so
## the next one opens.
func cleared(activity: ActivityData, level: int) -> bool:
	return best(activity, level) < INF or most(activity, level, "cleared") > 0.0


## Levels that can be played: every one finished, and the next.
func open_levels(activity: ActivityData) -> int:
	var count := 1
	while count < activity.levels.size() and cleared(activity, count - 1):
		count += 1
	return count


## The research grant for a replay played today: paid once a day per activity, the same
## whatever the score. Returns the amount paid (0: already paid today, or the story play).
func research_grant(activity: ActivityData) -> int:
	if not story_done(activity) or activity.daily_grant <= 0 or granted_today(activity):
		return 0
	_granted[activity.id] = GameClock.day
	var who := activity.display_name
	for person: PersonData in People.all():
		if person.id == activity.person:
			who = "%s's team" % person.short_name
	Funding.earn(activity.daily_grant, "%s used your %s results: a research grant." % [who, activity.display_name])
	return activity.daily_grant


## Whether today's research grant for `activity` has been paid.
func granted_today(activity: ActivityData) -> bool:
	return int(_granted.get(activity.id, -1)) == GameClock.day


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
	var granted := {}
	for id in _granted:
		granted[String(id)] = _granted[id]
	var most := {}
	for id in _most:
		most[String(id)] = (_most[id] as Dictionary).duplicate()
	return {"done": _done.keys().map(func(k: StringName) -> String: return String(k)), "bests": bests, "depths": depths, "most": most, "granted": granted}


func restore(saved: Dictionary) -> void:
	_done.clear()
	_bests.clear()
	_depths.clear()
	_most.clear()
	_granted.clear()
	var granted: Dictionary = saved.get("granted", {})
	for id in granted:
		_granted[StringName(id)] = int(granted[id])
	var most: Dictionary = saved.get("most", {})
	for id in most:
		var records := {}
		for key in most[id]:
			records[String(key)] = float(most[id][key])
		_most[StringName(id)] = records
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
	_forget_old_otter_records()


## Otter Dive's levels used to be endless ("seconds" lasted, "cleared"), and its story play set
## a time for level 1 with only 5 urchins: those records can't be compared with the new ones
## (collect 10, 20, 30... as fast as you can), so they start fresh. The story stays done.
func _forget_old_otter_records() -> void:
	var records: Dictionary = _most.get(&"otter_dive", {})
	if records.keys().any(func(k: String) -> bool: return k.ends_with("/seconds") or k.ends_with("/cleared")) \
			or (_bests.has(&"otter_dive") and records.is_empty()):
		_most.erase(&"otter_dive")
		_bests.erase(&"otter_dive")
