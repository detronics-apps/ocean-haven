class_name Animal
extends CharacterBody2D
## A sea animal that lives around a home spot: swims to random places in the
## water and rests. It reacts to *how* the ranger approaches: rushing at it makes
## it swim off; staying still nearby lets it relax (curious ones come closer).
## Once relaxed, the ranger can quietly observe it, photograph it, or free it if
## it's tangled in fishing line. Never touching, chasing or feeding.
## Species that nest (see AnimalData.nest_building) come ashore at night to lay
## eggs at the right building; hatchlings crawl to the sea and live there.
## Species details come from `data` (an AnimalData .tres).

enum State { REST, SWIM, FLEE, CURIOUS, CRAWL, LAY, GUIDE }

## How long a startled animal swims away before settling.
const FLEE_SECONDS := 2.0
## A ranger "moving" further than this in one frame jumped (boarding, loading) — not rushing.
const JUMP_DISTANCE := 64.0
const LAY_SECONDS := 6.0
## Crabs only dig up litter when the ranger is close enough to see it happen.
const DIG_WATCH_RANGE := 250.0
## Guiding animals show "follow me" to a ranger within this distance.
const FOLLOW_HINT_RANGE := 250.0
## A curious animal keeps the ranger company this long, then gets on with its day.
const CURIOUS_SECONDS := 20.0
## Physics layers: sea animals are blocked by land, land animals by water.
const WATER_LAYER := 1
## Leaving hatchlings are gone once this far from the middle of the world.
const OPEN_OCEAN_DISTANCE := 900.0
const LAND_LAYER := 4
const NEST_SCENE := "res://scenes/animals/nest.tscn"
const BANDAGE := preload("res://assets/effects/injured/bandage.svg")

@export var data: AnimalData
## How far from its home spot it wanders.
@export var home_radius := 140.0
## Tangled in fishing line: swims slowly until the ranger frees it.
@export var tangled := false
## Hurt (by a storm): slow and doesn't nest until a Rescue mission helps it recover. Never
## worse than that, never for good.
@export var injured := false
## Added to the inventory when the ranger frees it (the line is litter too).
@export var tangle_item: ItemData
## A hatchling: smaller, and doesn't nest. Grows up after data.grow_days.
@export var young := false
## GameClock.now() when it hatched here (-1 = it didn't: it was always here, or arrived).
var born_at := -1.0
## The grown one a young one follows round until it's grown (Births).
var parent: Animal
## A young one to be born where this one is going (Births.bring): it appears beside it there.
var _due: Animal
var _due_at := Vector2.INF
var _due_left := 0.0
var _due_note := ""
var _due_region: RegionData
## Not born yet (Births): hidden until its parent gets to where it belongs.
var unborn := false
## A hatchling with no room at home: once in the water it swims off into the open ocean.
@export var leaving := false
## Only passing through (dolphin tracking's visitor): not one of the island's own.
var visiting := false
## When it lost its home (GameClock.now(); -1 = it has one, or doesn't need one).
var homeless_since := -1.0
## Day this animal last nested (spaces nests out by nest_interval_days).
var last_nest_day := -99
## The protection area this animal belongs to (where it hatched or nests), or null.
var home_area: Node2D

## Circling over something (litter, trouble): a flying bird keeps flying and never lands.
var circling := false
var _state := State.REST
var _target: Vector2
var _rest_left := 0.0
var _flee_left := 0.0
## Seconds the ranger has stayed calm nearby, and has watched it while relaxed.
var _calm := 0.0
var _watched := 0.0
## Seconds spent keeping a calm ranger company (see CURIOUS_SECONDS).
var _company := 0.0
## Divers: under the water right now, and seconds until they surface / dive again.
var underwater := false
var _breath_left := 0.0
var _last_ranger_pos := Vector2.INF
## Litter this animal is leading the ranger to (trusting dolphins).
var _guide_to: Node2D
## Carriers (otters): the litter it's fetching or bringing ashore, where it's taking it
## (a water spot beside `_carry_land`), seconds on this trip, and seconds until it looks again.
var _carry: Debris
var _carry_ashore := false
var _carry_shore := Vector2.ZERO
var _carry_land := Vector2.ZERO
var _carry_time := 0.0
var _carry_wait := 0.0
static var _carry_note_day := -1
const LAND := ["sand", "grass", "mud", "rock", "ice"]
const CARRY_GIVE_UP := 40.0
## Guides: the ranger has played with it, so it'll show them the next litter it finds.
var played := false
## Day the ranger last photographed this animal: one photo per animal per day.
## ponytail: not saved, so reloading allows another photo that day.
var photo_day := -1
## Tree nesters: the palm with its nest, standing on it right now, flying there, and
## seconds left of flying / perching.
var nest_tree: Node2D
var perched := false
var _to_nest := false
var _fly_left := 0.0
var _perch_left := 0.0
## Where it's leaving from (the middle of its island), and how far it goes before it's gone.
var _leave_from := Vector2.INF
var _leave_distance := 0.0
## Day the "growing up" note was last shown (one a day).
static var _grow_note_day := -1
## Diggers: litter dug up today by each species (all of them together): id -> [day, count].
## ponytail: not saved, so reloading resets today's count.
static var _digs := {}
## What normally blocks it (switched off while crawling over land to nest).
var _land_mask: int
var _lay_left := 0.0
## What to do on reaching the end of a crawl.
var _crawl_then: Callable

@onready var _home := global_position
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tangle: Sprite2D = $Sprite2D/Tangle
## What to tell the ranger about it right now ("" = nothing). The HUD shows just the
## nearest animal's, in one place (not a label over every animal).
var info := ""
## Close enough for the ranger to observe, photograph or help it.
var _in_reach := false
var _bandage: Sprite2D


func _enter_tree() -> void:
	add_to_group("animals")
	add_to_group("interactables")


func _ready() -> void:
	_sprite.texture = data.sprite
	_tangle.visible = tangled
	if tangle_item:
		_tangle.texture = tangle_item.icon  # whatever it's caught in: line, net, bag...
	_rest_left = randf_range(0.0, data.rest_max)
	collision_mask = WATER_LAYER if _lives_on_land() else LAND_LAYER
	if _water_only() or _land_and_water():
		collision_mask = 0  # (tiles collide like walls: these check the ground ahead instead)
	if data.flies:
		collision_mask = 0
		z_index = 2  # over the trees
	_land_mask = collision_mask
	_fly_left = randf_range(0.0, data.fly_seconds.y)
	if young:
		_sprite.scale = Vector2.ONE if _own_young_picture() else Vector2(0.5, 0.5)
		if _own_young_picture():
			_sprite.texture = data.young_sprites[stage()]
	if data.shows_water_level:  # the water (or mud) round its legs: how deep it's standing
		var wading := ShaderMaterial.new()
		wading.shader = WADING
		_sprite.material = wading
	_bandage = Sprite2D.new()
	_bandage.texture = BANDAGE
	_bandage.position = Vector2(0, -12)
	_bandage.z_index = 3
	_bandage.visible = injured
	add_child(_bandage)


