class_name MangroveEcosystem
extends Node2D
## The Mangrove Coast's water (a child of its island): the land and ocean are connected, and
## water is the transport system. The ranger shapes the land and steers the water; the
## animals follow.
## - Nursery pools lie inland, cut off from the sea by silt. Digging through the mud (the
##   shovel) connects one: a flood fill from the open sea through the island's water, where
##   a closed water gate blocks the way.
## - Silt settles in dug channels, slowly where water flows (connected to the sea) and fast
##   where it stands (cut off, behind a closed gate). Full-grown mangroves beside a channel
##   slow it. Crabs walk to silted channel tiles near them and dig the silt out (seen: the crab
##   on the bank, the dark patch fading); too many crabs undercut the banks round the busiest
##   Crab Habitat. A silted channel tile turns back into mud (dig it out again: nothing is ever
##   lost for good).
## - The water level on the flats comes from every gate together: closed gates hold water,
##   open ones let it drain. Flamingos feed and build mud-mound nests on the flats only
##   when the level is right.
## - Young snappers grow up in connected pools with mangroves beside them, then swim out
##   to sea; crabs settle at Crab Habitats; crocodiles need Crocodile Protection Zones.
## Like the Kelp Forest it ticks every `tick_days` of game time, only while the ranger is on
## the island (Regions.ranger_on), and is saved via the "ecosystems" group.

@export var region_id := &"mangrove_coast"
@export var tick_days := 0.25

@export_group("Silt")
## A standing (cut-off) channel tile silts up in about 1 / silt_per_day days ...
@export var silt_per_day := 0.35
## ... and flowing water (connected to the sea) silts this share as fast.
@export var flowing_silt := 0.15
## Each full-grown mangrove within shelter_range of a channel tile slows its silting by this
## much, up to max_shelter.
@export var mangrove_shelter := 0.3
@export var max_shelter := 0.8
@export var shelter_range := 80.0
## Each grown crab walks to the most silted channel tile within its roaming range (silt from
## crab_work_from) and digs crab_clear_per_day of silt a day out of it, until it's clear; one
## crab a tile, so the island needs enough crabs near its channels (the owner).
@export var crab_clear_per_day := 0.5
@export var crab_work_from := 0.2
## Beyond crabs_too_many on the island, each extra crab's burrows undercut the banks round the
## busiest Crab Habitat: bank_damage_per_day of silt into every channel tile within
## bank_damage_range of it (the owner: a balancing act).
@export var crabs_too_many := 12
@export var bank_damage_per_day := 0.3
@export var bank_damage_range := 128.0

@export_group("Water level")
## The flats' water level (0 dry .. 1 flooded): base_level, plus level_per_closed for every
## closed gate, less level_per_open for every open one.
@export var base_level := 0.2
@export var level_per_closed := 0.2
@export var level_per_open := 0.05
## Right for flamingos between these.
@export var level_low := 0.4
@export var level_high := 0.8

@export_group("Animals")
## Young snappers: fish_base, plus fish_per_nursery for each nursery pool (connected, with a
## full-grown mangrove within nursery_range).
@export var fish_base := 2
@export var fish_per_nursery := 2
@export var nursery_range := 112.0
## Flamingos: one for every flats_per_flamingo mud tiles beside water, up to flamingo_max,
## while the water level is right (then each builds a mud-mound nest).
@export var flats_per_flamingo := 10
@export var flamingo_max := 4

## The mud-mound nest (tools/make_flamingo_nest.py: twice the pixels, drawn at half size).
const NEST_PICTURE := preload("res://assets/animals/flamingo/mud_nest.png")
const CRAB := preload("res://data/animals/mangrove_crab.tres")
const FISH := preload("res://data/animals/juvenile_snapper.tres")
const FLAMINGO := preload("res://data/animals/american_flamingo.tres")
const CROCODILE := preload("res://data/animals/american_crocodile.tres")
const MUD_TILE := Vector2i(5, 0)
const LAND := ["sand", "grass", "mud", "rock"]
const NEIGHBOURS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _ground: TileMapLayer
## The inland pools (as the island was made): lists of ground cells, and a marker at each.
var _pools: Array = []
var _pool_marks: Array[Node2D] = []
## Cells that were land when the island was made (water there now = a dug channel).
var _base_land := {}
## Silt in each dug channel cell (1 = silted up).
var _silt := {}
var _last_tick := -1.0
var _last_seen := -1.0
var _seeded := false
## Sediment management (a mission): silting much slower until then (GameClock.now()).
var _sediment_until := -1.0
var _silt_note_day := -1
var _silt_marks: Array[Node2D] = []


func _enter_tree() -> void:
	add_to_group("ecosystems")
	add_to_group("interactables")  # nests and silting channels explain themselves close up


## How close the ranger must be to a nest or silting channel to find out what it is.
const LOOK_RANGE := 40.0
var _nests_at: Array[Vector2] = []


## Narrow channels (water with land on both sides) where a water gate can go, marked with
## two little posts.
var _gate_spots: Array[Vector2i] = []
## Water a gate needs behind it, in tiles along the channel (and at least 1 in front): no posts
## where a channel just ends in mud.
@export var gate_water_behind := 2
const GATE := preload("res://data/buildings/water_gate.tres")


func _find_gate_spots() -> void:
	_gate_spots.clear()
	var land := func(c: Vector2i) -> bool: return _terrain(c) in LAND
	for cell in _ground.get_used_cells():
		if not _is_water(cell):
			continue
		var along := Vector2i.ZERO  # the way the channel runs (banks on the other two sides)
		if land.call(cell + Vector2i.LEFT) and land.call(cell + Vector2i.RIGHT):
			along = Vector2i.UP
		elif land.call(cell + Vector2i.UP) and land.call(cell + Vector2i.DOWN):
			along = Vector2i.LEFT
		if along == Vector2i.ZERO:
			continue
		# A gate holds water back: water on both sides of it, at least `gate_water_behind` on one.
		var ahead := _water_run(cell, along)
		var behind := _water_run(cell, -along)
		if mini(ahead, behind) >= 1 and maxi(ahead, behind) >= gate_water_behind:
			_gate_spots.append(cell)


