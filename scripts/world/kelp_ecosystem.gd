class_name KelpEcosystem
extends Node2D
## The Kelp Forest's food web (MASTER_PLAN "Kelp Forest"): kelp beds on the island's shallow
## and mid water, each with its sea urchins. Every `tick_days` (real elapsed game time, so
## sleeping catches up) urchins graze and multiply, and kelp regrows where grazing is low.
## Kelp is never fixed by planting alone: while urchins are too many, it keeps declining.
## Runs once the island is discovered. Saved by SaveGame (to_dict / restore).

const BED_SCRIPT := preload("res://scripts/world/kelp_bed.gd")
const URCHIN := preload("res://data/animals/sea_urchin.tres")
## The ranger finds the urchins this close to a bed that has some.
const SPOT_RANGE := 72.0

## The region this island belongs to (by id), for health, reach and discovery.
@export var region_id: StringName = &"kelp_forest"
@export var tick_days := 0.25
@export_group("Beds")
## How many beds, and at least how far apart (px).
@export var bed_count := 18
@export var bed_spacing := 96.0
## A new island starts damaged: kelp health and urchins per bed (random in these ranges).
@export var start_health := Vector2(0.15, 0.4)
@export var start_urchins := Vector2(6.0, 10.0)
@export_group("Food web (per bed, per day)")
## Urchins multiply towards urchin_cap, faster where there's kelp to eat.
@export var urchin_growth := 0.5
@export var urchin_cap := 12.0
## Kelp eaten per urchin.
@export var graze := 0.02
## Kelp regrowth towards full (restoration adds `restore_boost`).
@export var regrow := 0.15
@export var restore_boost := 0.25
## Urchins drift in from nearby reefs now and then, so there are always a few.
@export var urchin_drift_in := 0.3
## A bed counts as overgrazed at this many urchins.
@export var overgrazed_at := 8.0
@export_group("Otters")
## No more than this many otters live within crowd_range of one habitat (otters need room
## to forage), so habitats crowded together share the same otters.
@export var crowd_max := 3
@export var crowd_range := 240.0
## Chance that a new otter is a pup born on the island (with 2+ grown otters), not a newcomer.
@export var pup_chance := 0.5
@export_group("Fish and birds")
## Kelp fish the forest supports per healthy bed (health at least healthy_bed_at).
@export var fish_per_bed := 0.5
@export var healthy_bed_at := 0.5
## Fish it takes to feed one cormorant; cormorants also need a full-grown tree each to nest in.
@export var fish_per_cormorant := 3
@export var cormorant_max := 4
const FISH := preload("res://data/animals/blue_rockfish.tres")
const CORMORANT := preload("res://data/animals/double_crested_cormorant.tres")

var _last_tick := -1.0


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_place_beds()
	GameClock.new_day.connect(func(_d: int) -> void:
		if Regions.is_discovered(region()):
			settle())


func region() -> RegionData:
	return load("res://data/regions/%s.tres" % region_id)


func beds() -> Array[KelpBed]:
	var list: Array[KelpBed] = []
	for child in get_children():
		if child is KelpBed:
			list.append(child)
	return list


## Kelp beds on the island's own water tiles (shallow and mid, not the open ocean),
## spread out, the same every time (so saved beds line up).
func _place_beds() -> void:
	var ground := get_parent().get_node_or_null("Ground") as TileMapLayer
	if not ground:
		return
	var cells: Array[Vector2i] = []
	for cell in ground.get_used_cells():
		var data := ground.get_cell_tile_data(cell)
		if data and not data.get_custom_data("walkable") and data.get_custom_data("terrain") in ["water", ""]:
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _noise(a) < _noise(b))
	var spots: Array[Vector2] = []
	for cell in cells:
		if spots.size() >= bed_count:
			break
		var spot := ground.map_to_local(cell) + ground.position - position
		if spots.all(func(s: Vector2) -> bool: return s.distance_to(spot) >= bed_spacing):
			spots.append(spot)
	for i in spots.size():
		var bed: KelpBed = BED_SCRIPT.new()
		bed.name = "Kelp%d" % (i + 1)
		bed.position = spots[i]
		bed.health = lerpf(start_health.x, start_health.y, _noise(Vector2i(i, 7)))
		bed.urchins = roundf(lerpf(start_urchins.x, start_urchins.y, _noise(Vector2i(i, 13))))
		add_child(bed)


