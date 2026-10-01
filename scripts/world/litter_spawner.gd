class_name LitterSpawner
extends Node
## Litter keeps washing in: every `interval` seconds a piece of litter drifts into
## the sea around the island (within the rowboat's reach) or washes up on a beach, until
## `max_litter` pieces are out there. Floating litter slowly drifts in towards the island. It always appears away from the ranger, so it never pops up in view.

const DEBRIS_SCENE := preload("res://scenes/world/debris.tscn")

@export var interval := 20.0
@export var max_litter := 15
## Chance that a new piece floats at sea (the rest wash up on beaches).
@export var at_sea_chance := 0.75
## Chance that what drifts in at sea is an oil patch (from passing ships) instead of litter,
## once a building with id `oil_needs` exists (mid-game: the Deep Sea's Deep-Ocean Outpost
## brings the oil-spill equipment) ...
@export var oil_chance := 0.08
@export var oil_needs: StringName = &"deep_ocean_outpost"
## ... while there are fewer than this many oil patches in the area.
@export var max_oil := 2
const OIL := preload("res://data/items/oil_patch.tres")
const PLASTIC_BOTTLE := &"plastic_bottle"
## Area searched for spots (the waters around the home island). Spots are also always
## within its island's rowboat waters (less `reach_margin`), so every piece can be reached.
@export var area := Rect2(-900, -600, 1800, 1200)
@export var reach_margin := 80.0
@export var min_distance_from_ranger := 320.0
## Each morning, litter that entangles (nets, line, bags) this close to an animal that can
## get caught may catch one: at most this many a day in this area. Clean it up to prevent it.
@export var tangle_range := 320.0
@export var tangles_per_day := 1
## Patrol boats need to leave quiet water: with less than this share of the island's water
## free of them, a boat now and then hits a turtle or dolphin (hurt, never killed: a
## Rescue mission helps it). The less free water, the likelier.
@export var min_free_water := 0.65

var _items: Array[Resource] = DataFiles.load_all("res://data/items").filter(
	func(item: ItemData) -> bool: return item.is_litter)
var _time := 0.0
## GameClock.now() when the ranger left this island (-1 = they're here).
var _away_since := -1.0


func _enter_tree() -> void:
	add_to_group("litter_spawner")


func _ready() -> void:
	GameClock.new_day.connect(func(_d: int) -> void:
		entangle()
		busy_waters())


## Litter that entangles, left near an animal that can get caught, catches it (at most
## tangles_per_day). The litter is then round the animal: freeing it collects it. Returns
## the animals caught.
func entangle() -> Array[Animal]:
	var caught: Array[Animal] = []
	if not Regions.ranger_on(get_tree(), Regions.nearest(area.get_center())):
		return caught  # paused while the ranger's away
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if caught.size() >= tangles_per_day:
			break
		if not debris.item.entangles or debris.is_queued_for_deletion() or not area.has_point(debris.global_position):
			continue
		var animal := _catchable_near(debris.global_position)
		if animal:
			animal.tangle(debris.item)
			debris.remove()
			caught.append(animal)
			get_tree().call_group("hud", "show_toast", "A %s is caught in a %s!\nFind it and help it (the rescue boat can find it for you)." % [
				animal.data.display_name, debris.item.display_name.to_lower()])
	return caught


func _catchable_near(point: Vector2) -> Animal:
	var best: Animal = null
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if not animal.data.can_tangle or animal.tangled or animal.young or animal.leaving:
			continue
		var distance := animal.global_position.distance_to(point)
		if distance <= tangle_range and (not best or distance < best.global_position.distance_to(point)):
			best = animal
	return best


## Too much of the water is patrolled: maybe one boat-shy animal gets hit (never killed).
## Returns it, or null.
func busy_waters(chance := -1.0) -> Animal:
	var region := Regions.nearest(area.get_center())
	var free := PatrolBoat.free_water_share(get_tree(), region)
	if free >= min_free_water:
		return null
	if chance < 0.0:  # up to 60% a morning, as the quiet water shrinks
		chance = clampf((min_free_water - free) / 0.15, 0.0, 1.0) * 0.6
	if not Regions.ranger_on(get_tree(), region) or randf() >= chance:
		return null
	var at_risk := get_tree().get_nodes_in_group("animals").filter(func(a: Animal) -> bool:
		return (a.data.boat_shy_distance > 0.0 and not a.young and not a.injured and not a.leaving
			and Regions.nearest(a.global_position) == region))
	if at_risk.is_empty():
		return null
	var hit: Animal = at_risk.pick_random()
	hit.injure()
	get_tree().call_group("hud", "show_toast",
		"A patrol boat hit a %s! Patrol boats cover %d%% of the water, leaving turtles and dolphins too little quiet water. Move or take some away, and send a Rescue mission." % [
		hit.data.display_name.to_lower(), roundi((1.0 - free) * 100.0)])
	return hit


