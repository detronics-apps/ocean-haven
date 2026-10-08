class_name ReefEcosystem
extends Node2D
## The Tropical Reef (a child of its island): everything is connected, and a healthy reef gives
## people sustainable resources. Each of its four animals does a job:
## - parrotfish graze the coral reef and slowly build the sea floor up with sand around it
##   (deep → mid → shallow water → sand), which the ranger digs up for the Glassworks;
## - giant clams in a Marine Water Treatment Facility filter seawater into Clean Water;
## - reef sharks circle lost fishing gear hidden underwater: follow one and the gear shows up;
## - seahorses live in seagrass Protection Areas (the first one starts caught in debris).
## Coral grows back on the reef patches as far as it has been planted (fragments from Coral
## Restoration Sites, by boat), as fast as clean water and grazing parrotfish allow.
## Like the other islands it ticks every `tick_days` while the ranger is on the island.

@export var region_id := &"tropical_reef"
@export var tick_days := 0.25
@export var patch_count := 10
## Most patches the reef can grow to (splitting full patches).
@export var max_patches := 30
## Closest a patch may be to another (split and moved ones).
@export var patch_gap := 44.0
@export var patch_spacing := 150.0
@export var half_life_days := 1.0
@export var instant_share := 0.2

@export_group("Coral")
## Litter in reach that makes the water fully murky; each working clam clears this much.
@export var murky_at := 15.0
@export var clam_clearing := 0.05
## Parrotfish it takes to keep the whole reef's algae down.
@export var grazers_needed := 6
## Coral Restoration Sites: each looks after this many of the most damaged patches.
@export var site_patches := 2
@export var site_bonus := 0.15

@export_group("Sand")
## Each morning each parrotfish feeding on healthy coral may build up one tile near it.
@export var sand_chance := 0.25
@export var healthy_coral := 0.5
@export var sand_per_day := 3
## Most tiles the parrotfish can ever change (keeps the lagoon a lagoon).
@export var sand_max := 40
## Chance a shallow tile becomes sand (the last step is the slowest).
@export var sand_step_chance := 0.35

@export_group("Animals")
@export var parrotfish_max := 10
@export var fish_per_shark := 3
## Each morning a working shark may find hidden ghost gear (if none is waiting).
@export var gear_chance := 0.5
const GEAR_FOUND_RANGE := 72.0

const PARROTFISH := preload("res://data/animals/parrotfish.tres")
const CLAM := preload("res://data/animals/giant_clam.tres")
const SHARK := preload("res://data/animals/reef_shark.tres")
const SEAHORSE := preload("res://data/animals/seahorse.tres")
const PATCH_SCRIPT := preload("res://scripts/world/reef_patch.gd")
const MID_TILE := Vector2i(6, 0)
const SHALLOW_TILE := Vector2i(0, 0)
const SAND_TILE := Vector2i(1, 0)

var _ground: TileMapLayer
var _last_tick := -1.0
var _last_seen := -1.0
var _seeded := false
## Tiles the parrotfish have built up so far.
var _sand_made := 0
## Hidden ghost gear a shark is circling: its spot (INF = none) and item id.
var _gear_at := Vector2.INF
var _gear_item := &"ghost_net"
var _gear_shark: Animal
var _sand_note_day := -1
## The lagoon's water tiles as the island was made (sand there now = parrotfish sand).
var _base_water := {}


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_ground = get_parent().get_node("Ground")
	for cell in _ground.get_used_cells():
		if _terrain(cell) in ["water", ""]:
			_base_water[cell] = true
	_place_patches()
	GameClock.new_day.connect(func(_d: int) -> void:
		if Regions.is_discovered(region()) and Regions.ranger_on(get_tree(), region()):
			_morning())


func region() -> RegionData:
	return load("res://data/regions/%s.tres" % region_id)


func patches() -> Array[ReefPatch]:
	var list: Array[ReefPatch] = []
	for child in get_children():
		if child is ReefPatch:
			list.append(child)
	return list