func is_relaxed() -> bool:
	return _calm >= data.calm_time


## Frees it without the reward (loading a save where it was already freed).
func restore_freed() -> void:
	tangled = false
	_tangle.visible = false
	if perched:  # freed on its nest: it stands there a while as usual, then flies off
		_perch_left = randf_range(data.perch_seconds.x, data.perch_seconds.y)


## Caught in `item` (litter left about): swims slowly until the ranger frees it again.
func tangle(item: ItemData) -> void:
	tangled = true
	tangle_item = item
	_tangle.texture = item.icon
	_tangle.visible = true


## Hurt by a storm: needs a Rescue mission (the station) to recover.
func injure() -> void:
	injured = true
	if _bandage:
		_bandage.visible = true
	if perched or _to_nest:
		take_off()


## Helped by the rescue team: well again.
func recover() -> void:
	injured = false
	if _bandage:
		_bandage.visible = false


## Where it lives (for the save file).
func home() -> Vector2:
	return _home


## Lives round `spot` from now on, and heads there.
func set_home(spot: Vector2) -> void:
	_home = spot
	_swim_to(spot, State.SWIM)


## Not yet born (Births): not seen, not moving, nothing to do with it.
func hide_until_born() -> void:
	unborn = true
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	remove_from_group("interactables")


func is_expecting() -> bool:
	return is_instance_valid(_due)


## Goes to `spot` (where its young one belongs: its sanctuary, habitat, zone...), and the young
## one is born beside it there (or where it is after a while, if it can't get there).
func expect(baby: Animal, spot: Vector2, note: String, region: RegionData) -> void:
	_due = baby
	_due_at = spot
	_due_left = Births.DUE_SECONDS
	_due_note = note
	_due_region = region
	baby.global_position = spot
	set_home(spot)


func give_birth_now() -> void:
	_due_left = 0.0
	_check_birth(0.0)


func _check_birth(delta: float) -> void:
	if not is_instance_valid(_due):
		_due = null
		return
	_due_left -= delta
	if global_position.distance_to(_due_at) > 40.0 and _due_left > 0.0:
		return
	var baby := _due
	_due = null
	var beside := global_position + Vector2(randf_range(-10.0, 10.0), randf_range(4.0, 10.0))
	if not baby.in_habitat(beside):
		beside = global_position
	baby.global_position = beside
	baby._home = _due_at
	baby.unborn = false
	baby.visible = true
	baby.process_mode = Node.PROCESS_MODE_INHERIT
	baby.add_to_group("interactables")
	get_tree().call_group("hud", "animal_returned", data, _due_note, _due_region)


## Puts a hatchling back where it was (loading a save). If it was still on the
## beach, it carries on to the sea.
func restore_young(pos: Vector2, home_spot: Vector2) -> void:
	global_position = pos
	_home = home_spot
	if Terrain.at(get_tree(), pos) in ["sand", "grass"]:
		crawl_to_sea()


## Heads down the beach into the water (hatchlings, and adults after nesting).
func crawl_to_sea() -> void:
	var water := Terrain.nearest(get_tree(), global_position, ["water", ""])
	# A random spot in that water tile, so hatchlings fan out instead of stacking up.
	var spread := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
	_crawl_to(water + spread, true, _settle_in_water)


func _process(delta: float) -> void:
	if data.dives:
		_breathe(delta)
	if young and not leaving and data.grow_days > 0.0 and born_at >= 0.0:
		_grow()


## Young: 0 = a baby, 1 = growing up (each half of grow_days), 2 = grown.
func stage() -> int:
	if not young or born_at < 0.0 or data.grow_days <= 0.0:
		return 2
	return clampi(int((GameClock.now() - born_at) / (data.grow_days / 2.0)), 0, 2) if young else 2


## Shows its own young pictures (AnimalData.young_sprites) while growing up.
func _own_young_picture() -> bool:
	return young and data.young_sprites.size() >= 2 and stage() < 2


## Young ones get bigger as they grow (or show their young pictures), then grow up (not
## while crawling to the sea).
func _grow() -> void:
	var age := clampf((GameClock.now() - born_at) / data.grow_days, 0.0, 1.0)
	_sprite.scale = Vector2.ONE if _own_young_picture() else Vector2.ONE * lerpf(0.5, 0.85, age)
	if _own_young_picture():
		_pose()
	if age >= 1.0 and _state != State.CRAWL:
		grow_up()


## Grown up: full size, off to a spot of its own in the island's waters, and nesting
## from the next time it's due.
func grow_up() -> void:
	young = false
	var followed := parent != null  # born beside a parent (Births): it already has its own spot
	parent = null  # grown: off on its own
	if data.young_sprites.size() >= 2:
		_sprite.texture = data.sprite
	last_nest_day = GameClock.day
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 1.5)
	home_radius = maxf(home_radius, data.adult_home_radius)
	if not followed:
		_home = _own_spot()
	_rest(0.1)
	var ranger := ControlledBody.active(get_tree())
	if not ranger or Regions.nearest(ranger.global_position) != Regions.nearest(global_position):
		return  # (it just happens on islands the ranger isn't on)
	var kind: String = data.display_name.get_slice(" ", data.display_name.get_slice_count(" ") - 1).to_lower()
	if followed:
		get_tree().call_group("hud", "show_toast", "A young %s has grown up and gone its own way." % kind)
	elif _grow_note_day != GameClock.day:  # one note a day, however many grow up
		_grow_note_day = GameClock.day
		get_tree().call_group("hud", "show_toast", "Your young %ss are growing up and swimming out to live around the island!\nKeep some water free of patrol boats for them." % kind)


