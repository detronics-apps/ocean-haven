class_name PolarEcosystem
extends Node2D
## The Polar Ocean (a child of its island): polar life follows the seasons, and nothing can be
## fixed once. Every `cycle_days` the ice freezes and thaws:
## - freezing: the water round the old ice freezes ring by ring, and corridors of ice join the
##   floes (a boat keeps the water near it open);
## - frozen, then thawing: the seasonal ice melts back ring by ring, to the old, thick ice at
##   the floes' cores (which lasts all year, unless a breakup breaks some off);
## - open water.
## Ringed seals raise pups in Seal Pupping Zones, which need ice that lasts until the thaw ends:
## on seasonal ice the pups go into the water early and fewer seals settle. Polar bears rest on
## rock (Quiet Den Areas) and stay when the freeze joins the floes. Arctic cod follow the ice,
## and seals and terns follow the cod. Arctic terns nest on rock in the thaw and fly south in
## the freeze, visiting the ranger's other healthy islands on the way. The skua circles where
## something needs help. Like the other islands it only runs while the ranger is here.

@export var region_id := &"arctic_ocean"
@export var tick_days := 0.125
## One whole ice season: freeze, frozen, thaw, open water.
@export var cycle_days := 3.0
## How many rings of water round the old ice freeze at the peak.
@export var max_rings := 3
## Water this close to a boat doesn't freeze, and while it's freezing a boat leaves a lane of
## open water behind it for the rest of the season (boats break the thin new ice).
@export var boat_clear := 64.0

@export_group("Animals")
@export var seals_per_cod := 2
## More seals than this crowd the ice and eat the cod down (the runaway).
@export var seals_crowd := 9
## Seasonal ice frozen at the last peak, per cod it feeds.
@export var ice_per_cod := 80
@export var cod_max := 10
## The share of the floes the freeze must join for polar bears to reach the seals.
@export var corridor_needed := 0.75
@export var bear_max := 3
@export var balanced_at := 0.7
@export var drill_days := 3.0

const SEAL := preload("res://data/animals/ringed_seal.tres")
const BEAR := preload("res://data/animals/polar_bear.tres")
const COD := preload("res://data/animals/arctic_cod.tres")
const TERN := preload("res://data/animals/arctic_tern.tres")
const SKUA := preload("res://data/animals/arctic_skua.tres")
const ICE_TILE := Vector2i(4, 0)
const BALANCED_FLAG := &"polar_balanced"
const CORE_FLAG := &"ice_core_drilled"
## Phases of the cycle, as shares of it: freezing until 0.375 (a ring each eighth), frozen
## until 0.5, thawing until 0.75 (a ring each twelfth), then open water.
const FROZEN_FROM := 0.375
const THAW_FROM := 0.5
const OPEN_FROM := 0.75

var _ground: TileMapLayer
var _last_tick := -1.0
var _last_seen := -1.0
var _seeded := false
## How far into the current ice season it is (days, 0..cycle_days). The island starts in open
## water, late in a season.
var _season := 2.7
## Each water cell round the old ice: which ring it freezes in (1 = next to the old ice).
var _ring := {}
## Every cell's tile as the island was made (to put water back when ice melts).
var _base := {}
## The island's old ice and rock cells as made, and which floe each belongs to.
var _floe_of := {}
var _floe_count := 0
## Old ice broken off by a breakup (water until the ice is frozen again).
var _broken := {}
## Pupping zones whose ice melted this season (by cell), and how many floes the last freeze
## joined (share of what it could join), and the seasonal ice frozen at that peak.
var _failed := {}
var _corridor := 0.0
var _possible := 1.0
var _peak_ice := 0
var _drilled := 0.0
var _terns_last := 1
var _phase_was := &""
## Water a boat has broken through this freeze: it stays open until the thaw.
var _wake := {}
var _wake_check := 0.0


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_ground = get_parent().get_node("Ground")
	_survey_island()


func region() -> RegionData:
	return load("res://data/regions/%s.tres" % region_id)


