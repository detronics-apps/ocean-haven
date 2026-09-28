class_name PatrolBoat
extends Node2D
## Works from a patrol buoy (its parent building) and looks after the sea around it:
## cruises to random spots in its area and collects floating litter that washes
## in there, quietly, into the ranger's inventory. Stays on the water.

@export var radius := 160.0
@export var speed := 70.0

var _target := Vector2.ZERO

@onready var _hull: Sprite2D = $Hull


# ponytail: starts at its buoy rather than sailing out from the dock — that needs
# route-finding around islands, which isn't worth it yet.
func _ready() -> void:
	_target = _pick_spot()


func _process(delta: float) -> void:
	var litter := _nearest_litter()
	if litter:
		_target = to_local(litter.global_position)
		if _hull.position.distance_to(_target) < 10.0:
			litter.collect(false)
			_target = _pick_spot()
	elif _hull.position.distance_to(_target) < 4.0:
		_target = _pick_spot()
	var step := _hull.position.move_toward(_target, speed * delta)
	if step.x != _hull.position.x:
		_hull.flip_h = step.x < _hull.position.x
	_hull.position = step


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)


## Floating litter inside the patrol area, nearest the boat.
func _nearest_litter() -> Debris:
	var best: Debris = null
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if not debris.floating or debris.is_queued_for_deletion() or debris.item.ranger_cleans:
			continue
		if debris.global_position.distance_to(global_position) > radius:
			continue
		if not _is_water((to_local(debris.global_position) + _hull.position) / 2.0):
			continue  # the straight route would cross land
		if not best or debris.global_position.distance_to(_hull.global_position) \
				< best.global_position.distance_to(_hull.global_position):
			best = debris
	return best


## A random spot on the water inside the area (local coordinates). The halfway
## point must be water too, so it doesn't cut across a beach.
func _pick_spot() -> Vector2:
	for attempt in 20:
		var spot := Vector2.from_angle(randf() * TAU) * randf() * radius
		var halfway := (spot + _hull.position) / 2.0
		if _is_water(spot) and _is_water(halfway):
			return spot
	return Vector2.ZERO


func _is_water(local_point: Vector2) -> bool:
	var point := to_global(local_point)
	# Docks are walkways over the water: patrol boats go round them.
	return Terrain.at(get_tree(), point) in ["", "water"] and not Terrain.walkable(get_tree(), point)

