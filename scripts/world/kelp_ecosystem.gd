class_name KelpEcosystem
extends Node2D
## The Kelp Forest's food web (MASTER_PLAN "Kelp Forest"): kelp beds on the island's shallow
## and mid water, each with its sea urchins. Every `tick_days` (real elapsed game time, so
## sleeping catches up) urchins graze and multiply, and kelp regrows where grazing is low.
## Kelp is never fixed by planting alone: while urchins are too many, it keeps declining.
## Runs once the island is discovered. Saved by SaveGame (to_dict / restore).

const BED_SCRIPT := preload("res://scripts/world/kelp_bed.gd")
const URCHIN := preload("res://data/animals/sea_urchin.tres")
const KELP := preload("res://data/plants/giant_kelp.tres")
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
@export var start_urchins := Vector2(4.0, 7.0)
@export_group("Food web")
## With no otters, each bed carries about this many urchins (varying bed to bed).
@export var urchin_max := 12.0
## On bare rock urchins starve to this share of what a full forest feeds; a bed never has
## fewer than `urchin_min` (no species ever disappears).
@export var urchin_starved := 0.25
@export var urchin_min := 0.05
## Otters keep urchins down: every `otter_scale` otters cut the urchins to about a third.
## The whole island's otters count, wherever their habitats are.
@export var otter_scale := 2.0
## Urchins on a bed that graze it down to bare rock (kelp settles at 1 - urchins / bare_at).
@export var bare_at := 10.0
## Everything moves towards its new balance: half the way each `half_life_days` (so a change
## mostly settles within 3-4 days), plus `instant_share` of the way straight away when
## otters arrive or leave, so the player sees what their choice did.
@export var half_life_days := 1.0
@export var instant_share := 0.2
## Restoration (missions, Restoration Sites) lifts the kelp this much above what grazing
## allows; on overgrazed beds only `overgrazed_restore` of it.
@export var restore_bonus := 0.3
@export var overgrazed_restore := 0.2
## Cross-island link: clean water at this island (its first "clean" health factor) makes
## kelp here grow back up to `upstream_boost` faster.
@export var upstream_region: StringName = &"home_island"
@export var upstream_boost := 0.5
## A bed counts as overgrazed at this many urchins.
@export var overgrazed_at := 6.0
@export_group("Otters")
## Otters settled at a habitat only move away when food falls below this share of what they
## need (they ride out lean days while the kelp grows back).
@export var leave_below := 0.5
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
## The island's own struggling animals have been put out (the first time it's discovered).
var _seeded := false
## Otters with no habitat move away after this many days (a freed otter needs a quiet place).
@export var homeless_days := 1.0


func _enter_tree() -> void:
	add_to_group("ecosystems")


func _ready() -> void:
	_place_beds()
	GameClock.new_day.connect(func(_d: int) -> void:
		if Regions.is_discovered(region()):
			_objective()
		for bed in beds():
			bed.health_yesterday = bed.health)


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
		bed.urchin_share = lerpf(0.7, 1.3, _noise(Vector2i(i, 21)))  # some beds suit urchins more
		bed.urchins = roundf(lerpf(start_urchins.x, start_urchins.y, _noise(Vector2i(i, 13))))
		add_child(bed)


static func _noise(c: Vector2i) -> float:
	return fposmod(sin(c.x * 12.9898 + c.y * 78.233) * 43758.5453, 1.0)