func _terrain(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


## Works out, once, the island as made: its floes (old ice and rock, joined), and the rings of
## water round the old ice that freeze each season.
func _survey_island() -> void:
	var land: Array[Vector2i] = []
	var frontier: Array[Vector2i] = []
	for cell in _ground.get_used_cells():
		_base[cell] = _ground.get_cell_atlas_coords(cell)
		var kind := _terrain(cell)
		if kind in ["ice", "rock"]:
			land.append(cell)
		if kind == "ice":
			frontier.append(cell)
	for cell in land:
		if not _floe_of.has(cell):
			_fill_floe(cell, _floe_count)
			_floe_count += 1
	var ring := 0
	var seen := {}
	for cell in frontier:
		seen[cell] = true
	while ring < max_rings and not frontier.is_empty():
		ring += 1
		var next: Array[Vector2i] = []
		for cell in frontier:
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other: Vector2i = cell + step
				if seen.has(other) or not _base.has(other) or not _terrain(other) in ["water", ""]:
					continue
				seen[other] = true
				_ring[other] = ring
				next.append(other)
		frontier = next
	_possible = maxf(_joined_share(_full_freeze(false)), 0.01)


func _fill_floe(start: Vector2i, id: int) -> void:
	var todo: Array[Vector2i] = [start]
	_floe_of[start] = id
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other: Vector2i = cell + step
			if not _floe_of.has(other) and _terrain(other) in ["ice", "rock"]:
				_floe_of[other] = id
				todo.append(other)


# --- The season ---

## Where in the season it is: 0..1.
func phase() -> float:
	return fposmod(_season, cycle_days) / cycle_days


func phase_name() -> StringName:
	var p := phase()
	if p < FROZEN_FROM:
		return &"freezing"
	if p < THAW_FROM:
		return &"frozen"
	if p < OPEN_FROM:
		return &"thawing"
	return &"open"


## How many rings of water are frozen at this point in the season.
func rings_now() -> int:
	var p := phase()
	if p < FROZEN_FROM:
		return mini(floori(p / (FROZEN_FROM / max_rings)) + 1, max_rings)
	if p < THAW_FROM:
		return max_rings
	if p < OPEN_FROM:
		return maxi(max_rings - 1 - floori((p - THAW_FROM) / ((OPEN_FROM - THAW_FROM) / max_rings)), 0)
	return 0


## For the HUD gauge: "freezing", with how long until the next change.
func status_note() -> String:
	var days_left := 0.0
	var p := phase()
	for edge: float in [FROZEN_FROM, THAW_FROM, OPEN_FROM, 1.0]:
		if p < edge:
			days_left = (edge - p) * cycle_days
			break
	var next: String = {&"freezing": "frozen", &"frozen": "thaw", &"thawing": "open water", &"open": "freeze"}[phase_name()]
	return "%s (%s in %s)" % [{&"freezing": "Freezing", &"frozen": "Frozen", &"thawing": "Thawing", &"open": "Open water"}[phase_name()],
		next, Missions.real_time(days_left * GameClock.DAY_LENGTH)]


func _process(delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	if not _seeded:
		_seed()
	_wake_check -= delta
	if _wake_check <= 0.0:
		_wake_check = 0.5
		_break_ice()
	var now := GameClock.now()
	if _last_tick < 0.0:
		_last_tick = now
	if _last_seen >= 0.0 and now > _last_seen and not Regions.ranger_on(get_tree(), region()):
		_last_tick += now - _last_seen  # paused while the ranger is away: the season waits too
	_last_seen = now
	var ticks := 0
	while now - _last_tick >= tick_days and ticks < 32:
		tick(tick_days)
		_last_tick += tick_days
		ticks += 1
	if now - _last_tick >= tick_days:
		_last_tick = now


func tick(days: float) -> void:
	var before := phase()
	_season = fposmod(_season + days, cycle_days)
	if phase() < before:
		_new_season()
	apply_ice()
	var name := phase_name()
	if name != _phase_was:
		_phase_changed(name)
		_phase_was = name
	_check_zones()
	_drill(days)
	settle()
	_guide_skua()
	_objective()


## A new season starts (the freeze): this season's failures are forgotten.
func _new_season() -> void:
	_failed.clear()


## While it freezes, boats break the thin new ice: the water round them stays open this season.
func _break_ice() -> void:
	if phase() >= THAW_FROM:
		return
	for spot in _boat_spots():
		var centre := _ground.local_to_map(_ground.to_local(spot))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var cell := centre + Vector2i(dx, dy)
				if _ring.has(cell) and _ground.to_global(_ground.map_to_local(cell)).distance_to(spot) < boat_clear:
					_wake[cell] = true


func _phase_changed(name: StringName) -> void:
	match name:
		&"freezing":
			_terns_south()
			get_tree().call_group("hud", "show_toast", "The Polar Ocean is freezing: ice is spreading out from the floes. Keep boats out of the channels between them, so the ice can join them up.")
		&"frozen":
			_broken.clear()  # broken-off ice freezes back over
			apply_ice()
			_measure_freeze()
			get_tree().call_group("hud", "show_toast", "The ice is at its thickest: %s" % (
				"the floes are joined, and polar bears can reach the seals." if corridor_score() >= 1.0
				else "some floes are still apart (the corridor check shows where the boats are in the way)."))
		&"thawing":
			_wake.clear()
			_terns_north()
			get_tree().call_group("hud", "show_toast", "The thaw has begun: the seasonal ice is melting back to the old ice. The Arctic terns are back from the south!")
		&"open":
			get_tree().call_group("hud", "show_toast", "Open water: only the old, thick ice is left. The next freeze comes soon.")


## Puts every cell in the state the season calls for: old ice is ice (unless broken off),
## rings of water freeze up to `rings_now()`, the rest is water. Water near a boat doesn't
## freeze; ice under the ranger on foot doesn't melt until they step off.
func apply_ice() -> void:
	var rings := rings_now()
	var boats := _boat_spots()
	var ranger := ControlledBody.active(get_tree())
	var on_foot := ranger.global_position if ranger and not ranger is Boat else Vector2.INF
	for cell: Vector2i in _base:
		var base: Vector2i = _base[cell]
		var was_ice := base == ICE_TILE
		var want: bool
		if was_ice:
			want = not _broken.has(cell)
		elif _ring.has(cell):
			want = _ring[cell] <= rings and not _wake.has(cell)
		else:
			continue
		var is_ice := _ground.get_cell_atlas_coords(cell) == ICE_TILE
		if want == is_ice:
			continue
		var at := _ground.to_global(_ground.map_to_local(cell))
		if want and boats.any(func(b: Vector2) -> bool: return b.distance_to(at) < boat_clear):
			continue  # a boat keeps it open
		if not want and on_foot.distance_to(at) < 24.0:
			continue
		if _built_on(cell, at):
			continue
		var atlas := ICE_TILE if want else base
		_ground.set_cell(cell, 0, atlas)
		SaveGame.record_tile(_ground, cell, atlas)


func _boat_spots() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for boat: Node2D in get_tree().get_nodes_in_group("boat") + get_tree().get_nodes_in_group("busy_boats"):
		if Regions.nearest(boat.global_position).id == region_id:
			spots.append(boat.global_position)
	return spots


## Docks and other buildings standing in the water keep their cell as it is (pupping zones and
## drill sites stand on the ice and go with it).
func _built_on(cell: Vector2i, at: Vector2) -> bool:
	var world_cell := Terrain.cell_of(at)
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.rect().has_point(world_cell) and not building.data.id in [&"seal_pupping_zone", &"ice_core_drill"]:
			return true
	return false


## What a full freeze would look like with the boats where they are (`with_boats`): the set of
## frozen or land cells.
func _full_freeze(with_boats := true) -> Dictionary:
	var boats: Array = _boat_spots() if with_boats else []
	var land := {}
	for cell: Vector2i in _floe_of:
		if not _broken.has(cell):
			land[cell] = true
	for cell: Vector2i in _ring:
		if with_boats and _wake.has(cell):
			continue
		var at := _ground.to_global(_ground.map_to_local(cell))
		if not boats.any(func(b: Vector2) -> bool: return b.distance_to(at) < boat_clear):
			land[cell] = true
	return land


## The share of the floes joined together in the biggest stretch of `land`.
func _joined_share(land: Dictionary) -> float:
	var seen := {}
	var best := 0
	for start: Vector2i in land:
		if seen.has(start):
			continue
		var floes := {}
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			if _floe_of.has(cell):
				floes[_floe_of[cell]] = true
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other: Vector2i = cell + step
				if land.has(other) and not seen.has(other):
					seen[other] = true
					todo.append(other)
		best = maxi(best, floes.size())
	return float(best) / maxi(_floe_count, 1)


## At the peak of the freeze: how well the ice joined the floes, and how much seasonal ice there
## is for the cod.
func _measure_freeze() -> void:
	var land := {}
	var seasonal := 0
	for cell: Vector2i in _base:
		var kind := _terrain(cell)
		if kind in ["ice", "rock"]:
			land[cell] = true
			if _ring.has(cell):
				seasonal += 1
	_corridor = _joined_share(land)
	_peak_ice = seasonal


## How well the last freeze joined the floes, 0..1 (1 = as well as it can).
func corridor_score() -> float:
	return clampf(_corridor / _possible, 0.0, 1.0)


# --- Zones, drilling ---

func _buildings(id: StringName) -> Array[Building]:
	var list: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if not building.is_queued_for_deletion() and building.data.id == id and Regions.nearest(building.global_position).id == region_id:
			list.append(building)
	return list


func _on_ice(building: Building) -> bool:
	return Terrain.at(get_tree(), building.global_position) == "ice"


## Whether `building` stands on old ice (it lasts all season).
func on_old_ice(building: Building) -> bool:
	var cell := _ground.local_to_map(_ground.to_local(building.global_position))
	return _base.get(cell, Vector2i(-1, -1)) == ICE_TILE and not _broken.has(cell)


func _key(building: Building) -> String:
	return "%d,%d" % [building.cell.x, building.cell.y]


## A pupping zone whose ice has melted (or broken off) loses this season's pups.
func _check_zones() -> void:
	for zone in _buildings(&"seal_pupping_zone"):
		if _on_ice(zone) or _failed.has(_key(zone)):
			continue
		_failed[_key(zone)] = true
		get_tree().call_group("hud", "show_toast", "The ice under a Seal Pupping Zone has melted before the pups were ready: they've gone into the water early. Move the zone onto old ice (the ice survey shows where).")


## Pupping zones that will see their pups through: on ice, and not failed this season.
func _good_zones() -> Array[Building]:
	return _buildings(&"seal_pupping_zone").filter(func(z: Building) -> bool: return _on_ice(z) and not _failed.has(_key(z)))


## The share of pupping zones (and the drill site) on ice that lasts (0 with none built).
func planning() -> float:
	var zones := _buildings(&"seal_pupping_zone") + _buildings(&"ice_core_drill")
	if zones.is_empty():
		return 0.0  # no pupping zones: the seals have nowhere safe to raise pups
	var good := zones.filter(func(z: Building) -> bool: return on_old_ice(z) and not _failed.has(_key(z)))
	# Crowded ice raises fewer pups: too many seals count against it too.
	return float(good.size()) / zones.size() * minf(float(seals_crowd) / maxi(living(SEAL).size(), 1), 1.0)


func _drill(days: float) -> void:
	if Fleet.has_flag(CORE_FLAG):
		return
	for site in _buildings(&"ice_core_drill"):
		if not _on_ice(site):
			if _drilled > 0.0:
				get_tree().call_group("hud", "show_toast", "The ice under the drill site has melted: the drilling had to stop. Move it to old ice and start again.")
			_drilled = 0.0
		elif Fleet.has_flag(BALANCED_FLAG):
			_drilled += days
			if _drilled >= drill_days:
				Fleet.mark(CORE_FLAG)
				get_tree().call_group("hud", "show_toast", "The ice core is drilled! A long cylinder of ancient ice, its layers a record of the climate thousands of years ago. It's stored aboard, safely frozen.")


func drill_progress() -> float:
	return _drilled / drill_days


func _objective() -> void:
	if not Fleet.has_flag(BALANCED_FLAG) and IslandHealth.of(get_tree(), region()) >= balanced_at:
		Fleet.mark(BALANCED_FLAG)
		get_tree().call_group("hud", "show_toast", "The Polar Ocean is doing well through the seasons! Now drill an ice core: build the Ice Core Drill Site on old ice and keep it there for 3 days.")


# --- Animals ---

func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and not animal.visiting and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


## Cod follow the ice (seasonal ice at the last freeze); seals crowding the ice eat them down.
func cod_supported() -> int:
	return clampi(1 + _peak_ice / ice_per_cod - maxi(living(SEAL).size() - seals_crowd, 0), 1, cod_max)


func seals_supported() -> int:
	var room := 0
	for zone in _good_zones():
		room += zone.capacity()
	return clampi(1 + room, 1, maxi(living(COD).size() * seals_per_cod, 1) + 1)


func bears_supported() -> int:
	var dens := _buildings(&"quiet_den_area").size()
	if dens == 0 or corridor_score() < corridor_needed or living(SEAL).size() < 2:
		return 1
	return clampi(1 + dens, 1, bear_max)


func terns_supported() -> int:
	if phase() < THAW_FROM:
		return 0  # away in the south
	var room := 0
	for area in _buildings(&"tern_nesting_area"):
		room += area.capacity()
	return clampi(room, 1, maxi(living(COD).size(), 1))


func settle_now() -> void:
	if Regions.is_discovered(region()):
		settle()


func settle() -> void:
	_follow(COD, cod_supported())
	_follow(SEAL, seals_supported())
	_follow(BEAR, bears_supported())
	if phase() >= THAW_FROM:
		_follow(TERN, terns_supported())


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
	get_tree().call_group("hud", "animal_returned", species, "It has come to the Polar Ocean: %s" % _why(species), region())


func _why(species: AnimalData) -> String:
	match species:
		SEAL:
			return "a pupping zone on lasting ice has room."
		BEAR:
			return "the freeze joined the floes, and it has quiet rock to rest on."
		TERN:
			return "there's quiet rock to nest on, and cod to catch."
	return "there was more ice in the freeze."


func _home_spot(species: AnimalData) -> Vector2:
	var homes: Array[Building] = []
	match species:
		SEAL:
			homes = _good_zones()
		BEAR:
			homes = _buildings(&"quiet_den_area")
		TERN:
			homes = _buildings(&"tern_nesting_area")
	if not homes.is_empty():
		var home: Building = homes.pick_random()
		return home.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 24))
	var kinds: Array = ["", "water"] if species == COD else (["rock", "ice"] if species == BEAR else ["ice", "rock"])
	var floes := _floe_of.keys()
	var cell: Vector2i = floes[(species.id.hash() + living(species).size() * 7) % floes.size()] if not floes.is_empty() else Vector2i.ZERO
	return Terrain.nearest(get_tree(), _ground.to_global(_ground.map_to_local(cell)) + Vector2(randf_range(-30, 30), randf_range(-30, 30)), kinds)