## Water tiles in a row from `cell` (not counting it) going `step`, up to 8 (open sea counts).
func _water_run(cell: Vector2i, step: Vector2i) -> int:
	var count := 0
	var at := cell + step
	while count < 8 and (_is_water(at) or _terrain(at) == "sea"):
		count += 1
		at += step
	return count


func _gate_at(cell: Vector2i) -> Building:
	var world_cell := Terrain.cell_of(_world(cell))
	for gate in gates():
		if gate.rect().has_point(world_cell):
			return gate
	return null


## Builds a water gate at `cell` straight away (if it can go there and the ranger can pay).
func _build_gate(cell: Vector2i) -> void:
	var build_mode: BuildMode = get_tree().get_first_node_in_group("build_mode")
	var world_cell := Terrain.cell_of(_world(cell))
	var problem := build_mode.placement_problem(GATE, world_cell)
	if problem != "":
		get_tree().call_group("hud", "show_toast", problem)
		return
	BuildMode.pay(GATE.cost_funding, GATE.cost_litter, GATE.cost_items)
	build_mode.add_building(GATE, world_cell)
	settle_now()
	get_tree().call_group("hud", "show_toast", "Water gate built. It's open: close it to hold water on the flats (it blocks this channel while closed). To take it away, demolish it.")


## For the action bar: what that mud mound or brown channel is, when the ranger is beside it.
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or not Regions.ranger_on(get_tree(), region()):
		return []
	var at := ranger.global_position
	for spot in _gate_spots:
		if _world(spot).distance_to(at) <= LOOK_RANGE and not _gate_at(spot):
			return [{"label": "Build gate", "do": _build_gate.bind(spot)}]
	for nest in _nests_at:
		if nest.distance_to(at) <= LOOK_RANGE:
			return [{"label": "Flamingo nest", "do": func() -> void:
				get_tree().call_group("hud", "show_toast", "A flamingo nest: a mound of mud with a single egg on top. Flamingos build them on the mud flats while the water level is right (water level %s)." % _level_word())}]
	for cell: Vector2i in _silt:
		if silt_of(cell) > 0.2 and _world(cell).distance_to(at) <= LOOK_RANGE:
			return [{"label": "Silt %d%%" % roundi(silt_of(cell) * 100.0), "do": func() -> void:
				get_tree().call_group("hud", "show_toast", "Silt is settling in this channel (%d%%). At 100%% it turns back into mud. Water standing still silts fast; flowing water, a full-grown mangrove beside it, or the station's channel restoration help." % roundi(silt_of(cell) * 100.0))}]
	return []


func _ready() -> void:
	_ground = get_parent().get_node("Ground")
	SaveGame.tile_changed.connect(func() -> void: _tiles_version += 1)
	for cell in _ground.get_used_cells():
		if _terrain(cell) in LAND:
			_base_land[cell] = true
	_find_pools()
	_find_gate_spots()
	GameClock.new_day.connect(func(_d: int) -> void:
		for mark in _silt_marks:
			if is_instance_valid(mark):
				mark.queue_free()
		_silt_marks.clear()
		if Regions.is_discovered(region()) and Regions.ranger_on(get_tree(), region()):
			_objective())


func region() -> RegionData:
	return DataFiles.res("res://data/regions/%s.tres" % region_id)


func _terrain(cell: Vector2i) -> String:
	var tile := _ground.get_cell_tile_data(cell)
	return "sea" if not tile else String(tile.get_custom_data("terrain"))


func _is_water(cell: Vector2i) -> bool:
	return _terrain(cell) in ["water", ""]


func _world(cell: Vector2i) -> Vector2:
	return _ground.to_global(_ground.map_to_local(cell))


func _cell(point: Vector2) -> Vector2i:
	return _ground.local_to_map(_ground.to_local(point))


## The pools as the island was made: its water not linked to the open sea.
func _find_pools() -> void:
	var reached := _flood({})
	var seen := {}
	for cell in _ground.get_used_cells():
		if not _is_water(cell) or reached.has(cell) or seen.has(cell):
			continue
		var pool: Array[Vector2i] = []
		var todo: Array[Vector2i] = [cell]
		seen[cell] = true
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back()
			pool.append(c)
			for d in NEIGHBOURS:
				var n: Vector2i = c + d
				if _is_water(n) and not seen.has(n) and not reached.has(n):
					seen[n] = true
					todo.append(n)
		_pools.append(pool)
		var mark := Node2D.new()
		mark.name = "Pool%d" % _pools.size()
		var centre := Vector2.ZERO
		for c in pool:
			centre += _world(c)
		add_child(mark)
		mark.global_position = centre / pool.size()
		_pool_marks.append(mark)


## Water cells linked to the open sea (through the island's water, not past `blocked`).
func _flood(blocked: Dictionary) -> Dictionary:
	var reached := {}
	var todo: Array[Vector2i] = []
	for cell in _ground.get_used_cells():
		if _is_water(cell) and not blocked.has(cell) and NEIGHBOURS.any(func(d: Vector2i) -> bool: return _terrain(cell + d) == "sea"):
			reached[cell] = true
			todo.append(cell)
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in NEIGHBOURS:
			var n: Vector2i = c + d
			if not reached.has(n) and not blocked.has(n) and _is_water(n):
				reached[n] = true
				todo.append(n)
	return reached


## Water linked to the sea right now (closed gates block it; so do channel tiles in
## `also_blocked`).
## (Read only: the same answer is kept until a tile or a gate changes, or a few seconds pass:
## filling the whole island took ~9 ms and it's asked often.)
func connected(also_blocked: Dictionary = {}) -> Dictionary:
	var blocked := also_blocked.duplicate()
	for gate in gates():
		if gate.gate_closed:
			blocked[_cell(Terrain.centre_of(gate.cell))] = true
	var key := "%d %s" % [_tiles_version, blocked.keys()]
	var now := Time.get_ticks_msec()
	if key == _reach_key and now - _reach_at < REACH_KEEP_MSEC:
		return _reach
	_reach = _flood(blocked)
	_reach_key = key
	_reach_at = now
	return _reach


var _reach := {}
var _reach_key := ""
var _reach_at := 0
var _tiles_version := 0
const REACH_KEEP_MSEC := 3000