## Reef patches on the lagoon's shallow water, spread out, the same every time.
func _place_patches() -> void:
	var cells: Array[Vector2i] = []
	for cell in _ground.get_used_cells():
		if _terrain(cell) == "water":
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return KelpEcosystem._noise(a) < KelpEcosystem._noise(b))
	var spots: Array[Vector2] = []
	for cell in cells:
		if spots.size() >= patch_count:
			break
		var spot := _ground.map_to_local(cell) + _ground.position - position
		if spots.all(func(s: Vector2) -> bool: return s.distance_to(spot) >= patch_spacing):
			spots.append(spot)
	for i in spots.size():
		var patch: ReefPatch = PATCH_SCRIPT.new()
		patch.name = "Reef%d" % (i + 1)
		patch.position = spots[i]
		patch.coral = lerpf(0.04, 0.15, KelpEcosystem._noise(Vector2i(i, 3)))
		patch.planted = 0.15
		add_child(patch)


func _terrain(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


func _world(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))


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
	_check_gear()
	_spot_plants()


## Close to a patch the coral goes in the Journal; close to a Protection Area, the seagrass.
func _spot_plants() -> void:
	if Journal.has_plant(&"reef_coral") and Journal.has_plant(&"turtle_grass"):
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	for patch in patches():
		if patch.global_position.distance_to(ranger.global_position) <= 90.0:
			Journal.discover_plant(load("res://data/plants/reef_coral.tres"))
	for home in _homes(SEAHORSE):
		if home.global_position.distance_to(ranger.global_position) <= 90.0:
			Journal.discover_plant(load("res://data/plants/turtle_grass.tres"))


func tick(days: float) -> void:
	settle()
	_approach(1.0 - pow(0.5, days / half_life_days))


func nudge(share := instant_share) -> void:
	_approach(share)


func _approach(share: float) -> void:
	var sites := _restored_by_sites()
	for patch in patches():
		patch.coral += (coral_target(patch, sites) - patch.coral) * share
		if patch.storm_hit and patch.coral >= 0.5:
			patch.storm_hit = false


## How clear the water is, 0..1: litter within reach clouds it, working clams clear it.
func water_quality() -> float:
	var litter := float(get_tree().get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
		return (not d.is_queued_for_deletion() and d.item.is_litter and Regions.nearest(d.global_position) == region()
			and Regions.in_reach(region(), d.global_position))).size())
	return clampf(1.0 - litter / murky_at + clam_clearing * working(CLAM).size(), 0.0, 1.0)


## How well the algae is kept down, 0..1 (parrotfish grazing).
func grazing() -> float:
	return clampf(float(working(PARROTFISH).size()) / grazers_needed, 0.0, 1.0)


## The coral `patch` grows back to: as far as it's planted, held back by murky water and algae.
func coral_target(patch: ReefPatch, sites: Array) -> float:
	var target := patch.planted * (0.4 + 0.6 * water_quality()) * (0.5 + 0.5 * grazing())
	if patch in sites:
		target += site_bonus
	return clampf(maxf(target, 0.03), 0.0, 1.0)


## The patches the island's Coral Restoration Sites look after (the most damaged, anywhere).
func _restored_by_sites() -> Array[ReefPatch]:
	var count := 0
	for site in _buildings(func(b: Building) -> bool: return b.data.id == &"coral_restoration_site"):
		if not site.damaged:
			count += site_patches
	var list := patches()
	list.sort_custom(func(a: ReefPatch, b: ReefPatch) -> bool: return a.coral < b.coral)
	return list.slice(0, count)


## The reef's coral, 0..1: all of it added up, against the reef's first `patch_count` patches
## (so a bigger reef, from splitting, only fills it faster and never pulls it down).
func coral_health() -> float:
	return clampf(total_coral() / patch_count, 0.0, 1.0)


## All the reef's coral added up (a full patch is 1).
func total_coral() -> float:
	return patches().reduce(func(sum: float, p: ReefPatch) -> float: return sum + p.coral, 0.0)


## Whether a patch can sit at `point` (world): shallow water, not too close to another patch.
func spot_free(point: Vector2, ignore: ReefPatch = null) -> bool:
	if Terrain.at(get_tree(), point) != "water":
		return false
	return patches().all(func(p: ReefPatch) -> bool: return p == ignore or p.global_position.distance_to(point) >= patch_gap)