func _spawn(species: AnimalData, spot: Vector2, visiting := false) -> Animal:
	var animal: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)
	animal.visiting = visiting
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	animal.home_radius = {SEAL: 70.0, BEAR: 140.0, COD: 120.0, TERN: 120.0, SKUA: 260.0}.get(species, 120.0)
	animal.position = spot
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	return animal


## When the ranger first finds the island (in open water): a seal caught in a lost net, a polar
## bear on its rock, a couple of cod, one tern nesting and a skua.
func _seed() -> void:
	_seeded = true
	_phase_was = phase_name()
	apply_ice()
	_measure_open()
	var seal := _spawn(SEAL, _home_spot(SEAL))
	seal.tangle(load("res://data/items/ghost_net.tres"))
	_spawn(BEAR, _home_spot(BEAR))
	_spawn(COD, _home_spot(COD))
	_spawn(COD, _home_spot(COD))
	_spawn(TERN, _home_spot(TERN))
	_spawn(SKUA, _home_spot(SKUA))


## Before the first freeze: nothing joined yet, and only the floes' own ice for the cod.
func _measure_open() -> void:
	_corridor = 1.0 / maxi(_floe_count, 1)
	_peak_ice = 0


## The freeze: the terns fly south, and on the way they visit the ranger's other healthy islands.
func _terns_south() -> void:
	var here := living(TERN)
	_terns_last = maxi(here.size(), 1)
	for tern in here:
		tern.leaving = true
	for other: Resource in Regions.all():
		if other.id == region_id or not Regions.is_discovered(other) or IslandHealth.of(get_tree(), other) < balanced_at:
			continue
		_spawn(TERN, Terrain.nearest(get_tree(), other.center + Vector2(randf_range(-200, 200), randf_range(-200, 200)), ["", "water"]), true)