## A spot in its island's waters it can swim straight to, away from busy boats and as
## far as it can be from other grown-ups of its kind (so they spread out).
func _own_spot() -> Vector2:
	var region := Regions.nearest(global_position)
	var best := _home
	var best_room := -1.0
	var near := get_tree().get_nodes_in_group(data.settles_near).filter(func(n: Node2D) -> bool:
		return Regions.nearest(n.global_position) == region) if data.settles_near != &"" else []
	if is_instance_valid(home_area):  # close enough to forage from its own home
		var close := near.filter(func(n: Node2D) -> bool:
			return n.global_position.distance_to(home_area.global_position) <= data.forage_range)
		if not close.is_empty():
			near = close
	for attempt in 40:
		var spot := region.center + Vector2.from_angle(randf() * TAU) * randf_range(0.35, 0.85) * region.waters_radius
		if not near.is_empty():  # e.g. otters live among the kelp
			spot = (near.pick_random() as Node2D).global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 60.0)
		if not in_habitat(spot) or _near_busy_boat(spot) or not _clear_route(global_position, spot):
			continue
		var room := INF
		for other: Animal in get_tree().get_nodes_in_group("animals"):
			if other != self and other.data == data and not other.young and not other.leaving:
				room = minf(room, other.home().distance_to(spot))
		if room > best_room:
			best_room = room
			best = spot
	return best


## Water all the way from `from` to `to` (a sea animal can swim straight there).
func _clear_route(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / 16.0)
	for i in steps + 1:
		if not in_habitat(from.lerp(to, float(i) / maxf(steps, 1))):
			return false
	return true


## Divers come up for air, then dive and fade to a faint shadow under the water.
func _breathe(delta: float) -> void:
	_breath_left -= delta
	if _breath_left <= 0.0:
		underwater = not underwater
		var seconds := data.dive_seconds if underwater else data.surface_seconds
		_breath_left = randf_range(seconds.x, seconds.y)
	var target_alpha := 0.18 if underwater else 1.0
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target_alpha, delta * 1.5)


func _physics_process(delta: float) -> void:
	if _due:
		_check_birth(delta)
	if _state == State.CRAWL or _state == State.LAY:
		_nesting(delta)
		return
	if leaving:
		_swim_out_to_sea()
		return
	_keep_in_habitat(delta)
	_react_to_ranger(delta)
	_avoid_busy_boats()
	_maybe_nest()
	_maybe_guide()
	_maybe_carry(delta)
	if not young and (_tree_nesting(delta) or _ground_nesting(delta)):
		return

	_pose()
	var speed := data.swim_speed * (0.5 if tangled or injured else 1.0)
	var on_land := data.land_sprite != null and not Terrain.at(get_tree(), global_position) in ["water", ""]
	if data.land_sprite and not _own_young_picture():
		var picture := data.land_sprite if on_land else data.sprite
		if _sprite.texture != picture:
			_sprite.texture = picture
			_sprite.rotation = 0.0
		if on_land:
			speed *= data.land_speed  # slow, humping along on the ice
	match _state:
		State.REST:
			if data.flies and circling:  # circling over something: round again, never landing
				_swim_to(_pick_target(), State.SWIM)
				return
			velocity = Vector2.ZERO
			_rest_left -= delta
			# A curious animal stays beside a calm ranger rather than wandering off.
			if _rest_left <= 0.0 and not _keeping_company():
				_maybe_dig()
				_swim_to(_pick_target(), State.SWIM)
			return
		State.FLEE:
			speed *= 2.0
			_flee_left -= delta
			if _flee_left <= 0.0:
				_rest(data.rest_min)
				return
		State.CURIOUS:
			speed *= 0.6

	var to_target := _target - global_position
	if to_target.length() < 4.0:
		_rest(randf_range(data.rest_min, data.rest_max))
		return
	velocity = to_target.normalized() * speed
	if not data.flies and in_habitat(global_position) and not in_habitat(global_position + velocity.normalized() * 10.0):
		_rest(data.rest_min)  # its habitat ends here: never step out of it (then flicker back)
		return
	move_and_slide()
	_face(velocity)
	# Blocked by land (e.g. fled towards the beach): rest, then pick somewhere else.
	if get_real_velocity().length() < 1.0:
		_rest(data.rest_min)


## Tree nesters fly about for a while, then fly back to their nest and stand on it (easy
## to photograph). Rushing at them makes them take off. A bird caught in litter flies back
## to its nest and waits there until the ranger frees it. Returns true while it's handling
## the movement (flying to the nest, perched).
func _tree_nesting(delta: float) -> bool:
	if not data.nests_in_trees:
		return false
	var caught := tangled and not injured
	if caught and _state == State.FLEE:
		_state = State.REST  # too tangled up to fly off from the ranger
	if injured or (not caught and (_state == State.FLEE or _guide_to)):
		if perched or _to_nest:
			take_off()
		return false
	if not _has_nest_tree():
		var palm := PalmTree.free_grown_near(get_tree(), _home)
		if palm:
			set_nest_tree(palm)
		elif perched or _to_nest:
			take_off()
	if perched:
		velocity = Vector2.ZERO
		global_position = nest_tree.perch_point()
		if not caught:
			_perch_left -= delta
		if _perch_left <= 0.0 and not caught:
			take_off()
		return perched
	if not _to_nest:
		_fly_left -= delta
		if (_fly_left > 0.0 and not caught) or not _has_nest_tree():
			return false
		_to_nest = true
	var to_nest: Vector2 = nest_tree.perch_point() - global_position
	if to_nest.length() < 3.0:
		_perch()
		return true
	velocity = to_nest.normalized() * data.swim_speed
	_fly_pose()
	move_and_slide()
	_face(velocity)
	return true


## Ground nesters (Arctic terns) fly about, then land on their nest and sit on it for a while.
func _ground_nesting(delta: float) -> bool:
	if not data.nests_on_ground or visiting:
		return false
	if injured or (_state == State.FLEE and not tangled) or _guide_to:
		if perched or _to_nest:
			take_off()
		return false
	if _nest_spot == Vector2.INF or _nest_check <= 0.0:
		_nest_check = 10.0
		_nest_spot = _ground_nest()
	_nest_check -= delta
	if _nest_spot == Vector2.INF:
		return false
	if perched:
		velocity = Vector2.ZERO
		global_position = _nest_spot
		if not tangled:
			_perch_left -= delta
		if _perch_left <= 0.0 and not tangled:
			take_off()
		return true
	if not _to_nest:
		_fly_left -= delta
		if _fly_left > 0.0 and not tangled:
			return false
		_to_nest = true
	var to_nest := _nest_spot - global_position
	if to_nest.length() < 3.0:
		perched = true
		_to_nest = false
		_perch_left = randf_range(data.perch_seconds.x, data.perch_seconds.y)
		global_position = _nest_spot
		velocity = Vector2.ZERO
		_sprite.rotation = 0.0
		if data.perched_sprite:
			_sprite.texture = data.perched_sprite
		return true
	velocity = to_nest.normalized() * data.swim_speed
	_fly_pose()
	move_and_slide()
	_face(velocity)
	return true


