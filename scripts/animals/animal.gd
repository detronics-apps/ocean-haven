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

@export var data: AnimalData
## How far from its home spot it wanders.
@export var home_radius := 140.0
## Tangled in fishing line: swims slowly until the ranger frees it.
@export var tangled := false
## Added to the inventory when the ranger frees it (the line is litter too).
@export var tangle_item: ItemData
## A hatchling: smaller, and doesn't nest.
@export var young := false
## A hatchling with no room at home: once in the water it swims off into the open ocean.
@export var leaving := false
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
## What normally blocks it (switched off while crawling over land to nest).
var _land_mask: int
var _lay_left := 0.0
## What to do on reaching the end of a crawl.
var _crawl_then: Callable

@onready var _home := global_position
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _tangle: Sprite2D = $Sprite2D/Tangle
@onready var _hint: Label = $Hint


func _enter_tree() -> void:
	add_to_group("animals")


func _ready() -> void:
	_sprite.texture = data.sprite
	_tangle.visible = tangled
	if tangle_item:
		_tangle.texture = tangle_item.icon  # whatever it's caught in: line, net, bag...
	_rest_left = randf_range(0.0, data.rest_max)
	collision_mask = WATER_LAYER if _lives_on_land() else LAND_LAYER
	_land_mask = collision_mask
	if young:
		_sprite.scale = Vector2(0.5, 0.5)


func is_relaxed() -> bool:
	return _calm >= data.calm_time


## Frees it without the reward (loading a save where it was already freed).
func restore_freed() -> void:
	tangled = false
	_tangle.visible = false


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
	_maybe_nest()
	_maybe_guide()

	var speed := data.swim_speed * (0.5 if tangled else 1.0)
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


func _react_to_ranger(delta: float) -> void:
	_hint.visible = false
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
		_hint.visible = true
		if not is_relaxed():
			_hint.text = "Stay still so it can relax..."
		elif tangled:
			_hint.text = "%s: free the %s" % [_key_hint(), data.display_name.to_lower()]
		else:
			_hint.text = "%s: take a photo" % _key_hint()


## Trusting (relaxed) guides lead the ranger to floating litter they've spotted,
## and keep at it until the litter has been picked up.
func _maybe_guide() -> void:
	if not data.guides_to_litter or tangled or young or _state == State.FLEE:
		return
	if _guide_to and (not is_instance_valid(_guide_to) or _guide_to.is_queued_for_deletion()):
		_guide_to = null  # picked up: job done
	if not _guide_to and is_relaxed():
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
		_hint.visible = true
		_hint.text = "Follow me - I found some litter!"


func _nearest_floating_litter(within: float) -> Node2D:
	var best: Node2D = null
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.floating and not debris.is_queued_for_deletion() 				and debris.global_position.distance_to(global_position) <= within 				and (not best or debris.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = debris
	return best


## Diggers (crabs) sometimes turn up buried litter while the ranger is watching.
func _maybe_dig() -> void:
	if not data.digs_up_litter or tangled or young or randf() > data.dig_chance:
		return
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > DIG_WATCH_RANGE:
		return
	var spawner: LitterSpawner = get_tree().get_first_node_in_group("litter_spawner")
	if spawner and spawner.wash_up_at(global_position + Vector2(10.0, 4.0), false):
		Journal.record_gift(data)


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


## Relaxed and close enough for the ranger to observe, photograph or help it.
func can_interact() -> bool:
	return _hint.visible and is_relaxed() and _state != State.GUIDE


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


## "E / tap" on the animal E will act on; just "Tap" on the others.
func _key_hint() -> String:
	return "E / tap" if _is_first_choice() else "Tap"


func _interact() -> void:
	if tangled:
		restore_freed()
		if tangle_item:
			Inventory.add(tangle_item)
		SaveGame.mark_freed(self)
		Journal.help(data)
	else:
		Journal.photograph(data)


func _swim_to(target: Vector2, state: State) -> void:
	_target = target
	_state = state


func _rest(seconds: float) -> void:
	_state = State.REST
	_rest_left = seconds


## A random spot in its habitat (e.g. the sea, or the beach) within home_radius of home.
func _pick_target() -> Vector2:
	for attempt in 20:
		var spot := _home + Vector2.from_angle(randf() * TAU) * randf() * home_radius
		if in_habitat(spot):
			return spot
	return _home


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
	if young or tangled or data.nest_building == &"" or not GameClock.is_night():
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


## Links it to the nearest protection area its species nests in (loading a save).
func link_to_nearest_area() -> void:
	home_area = _nest_site()


func _nest_site() -> Node2D:
	var best: Node2D = null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == data.nest_building and (not best
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
	_hint.visible = not young and ranger != null 		and ranger.global_position.distance_to(global_position) <= data.interact_distance
	_hint.text = "Shh... she's nesting. Give her space."
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


## The hatchling "swimming frenzy": straight out to sea, away from the island,
## until it's out of the play area.
func _swim_out_to_sea() -> void:
	if global_position.length() > OPEN_OCEAN_DISTANCE:
		queue_free()
		return
	collision_mask = 0  # heading away from the island, so nothing's in the way
	velocity = global_position.normalized() * data.swim_speed * 2.0
	move_and_slide()
	_face(velocity)


func _settle_in_water() -> void:
	collision_mask = _land_mask
	if leaving:
		_state = State.SWIM
		return
	if young:
		_home = global_position
	_rest(data.rest_min)