## The thaw: the visitors fly on, and the terns come back to nest.
func _terns_north() -> void:
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == TERN and animal.visiting:
			animal.leaving = true
	settle()


func terns_counted() -> int:
	return living(TERN).size() if phase() >= THAW_FROM else _terns_last


## The skua circles over what needs help: a caught animal, a zone about to lose its ice, a bear
## cut off on its rock.
func _guide_skua() -> void:
	var skuas := living(SKUA)
	if skuas.is_empty():
		return
	var spot := trouble()
	if spot != Vector2.INF:
		(skuas[0] as Animal).restore_young(skuas[0].global_position, spot)


func trouble() -> Vector2:
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.tangled and Regions.nearest(animal.global_position).id == region_id:
			return animal.global_position
	for zone in _buildings(&"seal_pupping_zone"):
		if not on_old_ice(zone):
			return zone.global_position
	if corridor_score() < corridor_needed:
		var bears := living(BEAR)
		if not bears.is_empty():
			return bears[0].global_position
	return Vector2.INF


# --- Rare event: Major Ice Breakup ---

## A big piece of one floe's old ice breaks away (it freezes back at the next freeze's peak).
func ice_breakup(share: float) -> int:
	var by_floe := {}
	for cell: Vector2i in _floe_of:
		if _base[cell] == ICE_TILE:
			if not by_floe.has(_floe_of[cell]):
				by_floe[_floe_of[cell]] = []
			by_floe[_floe_of[cell]].append(cell)
	var floes := by_floe.keys().filter(func(f: int) -> bool: return (by_floe[f] as Array).size() >= 8)
	if floes.is_empty():
		return 0
	var cells: Array = by_floe[floes.pick_random()]
	var centre := Vector2.ZERO
	for cell: Vector2i in cells:
		centre += Vector2(cell)
	centre /= cells.size()
	var side := Vector2.from_angle(randf() * TAU)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) - centre).dot(side) > (Vector2(b) - centre).dot(side))
	for cell: Vector2i in cells.slice(0, ceili(cells.size() * share)):
		_broken[cell] = true
	apply_ice()
	_check_zones()
	settle()
	return _broken.size()