## A random piece of litter at `spot` (e.g. dug up by a crab), unless there's
## already enough litter about. Returns it, or null.
func wash_up_at(spot: Vector2, floating: bool) -> Debris:
	if _litter_in_area() >= max_litter:
		return null
	return spawn_at(_items.pick_random(), spot, floating)


## Buried litter turned up at `spot` (the ranger's shovel), however much is already about.
## It floats: the sand it was in is gone. Returns it.
func dig_up_at(spot: Vector2) -> Debris:
	return spawn_at(_items.pick_random(), spot, true)


func _process(delta: float) -> void:
	var region := Regions.nearest(area.get_center())
	if not Regions.ranger_on(get_tree(), region):
		if _away_since < 0.0:
			_away_since = GameClock.now()
		return  # paused while the ranger's on another island ...
	if _away_since >= 0.0:  # ... then a little litter has washed in while they were away
		var pieces := mini(floori((GameClock.now() - _away_since) * region.away_litter_per_day), region.away_litter_max)
		_away_since = -1.0
		for i in mini(pieces, max_litter - _litter_in_area()):
			spawn_one()
	_time += delta
	if _time >= interval:
		_time = 0.0
		spawn_one()


## Washes `count` pieces up onto its beaches (a storm), whatever is already about.
func wash_up_beaches(count: int) -> void:
	var beach := _sand_spots()
	if beach.is_empty():
		return
	for i in count:
		spawn_at(_items.pick_random(), beach.pick_random(), false)


## Fills its area up to `count` pieces (a new game starts with plenty to clean up).
func fill(count: int) -> void:
	var usual := max_litter
	max_litter = count
	for attempt in count * 2:
		if _litter_in_area() >= count:
			break
		spawn_one()
	max_litter = usual


## Adds one piece of litter somewhere suitable. Returns it, or null if there's
## already enough litter or no spot was found.
func spawn_one() -> Debris:
	var item: ItemData = _items.pick_random()
	if Fleet.reusable_bottles():
		# No new plastic bottles drift in, so there's less litter overall (old ones can still be
		# dug up or washed ashore by a storm: those use the full mix).
		if item.id == PLASTIC_BOTTLE:
			return null
		if _litter_in_area() >= roundi(max_litter * (1.0 - 1.0 / _items.size())):
			return null
	if _litter_in_area() >= max_litter:
		return null
	var at_sea := randf() < at_sea_chance
	var spot: Variant = _free_spot(at_sea)
	if spot == null:
		return null
	var oil := at_sea and randf() < oil_chance and IslandHealth.built(get_tree(), oil_needs) and _in_area(func(d: Debris) -> bool: return d.item == OIL) < max_oil
	return spawn_at(OIL if oil else item, spot, at_sea)


## A pollution survey searches further than the ranger can see: `count` more pieces of
## hidden, missed litter turn up (however much is already about). Returns them.
func reveal_hidden(count: int) -> Array[Debris]:
	var found: Array[Debris] = []
	for i in count:
		var at_sea := randf() < at_sea_chance
		var spot: Variant = _free_spot(at_sea)
		if spot == null:
			spot = _free_spot(not at_sea)
		if spot != null:
			found.append(spawn_at(_items.pick_random(), spot, at_sea))
	return found


## A spot for new litter at sea (within reach) or on a beach, away from the ranger; or null.
func _free_spot(at_sea: bool) -> Variant:
	var ranger := ControlledBody.active(get_tree())
	var beach := [] if at_sea else _sand_spots()
	for attempt in 40:
		var spot: Vector2
		if at_sea:
			var region := Regions.nearest(area.get_center())
			spot = region.center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * (region.waters_radius - reach_margin)
			if not area.has_point(spot) or Terrain.at(get_tree(), spot) not in ["", "water"]:
				continue
		else:
			if beach.is_empty():
				return null
			spot = beach.pick_random()
		if ranger and spot.distance_to(ranger.global_position) < min_distance_from_ranger:
			continue
		return spot
	return null


## Litter inside this spawner's area (each island's waters have their own limit).
func _litter_in_area() -> int:
	return _in_area(func(_d: Debris) -> bool: return true)


func _in_area(which: Callable) -> int:
	return get_tree().get_nodes_in_group("debris").filter(
		func(d: Debris) -> bool: return area.has_point(d.global_position) and which.call(d)).size()


## Centres of every beach (sand) tile on the islands — beaches are too small a
## share of the sea to find by random guessing.
func _sand_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			var spot := ground.to_global(ground.map_to_local(cell))
			if area.has_point(spot) and ground.get_cell_tile_data(cell).get_custom_data("terrain") == "sand":
				spots.append(spot)
	return spots


## Adds a washed-in piece at an exact spot (also used when loading a save).
func spawn_at(item: ItemData, spot: Vector2, floating: bool) -> Debris:
	var debris: Debris = DEBRIS_SCENE.instantiate()
	debris.item = item
	debris.floating = floating
	debris.spawned = true
	debris.position = spot
	var world := get_parent()
	world.add_child(debris)
	world.move_child(debris, world.get_node("Player").get_index())  # under the ranger and boat
	return debris
