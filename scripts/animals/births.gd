class_name Births
## How a new animal comes to an island (the islands decide when and how many, as before; this
## only decides how it appears). Never out of nowhere:
## - born: a grown one of its kind goes to where the newcomer belongs (its sanctuary, habitat,
##   zone...), and the young one appears beside it there, follows it round while it grows up
##   (AnimalData.young_sprites, or just its size), then goes its own way;
## - drifting in (AnimalData.drifts_in: fish, clams, squid, whose young drift in the open sea):
##   it swims in from the island's edge to where it belongs.
## The island's limit says how many there can be, never how fast: each parent has young again
## only once its last ones are a step on (`busy`: hatched for egg-layers, out of the baby stage
## for the born-live), and drifters come one per species every DRIFT_GAP days. Several parents
## can breed at once, so more grown ones fill the room faster.

## Seconds a parent has to get there before the young one is born where it is.
const DUE_SECONDS := 25.0
## Days between two of a drifting species coming to an island (3 a day at most).
const DRIFT_GAP := 1.0 / 3.0

## "region:species" -> GameClock.now() when one last drifted in (not saved).
static var _drifted := {}


## Whether one more of `species` can come to `region` now: a drifter not too soon after the
## last, a parent that's free (`parent_for`), or, with no grown one of its kind there yet,
## the first drifting in.
static func can_have(tree: SceneTree, species: AnimalData, region: RegionData) -> bool:
	if species.drifts_in:
		return GameClock.now() - float(_drifted.get(_key(species, region), -INF)) >= DRIFT_GAP
	var any_grown := false
	for other: Animal in tree.get_nodes_in_group("animals"):
		if other.data != species or other.young or other.leaving or other.visiting or Regions.nearest(other.global_position) != region:
			continue
		any_grown = true
		if _free(other):
			return true
	return not any_grown


## Its last young are still too little for it to have more: eggs that haven't hatched yet (it
## is expecting), a young one born less than incubation_days ago (egg-layers), or one still
## in its baby stage (the born-live: half of grow_days).
static func busy(parent: Animal) -> bool:
	if parent.is_expecting():
		return true
	var wait := parent.data.incubation_days if parent.data.lays_eggs else parent.data.grow_days / 2.0
	for child: Animal in parent.get_tree().get_nodes_in_group("animals"):
		if child.parent == parent and child.young and GameClock.now() - child.born_at < wait - 0.001:
			return true
	return false


static func _free(other: Animal) -> bool:
	return not other.tangled and not other.injured and not busy(other)


static func _key(species: AnimalData, region: RegionData) -> String:
	return "%s:%s" % [region.id, species.id]


## Turns `animal`, a grown newcomer the island has just added at the spot it belongs, into one
## that's born there (or drifts in). `note` is the card's "why", shown when it appears.
static func bring(animal: Animal, region: RegionData, note: String) -> void:
	var tree := animal.get_tree()
	var spot := animal.global_position
	var parent: Animal = null if animal.data.drifts_in else parent_for(animal, region)
	if not parent:
		_drifted[_key(animal.data, region)] = GameClock.now()
		_drift_in(animal, region, spot)
		tree.call_group("hud", "animal_returned", animal.data, note, region)
		return
	animal.young = true
	animal.born_at = GameClock.now()
	animal.parent = parent
	animal.hide_until_born()
	parent.expect(animal, spot, note, region)


## A grown one of `animal`'s kind on `region` to be its parent: the nearest that's free (not
## caught, hurt, leaving, visiting or `busy` with its last young), or null.
static func parent_for(animal: Animal, region: RegionData) -> Animal:
	var best: Animal = null
	var best_distance := INF
	for other: Animal in animal.get_tree().get_nodes_in_group("animals"):
		if other == animal or other.data != animal.data or other.young or other.leaving or other.visiting:
			continue
		if not _free(other) or Regions.nearest(other.global_position) != region:
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