func broken_count() -> int:
	return _broken.size()


# --- Health ---

func eco_score(factor: HealthFactor, projected := {}) -> float:
	match factor.target:
		&"corridor":
			return clampf(projected.get("corridor", corridor_score()), 0.0, 1.0)
		&"planning":
			return projected.get("planning", planning())
	return clampf(eco_count(factor.target, projected) / float(maxi(factor.amount, 1)), 0.0, 1.0)


func eco_count(target: StringName, projected := {}) -> float:
	if projected.has(target):
		return float(projected[target])
	match target:
		&"corridor":
			return roundi(corridor_score() * 100.0)
		&"terns":
			return terns_counted()
		&"planning":
			return planning()
	return 0.0


func eco_describe(factor: HealthFactor) -> String:
	match factor.target:
		&"corridor":
			return "%s: %d%% of what it can join (at the last freeze)" % [factor.text, roundi(corridor_score() * 100.0)]
		&"terns":
			return "%s: %d (%d for full health)%s" % [factor.text, terns_counted(), factor.amount, "" if phase() >= THAW_FROM else ", away in the south until the thaw"]
		&"planning":
			var zones := _buildings(&"seal_pupping_zone").size()
			var crowded := living(SEAL).size() > seals_crowd
			return "%s: %d%% %s" % [factor.text, roundi(planning() * 100.0), "(no zones yet: the seals have nowhere safe to raise pups)" if zones == 0
				else ("(the seals are crowding the ice: fewer pups survive)" if crowded else "of your zones are on old ice that lasts")]
	return factor.text