## The nearest free spot (a water tile's middle) around `point`, or null.
func free_spot_near(point: Vector2) -> Variant:
	var centre := _ground.local_to_map(_ground.to_local(point))
	var best: Variant = null
	var best_d := INF
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var at := _world(centre + Vector2i(dx, dy))
			var d := at.distance_to(point)
			if d < best_d and d >= patch_gap and spot_free(at):
				best = at
				best_d = d
	return best


## Adds a patch at `point` (world): split from another, or restored from a save.
func add_patch(point: Vector2, coral_now: float, planted_now: float, patch_name := "") -> ReefPatch:
	var patch: ReefPatch = PATCH_SCRIPT.new()
	var n := patches().size() + 1
	while patch_name == "" and has_node("Reef%d" % n):
		n += 1
	patch.name = patch_name if patch_name != "" else "Reef%d" % n
	add_child(patch)
	patch.global_position = point
	patch.coral = coral_now
	patch.planted = planted_now
	return patch


## Whether a patch is being moved (one at a time).
func carrying() -> bool:
	return patches().any(func(p: ReefPatch) -> bool: return p.carried)


func _buildings(which: Callable) -> Array[Building]:
	var list: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if not building.is_queued_for_deletion() and Regions.nearest(building.global_position).id == region_id and which.call(building):
			list.append(building)
	return list


func _homes(species: AnimalData) -> Array[Building]:
	return _buildings(func(b: Building) -> bool: return b.data.hosts == species.id)


func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


func working(species: AnimalData) -> Array[Animal]:
	return living(species).filter(func(a: Animal) -> bool: return not a.tangled and not a.injured)


func settle_now() -> void:
	if Regions.is_discovered(region()):
		settle()
		nudge()


## Each species takes one step towards what the island supports now.
func settle() -> void:
	_follow(PARROTFISH, parrotfish_supported())
	_follow(CLAM, _room(CLAM))
	_follow(SEAHORSE, seahorses_supported())
	_follow(SHARK, sharks_supported())
	for species in [CLAM, SEAHORSE, SHARK]:
		_house(species)


func parrotfish_supported() -> int:
	return clampi(roundi(total_coral()) + 1, 1, parrotfish_max)  # (a bigger reef feeds more)


func _room(species: AnimalData) -> int:
	var room := 0
	for home in _homes(species):
		if not home.damaged:
			room += home.capacity()
	return room


## Seahorses: room in Protection Areas whose seagrass has grown (a day after building); while a
## green turtle grazes the Reef (a traveller, or a rescued one visiting), the seagrass is lusher:
## one more in each. (Grazing turtles keep real seagrass meadows healthy and growing.)
func seahorses_supported() -> int:
	var room := 0
	var grazed := turtle_grazing()
	for home in _homes(SEAHORSE):
		if not home.damaged and GameClock.day - home.built_day >= 1:
			room += home.capacity() + (1 if grazed else 0)
	return room


## Whether a green turtle is on the Reef today, grazing its seagrass.
func turtle_grazing() -> bool:
	return get_tree().get_nodes_in_group("animals").any(func(a: Node) -> bool:
		return a.data.id == &"green_turtle" and not a.is_queued_for_deletion() and Regions.nearest(a.global_position) == region())


func sharks_supported() -> int:
	return mini(_homes(SHARK).size(), working(PARROTFISH).size() / fish_per_shark)


## Animals without a home move into one with room (seen there: clams in the beds, seahorses in
## the seagrass).
func _house(species: AnimalData) -> void:
	for animal in living(species):
		if animal.tangled or (is_instance_valid(animal.home_area) and not animal.home_area.is_queued_for_deletion()):
			continue
		for home in _homes(species):
			if home.room_for_animals() > 0:
				animal.home_area = home
				animal.restore_young(animal.global_position, Terrain.nearest(get_tree(), home.global_position, ["water", ""]))
				break


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
	if not Births.can_have(get_tree(), species, region()):
		return  # its parents' last young are still too little (or one drifted in just now)
	var homes := _homes(species)
	var spot := _patch_water(patches().pick_random()) if homes.is_empty() else Terrain.nearest(get_tree(), (homes.pick_random() as Building).global_position, ["water", ""])
	Births.bring(_spawn(species, spot), region(), "It has come to the reef: %s" % _why(species))