func gates() -> Array[Building]:
	return _buildings(func(b: Building) -> bool: return b.data.action == &"gate")


func _buildings(which: Callable) -> Array[Building]:
	var list: Array[Building] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if not building.is_queued_for_deletion() and Regions.nearest(building.global_position).id == region_id and which.call(building):
			list.append(building)
	return list


## Pools linked to the sea, and nursery pools (linked, with a full-grown mangrove beside).
func pools_connected(reach: Dictionary = {}) -> int:
	if reach.is_empty():
		reach = connected()
	var n := 0
	for pool: Array in _pools:
		if pool.any(func(c: Vector2i) -> bool: return reach.has(c)):
			n += 1
	return n


func _pool_linked(i: int, reach: Dictionary) -> bool:
	return (_pools[i] as Array).any(func(c: Vector2i) -> bool: return reach.has(c))


func _pool_has_mangroves(i: int) -> bool:
	return grown_mangroves().any(func(t: Node2D) -> bool: return t.global_position.distance_to(_pool_marks[i].global_position) <= nursery_range)


func nursery_pools(reach: Dictionary = {}) -> int:
	if reach.is_empty():
		reach = connected()
	var n := 0
	for i in _pools.size():
		if _pool_linked(i, reach) and _pool_has_mangroves(i):
			n += 1
	return n


func pool_count() -> int:
	return _pools.size()


## The island's mangrove trees (full grown only, or every one planted).
func grown_mangroves(all := false) -> Array[Node2D]:
	var list: Array[Node2D] = []
	for tree: Node in get_tree().get_nodes_in_group("plants"):
		if tree is PalmTree and tree.sapling and tree.sapling.id == &"mangrove_propagule" and not tree.is_queued_for_deletion() \
				and Regions.nearest(tree.global_position).id == region_id and (all or tree.stage() == PalmTree.GROWN):
			list.append(tree)
	return list


## The flats' water level, 0..1, and whether it suits the flamingos.
func water_level() -> float:
	var closed := gates().filter(func(g: Building) -> bool: return g.gate_closed).size()
	var open := gates().size() - closed
	var rain := flood_water if GameClock.now() < _flood_water_until else 0.0
	return clampf(base_level + closed * level_per_closed - open * level_per_open + rain, 0.0, 1.0)


## A flash flood's rain also brings water back to the flats for a few days: dry flats come
## right for the flamingos for a while (the good a storm can bring).
@export var flood_water := 0.3
@export var flood_water_days := 2.0
var _flood_water_until := -1.0


## The water level in a word, for the flamingos' legs: "low", "right" or "high".
func water_depth_word() -> String:
	var level := water_level()
	return "low" if level < level_low - 0.001 else ("high" if level > level_high + 0.001 else "right")


func level_right() -> bool:
	return water_level() >= level_low - 0.001 and water_level() <= level_high + 0.001


## 1 inside the right range, falling to 0 a fifth of the way outside it.
func level_score() -> float:
	var level := water_level()
	var off := maxf(level_low - level, level - level_high)
	return clampf(1.0 - off / 0.2, 0.0, 1.0) if off > 0.0 else 1.0


## Water in balance, 0..1: pools linked to the sea, and the right water level.
func water_score(reach: Dictionary = {}) -> float:
	var linked := float(pools_connected(reach)) / maxf(_pools.size(), 1)
	return 0.5 * linked + 0.5 * level_score()


## Mud tiles beside water: where flamingos feed and nest.
func flats() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for cell in _ground.get_used_cells():
		if _terrain(cell) == "mud" and NEIGHBOURS.any(func(d: Vector2i) -> bool: return _is_water(cell + d)):
			list.append(cell)
	return list


## Dug channels: water now where there was land.
func channels() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for cell: Vector2i in _base_land:
		if _is_water(cell):
			list.append(cell)
	return list


func silt_of(cell: Vector2i) -> float:
	return _silt.get(cell, 0.0)


## How much slower silt settles island-wide right now: sediment screens.
func _silt_scale() -> float:
	var scale := 1.0
	if _sediment_until > GameClock.now():
		scale *= 0.25
	return maxf(scale, 0.1)


func _shelter(cell: Vector2i) -> float:
	var point := _world(cell)
	var near := grown_mangroves().filter(func(t: Node2D) -> bool: return t.global_position.distance_to(point) <= shelter_range).size()
	return minf(near * mangrove_shelter, max_shelter)


var _flow_left := 2.0
var _steer_left := 0.25


func _process(_delta: float) -> void:
	if not Regions.is_discovered(region()):
		_last_tick = -1.0
		return
	if not _seeded:
		_seed()
	var now := GameClock.now()
	if _last_tick < 0.0:
		_last_tick = now
	# Paused while the ranger is on another island.
	if _last_seen >= 0.0 and now > _last_seen and not Regions.ranger_on(get_tree(), region()):
		_last_tick += now - _last_seen
	_last_seen = now
	var ticks := 0
	while now - _last_tick >= tick_days and ticks < 32:
		tick(tick_days)
		_last_tick += tick_days
		ticks += 1
	if now - _last_tick >= tick_days:
		_last_tick = now
	_flow_left -= _delta
	if _flow_left <= 0.0:
		_flow_left = 2.0
		if Regions.ranger_on(get_tree(), region()):
			_check_flowing()
			_crabs_work()
		else:
			_work_at = -1.0
	_steer_left -= _delta
	if _steer_left <= 0.0:
		_steer_left = 0.25
		_steer_crabs()
	if int(now * 40.0) != int(_last_draw * 40.0):
		_last_draw = now
		queue_redraw()


var _last_draw := 0.0


## One step, `days` long: silt settles in the channels, then the animals follow the water.
func tick(days: float) -> void:
	var reach := connected()
	var scale := _silt_scale()
	for cell in channels():
		if _occupied(cell):
			continue
		_silt[cell] = silt_of(cell) + _silt_rate(cell, reach, scale) * days
		if _silt[cell] >= 1.0:
			_silt_up(cell)
	_bank_damage(days)
	settle()