func _process(_delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	if not _seeded:
		_seed()
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


## When the ranger first finds the island, every species is there but struggling: urchins
## overgrazing a barren, a few rockfish in the thin kelp, one hungry cormorant, and an otter
## caught in a ghost net — it needs help, then a quiet place to rest (an Otter Habitat).
func _seed() -> void:
	_seeded = true
	var otter := _spawn(load("res://data/animals/sea_otter.tres"), beds()[0].global_position)
	otter.tangle(load("res://data/items/ghost_net.tres"))
	for i in 2:
		_spawn(FISH, beds()[(i + 3) % beds().size()].global_position)
	_spawn(CORMORANT, region().center + Vector2(0, -120))


## Puts a grown animal of `species` into the world at `spot` (saved like the island's own).
func _spawn(species: AnimalData, spot: Vector2) -> Animal:
	var animal: Animal = load("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	animal.home_radius = 360.0 if species.flies else (species.adult_home_radius if species.urchins_per_day > 0.0 else 60.0)
	animal.position = spot
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	return animal


## Close to a bed: the kelp (and its urchins) go in the Journal.
func _spot_urchins() -> void:
	if Journal.has(URCHIN.id) and Journal.has_plant(KELP.id):
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	for bed in beds():
		if bed.global_position.distance_to(ranger.global_position) <= SPOT_RANGE:
			Journal.discover_plant(KELP)
			if bed.urchin_count() > 0:
				Journal.discover(URCHIN)
			return


## One step of the food web, `days` long: animals settle or leave, then urchins and kelp
## move towards the balance the island's otters allow.
func tick(days: float) -> void:
	settle()
	_approach(1.0 - pow(0.5, days / half_life_days))


## Moves every bed `share` of the way towards its balance right now (after a change).
func nudge(share := instant_share) -> void:
	_approach(share)


func _approach(share: float) -> void:
	var sites := _restored_by_sites()
	var faster := 1.0 + upstream_boost * upstream_clean()  # clean water upstream: kelp recovers faster
	var kelp_share := 1.0 - pow(1.0 - share, faster)
	var pressure := otter_pressure()
	for bed in beds():
		bed.urchins += (urchin_target(bed, pressure) - bed.urchins) * share
		bed.health += (kelp_target(bed, sites) - bed.health) * (kelp_share if kelp_target(bed, sites) > bed.health else share)
		if bed.storm_hit and bed.health >= 0.6:
			bed.storm_hit = false  # recovered


## Otters at work (pups count half; hurt or caught ones not at all).
func otter_pressure() -> float:
	var pressure := 0.0
	for otter in otters():
		if not otter.injured and not otter.tangled:
			pressure += 0.5 if otter.young else 1.0
	return pressure


## The urchins `bed` settles at with this many otters about.
func urchin_target(bed: KelpBed, pressure: float) -> float:
	# Urchins follow their food as well as their predators: kelp growing back feeds a boom,
	# and a barren starves them back down. So restoring kelp before there are otters makes
	# urchins surge.
	var food := urchin_starved + (1.0 - urchin_starved) * bed.health
	return maxf(urchin_max * bed.urchin_share * food * exp(-pressure / otter_scale), urchin_min)


## The beds the island's Kelp Restoration Sites look after: each restores its share of the
## most damaged beds, wherever the site stands.
func _restored_by_sites() -> Array[KelpBed]:
	var count := 0
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.restores_beds > 0 and not building.damaged and building.upkeep_paid \
				and Regions.nearest(building.global_position).id == region_id:
			count += building.data.restores_beds
	var list := beds()
	list.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.health < b.health)
	return list.slice(0, count)


## The kelp `bed` settles at with its urchins (and any restoration).
func kelp_target(bed: KelpBed, sites: Array) -> float:
	var target := clampf(1.0 - bed.urchins / bare_at, 0.0, 1.0)
	var restoring := bed.restored_until > GameClock.now() or bed in sites
	if restoring:
		target += restore_bonus * (overgrazed_restore if bed.urchins >= overgrazed_at else 1.0)
	return clampf(target, 0.0, 1.0)


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


## Food for otters on the whole island: urchins, plus the other food healthy kelp shelters
## (crabs, snails, clams).
func food(species: AnimalData) -> float:
	var total := 0.0
	for bed in beds():
		total += bed.urchins + species.kelp_food * bed.health
	return total


## Otters the island's food can support.
func otters_supported(species: AnimalData) -> int:
	return floori(food(species) / species.food_needed)


func _habitats(species: AnimalData) -> Array[Building]:
	var homes: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.hosts == species.id and Regions.nearest(building.global_position).id == region_id \
				and not building.is_queued_for_deletion():
			homes.append(building)
	return homes


## Right away after the ranger builds or takes down something here.
func settle_now() -> void:
	if Regions.is_discovered(region()):
		settle()


## Otters settle at habitats with room while the island's food can support another (a
## newcomer, or a pup born here), and move away when it can't. Habitats only offer the
## conditions; the ecosystem decides. At most one change per habitat each time. Then fish
## follow the kelp, and cormorants the fish.
func settle() -> void:
	var species: AnimalData = load("res://data/animals/sea_otter.tres")
	var homes := _habitats(species)
	var all := otters()
	var before := all.size()
	# Otters without a home (freed from a net, or their habitat taken down) find one with
	# room, or move away after a while: they need a quiet place to rest.
	for otter in all:
		if not is_instance_valid(otter.home_area) or otter.home_area.is_queued_for_deletion():
			otter.home_area = null
			for home in homes:
				if home.room_for_animals() > 0:
					otter.home_area = home
					break
		if otter.home_area or otter.tangled or otter.injured:
			otter.homeless_since = -1.0
			continue
		if otter.homeless_since < 0.0:
			otter.homeless_since = GameClock.now()
			get_tree().call_group("hud", "show_toast", "A sea otter has nowhere quiet to rest: build an Otter Habitat, or it will move away.")
		elif GameClock.now() - otter.homeless_since >= homeless_days:
			if otters().size() > 1:  # the last one stays on: no species ever disappears
				_move_away(otter, "it had no quiet place to rest (an Otter Habitat)")
	all = otters()
	var fed := food(species)
	if all.size() > 1 and fed / all.size() < species.food_needed * leave_below:
		_move_away(all.back(), "there isn't enough food in the kelp for so many otters")
	else:
		for home in homes:
			if home.damaged or not home.upkeep_paid or home.room_for_animals() <= 0:
				continue
			if otters().size() + 1 > otters_supported(species):
				break
			_new_otter(species, home, otters())
	if otters().size() != before:
		nudge()  # the first effects show straight away
	_follow(FISH, fish_supported())
	_follow(CORMORANT, cormorants_supported())


## Kelp fish the forest can support now.
func fish_supported() -> int:
	return floori(beds().reduce(func(sum: float, b: KelpBed) -> float: return sum + b.health, 0.0) * fish_per_bed)


## Cormorants the fish can feed, if there are full-grown trees to nest in.
func cormorants_supported() -> int:
	var fish := living(FISH).size()
	return mini(mini(roundi(float(fish) / fish_per_cormorant), cormorant_max), Arrivals.grown_trees(get_tree(), region()))


## The island's animals of `species` (not ones moving away).
func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


## The objective (RegionData.goals): once the food web is in balance (island health at
## balanced_at, marked for good), the healthiest beds shed kelp each morning for the ranger
## to gather, until enough has been gathered.
@export_group("Objective")
@export var balanced_at := 0.7
@export var balanced_flag := &"kelp_balanced"
@export var shed_count := &"shed_kelp"
@export var shed_needed := 5
@export var shed_per_day := 2
const SHED_KELP := preload("res://data/items/shed_kelp.tres")


func _objective() -> void:
	if not Fleet.has_flag(balanced_flag):
		if IslandHealth.of(get_tree(), region()) >= balanced_at:
			Fleet.mark(balanced_flag)
			get_tree().call_group("hud", "show_toast",
				"The Kelp Forest's food web is back in balance! Healthy kelp sheds old fronds: gather them from the water.")
		else:
			return
	if Fleet.count_of(shed_count) >= shed_needed:
		return
	var floating := get_tree().get_nodes_in_group("debris").filter(func(d: Debris) -> bool: return d.item == SHED_KELP).size()
	var list := beds()
	list.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.health > b.health)
	var spawner: LitterSpawner = null
	for s: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(s.area.get_center()).id == region_id:
			spawner = s
	if not spawner:
		return
	for bed in list.slice(0, maxi(shed_per_day - floating, 0)):
		spawner.spawn_at(SHED_KELP, bed.global_position + Vector2(randf_range(-12.0, 12.0), 14.0), true)