## Where the island settles if everything stays as it is: the next freeze with the boats where
## they are, and the animals that would follow.
func project() -> Dictionary:
	var land := _full_freeze(true)
	var corridor := clampf(_joined_share(land) / _possible, 0.0, 1.0)
	var seasonal := land.keys().filter(func(c: Vector2i) -> bool: return _ring.has(c)).size()
	var lasting := _buildings(&"seal_pupping_zone").filter(func(z: Building) -> bool: return on_old_ice(z))
	var room := 0
	for zone: Building in lasting:
		room += zone.capacity()
	var seals := 1 + room
	var cod := clampi(1 + seasonal / ice_per_cod - maxi(seals - seals_crowd, 0), 1, cod_max)
	seals = clampi(seals, 1, cod * seals_per_cod + 1)
	var dens := _buildings(&"quiet_den_area").size()
	var bears := 1 if dens == 0 or corridor < corridor_needed or seals < 2 else clampi(1 + dens, 1, bear_max)
	var nests := 0
	for area in _buildings(&"tern_nesting_area"):
		nests += area.capacity()
	var zones := _buildings(&"seal_pupping_zone") + _buildings(&"ice_core_drill")
	var good := zones.filter(func(z: Building) -> bool: return on_old_ice(z))
	return {"corridor": corridor, "planning": 0.0 if zones.is_empty() else float(good.size()) / zones.size() * minf(float(seals_crowd) / seals, 1.0),
		"terns": clampi(nests, 1, cod), SEAL.id: seals, BEAR.id: bears, COD.id: cod}


