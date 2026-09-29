class_name IslandHealth
## Each island's health, 0..1 (its Ocean Impact): the weighted average of its
## RegionData.health factors — how clean its waters are and how many healthy animals
## live there (100 % = no litter in reach, no hurt or caught animals, fully populated). Islands without factors have no health yet (-1). Ground colours follow it
## (see tint), from muted when damaged to vibrant when healthy.

## Ground colour at 0 health (muted grey-blue); healthy ground shows its own colours.
const DAMAGED_TINT := Color(0.66, 0.7, 0.78)


## `region`'s health 0..1, or -1 if it has no health factors yet.
static func of(tree: SceneTree, region: RegionData) -> float:
	if region.health.is_empty():
		return -1.0
	var total := 0.0
	var weights := 0.0
	for factor: HealthFactor in region.health:
		total += score(tree, region, factor) * factor.weight
		weights += factor.weight
	return total / weights if weights > 0.0 else -1.0


## Whether a building with this id exists anywhere.
static func built(tree: SceneTree, id: StringName) -> bool:
	return tree.get_nodes_in_group("buildings").any(func(b: Node) -> bool: return b.data.id == id)


## How far along one factor is, 0..1.
static func score(tree: SceneTree, region: RegionData, factor: HealthFactor) -> float:
	var amount := float(maxi(factor.amount, 1))
	match factor.kind:
		&"clean":
			return clampf(1.0 - count(tree, region, factor) / amount, 0.0, 1.0)
		&"help", &"animals", &"kelp":
			return clampf(count(tree, region, factor) / amount, 0.0, 1.0)
		&"balance":
			var eco := ecosystem(tree, region)
			if not eco:
				return 0.0
			var beds: int = maxi(eco.beds().size(), 1)
			var overgrazed := 1.0 - 2.0 * float(count(tree, region, factor)) / beds
			var some := clampf(eco.urchin_total() / (beds * 0.2), 0.0, 1.0)  # a healthy forest keeps some
			return clampf(minf(overgrazed, some), 0.0, 1.0)
	return 0.0


## The island's own ecosystem node (e.g. the Kelp Forest's), or null.
static func ecosystem(tree: SceneTree, region: RegionData) -> Node:
	for eco: Node in tree.get_nodes_in_group("ecosystems"):
		if eco.region_id == region.id:
			return eco
	return null


## The raw number behind a factor: litter pieces about, times helped, animals living there.
static func count(tree: SceneTree, region: RegionData, factor: HealthFactor) -> int:
	match factor.kind:
		&"clean":
			return tree.get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
				# Only litter the rowboat can reach counts (drifting litter further out doesn't).
				return (not d.is_queued_for_deletion() and Regions.nearest(d.global_position) == region
					and Regions.in_reach(region, d.global_position)
					and (d.item.id == factor.target if factor.target != &"" else d.item.is_litter))).size()
		&"help":
			return Journal.helped_count(factor.target)
		&"kelp":  # the kelp's condition, in percent
			var eco := ecosystem(tree, region)
			return roundi(eco.kelp_health() * 100.0) if eco else 0
		&"balance":  # overgrazed beds
			var eco := ecosystem(tree, region)
			return eco.beds().filter(func(b: Node) -> bool: return b.urchins >= eco.overgrazed_at).size() if eco else 0
		&"animals":
			return tree.get_nodes_in_group("animals").filter(func(a: Node2D) -> bool:
				# Healthy residents only: hurt or caught ones count again once helped, and a
				# visiting dolphin (dolphin tracking) is only passing through.
				return (a.data.id == factor.target and not a.leaving and not a.injured and not a.tangled
					and not a.visiting and Regions.nearest(a.global_position) == region)).size()
	return 0


## "Litter in the water: 4" / "Turtles living here: 3 / 6" / "Turtles living here: 18
## (6 for full health)" for the Journal: animals are counted in full, not capped.
static func describe(tree: SceneTree, region: RegionData, factor: HealthFactor) -> String:
	var n := count(tree, region, factor)
	if factor.kind == &"clean":
		return "%s: %s" % [factor.text, "none" if n == 0 else str(n)]
	if factor.kind == &"kelp":
		return "%s: %d%% (%d%% for full health)" % [factor.text, n, factor.amount]
	if factor.kind == &"balance":
		var eco := ecosystem(tree, region)
		return "%s: %d overgrazed bed(s), %d urchins in all" % [factor.text, n, eco.urchin_total() if eco else 0]
	if factor.kind == &"animals" and n >= factor.amount:
		return "%s: %d (%d for full health)" % [factor.text, n, factor.amount]
	return "%s: %d / %d" % [factor.text, mini(n, factor.amount), factor.amount]


## Colours every island's ground by its health.
static func tint(tree: SceneTree) -> void:
	for ground: TileMapLayer in tree.get_nodes_in_group("ground"):
		var middle := ground.to_global(ground.map_to_local(ground.get_used_rect().get_center()))
		var health := of(tree, Regions.nearest(middle))
		ground.modulate = Color.WHITE if health < 0.0 else DAMAGED_TINT.lerp(Color.WHITE, health)