## One more of `species` arrives, or one moves away, towards `target`.
func _follow(species: AnimalData, target: int) -> void:
	target = maxi(target, 1)  # a few always hang on: no species ever disappears
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
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)  # grown: saved like the island's own
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
		otter.born_at = maxf(GameClock.now() - species.grow_days, 0.0)  # grown: counted and saved like the island's own
		otter.position = Terrain.nearest(get_tree(), home.global_position, ["water", ""])
	var world := get_tree().get_first_node_in_group("player").get_parent()
	world.add_child(otter)
	world.move_child(otter, world.get_node("Player").get_index())
	get_tree().call_group("hud", "show_toast", ("A sea otter pup was born near your %s!" if pup
		else "A sea otter has settled at your %s: the kelp around it can feed it.") % home.data.display_name)


## Heavy swell tears up kelp: `share` of the beds lose up to `damage` health (marked as
## storm-hit until they recover). Returns how many were damaged.
func swell(damage: float, share: float) -> int:
	var list := beds()
	list.shuffle()
	var hit := list.slice(0, ceili(list.size() * share))
	for bed: KelpBed in hit:
		bed.health -= damage * randf_range(0.5, 1.0)
		bed.storm_hit = true
	return hit.size()


## The Kelp Research Platform's missions (MissionData.effect) this ecosystem runs.
const MISSIONS := [&"kelp_survey", &"urchin_survey", &"otter_monitoring", &"balance_survey",
	&"kelp_restoration", &"urchin_relocation", &"storm_survey"]