# --- The Polar Research Station's missions ---

const MISSIONS := [&"ice_survey", &"corridor_check", &"seal_count", &"tern_tracking", &"breakup_survey", &"drill_planning"]


func handles(effect: StringName) -> bool:
	return effect in MISSIONS


func _mark(at: Vector2) -> Node2D:
	var mark := Node2D.new()
	add_child(mark)
	mark.global_position = at
	return mark


## The middle of the floe with the most old ice (the best place to drill).
func _oldest_ice() -> Vector2:
	var count := {}
	for cell: Vector2i in _floe_of:
		if _base[cell] == ICE_TILE and not _broken.has(cell):
			count[_floe_of[cell]] = int(count.get(_floe_of[cell], 0)) + 1
	var best := -1
	for floe: int in count:
		if best < 0 or count[floe] > count[best]:
			best = floe
	var sum := Vector2.ZERO
	var n := 0
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _floe_of:
		if _floe_of[cell] == best and _base[cell] == ICE_TILE and not _broken.has(cell):
			sum += _ground.map_to_local(cell)
			n += 1
			cells.append(cell)
	var middle := sum / maxi(n, 1)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _ground.map_to_local(a).distance_to(middle) < _ground.map_to_local(b).distance_to(middle))
	return _ground.to_global(_ground.map_to_local(cells[0])) if not cells.is_empty() else global_position


