class_name SeasonShow
extends Node2D
## A seasonal moment's sight in the world (SeasonEvent.show), on the ranger's island while it's
## on: the coral's pink spawn rising over the reef, whales' slanted blows, a flock of terns
## flying in. Only a sight: it changes nothing.

const SPAWN := [Color(1.0, 0.62, 0.72, 0.9), Color(1.0, 0.85, 0.9, 0.85), Color(1.0, 0.95, 0.8, 0.8)]
const BLOW := Color(0.95, 0.97, 1.0, 0.75)
const BIRD := Color(0.95, 0.95, 0.95, 1.0)

## The moment on now on the ranger's island (null = none).
var event: SeasonEvent
## Where it's drawn round (animals of event.species, and reef patches for the spawn).
var _spots: Array[Node2D] = []
var _check := 0.0
var _time := 0.0


func _ready() -> void:
	z_index = 4
	add_to_group("season_show")


func _process(delta: float) -> void:
	_time += delta
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		refresh()
	if event:
		queue_redraw()


## Looks again for a moment on now where the ranger is.
func refresh() -> void:
	var before := event
	event = null
	_spots.clear()
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position).id
	for one in SeasonEvent.all():
		if one.region == here and one.is_on():
			event = one
	if not event:
		if before:
			queue_redraw()
		return
	for animal: Node2D in get_tree().get_nodes_in_group("animals"):
		if animal.data.id == event.species and Regions.nearest(animal.global_position).id == here:
			_spots.append(animal)
	if event.show == &"spawn":
		for patch: Node2D in get_tree().get_nodes_in_group("reef_patches"):
			if Regions.nearest(patch.global_position).id == here:
				_spots.append(patch)


func _draw() -> void:
	if not event:
		return
	for i in _spots.size():
		var spot := _spots[i]
		if not is_instance_valid(spot):
			continue
		var at := spot.global_position
		match event.show:
			&"spawn":  # little bundles drifting up, round and round
				for k in 18:
					var s := float(i * 31 + k * 7)
					var rise := fmod(_time * 14.0 + s * 9.0, 70.0)
					var p := at + Vector2(sin(s) * 34.0 + sin(_time + s) * 4.0, cos(s * 1.3) * 18.0 - rise)
					draw_circle(p, 2.4, SPAWN[k % SPAWN.size()])
			&"spouts":  # a blow every few seconds, slanting forward and to the left
				var phase := fmod(_time + i * 1.7, 4.0)
				if phase < 1.2 and not spot.get("underwater"):
					var height := 26.0 * minf(phase / 0.4, 1.0)
					for k in 6:
						var up := float(k) / 5.0
						draw_circle(at + Vector2(-10.0 * up - 4.0, -height * up - 6.0), 2.0 + 3.0 * up, Color(BLOW, BLOW.a * (1.0 - phase / 1.2)))
			&"flock":  # a loose flock flying in over the bird
				for k in 9:
					var s := float(i * 13 + k * 5)
					var drift := fmod(_time * 40.0 + s * 20.0, 400.0) - 200.0
					var p := at + Vector2(drift, -60.0 - fmod(s * 11.0, 50.0))
					var flap := sin(_time * 8.0 + s) * 2.0
					draw_line(p, p + Vector2(-4, -2 + flap), BIRD, 1.5)
					draw_line(p, p + Vector2(4, -2 + flap), BIRD, 1.5)