## Beds under this health count as damaged; kelp restoration helps this many beds.
@export var damaged_below := 0.4
@export var restore_beds := 3
@export var restore_now := 0.15
## Urchin relocation moves at most this many, from the worst bed to the least grazed ones.
@export var relocate_max := 8


func handles(effect: StringName) -> bool:
	return effect in MISSIONS


## Runs a research mission: {found: nodes to mark on the minimap, detail: what it learned
## and what the ranger can do about it}. Observe → understand → intervene → observe again.
func run_mission(mission: MissionData) -> Dictionary:
	var list := beds()
	match mission.effect:
		&"kelp_survey":
			var damaged := list.filter(func(b: KelpBed) -> bool: return b.health < damaged_below)
			var recovering := list.filter(func(b: KelpBed) -> bool:
				return b.health_yesterday >= 0.0 and b.health > b.health_yesterday + 0.01)
			var healthy := list.size() - damaged.size()
			return {"found": damaged, "detail": "%d of %d kelp beds are healthy, %d damaged (marked)%s. %s" % [
				healthy, list.size(), damaged.size(),
				", %d recovering" % recovering.size() if recovering else "",
				"Find out why with an urchin pressure survey." if damaged else "The forest is in good shape."]}
		&"urchin_survey":
			var heavy := list.filter(func(b: KelpBed) -> bool: return b.urchins >= overgrazed_at * 0.6)
			heavy.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.urchins > b.urchins)
			var otter_count := otters().size()
			return {"found": heavy, "detail": "%d bed(s) are overgrazed by urchins (marked)%s. %s" % [
				heavy.size(), ", the worst with %d" % heavy[0].urchin_count() if heavy else "",
				("With %d otter(s) on the island, nothing keeps them in check. Otters eat urchins: check their conditions (otter monitoring)." % otter_count) if heavy and otter_count < 4
				else ("Urchin relocation can ease the worst beds for a while." if heavy else "Grazing is in balance.")]}
		&"otter_monitoring":
			return {"found": otters(), "detail": _otter_report()}
		&"balance_survey":
			return {"found": list.filter(func(b: KelpBed) -> bool: return b.urchins >= overgrazed_at), "detail": balance_report()}
		&"kelp_restoration":
			var worst := list.duplicate()
			worst.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.health < b.health)
			worst = worst.slice(0, restore_beds)
			for bed: KelpBed in worst:
				bed.health += restore_now
				bed.restored_until = GameClock.now() + mission.effect_days
			var grazed := worst.filter(func(b: KelpBed) -> bool: return b.urchins >= overgrazed_at * 0.6)
			return {"found": worst, "detail": "Divers replanted kelp at the %d most damaged beds (marked); it grows faster there for %d days. %s" % [
				worst.size(), roundi(mission.effect_days),
				"But %d of them are overgrazed: unless urchins there come down, the new kelp won't last." % grazed.size() if grazed
				else "Urchins there are few, so it should hold."]}
		&"urchin_relocation":
			var by_pressure := list.duplicate()
			by_pressure.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.urchins > b.urchins)
			var from: KelpBed = by_pressure[0]
			var moved := minf(relocate_max, floorf(from.urchins / 2.0))
			if moved < 1.0:
				return {"found": [], "detail": "No bed has too many urchins to move."}
			var to := by_pressure.slice(by_pressure.size() - 3)
			from.urchins -= moved
			for bed: KelpBed in to:
				bed.urchins += moved / to.size()
			return {"found": [from] + to, "detail": "Divers moved %d urchins from the most overgrazed bed to 3 lightly grazed ones (marked). The urchins aren't the enemy: there were just too many in the wrong place. Without more otters, they'll build up again." % roundi(moved)}
		&"storm_survey":
			var hit := list.filter(func(b: KelpBed) -> bool: return b.storm_hit)
			hit.sort_custom(func(a: KelpBed, b: KelpBed) -> bool: return a.urchins < b.urchins)
			var first := hit.slice(0, restore_beds)
			return {"found": first, "detail": ("%d bed(s) were damaged by the swell. Restore these %d first (marked): they have the fewest urchins, so new kelp will last there." % [
				hit.size(), first.size()]) if hit else "No storm damage to survey."}
	return {}