func _why(species: AnimalData) -> String:
	match species:
		PARROTFISH:
			return "there's more coral to graze."
		CLAM:
			return "your Water Treatment Facility has a safe bed for it."
		SEAHORSE:
			return "the seagrass in a Protection Area has grown."
	return "a Shark Protection Zone gives it quiet water, and there are fish to hunt."


func _patch_water(patch: ReefPatch) -> Vector2:
	return Terrain.nearest(get_tree(), patch.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20)), ["water", ""])


func _spawn(species: AnimalData, spot: Vector2) -> Animal:
	var animal: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	animal.home_radius = {PARROTFISH: 90.0, CLAM: 6.0, SEAHORSE: 24.0}.get(species, 200.0)
	animal.position = spot
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	return animal


## When the ranger first finds the island, every species is there but struggling: one
## parrotfish on a bare reef, one giant clam on the open reef, a seahorse caught in a plastic
## bag, and a reef shark caught in fishing line.
func _seed() -> void:
	_seeded = true
	var list := patches()
	if list.is_empty():
		return
	_spawn(PARROTFISH, _patch_water(list[0]))
	_spawn(CLAM, _patch_water(list[1 % list.size()]))
	var seahorse := _spawn(SEAHORSE, _patch_water(list[2 % list.size()]))
	seahorse.tangle(load("res://data/items/plastic_bag.tres"))
	var shark := _spawn(SHARK, _patch_water(list[3 % list.size()]))
	shark.tangle(load("res://data/items/fishing_line.tres"))


## Each morning: parrotfish build up a little sand, and a shark may find lost fishing gear.
func _morning() -> void:
	_build_sand()
	if _gear_at == Vector2.INF and randf() < gear_chance:
		_hide_gear()
	_objective()


## Parrotfish feeding on healthy coral slowly build the sea floor up near it.
func _build_sand() -> int:
	var changed := 0
	var healthy := patches().filter(func(p: ReefPatch) -> bool: return p.coral >= healthy_coral)
	if healthy.is_empty():
		return 0
	for fish in working(PARROTFISH):
		if changed >= sand_per_day or _sand_made >= sand_max:
			break
		if randf() >= sand_chance:
			continue
		var patch: ReefPatch = healthy.reduce(func(a: ReefPatch, b: ReefPatch) -> ReefPatch:
			return a if a.global_position.distance_to(fish.global_position) <= b.global_position.distance_to(fish.global_position) else b)
		if build_up_near(patch):
			changed += 1
	if changed > 0 and _sand_note_day != GameClock.day:
		_sand_note_day = GameClock.day
		get_tree().call_group("hud", "show_toast", "Parrotfish grinding up the reef have built up the sea floor near it. Shallow water turns to sand you can dig up.")
	return changed


## One tile near `patch` builds up a step (deep → mid → shallow → now and then sand). Returns
## whether one changed.
func build_up_near(patch: ReefPatch) -> bool:
	var centre := _ground.local_to_map(_ground.to_local(patch.global_position))
	var options: Array[Vector2i] = []
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cell := centre + Vector2i(dx, dy)
			if cell == centre or _occupied(cell):
				continue
			var kind := _terrain(cell)
			if kind in ["sea", "", "water"]:
				options.append(cell)
	# The deepest first: the floor builds up before it breaks the surface.
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _depth(a) > _depth(b) or (_depth(a) == _depth(b) and KelpEcosystem._noise(a) < KelpEcosystem._noise(b)))
	for cell in options:
		var depth := _depth(cell)
		if depth == 0 and randf() >= sand_step_chance:
			continue
		var atlas := MID_TILE if depth == 2 else (SHALLOW_TILE if depth == 1 else SAND_TILE)
		_ground.set_cell(cell, 0, atlas)
		SaveGame.record_tile(_ground, cell, atlas)
		_sand_made += 1
		return true
	return false