## Its nest on the ground: in its nesting area if it has one, else on the nearest rock to its
## home (INF = nowhere to nest).
func _ground_nest() -> Vector2:
	var near := home_area.global_position if is_instance_valid(home_area) else _home
	var spot := Terrain.nearest(get_tree(), near, ["rock"], 6)
	if Terrain.at(get_tree(), spot) != "rock":
		return Vector2.INF
	return spot + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0))


var _nest_spot := Vector2.INF
var _nest_check := 0.0


func _has_nest_tree() -> bool:
	return is_instance_valid(nest_tree) and not nest_tree.is_queued_for_deletion() and nest_tree.nest_of == self


## Its nest is now in `palm` (null = no nest: flown off). Moving a nest makes it take off.
func set_nest_tree(palm: Node2D) -> void:
	if is_instance_valid(nest_tree) and nest_tree.nest_of == self:
		nest_tree.nest_of = null
	nest_tree = palm
	if palm:
		palm.nest_of = self
	if perched or _to_nest:
		take_off()


func _perch() -> void:
	perched = true
	_to_nest = false
	_perch_left = randf_range(data.perch_seconds.x, data.perch_seconds.y)
	global_position = nest_tree.perch_point()
	velocity = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.flip_h = randf() < 0.5
	if data.perched_sprite:
		_sprite.texture = data.perched_sprite


func take_off() -> void:
	perched = false
	_to_nest = false
	_fly_left = randf_range(data.fly_seconds.x, data.fly_seconds.y)
	_sprite.texture = data.sprite
	_sprite.flip_h = false
	_swim_to(_pick_target(), State.SWIM)


## Boat-shy animals swim off from a patrol boat that comes close.
func _avoid_busy_boats() -> void:
	if data.boat_shy_distance <= 0.0 or _state == State.FLEE or tangled:
		return
	var boat := _nearest_busy_boat(global_position)
	if boat != Vector2.INF and boat.distance_to(global_position) < data.boat_shy_distance:
		_state = State.FLEE
		_flee_left = FLEE_SECONDS
		_target = _flee_spot(boat)


## The nearest patrol boat's position (INF if none).
func _nearest_busy_boat(point: Vector2) -> Vector2:
	var best := Vector2.INF
	if Missions.is_on(&"boat_patrol"):
		return best  # the station's boat patrol keeps the waters calm
	for boat: Node in get_tree().get_nodes_in_group("busy_boats"):
		var at: Vector2 = boat.hull_position()
		if at.distance_to(point) < best.distance_to(point):
			best = at
	return best


func _near_busy_boat(point: Vector2) -> bool:
	return data.boat_shy_distance > 0.0 and _nearest_busy_boat(point).distance_to(point) < data.boat_shy_distance


func _react_to_ranger(delta: float) -> void:
	_in_reach = false
	info = ""
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var pos := ranger.global_position
	var moved := pos.distance_to(_last_ranger_pos)
	_last_ranger_pos = pos
	var ranger_speed := 0.0 if moved > JUMP_DISTANCE else moved / delta
	var distance := global_position.distance_to(pos)
	if distance > data.discover_distance:
		_calm = 0.0
		_watched = 0.0
		_company = 0.0
		return
	Journal.discover(data)

	if ranger_speed > data.calm_speed:
		_calm = 0.0
		if distance < data.shy_distance and _state != State.FLEE:
			_state = State.FLEE
			_flee_left = FLEE_SECONDS
			_target = _flee_spot(pos)
	else:
		_calm += delta

	if is_relaxed() and _state != State.FLEE:
		if _keeping_company():
			_company += delta
		if _keeping_company() and distance > 48.0 and _state != State.CURIOUS and not _guide_to:
			_swim_to(pos + pos.direction_to(global_position) * 36.0, State.CURIOUS)
		if distance <= data.interact_distance:
			_watched += delta
			if _watched >= data.observe_time:
				Journal.observe(data)
				if has_meta("rescue_id"):
					Rescues.meet(get_meta("rescue_id"))

	if distance <= data.interact_distance:
		_in_reach = true
		var name := data.display_name
		if not is_relaxed():
			info = "%s: stay still so it can relax..." % name
		elif tangled:
			info = "%s: it's caught - free it!" % name
		elif injured:
			info = "%s: it's hurt. Send a Rescue mission from your station to help it recover." % name
		elif photographed_today():
			info = "%s: photographed today - see you tomorrow." % name
		elif perched:
			info = "%s: standing on its nest. Take a photo!" % name
		else:
			info = "%s: relaxed. Take a photo!" % name
		var reading := water_reading()
		if reading != "":
			info = "%s %s" % [name, reading]


## What a flamingo's legs say about the water level ("" = not a wader, or no flats here).
func water_reading() -> String:
	var depth := _water_depth()
	if depth == "":
		return ""
	return {"low": "with dry feet: the water's too low (close a gate).",
		"right": "wading ankle-deep and feeding: the water level is just right.",
		"high": "standing belly-deep, not feeding: the water's too high (open a gate)."}[depth]


## "low", "right" or "high" (the island's water level), or "" if it doesn't show it.
func _water_depth() -> String:
	if not data.shows_water_level:
		return ""
	for eco: Node in get_tree().get_nodes_in_group("ecosystems"):
		if eco.has_method("water_depth_word") and Regions.nearest(global_position) == eco.region():
			return eco.water_depth_word()
	return ""


## How many rows of its legs are under water at each water level, and sunk in mud.
const WADE_ROWS := {"low": 1, "right": 3, "high": 7}
const MUD_ROWS := 2
const WADING := preload("res://assets/effects/wading/wading.gdshader")
## Per texture: the lowest row with any pixels (its feet).
static var _feet_rows := {}
## Per tile (source / atlas coords): the tile's own colour.
static var _tile_colours := {}


## Wading (flamingos): only the pixels of its legs that are in the water take the water's
## colour, still showing the feet; in mud the feet are hidden in mud; on dry land, nothing.
func _update_wading() -> void:
	var wading := _sprite.material as ShaderMaterial
	if not wading:
		return
	var rows := 0
	var colour := Color.WHITE
	var tex := _sprite.texture
	if tex and (tex == data.sprite or tex == data.resting_sprite):
		var feet_row := _feet_row(tex)
		var feet := _sprite.to_global(Vector2(0.0, feet_row + 1.0 - tex.get_height() / 2.0) + _sprite.offset)
		for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
			var cell := ground.local_to_map(ground.to_local(feet))
			var tile := ground.get_cell_tile_data(cell)
			if not tile:
				continue
			var kind: String = tile.get_custom_data("terrain")
			if kind == "water":
				var depth := _water_depth()
				rows = WADE_ROWS.get(depth if depth != "" else "right", 3)
			elif kind == "mud":
				rows = MUD_ROWS
			if rows > 0:
				colour = _tile_colour(ground, cell) * ground.modulate
			wading.set_shader_parameter("see_through", kind == "water")
			break
		wading.set_shader_parameter("from_row", float(feet_row - rows + 1) if rows > 0 else 999.0)
	else:
		wading.set_shader_parameter("from_row", 999.0)
	wading.set_shader_parameter("ground_colour", colour)