func _nearest_otter_home(point: Vector2) -> float:
	var best := INF
	for otter in otters():
		best = minf(best, otter.home().distance_to(point))
	return best


## The island's otters, what the forest can feed, and what each habitat is doing.
func _otter_report() -> String:
	var species: AnimalData = load("res://data/animals/sea_otter.tres")
	var homes := _habitats(species)
	if homes.is_empty():
		return "No otters without a quiet place to rest: build an Otter Habitat on the shore."
	var room := 0
	var idle := 0
	for home in homes:
		room += home.capacity()
		if not home.upkeep_paid or home.damaged:
			idle += 1
	var all := otters().size()
	var can_feed := otters_supported(species)
	var line := "%d otter(s) at %d habitat(s) with room for %d; the forest can feed %d." % [all, homes.size(), room, can_feed]
	if idle > 0:
		line += " %d habitat(s) aren't looked after today (upkeep unpaid or damaged)." % idle
	elif all < room and all >= can_feed:
		line += " Not enough food for more: the kelp is too thin."
	elif all >= room and urchin_total() > beds().size() * 3:
		line += " The habitats are full but urchins are still too many: another habitat would help."
	elif urchin_total() < beds().size() * 0.2:
		line += " So many otters have eaten nearly all the urchins: fewer habitats would keep them in balance."
	else:
		line += " Otters and urchins are in balance."
	return line


## The food web in one line: otters → urchins → kelp → fish → cormorants, and where it breaks.
func balance_report() -> String:
	var otter_count := otters().size()
	var eaten := roundi(otters().reduce(func(sum: float, o: Animal) -> float: return sum + o.data.urchins_per_day, 0.0))
	var overgrazed := beds().filter(func(b: KelpBed) -> bool: return b.urchins >= overgrazed_at).size()
	var fish := living(FISH).size()
	var birds := living(CORMORANT).size()
	var chain := "Otters: %d (eating about %d urchins a day) → urchins: %d, overgrazing %d of %d beds → kelp: %d%% → fish: %d → cormorants: %d." % [
		otter_count, eaten, urchin_total(), overgrazed, beds().size(), roundi(kelp_health() * 100.0), fish, birds]
	var advice := ""
	if urchin_amount() / maxf(beds().size(), 1) > 3.0:
		advice = "Too many urchins (more than 3 a bed): few otters to keep them in check, so the kelp is being eaten faster than it grows."
	elif urchin_total() < beds().size() * 0.2:
		advice = "Almost no urchins left: otters may be eating them faster than they breed. A healthy forest keeps some; fewer habitats may balance it."
	elif kelp_health() > 0.6 and fish < fish_supported():
		advice = "The kelp is recovering: fish are returning."
	else:
		advice = "The food web is close to balance."
	var link := ""
	if upstream_clean() >= 0.5:
		link = " Clean water from the %s is helping the kelp grow back faster." % (load("res://data/regions/%s.tres" % upstream_region) as RegionData).display_name
	else:
		link = " Litter around the %s is slowing the kelp's recovery here: the ocean is connected." % (load("res://data/regions/%s.tres" % upstream_region) as RegionData).display_name
	return chain + " " + advice + link


## How clean the upstream island's water is, 0..1 (1 = no litter about it).
func upstream_clean() -> float:
	if upstream_region == &"":
		return 0.0
	var upstream: RegionData = load("res://data/regions/%s.tres" % upstream_region)
	for factor: HealthFactor in upstream.health:
		if factor.kind == &"clean" and factor.target == &"":
			return IslandHealth.score(get_tree(), upstream, factor)
	return 0.0


