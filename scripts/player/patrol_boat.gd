class_name PatrolBoat
extends Node2D
## Works from a patrol buoy (its parent building) and looks after the sea around it:
## cruises to random spots in its area and collects floating litter that washes
## in there, quietly, into the ranger's inventory. Stays on the water.

## Its patrol area; grows with its buoy's upgrades (BuildingData.range_per_tier).
@export var radius := 120.0
@export var speed := 70.0

var _target := Vector2.ZERO

@onready var _hull: Sprite2D = $Hull


# ponytail: starts at its buoy rather than sailing out from the dock — that needs
# route-finding around islands, which isn't worth it yet.
func _ready() -> void:
	add_to_group("busy_boats")  # shy animals (dolphins) keep away from its waters
	_target = _pick_spot()


## Where the boat is right now.
func hull_position() -> Vector2:
	return _hull.global_position


func _process(delta: float) -> void:
	var buoy := get_parent() as Building
	if buoy and not buoy.data.range_per_tier.is_empty():
		var reach := buoy.data.range_per_tier[clampi(buoy.tier, 1, buoy.data.range_per_tier.size()) - 1]
		if reach != radius:
			radius = reach
			queue_redraw()
	var litter := _nearest_litter()
	if litter:
		_target = to_local(litter.global_position)
		if _hull.position.distance_to(_target) < 10.0:
			litter.collect(false)
			get_tree().call_group("hud", "patrol_collected", litter.item)
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


## Share (0..1) of `region`'s own water (the shallows and mid water round its island) that's
## outside every patrol area: quiet water where turtles and dolphins can feed and rest.
static func free_water_share(tree: SceneTree, region: RegionData) -> float:
	var areas: Array[Vector2] = []
	var radii: Array[float] = []
	for boat: Node in tree.get_nodes_in_group("busy_boats"):
		if Regions.nearest(boat.global_position) == region:
			areas.append(boat.global_position)
			radii.append(boat.radius)
	if areas.is_empty():
		return 1.0
	var water := 0
	var busy := 0
	for ground: TileMapLayer in tree.get_nodes_in_group("ground"):
		for cell in ground.get_used_cells():
			var tile := ground.get_cell_tile_data(cell)
			if not tile or tile.get_custom_data("walkable") or tile.get_custom_data("terrain") not in ["water", ""]:
				continue
			var spot := ground.to_global(ground.map_to_local(cell))
			if Regions.nearest(spot) != region:
				continue
			water += 1
			for i in areas.size():
				if spot.distance_to(areas[i]) <= radii[i]:
					busy += 1
					break
	return 1.0 - float(busy) / maxi(water, 1)


func _is_water(local_point: Vector2) -> bool:
	var point := to_global(local_point)
	# Docks are walkways over the water: patrol boats go round them, and keep out of protected
	# zones (e.g. a crocodile's quiet water).
	return Terrain.at(get_tree(), point) in ["", "water"] and not Terrain.walkable(get_tree(), point) \
		and not in_protected_zone(get_tree(), point)


## Inside a zone boats keep out of (BuildingData.keeps_boats_out).
static func in_protected_zone(tree: SceneTree, point: Vector2) -> bool:
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.keeps_boats_out > 0.0 and building.global_position.distance_to(point) <= building.data.keeps_boats_out:
			return true
	return false