## 2 = open ocean (no tile), 1 = mid water, 0 = shallow water.
func _depth(cell: Vector2i) -> int:
	match _terrain(cell):
		"sea":
			return 2
		"":
			return 1
	return 0


func _occupied(cell: Vector2i) -> bool:
	var at := _world(cell)
	var world_cell := Terrain.cell_of(at)
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.rect().has_point(world_cell):
			return true
	for thing: Node2D in get_tree().get_nodes_in_group("boat") + get_tree().get_nodes_in_group("reef_patches"):
		if Terrain.cell_of(thing.global_position) == world_cell:
			return true
	return false


## A shark finds lost fishing gear on the reef and circles it, until the ranger comes close.
func _hide_gear() -> void:
	var sharks := working(SHARK)
	if sharks.is_empty():
		return
	_gear_shark = sharks.pick_random()
	_gear_at = _patch_water(patches().pick_random()) + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	_gear_item = [&"ghost_net", &"fishing_line"].pick_random()
	_gear_shark.restore_young(_gear_shark.global_position, _gear_at)
	_gear_shark.home_radius = 28.0
	get_tree().call_group("hud", "show_toast", "A reef shark is circling one spot on the reef, over and over. Follow it: it may have found something.")


func _check_gear() -> void:
	if _gear_at == Vector2.INF:
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(_gear_at) > GEAR_FOUND_RANGE:
		return
	var spawner: LitterSpawner = null
	for s: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(s.area.get_center()).id == region_id:
			spawner = s
	if spawner:
		spawner.spawn_at(load("res://data/items/%s.tres" % _gear_item), _gear_at, true)
	if is_instance_valid(_gear_shark):
		_gear_shark.home_radius = 200.0
		Journal.record_gift(SHARK)
	_gear_at = Vector2.INF
	get_tree().call_group("hud", "show_toast", "The shark led you to lost fishing gear hidden on the reef! Collect it before it catches anything.")


## Where hidden gear is waiting (for the lab's survey), or INF.
func hidden_gear() -> Vector2:
	return _gear_at


## For island health (HealthFactor kind "eco").
func eco_score(factor: HealthFactor, projected := {}) -> float:
	if factor.target == &"water":
		return projected.get("water", water_quality())
	return clampf(eco_count(factor.target, projected) / float(maxi(factor.amount, 1)), 0.0, 1.0)


func eco_count(target: StringName, projected := {}) -> float:
	if projected.has(target):
		return projected[target]
	match target:
		&"coral":
			return roundi(coral_health() * 100.0)
		&"water":
			return water_quality()
	return 0.0


func eco_describe(factor: HealthFactor) -> String:
	match factor.target:
		&"coral":
			return "%s: %d%% (%d%% for full health)" % [factor.text, roundi(coral_health() * 100.0), factor.amount]
		&"water":
			return "%s: %d%%" % [factor.text, roundi(water_quality() * 100.0)]
	return factor.text


## Where the reef settles if everything stays as it is.
func project() -> Dictionary:
	var sites := _restored_by_sites()
	var sum := 0.0
	for patch in patches():
		sum += coral_target(patch, sites)
	var coral := clampf(sum / patch_count, 0.0, 1.0)
	var fish := clampi(roundi(sum) + 1, 1, parrotfish_max)
	return {"coral": roundi(coral * 100.0), "water": water_quality(), PARROTFISH.id: fish,
		CLAM.id: maxi(_room(CLAM), 1), SEAHORSE.id: maxi(seahorses_supported(), 1),
		SHARK.id: maxi(mini(_homes(SHARK).size(), fish / fish_per_shark), 1)}


## RareEvents calls this for an event with kelp_damage (the Hurricane on this island).
func swell(damage: float, share: float) -> int:
	return hurricane(damage, share)