static func _feet_row(tex: Texture2D) -> int:
	if not _feet_rows.has(tex):
		var image := tex.get_image()
		var row := tex.get_height() - 1
		if image:
			if image.is_compressed():
				image.decompress()
			while row > 0 and not range(image.get_width()).any(func(x: int) -> bool: return image.get_pixel(x, row).a > 0.1):
				row -= 1
		_feet_rows[tex] = row
	return _feet_rows[tex]


static func _tile_colour(ground: TileMapLayer, cell: Vector2i) -> Color:
	var source_id := ground.get_cell_source_id(cell)
	var atlas := ground.get_cell_atlas_coords(cell)
	var key := Vector3i(source_id, atlas.x, atlas.y)
	if not _tile_colours.has(key):
		var colour := Color(0.32, 0.55, 0.58)
		var source := ground.tile_set.get_source(source_id) as TileSetAtlasSource
		if source and source.texture:
			var image := source.texture.get_image()
			if image:
				if image.is_compressed():
					image.decompress()
				colour = image.get_pixelv(source.get_tile_texture_region(atlas).position + Vector2i(3, 3))
		_tile_colours[key] = colour
	return _tile_colours[key]


## Trusting (relaxed) guides the ranger has played with lead them to floating
## litter they've spotted, and keep at it until the litter has been picked up.
func _maybe_guide() -> void:
	if not data.guides_to_litter or tangled or injured or young or _state == State.FLEE:
		return
	if _guide_to and (not is_instance_valid(_guide_to) or _guide_to.is_queued_for_deletion()):
		_guide_to = null  # picked up: job done
		played = false  # play again for the next one
	if not _guide_to and is_relaxed() and played:
		_guide_to = _nearest_floating_litter(data.guide_range)
		if _guide_to:
			Journal.record_gift(data)
	if not _guide_to:
		return
	var beside := _guide_to.global_position + _guide_to.global_position.direction_to(global_position) * 20.0
	if global_position.distance_to(beside) > 4.0:
		_swim_to(beside, State.GUIDE)
	var ranger := ControlledBody.active(get_tree())
	if ranger and ranger.global_position.distance_to(global_position) <= FOLLOW_HINT_RANGE:
		info = "The %s found some litter - follow it!" % data.display_name.to_lower()


func _nearest_floating_litter(within: float) -> Node2D:
	var best: Node2D = null
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.floating and not debris.is_queued_for_deletion() 				and debris.global_position.distance_to(global_position) <= within 				and (not best or debris.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = debris
	return best


## Carriers (otters) fetch floating litter near them and leave it on the nearest shore.
func _maybe_carry(delta: float) -> void:
	if not data.carries_litter_ashore:
		return
	if tangled or injured or young or leaving or (_carry and not is_instance_valid(_carry)):
		_drop_carry()
		return
	if not _carry:
		_carry_wait -= delta
		if _carry_wait > 0.0:
			return
		_carry_wait = 2.0
		_carry = _litter_to_carry()
		if not _carry:
			return
		_carry.set_meta("carried_by", self)
		_carry_ashore = false
		_carry_time = 0.0
		_swim_to(_carry.global_position, State.SWIM)
		return
	_carry_time += delta
	if not _carry_ashore:
		if global_position.distance_to(_carry.global_position) < 12.0:
			_carry_land = Terrain.nearest(get_tree(), global_position, LAND)
			_carry_shore = _shore_beside(_carry_land)
			_carry_ashore = true
			_swim_to(_carry_shore, State.SWIM)
		elif _state == State.REST:
			_swim_to(_carry.global_position, State.SWIM)
		elif _carry_time > CARRY_GIVE_UP:
			_drop_carry()
		return
	_carry.global_position = global_position + Vector2(0, -6)  # held up out of the water
	if global_position.distance_to(_carry_shore) < 8.0 or _carry_time > CARRY_GIVE_UP \
			or (_state == State.REST and global_position.distance_to(_carry_land) < 56.0):
		_carry.put_ashore(_carry_land)
		_carry.remove_meta("carried_by")
		_carry = null
		_carry_wait = data.carry_rest
		Journal.record_gift(data)
		if _carry_note_day != GameClock.day:  # one note a day
			_carry_note_day = GameClock.day
			get_tree().call_group("hud", "show_toast", "A %s brought some litter ashore - pick it up on the beach!" % data.display_name.to_lower())
		_rest(1.0)
	elif _state == State.REST:
		_swim_to(_carry_shore, State.SWIM)


## Lets go of what it's carrying (it floats on where it is).
func _drop_carry() -> void:
	if is_instance_valid(_carry):
		_carry.remove_meta("carried_by")
	_carry = null


## Floating litter within carry_range that no one else is fetching, with land near it.
func _litter_to_carry() -> Debris:
	var best: Debris = null
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if not debris.floating or debris.is_queued_for_deletion() or not debris.item.is_litter \
				or debris.item.ranger_cleans or debris.has_meta("carried_by"):
			continue
		var distance := debris.global_position.distance_to(global_position)
		if distance <= data.carry_range and (not best or distance < best.global_position.distance_to(global_position)):
			best = debris
	if best and not Terrain.at(get_tree(), Terrain.nearest(get_tree(), best.global_position, LAND)) in LAND:
		return null  # no shore anywhere near
	return best


## The water spot just off `land`, on the side towards this animal.
func _shore_beside(land: Vector2) -> Vector2:
	for i in range(1, 9):
		var spot := land.move_toward(global_position, 8.0 * i)
		if in_habitat(spot):
			return spot
	return global_position


## Diggers (crabs) sometimes turn up buried litter while the ranger is watching.
func _nearest_floating_litter_to(point: Vector2, within: float) -> Node2D:
	var best: Node2D = null
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.floating and not debris.is_queued_for_deletion() and debris.item.is_litter \
				and debris.global_position.distance_to(point) <= within \
				and (not best or debris.global_position.distance_to(point) < best.global_position.distance_to(point)):
			best = debris
	return best


func _maybe_dig() -> void:
	if not data.digs_up_litter or tangled or injured or young or randf() > data.dig_chance:
		return
	var today: Array = _digs.get(data.id, [-1, 0])
	if today[0] != GameClock.day:
		today = [GameClock.day, 0]
	if today[1] >= data.digs_per_day:
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > DIG_WATCH_RANGE:
		return
	var spawner: LitterSpawner = get_tree().get_first_node_in_group("litter_spawner")
	if spawner and spawner.wash_up_at(_dig_spot(), false):
		_dug_at = GameClock.now()
		today[1] += 1
		Journal.record_gift(data)
	_digs[data.id] = today


## A random bit of its habitat right beside it.
func _dig_spot() -> Vector2:
	for attempt in 10:
		var spot := global_position + Vector2.from_angle(randf() * TAU) * randf_range(12.0, 40.0)
		if in_habitat(spot):
			return spot
	return global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))


