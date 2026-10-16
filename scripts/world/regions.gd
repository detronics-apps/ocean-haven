class_name Regions
## The ocean's regions (data/regions/): which one a point is in, which have been
## discovered, and which one exploring warmer or colder finds next.

const WARMER := &"warmer"
const COLDER := &"colder"

static var _all: Array[Resource] = []
## Discovered region ids (the starting island is always known). Saved by SaveGame.
static var _discovered := {}


static func all() -> Array[Resource]:
	if _all.is_empty():  # checked every frame by the boat, so load once
		_all = DataFiles.load_all("res://data/regions")
		_all.sort_custom(func(a: RegionData, b: RegionData) -> bool: return a.order < b.order)
	return _all


## The region whose island is nearest `point`.
## Every island from the coldest to the warmest, as they lie: Polar Ocean, Deep Sea, Kelp
## Forest, Starting Island, Mangrove Coast, Tropical Reef.
static func coldest_first() -> Array[RegionData]:
	var list: Array[RegionData] = []
	for region: RegionData in all():
		list.append(region)
	var lie := func(r: RegionData) -> int: return -r.order if r.direction == COLDER else r.order
	list.sort_custom(func(a: RegionData, b: RegionData) -> bool: return lie.call(a) < lie.call(b))
	return list


static func nearest(point: Vector2) -> RegionData:
	var list := all()
	if _centres.size() != list.size():  # (called all the time: the centres kept, compared squared)
		_keep_centres(list)
	if _in_a_line and is_finite(point.x):  # (the islands lie in a line across: the one whose middle is nearest across)
		return _across[_cuts.bsearch(point.x)]
	var best := 0
	var best_d := INF
	for i in _centres.size():
		var d := _centres[i].distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = i
	return list[best]


## The islands' middles, and (when they all lie in a line across, as they do) the islands from
## west to east with the halfway points between them: nearest() was a big part of the island
## health checks, which count every animal and piece of litter.
static func _keep_centres(list: Array) -> void:
	_centres.clear()
	for region: RegionData in list:
		_centres.append(region.center)
	_across = list.duplicate()
	_across.sort_custom(func(a: RegionData, b: RegionData) -> bool: return a.center.x < b.center.x)
	_cuts.clear()
	_in_a_line = not _across.is_empty()
	for i in range(1, _across.size()):
		_in_a_line = _in_a_line and _across[i].center.y == _across[0].center.y and _across[i].center.x > _across[i - 1].center.x
		_cuts.append((_across[i - 1].center.x + _across[i].center.x) / 2.0)


static var _centres := PackedVector2Array()
static var _across: Array = []
static var _cuts := PackedFloat64Array()
static var _in_a_line := false


## Whether `point` is within `region`'s rowboat waters (less `margin`), so the ranger can reach it.
## Whether the ranger is on (or around) `region`. Islands they're not on are paused, so
## time spent on one island never costs progress on another.
static func ranger_on(tree: SceneTree, region: RegionData) -> bool:
	var ranger := ControlledBody.active(tree)
	return not ranger or not region or nearest(ranger.global_position) == region


## Pieces of litter the ranger must pick up on an island before its animals start coming back
## (or anything built there: a save from before this rule counts as helped).
const HELPED_AFTER := 10


## Whether the ranger has done something for `region` yet: picked up HELPED_AFTER pieces of
## litter there, or built something there (not counting the tent the game starts with). Until
## then no new animals arrive or settle: populations only grow because of the ranger.
static func helped(tree: SceneTree, region: RegionData) -> bool:
	if int(Inventory.picked_on.get(region.id, 0)) >= HELPED_AFTER:
		return true
	for building: Node in tree.get_nodes_in_group("buildings"):
		if building.data.id != &"tent" and not building.is_queued_for_deletion() and nearest(building.global_position) == region:
			return true
	return false


static func in_reach(region: RegionData, point: Vector2, margin := 0.0) -> bool:
	return point.distance_to(region.center) <= region.waters_radius - margin


static func is_discovered(region: RegionData) -> bool:
	return region.direction == &"" or _discovered.has(region.id)


static func discover(region: RegionData) -> void:
	_discovered[region.id] = true


## Undiscovers `region` (found before the fleet had the upgrade it needs).
static func forget(region: RegionData) -> void:
	_discovered.erase(region.id)


## The next undiscovered island that way, or null if that way is all explored.
static func next_undiscovered(direction: StringName) -> RegionData:
	for region: RegionData in all():  # sorted by order
		if region.direction == direction and not is_discovered(region):
			return region
	return null


## How many islands have been found (the Starting Island included).
static func discovered_count() -> int:
	return all().filter(func(r: RegionData) -> bool: return is_discovered(r)).size()


## Whether the fleet may find another island: one more than its level (Level 1 finds the 2nd
## island, Level 2 the 3rd...), so every island found has been helped before the next.
static func can_find_more() -> bool:
	return Fleet.level() >= discovered_count()


## The island next to `from` in `direction` (discovered or not; null = none that way). The
## islands lie in a line: Polar Ocean, Deep Sea, Kelp Forest, Starting Island, Mangrove Coast,
## Tropical Reef. An Exploration Ship only finds the island next to its own, so each step out
## needs a ship on the island before it.
static func next_from(from: RegionData, direction: StringName) -> RegionData:
	var line: Array[RegionData] = []
	for region: RegionData in all():  # sorted by order: nearest home first
		if region.direction == COLDER:
			line.push_front(region)
		elif region.direction == &"":
			line.append(region)
	for region: RegionData in all():
		if region.direction == WARMER:
			line.append(region)
	var at := line.find(from)
	if at < 0:
		return null
	var step := 1 if direction == WARMER else -1
	return line[at + step] if at + step >= 0 and at + step < line.size() else null


## Has an Exploration Ship established on its island (so you can explore on from there).
static func exploration_ready(tree: SceneTree, region: RegionData) -> bool:
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.action == &"explore" and nearest(building.global_position) == region:
			return true
	return false


## For the save file.
static func discovered_ids() -> Array:
	return _discovered.keys()


static func restore(ids: Array) -> void:
	_discovered.clear()
	for id in ids:
		_discovered[StringName(id)] = true