## Hurricane: coral broken on `share` of the patches (less where it's structured), seagrass
## areas battered (storm damage repairs them). Returns patches damaged.
func hurricane(damage: float, share: float) -> int:
	var list := patches()
	list.shuffle()
	var hit := list.slice(0, ceili(list.size() * share))
	for patch: ReefPatch in hit:
		patch.coral -= damage * randf_range(0.5, 1.0) * (1.0 - 0.5 * patch.coral)
		patch.storm_hit = true
	# Seagrass in a battered Protection Area is torn up: it grows back in a day once repaired.
	for area in _homes(SEAHORSE):
		if area.damaged:
			area.built_day = GameClock.day
	_wash_sand(0.5)
	settle()
	return hit.size()


## Waves wash `share` of the parrotfish's sand back into shallow water (they can build it again).
func _wash_sand(share: float) -> int:
	var washed := 0
	for cell: Vector2i in _base_water:
		if _terrain(cell) == "sand" and not _occupied(cell) and randf() < share:
			_ground.set_cell(cell, 0, SHALLOW_TILE)
			SaveGame.record_tile(_ground, cell, SHALLOW_TILE)
			washed += 1
	_sand_made = maxi(_sand_made - washed, 0)
	return washed


@export_group("Objective")
@export var restored_at := 0.7
@export var restored_flag := &"reef_restored"
@export var rubble_count := &"reef_limestone"
@export var rubble_needed := 5
@export var rubble_per_day := 2
const RUBBLE := preload("res://data/items/coral_rubble.tres")


## Once the reef is restored, pieces of dead coral rubble turn up on the sea floor each morning.
func _objective() -> void:
	if not Fleet.has_flag(restored_flag):
		if IslandHealth.of(get_tree(), region()) >= restored_at:
			Fleet.mark(restored_flag)
			get_tree().call_group("hud", "show_toast", "The reef is alive again! Storms and waves break off dead coral: collect the rubble from the sea floor by boat (never living coral).")
		else:
			return
	if Fleet.count_of(rubble_count) >= rubble_needed:
		return
	var lying := get_tree().get_nodes_in_group("debris").filter(func(d: Debris) -> bool: return d.item == RUBBLE).size()
	var spawner: LitterSpawner = null
	for s: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(s.area.get_center()).id == region_id:
			spawner = s
	if not spawner:
		return
	var list := patches()
	list.shuffle()
	for patch in list.slice(0, maxi(rubble_per_day - lying, 0)):
		spawner.spawn_at(RUBBLE, _patch_water(patch), true)


## The Coral Restoration Laboratory's missions.
const MISSIONS := [&"coral_survey", &"water_survey", &"parrotfish_monitoring", &"gear_survey",
	&"clam_monitoring", &"seagrass_survey", &"coral_restoration", &"reef_storm_survey"]
@export var restore_patches := 3


func handles(effect: StringName) -> bool:
	return effect in MISSIONS