func run_mission(mission: MissionData) -> Dictionary:
	match mission.effect:
		&"ice_survey":
			var risky := _buildings(&"seal_pupping_zone").filter(func(z: Building) -> bool: return not on_old_ice(z))
			var found: Array = risky.duplicate()
			if risky.is_empty():
				found.append(_mark(_oldest_ice()))
			return {"found": found, "detail": "It's %s. The old, thick ice is the white ice that's there in open water too: it lasts all season. %s" % [status_note().to_lower(),
				("%d pupping zone(s) stand on seasonal ice that will melt (marked): move them to old ice." % risky.size()) if risky
				else "Your zones are all on old ice. The biggest stretch of old ice is marked."]}
		&"corridor_check":
			var boats := _boat_spots()
			var blocking: Array = []
			for spot in boats:
				for cell: Vector2i in _ring:
					if _ground.to_global(_ground.map_to_local(cell)).distance_to(spot) < boat_clear:
						blocking.append(_mark(spot))
						break
			var projected := clampf(_joined_share(_full_freeze(true)) / _possible, 0.0, 1.0)
			return {"found": blocking, "detail": "At the last freeze the ice joined %d%% of what it can. With the boats where they are now, the next freeze will join %d%%. %s" % [
				roundi(corridor_score() * 100.0), roundi(projected * 100.0),
				("%d boat(s) sit in water that should freeze (marked): move them out before the freeze." % blocking.size()) if blocking else "No boats are in the way."]}
		&"seal_count":
			var seals := living(SEAL)
			var caught := seals.filter(func(a: Animal) -> bool: return a.tangled)
			return {"found": caught if caught else seals, "detail": "%d ringed seal(s), %d caught in litter%s. %d pupping zone(s) will see their pups through this season. %s" % [
				seals.size(), caught.size(), " (marked: free them)" if caught else "", _good_zones().size(),
				"Seals are crowding the ice: fewer zones would be better." if seals.size() > 9 else "Each zone on old ice raises pups every season."]}
		&"tern_tracking":
			var visitors: Array = get_tree().get_nodes_in_group("animals").filter(func(a: Animal) -> bool: return a.data == TERN and a.visiting and not a.leaving)
			if phase() >= THAW_FROM:
				return {"found": living(TERN), "detail": "%d Arctic tern(s) are nesting here (marked). They'll fly south when the ice freezes." % living(TERN).size()}
			return {"found": visitors, "detail": "The terns are away on their migration south.%s They'll be back in the thaw." % (
				(" %d are resting on your other healthy islands on the way (marked)." % visitors.size()) if visitors else " Healthy islands give them a place to rest on the way.")}
		&"breakup_survey":
			var gone := _buildings(&"seal_pupping_zone").filter(func(z: Building) -> bool: return not _on_ice(z)) \
				+ _buildings(&"ice_core_drill").filter(func(z: Building) -> bool: return not _on_ice(z))
			return {"found": gone, "detail": ("%d piece(s) of old ice are broken off for now; %d of your zones and sites are in the water (marked): move them onto solid ice. The ice freezes back at the next freeze." % [_broken.size(), gone.size()])
				if _broken or gone else "No broken ice: everything is on solid ice."}
		&"drill_planning":
			var spot := _oldest_ice()
			return {"found": [_mark(spot)], "detail": "The oldest, thickest ice is marked: build the Ice Core Drill Site there and it will last the 3 days of drilling. %s" % (
				"The island is healthy enough to drill." if Fleet.has_flag(BALANCED_FLAG) else "First the island needs to reach 70 % health.")}
	return {}


func to_dict() -> Dictionary:
	return {"last_tick": _last_tick, "seeded": _seeded, "season": _season, "broken": _broken.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]),
		"failed": _failed.keys(), "wake": _wake.keys().map(func(c: Vector2i) -> Array: return [c.x, c.y]), "corridor": _corridor, "peak_ice": _peak_ice, "drilled": _drilled, "terns_last": _terns_last, "phase": String(_phase_was)}


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	_seeded = bool(saved.get("seeded", false))
	_season = float(saved.get("season", 2.7))
	_broken.clear()
	for c: Array in saved.get("broken", []):
		_broken[Vector2i(int(c[0]), int(c[1]))] = true
	_failed.clear()
	for key in saved.get("failed", []):
		_failed[String(key)] = true
	_wake.clear()
	for c: Array in saved.get("wake", []):
		_wake[Vector2i(int(c[0]), int(c[1]))] = true
	_corridor = float(saved.get("corridor", 0.0))
	_peak_ice = int(saved.get("peak_ice", 0))
	_drilled = float(saved.get("drilled", 0.0))
	_terns_last = int(saved.get("terns_last", 1))
	_phase_was = StringName(saved.get("phase", ""))