static func _noise(c: Vector2i) -> float:
	return fposmod(sin(c.x * 12.9898 + c.y * 78.233) * 43758.5453, 1.0)


func _process(_delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	_spot_urchins()
	var now := GameClock.now()
	if _last_tick < 0.0:
		_last_tick = now
	# Catch up on time that passed (sleeping), but not forever.
	var ticks := 0
	while now - _last_tick >= tick_days and ticks < 32:
		tick(tick_days)
		_last_tick += tick_days
		ticks += 1
	if now - _last_tick >= tick_days:
		_last_tick = now


## Close to a bed with urchins: they're in the Journal.
func _spot_urchins() -> void:
	if Journal.has(URCHIN.id):
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	for bed in beds():
		if bed.urchin_count() > 0 and bed.global_position.distance_to(ranger.global_position) <= SPOT_RANGE:
			Journal.discover(URCHIN)
			return


## One step of the food web, `days` long.
func tick(days: float) -> void:
	_otters_eat(days)
	for bed in beds():
		var restoring := 1.0 if bed.restored_until > GameClock.now() else 0.0
		var food := 0.3 + 0.7 * bed.health
		var growth := urchin_growth * bed.urchins * (1.0 - bed.urchins / urchin_cap) * food
		bed.urchins += (growth + urchin_drift_in * (1.0 if bed.urchins < 1.0 else 0.0)) * days
		var eaten := graze * bed.urchins
		var grown := (regrow + restore_boost * restoring) * (1.0 - bed.health)
		bed.health += (grown - eaten) * days


## Each otter eats urchins from the beds it forages (near where it lives), most from the
## beds with most urchins.
func _otters_eat(days: float) -> void:
	for otter in otters():
		if otter.young or otter.injured or otter.tangled:
			continue
		var near := beds_near(otter.home(), otter.data.forage_range)
		var available: float = near.reduce(func(sum: float, b: KelpBed) -> float: return sum + b.urchins, 0.0)
		if available <= 0.0:
			continue
		var eat := minf(otter.data.urchins_per_day * days, available)
		for bed in near:
			bed.urchins -= eat * bed.urchins / available


## The island's otters (and any other urchin eaters) that aren't leaving.
func otters() -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data.urchins_per_day > 0.0 and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


func beds_near(point: Vector2, range: float) -> Array[KelpBed]:
	var list: Array[KelpBed] = []
	for bed in beds():
		if bed.global_position.distance_to(point) <= range:
			list.append(bed)
	return list


## Food for otters around `point`: its urchins, plus the other food healthy kelp shelters
## (crabs, snails, clams).
func food_at(point: Vector2, species: AnimalData) -> float:
	var food := 0.0
	for bed in beds_near(point, species.forage_range):
		food += bed.urchins + species.kelp_food * bed.health
	return food


## Every morning: otters settle at habitats where the forest can feed them (a newcomer,
## or a pup born on the island), and move away from ones where it can't. Habitats only
## offer the conditions; the ecosystem decides. At most one change per habitat a day.
func settle() -> void:
	var species: AnimalData = load("res://data/animals/sea_otter.tres")
	var homes: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.hosts == species.id and Regions.nearest(building.global_position).id == region_id \
				and not building.is_queued_for_deletion():
			homes.append(building)
	var all := otters()
	# Otters whose home was taken down find another with room, or move away.
	for otter in all:
		if not is_instance_valid(otter.home_area) or otter.home_area.is_queued_for_deletion():
			otter.home_area = null
			for home in homes:
				if home.room_for_animals() > 0:
					otter.home_area = home
					break
			if not otter.home_area:
				_move_away(otter, "its habitat was taken down and there's no other with room")
	for home in homes:
		var living := all.filter(func(o: Animal) -> bool: return o.home_area == home and not o.leaving)
		var crowd := all.filter(func(o: Animal) -> bool:
			return not o.leaving and o.home().distance_to(home.global_position) <= crowd_range).size()
		var food := food_at(home.global_position, species)
		if not living.is_empty() and food / maxf(crowd, 1) < species.food_needed:
			_move_away(living.back(), "there isn't enough food in the kelp around the %s" % home.data.display_name)
			continue
		if home.damaged or not home.upkeep_paid or home.room_for_animals() <= 0 or crowd >= crowd_max:
			continue
		if food / (crowd + 1) < species.food_needed:
			continue
		_new_otter(species, home, all)
		all = otters()
	# Fish follow the kelp, and cormorants the fish: one arrives or moves away a morning.
	_follow(FISH, fish_supported())
	_follow(CORMORANT, cormorants_supported())


## Kelp fish the forest can support now.
func fish_supported() -> int:
	return floori(beds().filter(func(b: KelpBed) -> bool: return b.health >= healthy_bed_at).size() * fish_per_bed)


## Cormorants the fish can feed, if there are full-grown trees to nest in.
func cormorants_supported() -> int:
	var fish := living(FISH).size()
	return mini(mini(fish / fish_per_cormorant, cormorant_max), Arrivals.grown_trees(get_tree(), region()))


## The island's animals of `species` (not ones moving away).
func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


## One more of `species` arrives, or one moves away, towards `target`.
func _follow(species: AnimalData, target: int) -> void:
	var now := living(species)
	if now.size() > target:
		var going: Animal = now.back()
		if going.data.nests_in_trees:
			going.set_nest_tree(null)
		going.leaving = true
		if species.flies:
			get_tree().call_group("hud", "show_toast", "A %s has flown off: there aren't enough fish for it." % species.display_name)
		return
	if now.size() >= target:
		return
	var animal: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = GameClock.now() - species.grow_days  # grown: saved like the island's own
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	if species.flies:
		animal.home_radius = 360.0
		animal.position = region().center + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))
		get_tree().call_group("hud", "show_toast",
			"A %s has come to fish in the Kelp Forest: there are enough fish now!" % species.display_name)
	else:
		# At a healthy bed with few fish yet.
		var best: KelpBed = null
		var best_score := -INF
		for bed in beds():
			var crowd := now.filter(func(f: Animal) -> bool: return f.home().distance_to(bed.global_position) < 48.0).size()
			var score := bed.health - 0.3 * crowd
			if score > best_score:
				best_score = score
				best = bed
		animal.home_radius = 60.0
		animal.position = best.global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-16.0, 16.0))
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())