func run_mission(mission: MissionData) -> Dictionary:
	var list := patches()
	match mission.effect:
		&"coral_survey":
			var weak := list.filter(func(p: ReefPatch) -> bool: return p.coral < 0.4)
			var why := "The water is murky: clear the litter and give the clams a home." if water_quality() < 0.7 \
				else ("Too few parrotfish to keep the algae down: more coral brings more parrotfish." if grazing() < 0.7
				else "Plant more coral fragments on them.")
			return {"found": weak, "detail": "Coral is %d%% across the reef; %d of %d patches are struggling (marked). %s" % [
				roundi(coral_health() * 100.0), weak.size(), list.size(), why if weak else "The reef is in good shape."]}
		&"water_survey":
			return {"found": [], "detail": "The water is %d%% clear. Litter in the lagoon clouds it; each giant clam in a Water Treatment Facility filters some clean (%d working)." % [
				roundi(water_quality() * 100.0), working(CLAM).size()]}
		&"parrotfish_monitoring":
			var healthy := list.filter(func(p: ReefPatch) -> bool: return p.coral >= healthy_coral)
			return {"found": working(PARROTFISH), "detail": "%d parrotfish (marked) graze the reef. %s" % [working(PARROTFISH).size(),
				("They're building sand up around %d healthy patch(es). Dig the sand up for the Glassworks." % healthy.size()) if healthy
				else "No patch is healthy enough for them to build up sand yet: coral needs to reach about half."]}
		&"gear_survey":
			var sharks := working(SHARK)
			if _gear_at != Vector2.INF:
				var mark := Node2D.new()
				add_child(mark)
				mark.global_position = _gear_at
				return {"found": [mark], "detail": "A shark is circling lost fishing gear (marked). Go there by boat to find it."}
			return {"found": sharks, "detail": "No lost gear found right now. %s" % ("Reef sharks find it now and then: watch for one circling a spot." if sharks
				else "A reef shark would help you find lost gear: free the one caught in fishing line.")}
		&"clam_monitoring":
			var homes := _homes(CLAM)
			return {"found": living(CLAM), "detail": ("%d giant clam(s); %d Water Treatment Facility bed(s) with room for %d. Each working clam makes 1 clean water a morning." % [
				living(CLAM).size(), homes.size(), _room(CLAM)]) if homes else "Build a Marine Water Treatment Facility: it gives giant clams a safe bed, and they filter clean water."}
		&"seagrass_survey":
			var caught := living(SEAHORSE).filter(func(a: Animal) -> bool: return a.tangled)
			return {"found": caught + _homes(SEAHORSE), "detail": "%d seahorse(s), %d caught in debris%s; %d Protection Area(s) with room for %d. %s" % [
				living(SEAHORSE).size(), caught.size(), " (marked: free them)" if caught else "", _homes(SEAHORSE).size(), seahorses_supported(),
				"Build a Seahorse & Seagrass Protection Area on shallow water: its seagrass grows in a day." if _homes(SEAHORSE).is_empty()
				else ("A green turtle is grazing the seagrass: it's growing lusher, with room for more seahorses." if turtle_grazing() else "")]}
		&"coral_restoration":
			var worst := list.duplicate()
			worst.sort_custom(func(a: ReefPatch, b: ReefPatch) -> bool: return a.planted < b.planted)
			worst = worst.slice(0, restore_patches)
			for patch: ReefPatch in worst:
				patch.planted += ReefPatch.FRAGMENT
			nudge()
			return {"found": worst, "detail": "Divers planted coral at the %d least planted patches (marked). It grows back as fast as the water and the grazing allow." % worst.size()}
		&"reef_storm_survey":
			var hit := list.filter(func(p: ReefPatch) -> bool: return p.storm_hit)
			return {"found": hit, "detail": ("%d patch(es) were broken by the hurricane (marked): plant coral fragments there first." % hit.size()) if hit else "No storm damage to survey."}
	return {}


func to_dict() -> Dictionary:
	var saved := {"last_tick": _last_tick, "seeded": _seeded, "sand_made": _sand_made, "patches": {}}
	if _gear_at != Vector2.INF:
		saved["gear"] = [_gear_at.x, _gear_at.y, String(_gear_item)]
	for patch in patches():
		saved.patches[String(patch.name)] = [patch.coral, patch.planted, patch.storm_hit, patch.global_position.x, patch.global_position.y]
	return saved


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	_seeded = bool(saved.get("seeded", false))
	_sand_made = int(saved.get("sand_made", 0))
	var gear: Array = saved.get("gear", [])
	_gear_at = Vector2(gear[0], gear[1]) if gear.size() == 3 else Vector2.INF
	if gear.size() == 3:
		_gear_item = StringName(gear[2])
	var saved_patches: Dictionary = saved.get("patches", {})
	for patch_name: String in saved_patches:  # (split ones: made again where they were)
		var entry: Array = saved_patches[patch_name]
		if not has_node(patch_name) and entry.size() >= 5:
			add_patch(Vector2(entry[3], entry[4]), float(entry[0]), float(entry[1]), patch_name)
	for patch in patches():
		var entry: Array = saved_patches.get(String(patch.name), [])
		if entry.size() >= 3:
			patch.coral = float(entry[0])
			patch.planted = float(entry[1])
			patch.storm_hit = bool(entry[2])
		if entry.size() >= 5:  # (moved ones: where they were set down)
			patch.global_position = Vector2(entry[3], entry[4])