## Too many crabs: their burrows undercut the banks round the busiest Crab Habitat, silting the
## channels there.
func _bank_damage(days: float) -> void:
	var extra := working(CRAB).size() - crabs_too_many
	if extra <= 0:
		return
	var busiest: Building = null
	var most := 0
	for home in _buildings(func(b: Building) -> bool: return b.data.hosts == CRAB.id):
		var here := living(CRAB).filter(func(c: Animal) -> bool: return c.home_area == home).size()
		if here > most:
			busiest = home
			most = here
	if not busiest:
		return
	var cells := channels()
	for spot in _gate_spots:
		if not spot in cells:
			cells.append(spot)
	for cell in cells:
		if _occupied(cell) or _world(cell).distance_to(busiest.global_position) > bank_damage_range:
			continue
		_silt[cell] = silt_of(cell) + bank_damage_per_day * extra * days
		if _silt[cell] >= 1.0:
			_silt_up(cell)


## Crabs at work: crab -> the channel tile it's clearing, and where it lived before.
var _jobs := {}
## Crab -> the corners of its walk to the bank still ahead (crabs only walk in straight lines and
## stop where their mud and grass end, so they're led along the land, corner by corner).
var _paths := {}
var _work_at := -1.0
## How far (in tiles walked over mud and grass) a crab goes to dig a channel out.
const CRAB_WALK_TILES := 10


## Every couple of seconds while the ranger is here: crabs at their tile dig its silt out (a tile
## clear: off roaming again, or on to the next); free crabs head for the most silted tile they
## can walk to.
func _crabs_work() -> void:
	var now := GameClock.now()
	var days := clampf(now - _work_at, 0.0, 0.5) if _work_at >= 0.0 else 0.0
	_work_at = now
	for crab: Animal in _jobs.keys():
		var cell: Vector2i = _jobs[crab]
		if not is_instance_valid(crab) or crab.leaving or crab.tangled or crab.injured or not _silt.has(cell) or not _is_water(cell):
			_end_job(crab)
			continue
		if _paths.has(crab) or crab.global_position.distance_to(_work_spot(cell)) > 24.0:
			continue  # still on its way
		_silt[cell] = silt_of(cell) - crab_clear_per_day * days
		if _silt[cell] <= 0.01:
			_silt.erase(cell)
			_end_job(crab)
		queue_redraw()
	var wanted := _silt.keys().filter(func(c: Vector2i) -> bool:
		return silt_of(c) >= crab_work_from and _is_water(c) and _bank(c) != Vector2i.MAX and not c in _jobs.values())
	if wanted.is_empty():
		return
	for crab in working(CRAB):
		if crab.young or crab.leaving or _jobs.has(crab):
			continue
		var from := _cell(crab.global_position)
		var came := _walkable_from(from)
		var best := Vector2i.MAX
		for cell: Vector2i in wanted:
			if came.has(_bank(cell)) and (best == Vector2i.MAX or silt_of(cell) > silt_of(best)):
				best = cell
		if best == Vector2i.MAX:
			continue
		var corners: Array[Vector2] = []
		var at := _bank(best)
		while at != from:  # back along the walk, keeping only where it turns
			var before: Vector2i = came[at]
			if corners.is_empty() or came.get(before, before) - before != before - at:
				corners.push_front(_world(before))
			at = before
		corners.append(_work_spot(best))
		_jobs[crab] = best
		_paths[crab] = corners
		wanted.erase(best)
		crab.home_radius = 4.0
		crab.set_home(corners[0])


## A few times a second: crabs on their way to a bank walk on to the next corner.
func _steer_crabs() -> void:
	for crab: Animal in _paths.keys():
		if not is_instance_valid(crab) or not _jobs.has(crab):
			_paths.erase(crab)
			continue
		var corners: Array = _paths[crab]
		if crab.global_position.distance_to(corners[0]) > 6.0:
			continue
		corners.pop_front()
		if corners.is_empty():
			_paths.erase(crab)
		else:
			crab.set_home(corners[0])


## Mud and grass a crab can walk to from `start`, within CRAB_WALK_TILES: cell -> the cell it
## came from.
func _walkable_from(start: Vector2i) -> Dictionary:
	var came := {start: start}
	var todo: Array[Vector2i] = [start]
	var steps := {start: 0}
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if steps[c] >= CRAB_WALK_TILES:
			continue
		for d: Vector2i in NEIGHBOURS:
			var n: Vector2i = c + d
			if not came.has(n) and _terrain(n) in CRAB.habitat_terrain:
				came[n] = c
				steps[n] = steps[c] + 1
				todo.append(n)
	return came


func _end_job(crab: Animal) -> void:
	if is_instance_valid(crab):
		crab.home_radius = CRAB.adult_home_radius
		crab.set_home(crab.global_position)  # roams on from here
	_jobs.erase(crab)
	_paths.erase(crab)


## The bank a crab digs channel tile `cell` from (mud or grass beside it), or Vector2i.MAX.
func _bank(cell: Vector2i) -> Vector2i:
	for d: Vector2i in NEIGHBOURS:
		if _terrain(cell + d) in CRAB.habitat_terrain:
			return cell + d
	return Vector2i.MAX


## Where a crab sits to dig channel tile `cell` out: on its bank, at the water's edge.
func _work_spot(cell: Vector2i) -> Vector2:
	var bank := _bank(cell)
	return Vector2.INF if bank == Vector2i.MAX else _world(bank) - Vector2(bank - cell) * 10.0


## Silt a day settling in channel `cell`.
func _silt_rate(cell: Vector2i, reach: Dictionary, scale: float) -> float:
	return silt_per_day * (flowing_silt if reach.has(cell) else 1.0) * (1.0 - _shelter(cell)) * scale


## Channel tiles that will have silted up within `days` if nothing changes.
func _silting_within(days: float) -> Dictionary:
	var reach := connected()
	var scale := _silt_scale()
	var soon := {}
	var worked: Array = _jobs.values()
	for cell in channels():
		if not _occupied(cell) and not cell in worked and silt_of(cell) + _silt_rate(cell, reach, scale) * days >= 1.0:
			soon[cell] = true
	return soon


## A building, tree or boat keeps its tile as it is.
func _occupied(cell: Vector2i) -> bool:
	var world_cell := Terrain.cell_of(_world(cell))
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.rect().has_point(world_cell):
			return true
	for boat: Node2D in get_tree().get_nodes_in_group("boat"):
		if Terrain.cell_of(boat.global_position) == world_cell:
			return true
	return false


