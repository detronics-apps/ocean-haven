class_name DeepEcosystem
extends Node2D
## The Deep Sea (a child of its island): we can't protect what we don't understand. The deep
## water round the hook is split into dark areas (DeepSector) nobody knows yet. Instruments
## build up knowledge every day, island-wide: how many there are counts, never where.
## - Hydrophone Buoys listen quietly; each sperm whale's clicks make them learn more.
## - Deep Cameras learn faster, but their lamps light up the dark (anglerfish glow lets them
##   use less); baited, faster still, but the bait draws sixgill sharks in.
## - A submarine dive from the Deep-Ocean Outpost reveals one area fast (the marked one).
## The more light and noise, the less quiet water: whales and anglerfish move away (never
## below 1) and the giant squid stays hidden. Mapped areas show their habitat and the lost
## fishing gear hidden there; a sixgill shark with a hook in its jaw shows some early.
## Like the other islands it ticks every `tick_days` while the ranger is on the island.

@export var region_id := &"deep_sea"
@export var tick_days := 0.25

@export_group("Knowledge")
## Knowledge a day (1 = one whole area) from each instrument.
@export var hydrophone_rate := 0.12
## Each working sperm whale adds this share to every hydrophone.
@export var whale_boost := 0.25
@export var camera_rate := 0.25
@export var bait_rate := 0.4
## A submarine dive reveals this much of its area.
@export var dive_reveal := 0.7

@export_group("Quiet")
## Light and noise that leaves no quiet water at all.
@export var quiet_capacity := 6.0
@export var hydrophone_noise := 0.1
## A camera's lamp (less per level), and the extra commotion of bait.
@export var camera_light := 1.0
@export var bait_noise := 0.5
## Each anglerfish lets cameras use this much less light (down to `light_floor`).
@export var angler_light_cut := 0.15
@export var light_floor := 0.4
@export var dive_noise := 1.5
@export var dive_noise_days := 1.0
## A patrol boat working over a dark area (where the animals are), and one kept away from
## them (near the shore, outside every dark area).
@export var patrol_noise := 0.75
@export var patrol_noise_away := 0.15
@export var outpost_noise := 0.5

@export_group("Animals")
## Whales need this much quiet water to stay; anglerfish leave above `angler_light_max` light.
@export var whale_quiet := 0.5
@export var whale_max := 4
@export var angler_light_max := 2.0
@export var angler_max := 5
## Each baited camera draws this many extra sixgills in.
@export var sharks_per_bait := 2
## The giant squid: a camera watching the known squid canyon this long in quiet water.
@export var squid_quiet := 0.7
@export var squid_days := 2.0
## Each morning a sixgill (when they aren't crowding round bait) may surface with a hook from
## lost gear in a dark area.
@export var hook_chance := 0.5
## Each morning before gear marking, new lost gear may sink in an unprotected area.
@export var new_gear_chance := 0.1

const WHALE := preload("res://data/animals/sperm_whale.tres")
const SQUID := preload("res://data/animals/giant_squid.tres")
const ANGLER := preload("res://data/animals/anglerfish.tres")
const SHARK := preload("res://data/animals/sixgill_shark.tres")
const SECTOR_SCRIPT := preload("res://scripts/world/deep_sector.gd")
const OIL := preload("res://data/items/oil_patch.tres")
const CARGO := preload("res://data/items/lost_cargo_module.tres")
## The sectors' habitats: the one inside the hook first, then the open water round it.
const LAYOUT := [&"squid_canyon", &"whale_ground", &"angler_slope", &"shark_ledge", &"shipping_lane",
	&"whale_ground", &"angler_slope", &"shark_ledge"]
## Lost gear hidden at the start: area index -> item.
const START_GEAR := {1: &"lost_ghost_net", 2: &"lost_longline", 3: &"lost_longline"}
const GEAR_COUNT := &"deep_gear"
const GEAR_MARKING := &"gear_marking"
const MAPPED_FLAG := &"deep_mapped"
const CARGO_FLAG := &"cargo_located"

