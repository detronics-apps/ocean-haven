class_name Births
## How a new animal comes to an island (the islands decide when and how many, as before; this
## only decides how it appears). Never out of nowhere:
## - born: a grown one of its kind goes to where the newcomer belongs (its sanctuary, habitat,
##   zone...), and the young one appears beside it there, follows it round while it grows up
##   (AnimalData.young_sprites, or just its size), then goes its own way;
## - drifting in (AnimalData.drifts_in: fish, clams, squid, whose young drift in the open sea):
##   it swims in from the island's edge to where it belongs.

## Seconds a parent has to get there before the young one is born where it is.
const DUE_SECONDS := 25.0


## Turns `animal`, a grown newcomer the island has just added at the spot it belongs, into one
## that's born there (or drifts in). `note` is the card's "why", shown when it appears.
static func bring(animal: Animal, region: RegionData, note: String) -> void:
	var tree := animal.get_tree()
	var spot := animal.global_position
	var parent: Animal = null if animal.data.drifts_in else parent_for(animal, region)
	if not parent:
		_drift_in(animal, region, spot)
		tree.call_group("hud", "animal_returned", animal.data, note, region)
		return
	animal.young = true
	animal.born_at = GameClock.now()
	animal.parent = parent
	animal.hide_until_born()
	parent.expect(animal, spot, note, region)


## A grown one of `animal`'s kind on `region` to be its parent: the nearest that's free (not
## caught, hurt, leaving, visiting or already expecting), or null.
static func parent_for(animal: Animal, region: RegionData) -> Animal:
	var best: Animal = null
	var best_distance := INF
	for other: Animal in animal.get_tree().get_nodes_in_group("animals"):
		if other == animal or other.data != animal.data or other.young or other.leaving or other.visiting:
			continue
		if other.tangled or other.injured or other.is_expecting() or Regions.nearest(other.global_position) != region:
			continue
		var distance := other.global_position.distance_to(animal.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


## In from the island's edge, swimming (or flying) to `spot`.
static func _drift_in(animal: Animal, region: RegionData, spot: Vector2) -> void:
	var away := (spot - region.center).normalized()
	if away == Vector2.ZERO:
		away = Vector2.from_angle(randf() * TAU)
	var edge := region.center + away * region.waters_radius * 0.9
	if not animal.data.flies:
		edge = Terrain.nearest(animal.get_tree(), edge, Array(animal.data.habitat_terrain), 8)
	animal.global_position = edge
	animal.set_home(spot)


## Every young one still waiting for its parent is born now, beside it (after a sleep, and in
## tests).
static func born_now(tree: SceneTree) -> void:
	for animal: Animal in tree.get_nodes_in_group("animals"):
		if animal.is_expecting():
			animal.give_birth_now()