## A channel tile silted up: mud again (it can be dug out again).
func _silt_up(cell: Vector2i) -> void:
	_silt.erase(cell)
	_ground.set_cell(cell, 0, MUD_TILE)
	SaveGame.record_tile(_ground, cell, MUD_TILE)
	if _silt_note_day != GameClock.day:
		_silt_note_day = GameClock.day
		get_tree().call_group("hud", "show_toast",
			"A channel silted up")


## Right away after the ranger digs, builds, or opens or closes a gate.
func settle_now() -> void:
	if Regions.is_discovered(region()):
		settle()


## Each species takes one step towards what the island supports now.
func settle() -> void:
	_follow(FISH, fish_supported())
	_follow(FLAMINGO, flamingos_supported())
	_follow(CRAB, crabs_supported())
	_spread_crabs()
	_follow(CROCODILE, crocodiles_supported())
	_nests_at = _nest_spots()
	_find_gate_spots()  # digging and silting change the channels
	queue_redraw()


func fish_supported(reach: Dictionary = {}) -> int:
	return fish_base + fish_per_nursery * nursery_pools(reach)


func flamingos_supported() -> int:
	if not level_right():
		return 1
	return clampi(flats().size() / flats_per_flamingo, 1, flamingo_max)


## Mud-mound nests on the flats: every flamingo builds one while the water level is right.
func nests() -> int:
	return mini(living(FLAMINGO).size(), flamingo_max) if level_right() else 0


func crabs_supported() -> int:
	var room := 0
	for home in _buildings(func(b: Building) -> bool: return b.data.hosts == CRAB.id):
		if not home.damaged and home.upkeep_paid:
			room += home.capacity()
	return maxi(room, 1)


func crocodiles_supported() -> int:
	return maxi(_buildings(func(b: Building) -> bool: return b.data.hosts == CROCODILE.id).size(), 1)


## The island's animals of `species` (not ones moving away).
func living(species: AnimalData) -> Array[Animal]:
	var list: Array[Animal] = []
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data == species and not animal.leaving and Regions.nearest(animal.global_position).id == region_id:
			list.append(animal)
	return list


## Not caught or hurt (they help again once the ranger has helped them).
func working(species: AnimalData) -> Array[Animal]:
	return living(species).filter(func(a: Animal) -> bool: return not a.tangled and not a.injured)


## One more of `species` arrives, or one moves away, towards `target` (never below 1).
func _follow(species: AnimalData, target: int) -> void:
	target = maxi(target, 1)
	var now := living(species)
	if now.size() > target:
		var going: Animal = now.filter(func(a: Animal) -> bool: return not a.tangled).back() if now.any(func(a: Animal) -> bool: return not a.tangled) else null
		if going:
			going.leaving = true
			get_tree().call_group("hud", "show_toast", "A %s has moved away: %s" % [species.display_name.to_lower(), _why_leaving(species)])
		return
	if now.size() >= target:
		return
	if not Regions.helped(get_tree(), region()):
		return  # nothing new comes until the ranger has helped the island (Regions.helped)
	if not Births.can_have(get_tree(), species, region()):
		return  # its parents' last young are still too little (or one drifted in just now)
	var animal := _spawn(species, _spot_for(species))
	Births.bring(animal, region(), "It has come to the Mangrove Coast: %s" % _why_coming(species))
	if species == CRAB:
		var homes := _buildings(func(b: Building) -> bool: return b.data.hosts == CRAB.id)
		if not homes.is_empty():
			animal.home_area = homes.pick_random()


func _why_leaving(species: AnimalData) -> String:
	match species:
		FISH:
			return "fewer nursery pools are linked to the sea."
		FLAMINGO:
			return "the water on the flats isn't right for feeding (%s)." % _level_word()
		CRAB:
			return "there's no room for it at a Crab Habitat."
	return "there isn't a quiet place for it."


func _why_coming(species: AnimalData) -> String:
	match species:
		FISH:
			return "a nursery pool with mangroves is linked to the sea."
		FLAMINGO:
			return "the water on the flats is just right for feeding."
		CRAB:
			return "a Crab Habitat has room for it."
	return "a Crocodile Protection Zone gives it quiet water."


func _level_word() -> String:
	var level := water_level()
	return "too low: close a gate" if level < level_low else ("too high: open a gate" if level > level_high else "right")


## A spot on the mud round `at`, apart from the other crabs' homes (they used to pile up on
## the one mud tile nearest their habitat).
func _mud_near(at: Vector2) -> Vector2:
	var taken := living(CRAB).map(func(a: Animal) -> Vector2: return a.home())
	for attempt in 30:
		var spot := at + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0)
		if Terrain.at(get_tree(), spot) == "mud" and not taken.any(func(t: Vector2) -> bool: return t.distance_to(spot) < 20.0):
			return spot
	return Terrain.nearest(get_tree(), at, ["mud"])


## Crabs sharing a home spot (from older versions) move to their own bit of mud, and grown ones
## roam the island over mud and grass (older saves kept them on one small mud patch).
func _spread_crabs() -> void:
	var homes: Array[Vector2] = []
	for crab in living(CRAB):
		if crab.young or _jobs.has(crab):
			continue
		crab.home_radius = maxf(crab.home_radius, CRAB.adult_home_radius)
		var home := crab.home()
		if homes.any(func(h: Vector2) -> bool: return h.distance_to(home) < 12.0):
			home = _mud_near(home)
			crab.set_home(home)
		homes.append(home)


