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
static func nearest(point: Vector2) -> RegionData:
	var best: RegionData = null
	for region: RegionData in all():
		if not best or region.center.distance_to(point) < best.center.distance_to(point):
			best = region
	return best


## Whether `point` is within `region`'s rowboat waters (less `margin`), so the ranger can reach it.
## Whether the ranger is on (or around) `region`. Islands they're not on are paused, so
## time spent on one island never costs progress on another.
static func ranger_on(tree: SceneTree, region: RegionData) -> bool:
	var ranger := ControlledBody.active(tree)
	return not ranger or not region or nearest(ranger.global_position) == region


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