func _input(event: InputEvent) -> void:
	# _input (not _unhandled_input) so helping an animal wins over boarding/walking.
	if not can_interact():
		return
	# A tap picks this exact animal; E goes to one animal only: see _is_first_choice().
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 24.0
	if tapped or (event.is_action_pressed("interact") and _is_first_choice()):
		get_viewport().set_input_as_handled()
		_interact()


## Curious and relaxed, and hasn't had enough of the ranger's company yet.
func _keeping_company() -> bool:
	return data.curious and is_relaxed() and _company < CURIOUS_SECONDS


## What the ranger can do with it right now, for the action bar: [{label, do}].
func actions() -> Array:
	if not can_interact():
		return []
	var list := []
	if tangled:
		list.append({"label": "Free the %s" % data.display_name, "do": _interact, "helps": true})
	elif not photographed_today():
		list.append({"label": "Photo: %s" % data.display_name, "do": _interact, "helps": false})
	if data.guides_to_litter and not tangled and not young and not played:
		list.append({"label": "Play with the %s" % data.display_name, "do": play})
	return list


## Guides: a splash and a leap; then it leads the ranger to the next litter it finds.
func play() -> void:
	played = true
	underwater = false
	_breath_left = maxf(_breath_left, 3.0)
	var leap := create_tween()
	leap.tween_property(_sprite, "position:y", -14.0, 0.25).set_ease(Tween.EASE_OUT)
	leap.parallel().tween_property(_sprite, "rotation", -0.4, 0.25)
	leap.tween_property(_sprite, "position:y", 0.0, 0.3).set_ease(Tween.EASE_IN)
	leap.parallel().tween_property(_sprite, "rotation", 0.0, 0.3)


## Relaxed and close enough for the ranger to observe, photograph or help it.
func can_interact() -> bool:
	return _in_reach and is_relaxed() and _state != State.GUIDE


## With several animals in reach, E goes to one: an animal that needs help first,
## then the one nearest the ranger.
func _is_first_choice() -> bool:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return false
	var best: Animal = null
	for other: Animal in get_tree().get_nodes_in_group("animals"):
		if not other.can_interact():
			continue
		if not best or (other.tangled and not best.tangled) or (other.tangled == best.tangled
				and other.global_position.distance_to(ranger.global_position)
				< best.global_position.distance_to(ranger.global_position)):
			best = other
	return best == self


func _interact() -> void:
	if has_meta("rescue_id"):
		Rescues.meet(get_meta("rescue_id"))  # one of the ranger's rescued animals: its name shows
	if tangled:
		restore_freed()
		if tangle_item:
			Inventory.add(tangle_item)
		SaveGame.mark_freed(self)
		Journal.help(data)
	elif not photographed_today():
		photo_day = GameClock.day
		Journal.photograph(data)
		_photo_moment()


## Photo moments: every moment the animal is in right now gets this photo, the latest one
## replacing the last (the first of each is also a new find).
func _photo_moment() -> void:
	var picture: Image = null
	for moment: PhotoMoment in data.moments:
		if Array(moment.when).all(moment_holds):
			if picture == null:
				picture = _snapshot()
			Journal.add_moment(data, moment, picture)


## Whether the animal is in situation `condition` now (PhotoMoment.when).
func moment_holds(condition: String) -> bool:
	var ground := Terrain.at(get_tree(), global_position)
	match condition:
		"young": return young
		"adult": return not young
		"day": return not GameClock.is_night()
		"night": return GameClock.is_night()
		"on:water": return ground in ["water", ""]
		"on:land": return not ground in ["water", ""]
		"nesting": return _state == State.LAY or (_state == State.CRAWL and _crawl_then.is_valid() and not young)
		"perched": return perched
		"flying": return data.flies and not perched
		"surfaced": return data.dives and not underwater
		"underwater": return data.dives and underwater
		"guiding": return _state == State.GUIDE
		"carrying": return _carry != null
		"digging": return _dug_at >= 0.0 and GameClock.now() - _dug_at < 0.05
		"near_boat":
			var ranger := ControlledBody.active(get_tree())
			return ranger is Boat and ranger.global_position.distance_to(global_position) < 120.0
		"visiting": return visiting
	if condition.begins_with("on:"):
		return ground == condition.trim_prefix("on:")
	if condition.begins_with("event:"):  # a seasonal moment on its island (SeasonEvent)
		var event := SeasonEvent.find(StringName(condition.trim_prefix("event:")))
		return event != null and event.is_on() and Regions.nearest(global_position).id == event.region
	return false


## A small picture of the animal where it is now (the screen around it).
func _snapshot() -> Image:
	var viewport := get_viewport()
	if not viewport or not viewport.get_texture() or DisplayServer.get_name() == "headless":
		return null  # (no pictures without a screen)
	var frame := viewport.get_texture().get_image()
	if not frame or frame.is_empty():
		return null
	# The animal and the tiles around it (4 x 3 tiles), in the screen's own pixels: through
	# the camera (zoom) and the window's stretch.
	var to_screen := viewport.get_final_transform() * get_global_transform_with_canvas()
	var at := to_screen.origin
	var scale := to_screen.get_scale().abs()
	var size := Vector2i(Vector2(PHOTO_TILES) * Terrain.TILE * scale)
	size = Vector2i(clampi(size.x, 16, frame.get_width()), clampi(size.y, 12, frame.get_height()))
	var corner := Vector2i(clampi(int(at.x) - size.x / 2, 0, frame.get_width() - size.x),
		clampi(int(at.y) - size.y / 2, 0, frame.get_height() - size.y))
	var crop := frame.get_region(Rect2i(corner, size))
	crop.resize(160, 120, Image.INTERPOLATE_NEAREST)
	return crop


## How much a photo shows around the animal, in tiles.
const PHOTO_TILES := Vector2(4, 3)


func photographed_today() -> bool:
	return photo_day == GameClock.day


