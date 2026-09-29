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
	if data.flies:
		collision_mask = 0
		z_index = 2  # over the trees
	_land_mask = collision_mask
	_fly_left = randf_range(0.0, data.fly_seconds.y)
	if young:
		_sprite.scale = Vector2(0.5, 0.5)
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


## Hatchlings get bigger as they grow, then grow up (not while crawling to the sea).
func _grow() -> void:
	var age := clampf((GameClock.now() - born_at) / data.grow_days, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * lerpf(0.5, 0.85, age)
	if age >= 1.0 and _state != State.CRAWL:
		grow_up()


## Grown up: full size, off to a spot of its own in the island's waters, and nesting
## from the next time it's due.
func grow_up() -> void:
	young = false
	last_nest_day = GameClock.day
	create_tween().tween_property(_sprite, "scale", Vector2.ONE, 1.5)
	home_radius = maxf(home_radius, data.adult_home_radius)
	_home = _own_spot()
	_rest(0.1)
	if _grow_note_day != GameClock.day:  # one note a day, however many grow up
		_grow_note_day = GameClock.day
		get_tree().call_group("hud", "show_toast", "Your young %ss are growing up and swimming out to live around the island!\nKeep some water free of patrol boats for them." % data.display_name.get_slice(" ", data.display_name.get_slice_count(" ") - 1).to_lower())


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
	if _state == State.CRAWL or _state == State.LAY:
		_nesting(delta)
		return
	if leaving:
		_swim_out_to_sea()
		return
	_react_to_ranger(delta)
	_avoid_busy_boats()
	_maybe_nest()
	_maybe_guide()
	if _tree_nesting(delta):
		return

	var speed := data.swim_speed * (0.5 if tangled or injured else 1.0)
	match _state:
		State.REST:
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
	move_and_slide()
	_face(velocity)
	# Blocked by land (e.g. fled towards the beach): rest, then pick somewhere else.
	if get_real_velocity().length() < 1.0:
		_rest(data.rest_min)


## Tree nesters fly about for a while, then fly back to their nest and stand on it (easy
## to photograph). Rushing at them makes them take off. Returns true while it's handling
## the movement (flying to the nest, perched).
func _tree_nesting(delta: float) -> bool:
	if not data.nests_in_trees:
		return false
	if tangled or injured or _state == State.FLEE or _guide_to:
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
		_perch_left -= delta
		if _perch_left <= 0.0:
			take_off()
		return perched
	if not _to_nest:
		_fly_left -= delta
		if _fly_left > 0.0 or not _has_nest_tree():
			return false
		_to_nest = true
	var to_nest: Vector2 = nest_tree.perch_point() - global_position
	if to_nest.length() < 3.0:
		_perch()
		return true
	velocity = to_nest.normalized() * data.swim_speed
	move_and_slide()
	_face(velocity)
	return true


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
	_rest(0.1)


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
	if tangled:
		restore_freed()
		if tangle_item:
			Inventory.add(tangle_item)
		SaveGame.mark_freed(self)
		Journal.help(data)
	elif not photographed_today():
		photo_day = GameClock.day
		Journal.photograph(data)


func photographed_today() -> bool:
	return photo_day == GameClock.day


func _swim_to(target: Vector2, state: State) -> void:
	_target = target
	_state = state


func _rest(seconds: float) -> void:
	_state = State.REST
	_rest_left = seconds


## A random spot in its habitat (e.g. the sea, or the beach) within home_radius of home.
func _pick_target() -> Vector2:
	if data.circles_litter and not tangled:
		var litter := _nearest_floating_litter_to(_home, data.circle_range)
		if litter:  # circling over it shows the ranger where it is
			return litter.global_position + Vector2.from_angle(randf() * TAU) * randf_range(16.0, 32.0)
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
	return spot if in_habitat(spot) else _home


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
func _face(motion: Vector2) -> void:
	if data.faces_movement:
		_sprite.rotation = lerp_angle(_sprite.rotation, motion.angle(), 0.1)
	elif motion.x != 0.0:
		_sprite.flip_h = motion.x < 0.0


func _maybe_nest() -> void:
	if young or tangled or injured or data.nest_building == &"" or not GameClock.is_night():
		return
	if GameClock.day - last_nest_day < data.nest_interval_days:
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