## Where a newcomer of `species` turns up.
func _spot_for(species: AnimalData) -> Vector2:
	var reach := connected()
	match species:
		FISH:
			var best := Terrain.nearest(get_tree(), region().center + Vector2(-260, 60), ["water"])
			for i in _pools.size():
				if _pool_linked(i, reach) and _pool_has_mangroves(i):
					best = _pool_marks[i].global_position
					if living(FISH).filter(func(f: Animal) -> bool: return f.home().distance_to(best) < 40.0).size() < fish_per_nursery:
						break
			return best
		FLAMINGO, CRAB:
			var spots := flats()
			if species == CRAB:
				var homes := _buildings(func(b: Building) -> bool: return b.data.hosts == CRAB.id)
				if not homes.is_empty():
					return _mud_near((homes.pick_random() as Building).global_position)
			return _world(spots[randi() % spots.size()]) if not spots.is_empty() else region().center
		CROCODILE:
			var zones := _buildings(func(b: Building) -> bool: return b.data.hosts == CROCODILE.id)
			var at := (zones.pick_random() as Building).global_position if not zones.is_empty() else region().center + Vector2(0, region().waters_radius * 0.5)
			return Terrain.nearest(get_tree(), at, ["water", ""])
	return region().center


## Puts a grown animal of `species` into the world at `spot` (saved like the island's own).
func _spawn(species: AnimalData, spot: Vector2) -> Animal:
	var animal: Animal = DataFiles.res("res://scenes/animals/animal.tscn").instantiate()
	animal.data = species
	animal.born_at = maxf(GameClock.now() - species.grow_days, 0.0)
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var n := 1
	while world.has_node("%s%d" % [species.id.to_pascal_case(), n]):
		n += 1
	animal.name = "%s%d" % [species.id.to_pascal_case(), n]
	animal.home_radius = 40.0 if species == FISH else (60.0 if species == CRAB else 140.0)
	animal.position = spot
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	return animal


## When the ranger first finds the island, every species is there but struggling: a crab
## trapped in a plastic bag, 2 young snappers out at sea (no nursery to grow up in), one
## hungry flamingo on dry flats with no nest, one restless crocodile.
func _seed() -> void:
	_seeded = true
	var spots := flats()
	var crab := _spawn(CRAB, _world(spots[0]) if not spots.is_empty() else region().center)
	crab.tangle(DataFiles.res("res://data/items/plastic_bag.tres"))
	for i in 2:
		_spawn(FISH, Terrain.nearest(get_tree(), region().center + Vector2(-260 + i * 40, 60), ["water"]))
	_spawn(FLAMINGO, _world(spots[spots.size() / 2]) if not spots.is_empty() else region().center)
	_spawn(CROCODILE, Terrain.nearest(get_tree(), region().center + Vector2(0, region().waters_radius * 0.5), ["water", ""]))


## The mud-mound nest within `radius` of `point` (a resting flamingo sits on it), or null.
func mound_near(point: Vector2, radius: float) -> Variant:
	for spot: Vector2 in _nests_at:
		if spot.distance_to(point) <= radius:
			return spot
	return null


## Nests on the flats (mud mounds, one per flamingo while the water is right) and silt
## building up in the channels (brown, as it gets closer to silting up).
func _draw() -> void:
	for spot in _gate_spots:  # where a gate can go: two little posts on the banks
		if _gate_at(spot):
			continue
		var at := to_local(_world(spot))
		var across := Vector2(1, 0) if _terrain(spot + Vector2i.LEFT) in LAND else Vector2(0, 1)
		for side in [-1.0, 1.0]:
			var post: Vector2 = at + across * 14.0 * side
			draw_rect(Rect2(post - Vector2(2, 5), Vector2(4, 7)), Color(0.48, 0.34, 0.2, 0.85))
			draw_rect(Rect2(post - Vector2(2, 5), Vector2(4, 2)), Color(0.66, 0.5, 0.3, 0.85))
	for spot in _nests_at:  # (the owner's style: a pixel picture at twice the pixels, a soft shadow)
		var at := to_local(spot)
		draw_texture_rect(Shadow._texture(), Rect2(at + Vector2(-8, 1), Vector2(16, 6)), false)
		draw_texture_rect(NEST_PICTURE, Rect2(at - Vector2(7, 8), NEST_PICTURE.get_size() / 2.0), false)
	if GameClock.now() < _pools_shown_until:  # after the water flow survey, for a day
		var reach := connected()
		for i in _pools.size():
			var at := to_local(_pool_marks[i].global_position)
			if _pool_linked(i, reach):
				draw_circle(at, 9.0, Color(0.55, 0.85, 1.0, 0.35))
				draw_arc(at, 9.0, 0.0, TAU, 24, Color(0.85, 0.97, 1.0, 0.95), 2.0)
			else:
				draw_circle(at, 9.0, Color(0.95, 0.85, 0.6, 0.5))
				draw_arc(at, 9.0, 0.0, TAU, 24, Color(0.42, 0.22, 0.1, 0.95), 2.0)
				draw_line(at + Vector2(-5, -5), at + Vector2(5, 5), Color(0.42, 0.22, 0.1, 0.95), 2.0)
				draw_line(at + Vector2(5, -5), at + Vector2(-5, 5), Color(0.42, 0.22, 0.1, 0.95), 2.0)
	for cell: Vector2i in _silt:
		var silt: float = _silt[cell]
		if silt > 0.2:
			draw_rect(Rect2(to_local(_world(cell)) - Vector2(16, 16), Vector2(32, 32)), Color(0.45, 0.33, 0.2, 0.15 + silt * 0.45))


## Where the nests are: flat tiles near the middle of the flats, spread out.
func _nest_spots() -> Array[Vector2]:
	var list: Array[Vector2] = []
	var count := nests()
	if count == 0:
		return list
	var spots := flats()
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return KelpEcosystem._noise(a) < KelpEcosystem._noise(b))
	for cell in spots:
		if list.size() >= count:
			break
		var at := _world(cell)
		if list.all(func(p: Vector2) -> bool: return p.distance_to(at) >= 96.0):
			list.append(at)
	return list


## For island health (HealthFactor kind "eco"): how far along `target` is, 0..1.
func eco_score(factor: HealthFactor, projected := {}) -> float:
	if factor.target == &"water":
		return projected.get("water", water_score())
	return clampf(eco_count(factor.target, projected) / float(maxi(factor.amount, 1)), 0.0, 1.0)


func eco_count(target: StringName, projected := {}) -> float:
	if projected.has(target):
		return projected[target]
	match target:
		&"mangroves":
			return grown_mangroves().size()
		&"nests":
			return nests()
		&"water":
			return water_score()
	return 0.0