func _swim_to(target: Vector2, state: State) -> void:
	_target = target
	_state = state


## A flying bird on the move: its flying picture (from above), whatever it showed before.
func _fly_pose() -> void:
	if data.flies and _sprite.texture != data.sprite:
		_sprite.texture = data.sprite
		_sprite.flip_h = false


func _rest(seconds: float) -> void:
	_state = State.REST
	_rest_left = seconds


## A random spot in its habitat (e.g. the sea, or the beach) within home_radius of home.
func _pick_target() -> Vector2:
	if data.circles_litter and not tangled:
		var litter := _nearest_floating_litter_to(_home, data.circle_range)
		circling = litter != null
		if litter:  # circling over it shows the ranger where it is
			return litter.global_position + Vector2.from_angle(randf() * TAU) * randf_range(16.0, 32.0)
	if young and parent == null and not data.drifts_in and data.nest_building == &"" and born_at >= 0.0:
		parent = Births.parent_for(self, Regions.nearest(global_position))  # (after loading a save)
	if young and is_instance_valid(parent) and not parent.leaving and not (data.flies and stage() == 0):
		# Growing up: keeps close to its parent (chicks that can't fly yet stay at the nest).
		var beside := parent.global_position + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 22.0)
		if in_habitat(beside):
			return beside
	if data.roams and not tangled and not injured and not young and randf() < data.roam_share:
		var wander := _roam_spot()
		if wander != Vector2.INF:
			return wander
	var spot := _home
	# Boat-shy animals: the spot furthest from busy boats, if none is clear of them.
	var furthest := Vector2.INF
	for attempt in 20:
		spot = _home + Vector2.from_angle(randf() * TAU) * randf() * home_radius
		if not in_habitat(spot):
			continue
		if not _near_busy_boat(spot):
			return spot
		if furthest == Vector2.INF or _nearest_busy_boat(spot).distance_to(spot) > _nearest_busy_boat(furthest).distance_to(furthest):
			furthest = spot
	if furthest != Vector2.INF:
		return furthest
	# Not much habitat around (a narrow beach): the nearest bit to a random spot,
	# rather than always heading back to exactly the same place.
	spot = Terrain.nearest(get_tree(), spot, Array(data.habitat_terrain), 4)
	if in_habitat(spot):
		return spot
	return _home if in_habitat(_home) else global_position


## A spot a little way off in its habitat, anywhere in its island's waters (INF = none found):
## roamers drift all round the island like this.
func _roam_spot() -> Vector2:
	var island := Regions.nearest(_home)
	for attempt in 16:
		var spot := global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 320.0)
		if spot.distance_to(island.center) > island.waters_radius * 0.92 or not in_habitat(spot):
			continue
		if not _near_busy_boat(spot):
			return spot
	return Vector2.INF


## Somewhere in its habitat, further from `danger` (so a crab runs along the beach
## instead of into the sea's edge).
func _flee_spot(danger: Vector2) -> Vector2:
	var away := danger.direction_to(global_position)
	# Mostly straight away, but on a narrow beach that's the sea: then along the shore.
	for attempt in 24:
		var spread := 1.2 if attempt < 8 else 1.7
		var spot := global_position + away.rotated(randf_range(-spread, spread)) * randf_range(40.0, 112.0)
		if in_habitat(spot) and spot.distance_to(danger) > global_position.distance_to(danger):
			return spot
	return global_position + away * 96.0


func in_habitat(point: Vector2) -> bool:
	return Terrain.at(get_tree(), point) in data.habitat_terrain


func _lives_on_land() -> bool:
	return not data.habitat_terrain.has("")


## Turns to swim the way it's going, or (crabs) just flips left/right.
## Walkers with more than one picture: standing still, walking, or flying off when startled.
func _pose() -> void:
	if _own_young_picture():  # growing up: its young picture, whatever it's doing
		var stage_picture: Texture2D = data.young_sprites[stage()]
		if _sprite.texture != stage_picture:
			_sprite.texture = stage_picture
			_sprite.rotation = 0.0
		return
	if data.shows_water_level:
		_update_wading.call_deferred()  # (after this pose's picture is set)
	if data.flies and data.resting_sprite:  # a bird: flying (from above), or landed (side view)
		var landed := _state == State.REST and not circling  # (only once it has really landed)
		var texture := data.sprite
		if landed:
			texture = data.floating_sprite if data.floating_sprite and Terrain.at(get_tree(), global_position) in ["water", ""] \
				else data.resting_sprite
		if _sprite.texture != texture:
			_sprite.texture = texture
			if landed:
				_sprite.flip_h = _sprite.rotation > PI / 2.0 or _sprite.rotation < -PI / 2.0
				_sprite.rotation = 0.0
			else:
				_sprite.flip_h = false
		return
	if not data.resting_sprite and not data.flying_sprite:
		return
	var texture := data.sprite
	if _state == State.FLEE and data.flying_sprite:
		texture = data.flying_sprite
	elif _state == State.REST and data.perched_sprite and not data.flies and _sit_on_mound():
		texture = data.perched_sprite  # (a flamingo resting by its mud-mound nest sits on it)
	elif _state == State.REST and data.resting_sprite:
		texture = data.resting_sprite
	if _sprite.texture != texture:
		_sprite.texture = texture


## A walker resting next to a mud-mound nest (MangroveEcosystem.mound_near) settles onto it.
func _sit_on_mound() -> bool:
	for eco: Node in get_tree().get_nodes_in_group("ecosystems"):
		if eco.has_method("mound_near"):
			var mound: Variant = eco.mound_near(global_position, 40.0)
			if mound != null:
				global_position = mound
				return true
	return false


## Water animals that find themselves on land (their channel silted up, or mud was put on
## their water) go back to the nearest water, checked about once a second.
func _keep_in_habitat(delta: float) -> void:
	_habitat_check -= delta
	if _habitat_check > 0.0:
		return
	_habitat_check = 1.0
	if not _water_only() or _state == State.CRAWL or _state == State.LAY or in_habitat(global_position):
		return
	var water := Terrain.nearest(get_tree(), global_position, Array(data.habitat_terrain))
	if not in_habitat(water):
		return
	global_position = water
	if not in_habitat(_home):
		_home = water
	_rest(0.5)


var _habitat_check := randf()
## When it last dug up litter (a photo moment).
var _dug_at := -1.0


## Lives on land (or ice) and in water both (seals).
func _land_and_water() -> bool:
	var kinds := Array(data.habitat_terrain)
	return not data.flies and kinds.any(func(t: String) -> bool: return t in ["water", ""]) \
		and kinds.any(func(t: String) -> bool: return t in ["sand", "grass", "mud", "rock", "ice"])