func _move_away(otter: Animal, why: String) -> void:
	otter.leaving = true
	otter.home_area = null
	get_tree().call_group("hud", "show_toast", "A sea otter has moved away: %s." % why)


## A newcomer from along the coast, or (with 2+ grown otters here) a pup.
func _new_otter(species: AnimalData, home: Building, all: Array[Animal]) -> void:
	var grown := all.filter(func(o: Animal) -> bool: return not o.young)
	var pup := grown.size() >= 2 and randf() < pup_chance
	var otter: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	otter.data = species
	otter.home_area = home
	otter.home_radius = species.adult_home_radius
	if pup:
		var parent: Animal = grown.pick_random()
		otter.young = true
		otter.born_at = GameClock.now()
		otter.position = parent.global_position
	else:
		otter.born_at = GameClock.now() - species.grow_days  # grown: counted and saved like the island's own
		otter.position = Terrain.nearest(get_tree(), home.global_position, ["water", ""])
	var world := get_tree().get_first_node_in_group("player").get_parent()
	world.add_child(otter)
	world.move_child(otter, world.get_node("Player").get_index())
	get_tree().call_group("hud", "show_toast", ("A sea otter pup was born near your %s!" if pup
		else "A sea otter has settled at your %s: the kelp around it can feed it.") % home.data.display_name)


## Everything about the forest, 0..1 on average (the kelp's condition).
func kelp_health() -> float:
	var list := beds()
	if list.is_empty():
		return 0.0
	return list.reduce(func(sum: float, b: KelpBed) -> float: return sum + b.health, 0.0) / list.size()


func urchin_total() -> int:
	return beds().reduce(func(sum: int, b: KelpBed) -> int: return sum + b.urchin_count(), 0)


## For the save file: each bed's health and urchins, by name.
func to_dict() -> Dictionary:
	var saved := {"last_tick": _last_tick, "beds": {}}
	for bed in beds():
		saved.beds[String(bed.name)] = [bed.health, bed.urchins, bed.restored_until]
	return saved


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	var saved_beds: Dictionary = saved.get("beds", {})
	for bed in beds():
		var entry: Array = saved_beds.get(String(bed.name), [])
		if entry.size() >= 3:
			bed.health = float(entry[0])
			bed.urchins = float(entry[1])
			bed.restored_until = float(entry[2])