func eco_describe(factor: HealthFactor) -> String:
	match factor.target:
		&"mangroves":
			return "%s: %d full grown (%d for full health)" % [factor.text, grown_mangroves().size(), factor.amount]
		&"nests":
			return "%s: %d / %d (water level %s)" % [factor.text, mini(nests(), factor.amount), factor.amount, _level_word()]
		&"water":
			return "%s: %d of %d pools linked to the sea, water level %s" % [factor.text, pools_connected(), _pools.size(), _level_word()]
	return factor.text


## Where the island settles if the ranger leaves everything as it is: the animals reach what
## the water supports; planted mangroves grow up; channels cut off from the sea silt up (so
## nothing more is linked than now).
func project() -> Dictionary:
	var reach := connected(_silting_within(project_days))
	var grown := grown_mangroves(true).size()
	var crabs := crabs_supported()
	return {"water": water_score(reach), "mangroves": grown,
		"nests": mini(flamingos_supported(), flamingo_max) if level_right() else 0,
		FISH.id: fish_supported(reach), FLAMINGO.id: flamingos_supported(), CRAB.id: crabs,
		CROCODILE.id: crocodiles_supported()}


## Flash flood: silt dumped in every channel (half as much where water flows out to sea).
## Returns how many channel tiles silted up.
## How far ahead the gauge looks for channels silting up.
@export var project_days := 4.0


func flood(amount: float) -> int:
	var was_dry := water_depth_word() == "low"
	_flood_water_until = GameClock.now() + flood_water_days
	if was_dry and water_depth_word() != "low":
		get_tree().call_group("clue_watchers", "storm_water")
	var reach := connected()
	var hit := 0
	var cells := channels()
	for spot in _gate_spots:  # the island's own narrow channels silt too (open gates flush it)
		if not spot in cells:
			cells.append(spot)
	for cell in cells:
		if _occupied(cell):
			continue
		_silt[cell] = silt_of(cell) + amount * (0.5 if reach.has(cell) else 1.0)
		if _silt[cell] >= 1.0:
			_silt_up(cell)
			hit += 1
	_find_gate_spots()
	settle()
	return hit


## The objective (RegionData.goals): once the nursery is linked (most pools connected) and
## the island is healthy, fallen mangrove branches with resin turn up each morning.
@export_group("Objective")
@export var flowing_at := 0.7
## 3 of the 5 (the owner): some gates stay shut to hold water on the flats.
@export var pools_needed := 3
@export var flowing_flag := &"mangrove_flowing"
@export var resin_count := &"mangrove_resin"
@export var resin_needed := 5
@export var resin_per_day := 2
const RESIN := preload("res://data/items/resin_branch.tres")


## Marks the water flowing once enough pools are linked and the island is healthy enough
## (checked every couple of seconds while the ranger is here, and each morning).
func _check_flowing() -> bool:
	if Fleet.has_flag(flowing_flag):
		return true
	if pools_connected() < pools_needed or IslandHealth.of(get_tree(), region()) < flowing_at:
		return false
	Fleet.mark(flowing_flag)
	get_tree().call_group("hud", "show_toast", "Water flowing through the mangroves", true)
	return true


## The water flow survey marks the 5 pools (linked: a blue ring; cut off: a brown cross) for
## this long; never before it (the owner).
const POOLS_SHOWN_DAYS := 1.0
var _pools_shown_until := -1.0


## Which way pool `i` lies from the island's middle: "north", "south-west"...
func _pool_way(i: int) -> String:
	var to := _pool_marks[i].global_position - region().center
	const WAYS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	return WAYS[posmod(roundi(to.angle() / (TAU / 8.0)), 8)]


## What Samuel, the island's hint-giver, says about the water ("{advice:water}", every talk until
## it flows): which pools are still cut off, in words, or what's left once enough are linked.
func advice(factor: HealthFactor) -> String:
	if factor == null or factor.target != &"water":
		return ""
	if pools_connected() >= pools_needed:
		return "That's %d pools joined to the sea! Now the island needs to be 70 %% healthy." % pools_connected() \
			if not Fleet.has_flag(flowing_flag) else "The water's flowing through the pools."
	var reach := connected()
	var ways: Array[String] = []
	for i in _pools.size():
		if not _pool_linked(i, reach) and not _pool_way(i) in ways:
			ways.append(_pool_way(i))
	var listed := ", ".join(ways.slice(0, -1)) + " and " + ways[-1] if ways.size() > 1 else ways[0]
	return "The pools to the %s are still cut off from the sea. The station's water survey marks them for a day." % listed


## The goal line for the objective (People.goal_text), only what's still missing, kept short
## (the owner): "Pools 2/3", then "Island health 70 %".
func goal_progress(target: StringName) -> String:
	if target != flowing_flag:
		return ""
	if pools_connected() < pools_needed:
		return "Pools %d/%d" % [pools_connected(), pools_needed]
	return "Island health %d %%" % roundi(flowing_at * 100.0)


func _objective() -> void:
	if not _check_flowing():
		return
	if Fleet.count_of(resin_count) >= resin_needed:
		return
	var lying := get_tree().get_nodes_in_group("debris").filter(func(d: Debris) -> bool: return d.item == RESIN).size()
	var spawner: LitterSpawner = null
	for s: LitterSpawner in get_tree().get_nodes_in_group("litter_spawner"):
		if Regions.nearest(s.area.get_center()).id == region_id:
			spawner = s
	var trees := grown_mangroves()
	trees.shuffle()
	if not spawner:
		return
	for tree in trees.slice(0, maxi(resin_per_day - lying, 0)):
		var spot := Terrain.nearest(get_tree(), tree.global_position + Vector2(20, 12), ["mud", "sand", "grass"])
		spawner.spawn_at(RESIN, spot, false)


## The Waterworks Station's missions (MissionData.effect) this ecosystem runs.
const MISSIONS := [&"water_flow", &"nursery", &"water_level", &"channel_restoration", &"sediment", &"mangrove_wildlife"]
## Channel restoration clears this many of the most silted channel tiles.
@export var restore_tiles := 8


func handles(effect: StringName) -> bool:
	return effect in MISSIONS