var _ground: TileMapLayer
var _last_tick := -1.0
var _last_seen := -1.0
var _seeded := false
var _dive_noise_until := -1.0
## How long a camera has watched the known squid canyon in quiet water so far (days).
var _squid_watch := 0.0
var _squid_found := false
## Oil spill: the area it's coming from (-1 = none) and whether its source is contained.
var _spill_source := -1
var _spill_contained := false


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_ground = get_parent().get_node("Ground")
	_place_sectors()
	GameClock.new_day.connect(func(_d: int) -> void:
		if Regions.is_discovered(region()) and Regions.ranger_on(get_tree(), region()):
			_morning())


func region() -> RegionData:
	return load("res://data/regions/%s.tres" % region_id)


func sectors() -> Array[DeepSector]:
	var list: Array[DeepSector] = []
	for child in get_children():
		if child is DeepSector:
			list.append(child)
	return list


## The dark areas: one in the deep water inside the hook, the rest spread round the island in
## open water, each covering the deep-water cells near it. The same every time.
func _place_sectors() -> void:
	var spots: Array[Vector2] = [_inner_basin()]
	var outside := LAYOUT.size() - 1
	for i in outside:
		var direction := Vector2.RIGHT.rotated(TAU * i / outside - PI / 2.0)
		spots.append(_open_water_along(direction))
	for i in spots.size():
		var sector: DeepSector = SECTOR_SCRIPT.new()
		sector.name = "Sector%d" % (i + 1)
		sector.habitat = LAYOUT[i]
		sector.radius = 110.0 if i == 0 else 150.0
		sector.gear_item = START_GEAR.get(i, &"")
		sector.position = spots[i]
		add_child(sector)
		for cell in _deep_cells_within(spots[i], sector.radius):
			sector.cells.append(cell - spots[i])


## The middle of the deep water the hook curls round.
func _inner_basin() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	var rect := _ground.get_used_rect()
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, y)
			if _ground.get_cell_tile_data(cell) == null and _enclosed(cell, rect):
				sum += _ground.map_to_local(cell)
				n += 1
	return sum / n if n > 0 else Vector2.ZERO


## Deep water with land or shallows on both sides, across and along (inside the hook).
func _enclosed(cell: Vector2i, rect: Rect2i) -> bool:
	var hits := 0
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var at := cell + step
		while rect.has_point(at) and _ground.get_cell_tile_data(at) == null:
			at += step
		if rect.has_point(at):
			hits += 1
	return hits >= 4


## A spot in open deep water out from the island along `direction`, within the rowboat's reach.
func _open_water_along(direction: Vector2) -> Vector2:
	var reach := region().waters_radius - 130.0
	var distance := 300.0
	while distance < reach:
		var spot := direction * distance
		if _deep_cells_within(spot, 64.0).size() >= 13:
			return direction * minf(distance + 90.0, reach)
		distance += 16.0
	return direction * reach


## Deep water (mid water or no tile at all) within `range` of `spot` (cell centres, local).
func _deep_cells_within(spot: Vector2, within: float) -> Array[Vector2]:
	var list: Array[Vector2] = []
	var centre := _ground.local_to_map(spot)
	var r := ceili(within / 32.0)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var cell := centre + Vector2i(dx, dy)
			var at := _ground.map_to_local(cell)
			if at.distance_to(spot) <= within and _terrain(cell) in ["sea", ""]:
				list.append(at)
	return list