## Everything about the forest, 0..1 on average (the kelp's condition).
func kelp_health() -> float:
	var list := beds()
	if list.is_empty():
		return 0.0
	return list.reduce(func(sum: float, b: KelpBed) -> float: return sum + b.health, 0.0) / list.size()


## Where the food web settles if the ranger leaves everything as it is now: the same model
## run forward on copies (habitats, restoration and hurt or caught otters as they are).
## Returns counts for IslandHealth.of's `projected`: "kelp" (%), "urchins", and animals by id.
func project() -> Dictionary:
	var species: AnimalData = load("res://data/animals/sea_otter.tres")
	var list := beds()
	var health: Array[float] = []
	var urchins: Array[float] = []
	for bed in list:
		health.append(bed.health)
		urchins.append(bed.urchins)
	var room := 0
	for home in _habitats(species):
		if not home.damaged and home.upkeep_paid:
			room += home.capacity()
	var working := otters().filter(func(o: Animal) -> bool: return not o.injured and not o.tangled).size()
	var restored := 0
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.restores_beds > 0 and not building.damaged and building.upkeep_paid \
				and Regions.nearest(building.global_position).id == region_id:
			restored += building.data.restores_beds
	var otter_count := mini(working, 1) if room == 0 else room
	for step in 60:
		var fed := 0.0
		for i in list.size():
			fed += urchins[i] + species.kelp_food * health[i]
		if room > 0:
			otter_count = clampi(floori(fed / species.food_needed), 1, room)
		var order := range(list.size())
		order.sort_custom(func(a: int, b: int) -> bool: return health[a] < health[b])
		for i in list.size():
			var food_share := urchin_starved + (1.0 - urchin_starved) * health[i]
			urchins[i] = lerpf(urchins[i], maxf(urchin_max * list[i].urchin_share * food_share * exp(-otter_count / otter_scale), urchin_min), 0.3)
			var target := clampf(1.0 - urchins[i] / bare_at, 0.0, 1.0)
			if order.find(i) < restored:
				target = clampf(target + restore_bonus * (overgrazed_restore if urchins[i] >= overgrazed_at else 1.0), 0.0, 1.0)
			health[i] = lerpf(health[i], target, 0.3)
	var kelp_sum: float = health.reduce(func(sum: float, h: float) -> float: return sum + h, 0.0)
	var fish := maxi(floori(kelp_sum * fish_per_bed), 1)
	var birds := maxi(mini(mini(roundi(float(fish) / fish_per_cormorant), cormorant_max), Arrivals.grown_trees(get_tree(), region())), 1)
	return {"kelp": roundi(kelp_sum / maxf(list.size(), 1) * 100.0),
		"urchins": urchins.reduce(func(sum: float, u: float) -> float: return sum + u, 0.0),
		species.id: otter_count, FISH.id: fish, CORMORANT.id: birds}


## Urchins on the island, not rounded (a few scattered ones still count).
func urchin_amount() -> float:
	return beds().reduce(func(sum: float, b: KelpBed) -> float: return sum + b.urchins, 0.0)


func urchin_total() -> int:
	return beds().reduce(func(sum: int, b: KelpBed) -> int: return sum + b.urchin_count(), 0)


## For the save file: each bed's health and urchins, by name.
func to_dict() -> Dictionary:
	var saved := {"last_tick": _last_tick, "seeded": _seeded, "beds": {}}
	for bed in beds():
		saved.beds[String(bed.name)] = [bed.health, bed.urchins, bed.restored_until, bed.storm_hit, bed.position.x, bed.position.y]
	return saved


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	_seeded = bool(saved.get("seeded", false))
	var saved_beds: Dictionary = saved.get("beds", {})
	for bed in beds():
		var entry: Array = saved_beds.get(String(bed.name), [])
		if entry.size() >= 3:
			bed.health = float(entry[0])
			bed.urchins = float(entry[1])
			bed.restored_until = float(entry[2])
			bed.storm_hit = entry.size() > 3 and bool(entry[3])
			if entry.size() > 5:
				bed.position = Vector2(entry[4], entry[5])  # it may have been moved