func run_mission(mission: MissionData) -> Dictionary:
	var reach := connected()
	match mission.effect:
		&"water_flow":
			_pools_shown_until = GameClock.now() + POOLS_SHOWN_DAYS
			queue_redraw()
			var cut := []
			for i in _pools.size():
				if not _pool_linked(i, reach):
					cut.append(_pool_marks[i])
			var silting := channels().filter(func(c: Vector2i) -> bool: return silt_of(c) >= 0.4)
			var found: Array = cut + _mark_cells(silting)
			return {"found": found, "detail": "%d of %d pools are linked to the sea. %s%s" % [
				_pools.size() - cut.size(), _pools.size(),
				("%d are cut off (marked): dig through the mud between them and open water with your shovel. Keep the mud: it can build flats or fill a channel in again. " % cut.size()) if cut else "",
				("%d channel tile(s) are silting up (marked): water standing still silts fast. A full-grown mangrove beside them, or opening a gate that blocks them, slows it." % silting.size()) if silting
				else "No channels are silting up badly."]}
		&"nursery":
			var need_trees := []
			var cut := []
			for i in _pools.size():
				if not _pool_linked(i, reach):
					cut.append(_pool_marks[i])
				elif not _pool_has_mangroves(i):
					need_trees.append(_pool_marks[i])
			var nurseries := nursery_pools(reach)
			return {"found": need_trees + cut, "detail": "%d young snapper(s) live here; %d nursery pool(s) send about %d a day out to sea to grow up on the reefs. %s%s" % [
				living(FISH).size(), nurseries, nurseries * fish_per_nursery,
				("%d linked pool(s) have no full-grown mangroves beside them (marked): plant mangrove propagules in the mud next to them. " % need_trees.size()) if need_trees else "",
				("%d pool(s) are cut off from the sea (marked): young fish there can't get out." % cut.size()) if cut else ""]}
		&"water_level":
			var level := water_level()
			var closed := gates().filter(func(g: Building) -> bool: return g.gate_closed)
			var open := gates().filter(func(g: Building) -> bool: return not g.gate_closed)
			var advice := ""
			if gates().is_empty():
				advice = "There are no water gates yet: build one across a narrow channel and close it to hold water on the flats."
			elif level < level_low:
				advice = "Close a gate (open ones are marked) to hold more water on the flats. Put gates where they don't cut off a nursery pool."
			elif level > level_high:
				advice = "Open a gate (closed ones are marked): the flats are flooded too deep for flamingos."
			else:
				advice = "Flamingos can feed and nest."
			return {"found": open if level < level_low else (closed if level > level_high else []),
				"detail": "The water on the flats is %s (%d%%, right between %d%% and %d%%). %d gate(s) closed, %d open. %s" % [
					_level_word().get_slice(":", 0), roundi(level * 100.0), roundi(level_low * 100.0), roundi(level_high * 100.0),
					closed.size(), open.size(), advice]}
		&"channel_restoration":
			var list := channels().filter(func(c: Vector2i) -> bool: return silt_of(c) > 0.05)
			list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return silt_of(a) > silt_of(b))
			list = list.slice(0, restore_tiles)
			for cell: Vector2i in list:
				_silt.erase(cell)
			return {"found": _mark_cells(list), "detail": ("The team cleared silt from %d channel tile(s) (marked); the water flows freely there again." % list.size())
				if list else "No channels needed clearing: the silt hasn't built up yet."}
		&"sediment":
			_sediment_until = GameClock.now() + mission.effect_days
			return {"found": [], "detail": "Silt screens are up: channels silt up far more slowly for %d days. A good time to dig the channels you need." % roundi(mission.effect_days)}
		&"mangrove_wildlife":
			var crabs := living(CRAB).size()
			var lines := PackedStringArray()
			lines.append("Crabs: %d%s." % [crabs, " (too many: their burrows are undercutting the banks round the busiest Crab Habitat and silting the channels there; fewer Crab Habitats would help)" if crabs > crabs_too_many
				else " (each digs the silt out of the channels near it, one tile at a time; Crab Habitats near your channels give more room)"])
			lines.append("Young snappers: %d, from %d nursery pool(s)." % [living(FISH).size(), nursery_pools(reach)])
			lines.append("Flamingos: %d, with %d nest(s) (water level %s)." % [living(FLAMINGO).size(), nests(), _level_word()])
			var zones := _buildings(func(b: Building) -> bool: return b.data.hosts == CROCODILE.id).size()
			lines.append("Crocodiles: %d, with %d protection zone(s)%s." % [living(CROCODILE).size(), zones,
				": a zone would give it quiet water" if zones == 0 else ""])
			var caught := get_tree().get_nodes_in_group("animals").filter(func(a: Animal) -> bool:
				return a.tangled and Regions.nearest(a.global_position).id == region_id)
			if caught:
				lines.append("%d animal(s) are caught in litter (marked): free them." % caught.size())
			return {"found": caught, "detail": " ".join(lines)}
	return {}


## Minimap marks for channel cells (freed the next morning).
func _mark_cells(cells: Array) -> Array:
	var marks := []
	for cell: Vector2i in cells:
		var mark := Node2D.new()
		add_child(mark)
		mark.global_position = _world(cell)
		_silt_marks.append(mark)
		marks.append(mark)
	return marks


## For the save file (dug and silted tiles themselves are saved as tile edits).
func to_dict() -> Dictionary:
	var silt := {}
	for cell: Vector2i in _silt:
		silt["%d,%d" % [cell.x, cell.y]] = _silt[cell]
	return {"last_tick": _last_tick, "seeded": _seeded, "silt": silt, "sediment_until": _sediment_until,
		"flood_water_until": _flood_water_until, "pools_shown_until": _pools_shown_until}


func restore(saved: Dictionary) -> void:
	_last_tick = float(saved.get("last_tick", -1.0))
	_flood_water_until = float(saved.get("flood_water_until", -1.0))
	_pools_shown_until = float(saved.get("pools_shown_until", -1.0))
	_seeded = bool(saved.get("seeded", false))
	_sediment_until = float(saved.get("sediment_until", -1.0))
	_silt.clear()
	var silt: Dictionary = saved.get("silt", {})
	for key: String in silt:
		var parts := key.split(",")
		if parts.size() == 2:
			_silt[Vector2i(int(parts[0]), int(parts[1]))] = float(silt[key])
