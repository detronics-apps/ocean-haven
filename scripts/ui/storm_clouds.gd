class_name StormClouds
extends Control
## A storm gathering (RareEvents): on its island's warning days its clouds fill the sea beyond
## the rowboat's waters, the edge of where the ranger can go (RegionData.waters_radius). Two
## days ahead they're thin and far out; the day before, thick and right up to the edge; on
## its day, before it strikes, as close and thick as they get. Each event looks like itself
## (StormWeather.cloud_colour: storm clouds, grey-green swell, brown rain, a spinning hurricane,
## an oil slick, snow).

## Gaps between cloud puffs (world pixels), at least.
const SPACING := 80.0
const MAX_PUFFS := 700
## How far beyond the edge the clouds start, two days ahead.
const FAR_OUT := 300.0

var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 0..1: how near the storm heading for `region_id` is (0 = none; 1 = its day).
static func nearness(region_id: StringName) -> float:
	var days := RareEvents.days_until(region_id)
	if days < 0 or days > 2:
		return 0.0
	return [1.0, 0.7, 0.4][days]


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var region := Regions.nearest(ranger.global_position)
	var event := RareEvents.coming_to(region.id)
	var near := nearness(region.id)
	var weather := get_tree().get_first_node_in_group("storm_weather") as StormWeather
	if not event or near <= 0.0 or (weather and weather.is_playing()):
		return
	var start: float = region.waters_radius + (1.0 - near) * FAR_OUT
	var to_world := get_viewport().get_canvas_transform().affine_inverse()
	var zoom := get_viewport().get_canvas_transform().get_scale().x
	var top_left := to_world * Vector2.ZERO
	var bottom_right := to_world * size
	var seen := Rect2(top_left, bottom_right - top_left).grow(120.0)
	# Nothing to draw while the whole view is inside the edge.
	var corners := [seen.position, seen.end, Vector2(seen.position.x, seen.end.y), Vector2(seen.end.x, seen.position.y)]
	if corners.all(func(c: Vector2) -> bool: return c.distance_to(region.center) < start - 150.0):
		return
	var spacing := maxf(SPACING, sqrt(seen.get_area() / MAX_PUFFS))
	var colour := StormWeather.cloud_colour(event.weather)
	var drift := Vector2(_time * 14.0, _time * 4.0)
	var x := floorf(seen.position.x / spacing) * spacing
	while x < seen.end.x:
		var y := floorf(seen.position.y / spacing) * spacing
		while y < seen.end.y:
			_puff(Vector2(x, y), region.center, start, near, spacing, colour, event.weather, drift, zoom)
			y += spacing
		x += spacing


## One cloud puff at grid point `at` (world), if it's past where the clouds start.
func _puff(at: Vector2, centre: Vector2, start: float, near: float, spacing: float, colour: Color,
		kind: StringName, drift: Vector2, zoom: float) -> void:
	var noise := fposmod(sin(at.x * 12.9898 + at.y * 78.233) * 43758.5453, 1.0)
	var spot := at + drift + Vector2(noise - 0.5, fposmod(noise * 7.0, 1.0) - 0.5) * spacing
	if kind == &"hurricane":  # its clouds turn round the island
		spot = centre + (spot - centre).rotated(_time * 0.04)
	var past := spot.distance_to(centre) - start - noise * 120.0
	if past < 0.0:
		return
	var thick := clampf(past / 200.0, 0.0, 1.0) * near
	var screen := get_viewport().get_canvas_transform() * spot
	var radius := spacing * zoom * (0.7 + 0.5 * noise)
	match kind:
		&"oil":  # a slick lying flat on the sea, a rainbow sheen round its edge
			draw_set_transform(screen, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, radius, Color(colour, 0.85 * thick))
			draw_arc(Vector2.ZERO, radius * 0.8, 0.0, TAU, 16,
				Color.from_hsv(fposmod(noise + _time * 0.05, 1.0), 0.5, 0.9, 0.35 * thick), 3.0)
			draw_set_transform(Vector2.ZERO)
		_:
			draw_circle(screen, radius, Color(colour, 0.8 * thick))
			draw_circle(screen + Vector2(-radius * 0.4, -radius * 0.3), radius * 0.7, Color(colour.lightened(0.12), 0.7 * thick))
			if kind == &"flood" or kind == &"storm":  # rain falling under the cloud
				for i in 3:
					var x := screen.x + (i - 1) * radius * 0.5
					var y := screen.y + radius * 0.4 + fposmod(_time * 120.0 + noise * 50.0 + i * 13.0, radius)
					draw_line(Vector2(x, y), Vector2(x - 2.0, y + 8.0), Color(0.75, 0.8, 0.9, 0.6 * thick), 1.0)
			elif kind == &"blizzard":
				for i in 3:
					var at_flake := screen + Vector2(fposmod(noise * 90.0 + _time * 40.0 + i * 30.0, radius * 2.0) - radius,
						fposmod(_time * 50.0 + i * 21.0, radius * 1.5))
					draw_rect(Rect2(at_flake, Vector2(2, 2)), Color(1, 1, 1, 0.8 * thick))
			elif kind == &"swell":
				draw_arc(screen + Vector2(0, radius * 0.6), radius * 0.6, PI * 1.1, PI * 1.9, 8,
					Color(0.92, 0.97, 1.0, 0.5 * thick), 2.0)
			if kind == &"storm" and near >= 1.0 and fposmod(_time + noise * 9.0, 3.1) < 0.08:
				draw_circle(screen, radius * 0.8, Color(1, 1, 0.9, 0.35 * thick))  # lightning in the clouds