func _terrain(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


func _process(_delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	if not _seeded:
		_seed()
	var now := GameClock.now()
	if _last_tick < 0.0:
		_last_tick = now
	if _last_seen >= 0.0 and now > _last_seen and not Regions.ranger_on(get_tree(), region()):
		_last_tick += now - _last_seen  # paused while the ranger is away
	_last_seen = now
	var ticks := 0
	while now - _last_tick >= tick_days and ticks < 32:
		tick(tick_days)
		_last_tick += tick_days
		ticks += 1
	if now - _last_tick >= tick_days:
		_last_tick = now


func tick(days: float) -> void:
	learn(knowledge_rate() * days)
	_watch_for_squid(days)
	_check_gear()
	settle()


# --- Knowledge ---

func _buildings(which: Callable) -> Array[Building]:
	var list: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if not building.is_queued_for_deletion() and not building.damaged and Regions.nearest(building.global_position).id == region_id and which.call(building):
			list.append(building)
	return list


func _of(id: StringName) -> Array[Building]:
	return _buildings(func(b: Building) -> bool: return b.data.id == id)


## Knowledge the instruments add a day (1 = one whole area), island-wide.
func knowledge_rate() -> float:
	var rate := 0.0
	var whales := working(WHALE).size()
	for buoy in _of(&"hydrophone_buoy"):
		rate += hydrophone_rate * (1.0 + whale_boost * whales)
	for camera in _of(&"deep_camera"):
		rate += bait_rate if camera.baited() else camera_rate
	return rate


## Adds `amount` of knowledge, to `target` or else to the least-known dark areas in turn.
func learn(amount: float, target: DeepSector = null) -> void:
	while amount > 0.0001:
		var sector := target
		if not sector or sector.known():
			var dark := sectors().filter(func(s: DeepSector) -> bool: return not s.known())
			if dark.is_empty():
				return
			dark.sort_custom(func(a: DeepSector, b: DeepSector) -> bool: return a.knowledge > b.knowledge)
			sector = dark[0]  # finish the best-known one first, so areas open one by one
		var step := minf(amount, 1.0 - sector.knowledge)
		sector.knowledge += step
		amount -= step
		target = null
		if sector.known():
			_mapped(sector)


func _mapped(sector: DeepSector) -> void:
	var note := "%s is mapped: %s." % [sector.label(), sector.describe()]
	if sector.gear_item != &"" and not sector.gear_found:
		_surface_gear(sector)
		note += " Lost fishing gear was found there: collect it by boat before it catches anything."
	if sector.habitat == &"squid_canyon":
		note += " Keep the deep quiet and leave a camera watching: giant squid may come."
	get_tree().call_group("hud", "show_toast", note)
	settle()


func known_count(habitat: StringName = &"") -> int:
	return sectors().filter(func(s: DeepSector) -> bool: return s.known() and (habitat == &"" or s.habitat == habitat)).size()


## How well the deep is understood, 0..1 (all the areas' knowledge together).
func understanding() -> float:
	var list := sectors()
	return list.reduce(func(sum: float, s: DeepSector) -> float: return sum + s.knowledge, 0.0) / maxf(list.size(), 1)


# --- Light and noise ---

## How much light the cameras give off (anglerfish glow lets them use less).
func light() -> float:
	var cut := maxf(1.0 - angler_light_cut * working(ANGLER).size(), light_floor)
	var total := 0.0
	for camera in _of(&"deep_camera"):
		total += camera_light * cut
	return total


## All the light and noise in the deep: lamps, bait, buoys, dives, patrol boats and the Outpost.
func disturbance() -> float:
	var total := light() + hydrophone_noise * _of(&"hydrophone_buoy").size()
	total += bait_noise * _of(&"deep_camera").filter(func(c: Building) -> bool: return c.baited()).size()
	total += outpost_noise * _of(&"deep_ocean_outpost").size()
	for boat in _buildings(func(b: Building) -> bool: return b.has_node("PatrolBoat")):
		total += patrol_noise if _over_dark_area(boat.global_position) else patrol_noise_away
	if _dive_noise_until > GameClock.now():
		total += dive_noise
	return total


## Whether `point` is over one of the dark areas' deep water (where the animals live).
func _over_dark_area(point: Vector2) -> bool:
	for sector in sectors():
		for cell in sector.cells:
			if sector.to_global(cell).distance_to(point) < 24.0:
				return true
	return false


## The share of the deep that is still quiet and dark, 0..1.
func quiet() -> float:
	return clampf(1.0 - disturbance() / quiet_capacity, 0.0, 1.0)


# --- Animals ---

func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


func working(species: AnimalData) -> Array[Animal]:
	return living(species).filter(func(a: Animal) -> bool: return not a.tangled and not a.injured)


func _sanctuaries(habitat: StringName) -> int:
	var n := 0
	for marker in _of(&"deep_sanctuary"):
		var sector := sector_at(marker.global_position)
		if sector and sector.known() and sector.habitat == habitat:
			n += 1
	return n


## The area `point` is in (null = none).
func sector_at(point: Vector2) -> DeepSector:
	for sector in sectors():
		if sector.global_position.distance_to(point) <= sector.radius:
			return sector
	return null


func whales_supported(quiet_share := -1.0) -> int:
	if (quiet() if quiet_share < 0.0 else quiet_share) < whale_quiet:
		return 1
	return clampi(1 + known_count(&"whale_ground") + _sanctuaries(&"whale_ground"), 1, whale_max)


func anglers_supported() -> int:
	if light() > angler_light_max:
		return 1
	return clampi(1 + 2 * known_count(&"angler_slope") + _sanctuaries(&"angler_slope"), 1, angler_max)


func sharks_supported() -> int:
	var baited := _of(&"deep_camera").filter(func(c: Building) -> bool: return c.baited()).size()
	return 1 + mini(known_count(&"shark_ledge"), 1) + _sanctuaries(&"shark_ledge") + sharks_per_bait * baited


func settle_now() -> void:
	if Regions.is_discovered(region()):
		settle()


## Each species takes one step towards what the deep supports now.
func settle() -> void:
	_follow(WHALE, whales_supported())
	_follow(ANGLER, anglers_supported())
	_follow(SHARK, sharks_supported())


func _follow(species: AnimalData, target: int) -> void:
	target = maxi(target, 1)  # no species ever disappears
	var now := living(species)
	if now.size() > target:
		var going: Array = now.filter(func(a: Animal) -> bool: return not a.tangled)
		if not going.is_empty():
			(going.back() as Animal).leaving = true
		return
	if now.size() >= target:
		return
	if not Regions.helped(get_tree(), region()):
		return  # nothing new comes until the ranger has helped the island (Regions.helped)
	_spawn(species, _home_spot(species))
	get_tree().call_group("hud", "animal_returned", species, "It has come to the deep: %s" % _why(species), region())


func _why(species: AnimalData) -> String:
	match species:
		WHALE:
			return "the water is quiet, and you've mapped where whales feed."
		ANGLER:
			return "the dark slopes are mapped and the cameras' lamps aren't too bright."
	return "there's food on the ledges%s." % (", and bait at your cameras" if _of(&"deep_camera").any(func(c: Building) -> bool: return c.baited()) else "")


## Where a newcomer of `species` turns up: in an area of its habitat (known ones first).
func _home_spot(species: AnimalData) -> Vector2:
	var habitat: StringName = {WHALE: &"whale_ground", ANGLER: &"angler_slope", SHARK: &"shark_ledge", SQUID: &"squid_canyon"}[species]
	var homes := sectors().filter(func(s: DeepSector) -> bool: return s.habitat == habitat)
	homes.sort_custom(func(a: DeepSector, b: DeepSector) -> bool: return a.knowledge > b.knowledge)
	var home: DeepSector = homes[0] if not homes.is_empty() else sectors()[0]
	if species == SHARK:  # visitors drawn in by bait gather at the cameras
		var bait := _of(&"deep_camera").filter(func(c: Building) -> bool: return c.baited())
		if not bait.is_empty() and living(SHARK).size() > mini(known_count(&"shark_ledge"), 1):
			return _water_near((bait.pick_random() as Building).global_position)
	return _water_near(home.global_position)


func _water_near(point: Vector2) -> Vector2:
	return Terrain.nearest(get_tree(), point + Vector2(randf_range(-40, 40), randf_range(-40, 40)), [""])


func _spawn(species: AnimalData, spot: Vector2) -> Animal:
	var animal: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	animal.home_radius = {WHALE: 200.0, ANGLER: 50.0, SQUID: 70.0}.get(species, 160.0)
	animal.position = spot
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	return animal


## When the ranger first finds the island every species is there but struggling: a sperm whale
## caught in lost fishing line at the surface, one anglerfish, one sixgill shark, and the giant
## squid somewhere unseen. Every area is dark, and lost gear lies hidden in three of them.
func _seed() -> void:
	_seeded = true
	var list := sectors()
	if list.size() < LAYOUT.size():
		return
	var whale := _spawn(WHALE, _water_near(list[1].global_position))
	whale.tangle(load("res://data/items/fishing_line.tres"))
	_spawn(ANGLER, _water_near(list[2].global_position))
	_spawn(SHARK, _water_near(list[3].global_position))


## The giant squid: once the squid canyon is known, a camera left watching it in quiet water
## for `squid_days` finally films one. After that it stays (it hides, never leaves).
func _watch_for_squid(days: float) -> void:
	if _squid_found:
		return
	if known_count(&"squid_canyon") > 0 and quiet() >= squid_quiet and not _of(&"deep_camera").is_empty():
		_squid_watch += days
	else:
		_squid_watch = 0.0
	if _squid_watch >= squid_days:
		_squid_found = true
		_spawn(SQUID, _home_spot(SQUID))
		get_tree().call_group("hud", "show_toast", "Your camera filmed a giant squid in the canyon inside the hook! Hardly anyone has ever seen one alive. Go and photograph it while it's near the surface.")


func squid_found() -> bool:
	return _squid_found


# --- Lost gear ---

## Lost gear in `sector` floats up where the ranger can collect it by boat.
func _surface_gear(sector: DeepSector) -> void:
	sector.gear_found = true
	var spawner := _spawner()
	if spawner:
		spawner.spawn_at(load("res://data/items/%s.tres" % sector.gear_item), _water_near(sector.global_position), true)


## Surfaced gear that has been collected is gone for good (collecting it counts towards gear
## marking: the items count as `GEAR_COUNT`).
func _check_gear() -> void:
	for sector in sectors():
		if sector.gear_item == &"" or not sector.gear_found or _gear_debris(sector):
			continue
		sector.gear_item = &""
		sector.gear_found = false
		if Fleet.count_of(GEAR_COUNT) >= START_GEAR.size() and not Fleet.has_flag(GEAR_MARKING):
			Fleet.mark(GEAR_MARKING)
			get_tree().call_group("hud", "show_toast", "From the gear you've recovered, researchers have worked out where the lost nets and lines come from. Fishing boats now mark and recover their gear: no new ghost nets or fishing line drift in on any island.")


func _gear_debris(sector: DeepSector) -> Debris:
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.item.id == sector.gear_item and not debris.is_queued_for_deletion() \
				and debris.global_position.distance_to(sector.global_position) <= sector.radius + 160.0:
			return debris
	return null


## Lost gear still in the deep (hidden, or surfaced and not yet collected).
func gear_left() -> int:
	return sectors().filter(func(s: DeepSector) -> bool: return s.gear_item != &"").size()


func _spawner() -> LitterSpawner:
	for s: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(s.area.get_center()).id == region_id:
			return s
	return null


## Each morning: a sixgill may surface with a hook from lost gear in a dark area, new lost gear
## may sink (until gear marking), an oil spill spreads, and the objective moves on.
func _morning() -> void:
	var crowding := living(SHARK).size() > 1 + mini(known_count(&"shark_ledge"), 1) + _sanctuaries(&"shark_ledge")
	var hidden := sectors().filter(func(s: DeepSector) -> bool: return s.gear_item != &"" and not s.gear_found)
	if not hidden.is_empty() and not working(SHARK).is_empty() and not crowding and randf() < hook_chance:
		var sector: DeepSector = hidden.pick_random()
		_surface_gear(sector)
		learn(0.25, sector)
		Journal.record_gift(SHARK)
		get_tree().call_group("hud", "show_toast", "A sixgill shark came up with a hook in its jaw: there's lost fishing line near %s! It has floated up: collect it by boat." % sector.label())
	if not Fleet.has_flag(GEAR_MARKING) and randf() < new_gear_chance:
		var open := sectors().filter(func(s: DeepSector) -> bool: return s.gear_item == &"" and _of(&"deep_sanctuary").all(
			func(m: Building) -> bool: return sector_at(m.global_position) != s))
		if not open.is_empty():
			(open.pick_random() as DeepSector).gear_item = [&"lost_ghost_net", &"lost_longline"].pick_random()
	_spread_oil()
	_objective()


# --- Oil spill (the Deep Sea's rare event) ---

## RareEvents calls this when an oil spill strikes: oil from a hidden source starts coming up in
## one of the areas and spreads every morning until the Outpost contains it.
func oil_spill(patches: int) -> int:
	var list := sectors()
	_spill_source = randi() % list.size()
	_spill_contained = false
	list[_spill_source].oily = true
	for i in patches:
		_add_oil(list[_spill_source])
	return 1


func _spread_oil() -> void:
	if _spill_source < 0 or _spill_contained:
		return
	var list := sectors()
	var source := list[_spill_source]
	for i in 2:
		_add_oil(source)
	# Spreading: the next area round the island is reached too.
	var next := list[(_spill_source % (list.size() - 1)) + 1]
	if not next.oily and randf() < 0.5:
		next.oily = true
		get_tree().call_group("hud", "show_toast", "The oil is spreading to %s. Find the source with a submarine dive, then contain it from the Outpost." % next.label())
	for sector in list:
		if sector.oily and sector != source:
			_add_oil(sector)


func _add_oil(sector: DeepSector) -> void:
	var spawner := _spawner()
	var lying := get_tree().get_nodes_in_group("debris").filter(func(d: Debris) -> bool: return d.item == OIL and Regions.nearest(d.global_position).id == region_id).size()
	if spawner and lying < 14:
		spawner.spawn_at(OIL, _water_near(sector.global_position), true)


func spill_active() -> bool:
	return _spill_source >= 0 and not _spill_contained


# --- Health ---

func eco_score(factor: HealthFactor, projected := {}) -> float:
	match factor.target:
		&"quiet":  # quiet enough for the giant squid counts in full
			return clampf(projected.get("quiet", quiet()) / squid_quiet, 0.0, 1.0)
		&"gear":
			return 1.0 - float(projected.get("gear", gear_left())) / START_GEAR.size()
		&"squid":
			return 1.0 if projected.get("squid", _squid_found) else 0.0
	return clampf(eco_count(factor.target, projected) / float(maxi(factor.amount, 1)), 0.0, 1.0)


func eco_count(target: StringName, projected := {}) -> float:
	if projected.has(target):
		return float(projected[target])
	match target:
		&"knowledge":
			return roundi(understanding() * 100.0)
		&"gear":
			return gear_left()
		&"quiet":
			return quiet()
		&"squid":
			return 1.0 if _squid_found else 0.0
	return 0.0


## What a hint-giver says when this factor is what's holding the island back (People: a ranger
## who keeps coming back stuck gets a concrete clue, not the same story again).
func advice(factor: HealthFactor) -> String:
	match factor.target:
		&"quiet":
			var sources: Array = []  # [noise, what it is]
			var over := _buildings(func(b: Building) -> bool: return b.has_node("PatrolBoat") and _over_dark_area(b.global_position)).size()
			if over > 0:
				sources.append([patrol_noise * over, "your %d patrol boat%s working over the dark areas: move %s near the shore, or take %s down" % [
					over, "" if over == 1 else "s", "it" if over == 1 else "them", "it" if over == 1 else "them"]])
			if light() > 0.0:
				sources.append([light(), "the camera lamps: fewer cameras (anglerfish glow lets them use less light)"])
			var baited := _of(&"deep_camera").filter(func(c: Building) -> bool: return c.baited()).size()
			if baited > 0:
				sources.append([bait_noise * baited, "the bait at your cameras: it brings the sharks crowding in"])
			if _dive_noise_until > GameClock.now():
				sources.append([dive_noise, "the submarine dive (that settles down after a day)"])
			if sources.is_empty():
				return "The deep's as quiet as you can make it. Give the whales time."
			sources.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			return "Listen: the loudest thing down there now is %s. The whales will stay once it's quiet." % sources[0][1]
		&"knowledge":
			return "Some dark areas are still a mystery: look for the dashed yellow circles. A hydrophone buoy or a camera close to one learns about it every day, and a dive from the Outpost maps it at once."
		&"gear":
			return "There's still lost gear down in the mapped areas. Sail over them in your boat and bring it up."
	return ""


func eco_describe(factor: HealthFactor) -> String:
	match factor.target:
		&"knowledge":
			return "%s: %d of %d areas mapped (%d%% known)" % [factor.text, known_count(), sectors().size(), roundi(understanding() * 100.0)]
		&"gear":
			var left := gear_left()
			return "%s: %s" % [factor.text, "all recovered" if left == 0 else "%d piece(s) still down there (map the dark areas to find them)" % left]
		&"quiet":
			return "%s: %d%% (lamps, bait, dives and boats all disturb the deep)" % [factor.text, roundi(quiet() * 100.0)]
		&"squid":
			return "%s: %s" % [factor.text, "found!" if _squid_found else "not seen yet"]
	return factor.text


## Where the deep settles if everything stays as it is: instruments keep mapping it, and the
## animals follow the quiet and the mapped habitats.
func project() -> Dictionary:
	var rate := knowledge_rate()
	var all_known := rate > 0.0
	var count := func(habitat: StringName) -> int:
		return sectors().filter(func(s: DeepSector) -> bool: return s.habitat == habitat and (s.known() or all_known)).size()
	var calm := quiet() if _dive_noise_until <= GameClock.now() else clampf(1.0 - (disturbance() - dive_noise) / quiet_capacity, 0.0, 1.0)
	var whales := 1 if calm < whale_quiet else clampi(1 + count.call(&"whale_ground") + _sanctuaries(&"whale_ground"), 1, whale_max)
	var anglers := 1 if light() > angler_light_max else clampi(1 + 2 * count.call(&"angler_slope") + _sanctuaries(&"angler_slope"), 1, angler_max)
	var baited := _of(&"deep_camera").filter(func(c: Building) -> bool: return c.baited()).size()
	var squid := _squid_found or (all_known and calm >= squid_quiet and not _of(&"deep_camera").is_empty())
	return {"knowledge": 100 if all_known else roundi(understanding() * 100.0), "quiet": calm, "gear": gear_left(),
		"squid": squid, WHALE.id: whales, ANGLER.id: anglers, SQUID.id: 1 if squid else 0,
		SHARK.id: 1 + mini(count.call(&"shark_ledge"), 1) + _sanctuaries(&"shark_ledge") + sharks_per_bait * baited}


# --- Objective ---

@export_group("Objective")
@export var mapped_needed := 6
@export var mapped_health := 0.7


## Once 6 areas are mapped and the island is at 70 %, the cargo search can find the module.
func _objective() -> void:
	if Fleet.has_flag(MAPPED_FLAG):
		return
	if known_count() >= mapped_needed and IslandHealth.of(get_tree(), region()) >= mapped_health:
		Fleet.mark(MAPPED_FLAG)
		get_tree().call_group("hud", "show_toast", "The deep is mapped and healthy! Somewhere in the old shipping lane lies a lost cargo module: send a Cargo Search from the Deep-Ocean Outpost.")


func _cargo_sector() -> DeepSector:
	for sector in sectors():
		if sector.habitat == &"shipping_lane":
			return sector
	return sectors()[0]


# --- The Outpost's missions ---

const MISSIONS := [&"deep_dive", &"acoustic_survey", &"gear_search", &"disturbance_check", &"habitat_survey",
	&"cargo_search", &"contain_spill"]


func handles(effect: StringName) -> bool:
	return effect in MISSIONS


func run_mission(mission: MissionData) -> Dictionary:
	var list := sectors()
	match mission.effect:
		&"deep_dive":
			_dive_noise_until = GameClock.now() + dive_noise_days
			var target: DeepSector = null
			for sector in list:
				if sector.dive_marked and not sector.known() and not sector.oily:
					target = sector
			if not target:
				var dark := list.filter(func(s: DeepSector) -> bool: return not s.known() and not s.oily)
				if dark.is_empty():
					var source := list[_spill_source] if spill_active() else null
					if source:  # with everything mapped, a dive finds where the oil is coming from
						return {"found": [source], "detail": "The submarine traced the oil to its source in %s (marked). Contain it from the Outpost." % source.label()}
					return {"found": [], "detail": "Every area is mapped already: there's nothing left in the dark to dive for."}
				dark.sort_custom(func(a: DeepSector, b: DeepSector) -> bool: return a.knowledge > b.knowledge)
				target = dark[0]
			target.dive_marked = false
			learn(dive_reveal, target)
			var oil_note := ""
			if spill_active():
				oil_note = " It also traced the oil to its source in %s: contain it from the Outpost." % list[_spill_source].label()
			return {"found": [target], "detail": "The submarine dived into %s (marked): it's %d%% known now.%s The dive was noisy: the deep is less quiet for a day." % [
				target.label(), floori(target.knowledge * 100.0), oil_note]}
		&"acoustic_survey":
			var noisy := quiet() < whale_quiet
			return {"found": living(WHALE), "detail": "%d sperm whale(s) heard (marked). Quiet water: %d%%. %s" % [living(WHALE).size(), roundi(quiet() * 100.0),
				"It's too noisy for more whales: fewer lamps, bait, dives or boats." if noisy
				else ("Map the whale feeding grounds and more whales will come." if known_count(&"whale_ground") < 2 else "The whales have what they need.")]}
		&"gear_search":
			var surfaced := list.filter(func(s: DeepSector) -> bool: return s.gear_item != &"" and s.gear_found)
			var hidden := list.filter(func(s: DeepSector) -> bool: return s.gear_item != &"" and not s.gear_found)
			var marks: Array = []
			for sector: DeepSector in surfaced:
				var piece := _gear_debris(sector)
				if piece:
					marks.append(piece)
			return {"found": marks, "detail": "%d piece(s) of lost gear are floating, waiting to be collected (marked). %s" % [marks.size(),
				("%d more lie hidden in dark areas: map them, or watch for a sixgill with a hook in its jaw." % hidden.size()) if hidden else "No more lost gear is hidden in the deep."]}
		&"disturbance_check":
			var cameras := _of(&"deep_camera")
			var baited := cameras.filter(func(c: Building) -> bool: return c.baited())
			return {"found": cameras, "detail": "Quiet water: %d%%. Light from %d camera(s) (marked)%s, %d hydrophone(s) (nearly silent)%s. Whales need %d%% quiet, the giant squid %d%%; anglerfish leave if the lamps are too bright." % [
				roundi(quiet() * 100.0), cameras.size(), (", %d baited (busy with sharks)" % baited.size()) if baited else "",
				_of(&"hydrophone_buoy").size(), ", a submarine dive's noise for a day" if _dive_noise_until > GameClock.now() else "",
				roundi(whale_quiet * 100.0), roundi(squid_quiet * 100.0)]}
		&"habitat_survey":
			var known := list.filter(func(s: DeepSector) -> bool: return s.known() and s.habitat != &"shipping_lane")
			var unprotected := known.filter(func(s: DeepSector) -> bool: return _of(&"deep_sanctuary").all(func(m: Building) -> bool: return sector_at(m.global_position) != s))
			return {"found": unprotected, "detail": ("%d mapped habitat(s) have no sanctuary yet (marked): a Deep-Sea Sanctuary there stops new lost gear and lets one more of its animals settle." % unprotected.size()) if unprotected
				else ("Every mapped habitat is protected." if known else "No habitat is mapped yet: map the dark areas first.")}
		&"cargo_search":
			if not Fleet.has_flag(MAPPED_FLAG):
				return {"found": [], "detail": "The cargo module can't be found yet: map at least %d dark areas and bring the island to %d%% health first (%d mapped)." % [
					mapped_needed, roundi(mapped_health * 100.0), known_count()]}
			Fleet.mark(CARGO_FLAG)
			var sector := _cargo_sector()
			var spawner := _spawner()
			var module: Debris = spawner.spawn_at(CARGO, _water_near(sector.global_position), true) if spawner else null
			return {"found": [module] if module else [sector], "detail": "The submarine found the lost cargo module in the old shipping lane and floated it up on lifting bags (marked). Sail out and tow it in with your boat."}
		&"contain_spill":
			if not spill_active():
				return {"found": [], "detail": "There's no oil spill to contain."}
			_spill_contained = true
			for sector in list:
				sector.oily = false
			var oil := get_tree().get_nodes_in_group("debris").filter(func(d: Debris) -> bool: return d.item == OIL and Regions.nearest(d.global_position).id == region_id)
			return {"found": oil, "detail": "The source is sealed: no more oil is coming up. %d patch(es) are left on the water (marked): sail your boat through them to clean them up." % oil.size()}
	return {}


func to_dict() -> Dictionary:
	var saved := {"last_tick": _last_tick, "seeded": _seeded, "dive_noise": _dive_noise_until, "squid_watch": _squid_watch,
		"squid": _squid_found, "spill": _spill_source, "contained": _spill_contained, "sectors": {}}
	for sector in sectors():
		saved.sectors[String(sector.name)] = [sector.knowledge, String(sector.gear_item), sector.gear_found, sector.dive_marked, sector.oily]
	return saved


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	_seeded = bool(saved.get("seeded", false))
	_dive_noise_until = float(saved.get("dive_noise", -1.0))
	_squid_watch = float(saved.get("squid_watch", 0.0))
	_squid_found = bool(saved.get("squid", false))
	_spill_source = int(saved.get("spill", -1))
	_spill_contained = bool(saved.get("contained", false))
	var saved_sectors: Dictionary = saved.get("sectors", {})
	for sector in sectors():
		var entry: Array = saved_sectors.get(String(sector.name), [])
		if entry.size() >= 5:
			sector.knowledge = float(entry[0])
			sector.gear_item = StringName(entry[1])
			sector.gear_found = bool(entry[2])
			sector.dive_marked = bool(entry[3])
			sector.oily = bool(entry[4])