## Lives only in water (fish, turtles, dolphins, otters, crocodiles), never on land.
func _water_only() -> bool:
	return not data.flies and not Array(data.habitat_terrain).any(func(t: String) -> bool: return t in ["sand", "grass", "mud", "rock", "ice"])


func _face(motion: Vector2) -> void:
	if data.land_sprite and _sprite.texture == data.land_sprite:  # on land: side view, never turned
		_sprite.rotation = 0.0
		if motion.x != 0.0:
			_sprite.flip_h = motion.x < 0.0
		return
	if data.land_sprite:
		_sprite.flip_h = false
	if data.faces_movement:
		_sprite.rotation = lerp_angle(_sprite.rotation, motion.angle(), 0.1)
	elif motion.x != 0.0:
		_sprite.flip_h = motion.x < 0.0


## Days between its nests now: often in its nesting season, rarely (or never) outside it.
func nest_interval() -> int:
	if _island_needs_young():
		return 1  # the island has room for more: she nests the next night, any time of year
	if data.nest_season == &"" or GameClock.season() == data.nest_season:
		return data.nest_interval_days
	return data.off_season_interval_days if data.off_season_interval_days > 0 else 1 << 30


## Its nesting areas have room for young and no nest there is waiting to hatch yet.
func _island_needs_young() -> bool:
	if data.nest_building == &"" or Nest.island_room(self, data) <= 0:
		return false
	var island := Regions.nearest(global_position)
	return not get_tree().get_nodes_in_group("nests").any(func(n: Node2D) -> bool:
		return n.species == data and not n.is_queued_for_deletion() and Regions.nearest(n.global_position) == island)


## Old enough to nest: always for animals that came to the island; for ones that hatched here
## (nests_from_next_season), from the start of the next nesting season after they hatched.
func mature() -> bool:
	if young:
		return false
	if not data.nests_from_next_season or data.nest_season == &"" or born_at < 0.0:
		return true
	return GameClock.day >= GameClock.next_season_start(data.nest_season, born_at)


func _maybe_nest() -> void:
	if young or tangled or injured or data.nest_building == &"" or not GameClock.is_night():
		return
	if GameClock.day - last_nest_day < nest_interval():
		return
	if not mature():
		return
	var site := _nest_site()
	if not site:
		return
	last_nest_day = GameClock.day
	if not home_area:
		home_area = site  # she belongs to the area where she nests
	var beach_spot := site.global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0))
	# Swim to the water nearest the beach, then crawl up it to lay.
	var shore := Terrain.nearest(get_tree(), beach_spot, ["water", ""])
	_crawl_to(shore, false, func() -> void: _crawl_to(beach_spot, true, _lay))


## The kind of building it belongs to: where it lives (otters), or else where it nests (turtles).
func home_building() -> StringName:
	return data.lives_at if data.lives_at != &"" else data.nest_building


## Links it to the nearest protection area its species nests in that still has room
## (loading a save), so a reload spreads turtles out as they were, not all into one area.
func link_to_nearest_area() -> void:
	home_area = null  # don't count itself while looking for room
	var sites := get_tree().get_nodes_in_group("buildings").filter(
		func(b: Building) -> bool: return b.data.id == home_building())
	sites.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	for site: Building in sites:
		if site.room_for_animals() > 0:
			home_area = site
			return
	home_area = sites[0] if sites else null


func _nest_site() -> Node2D:
	var best: Node2D = null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == data.nest_building and not building.too_busy() and not building.damaged and (not best
				or building.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = building
	return best


## Moves to `point`, over land if `over_land`, then calls `then`.
func _crawl_to(point: Vector2, over_land: bool, then: Callable) -> void:
	_state = State.CRAWL
	_target = point
	_crawl_then = then
	collision_mask = 0 if over_land else _land_mask


func _nesting(delta: float) -> void:
	var ranger := ControlledBody.active(get_tree())
	var near := not young and ranger != null and ranger.global_position.distance_to(global_position) <= data.interact_distance
	info = "Shh... she's nesting. Give her space." if near else ""
	if _state == State.LAY:
		_lay_left -= delta
		if _lay_left <= 0.0:
			_finish_laying()
		return
	var to_target := _target - global_position
	if to_target.length() < 3.0:
		_crawl_then.call()
		return
	velocity = to_target.normalized() * data.swim_speed * 0.6
	move_and_slide()
	_face(velocity)
	# ponytail: straight-line route; if land is in the way, it crawls over it. Pathfinding when islands get complex.
	if collision_mask != 0 and get_real_velocity().length() < 1.0:
		collision_mask = 0


func _lay() -> void:
	_state = State.LAY
	_lay_left = LAY_SECONDS
	velocity = Vector2.ZERO
	Journal.record_nest(data)


func _finish_laying() -> void:
	var nest: Node2D = load(NEST_SCENE).instantiate()
	nest.set("species", data)
	nest.set("area", home_area)
	nest.set("laid_at", GameClock.now())
	nest.position = position
	var world := get_parent()
	world.add_child(nest)
	world.move_child(nest, get_index())  # under the turtle
	crawl_to_sea()


## Heading out to sea (a hatchling's "swimming frenzy", or an animal moving away from an
## island that can't support it): straight away from its island until it's out in the
## open ocean, then gone (never dies: it lives on elsewhere).
func _swim_out_to_sea() -> void:
	if _leave_from == Vector2.INF:
		var region := Regions.nearest(global_position)
		_leave_from = region.center
		_leave_distance = maxf(region.waters_radius, OPEN_OCEAN_DISTANCE)
		# A sea animal with no open water between it and the sea (e.g. a fish in an inland
		# pool) slips away where it is, rather than swimming over land.
		var out := global_position + (global_position - _leave_from).normalized() * 200.0
		if _water_only() and not _clear_route(global_position, out):
			create_tween().tween_property(self, "modulate:a", 0.0, 1.0).finished.connect(queue_free)
			_leave_distance = INF
	if _leave_distance == INF:
		return
	var away := global_position - _leave_from
	if away.length() > _leave_distance:
		queue_free()
		return
	collision_mask = 0  # heading away from the island, so nothing's in the way
	velocity = (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * data.swim_speed * 2.0
	move_and_slide()
	_face(velocity)


func _settle_in_water() -> void:
	collision_mask = _land_mask
	if leaving:
		_state = State.SWIM
		return
	if young:
		# Live in the water by the protection area it belongs to (it may be another beach).
		_home = Terrain.nearest(get_tree(), home_area.global_position, ["water", ""]) if home_area else global_position
	_rest(data.rest_min)
