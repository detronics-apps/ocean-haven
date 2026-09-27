class_name Regions
## The ocean's regions (data/regions/): which one a point is in, and which can be visited.


static var _all: Array[Resource] = []


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


## Whether the ranger can sail to `region` yet (and why not, if not).
static func why_locked(tree: SceneTree, region: RegionData) -> String:
	if region.locked:
		return "Coming later: " + region.unlock_hint
	if region.requires_building == &"":
		return ""
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.id == region.requires_building:
			return ""
	return region.unlock_hint
