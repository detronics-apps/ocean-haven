class_name StormWeather
extends Control
## A rare event passing over the ranger's island (RareEvents: STORM_SECONDS on its day, the
## last TAIL_SECONDS of it the day after). The game keeps running, but only VISIBLE_TILES round
## the ranger can be seen: past that there's only the storm, closing in, then clearing. Each
## event has its own look (EventData.weather): a coastal storm's slanting rain and lightning,
## heavy swell's spray and rolling swell lines, a flash flood's brown downpour and muddy water
## running past, a hurricane's spinning bands and flying leaves (and its calm eye), an oil
## spill's dark rainbow sheen, an ice breakup's blizzard with a crack running through the ice.

const KINDS := {
	&"storm": {"fog": Color(0.16, 0.2, 0.27, 0.99), "cloud": Color(0.22, 0.25, 0.32), "rain": 220, "slant": 0.35,
		"wind": 8, "flash": true, "sound": &"thunder"},
	&"swell": {"fog": Color(0.2, 0.32, 0.33, 0.99), "cloud": Color(0.36, 0.46, 0.45), "rain": 40, "slant": 0.25,
		"wind": 12, "swell": 7, "spray": 60, "sound": &"splash"},
	&"flood": {"fog": Color(0.3, 0.24, 0.16, 0.99), "cloud": Color(0.38, 0.32, 0.25), "rain": 280, "slant": 0.05,
		"wind": 2, "mud": true, "sound": &"splash"},
	&"hurricane": {"fog": Color(0.15, 0.18, 0.23, 0.99), "cloud": Color(0.26, 0.29, 0.34), "rain": 300, "slant": 1.4,
		"wind": 26, "leaves": 30, "spiral": true, "flash": true, "sound": &"thunder"},
	&"oil": {"fog": Color(0.08, 0.06, 0.1, 0.99), "cloud": Color(0.1, 0.08, 0.12), "rain": 0, "slant": 0.0,
		"wind": 0, "sheen": true, "sound": &"whoosh"},
	&"blizzard": {"fog": Color(0.78, 0.85, 0.9, 0.99), "cloud": Color(0.88, 0.92, 0.96), "rain": 0, "slant": 0.0,
		"wind": 14, "snow": 260, "crack": true, "sound": &"thunder"},
}
## How far the ranger can see while it passes (tiles from them): clear this far, then fading
## into the storm over FADE_TILES more (so about 3-4 tiles can be made out).
const VISIBLE_TILES := 1.5
const FADE_TILES := 4.0
## Seconds it takes to close in and to clear.
const CLOSE_IN := 2.0
const CLEAR := 2.0
const FOG := preload("res://assets/effects/storm/storm_fog.gdshader")

var _kind := {}
var _kind_id: StringName = &""
var _time := -1.0
var _seconds := 10.0
var _tail := false
var _drops: Array[Vector2] = []
var _seed := 0.0
var _fog: ColorRect
var _fx: Control


## The colour of `kind`'s clouds gathering on the horizon (StormClouds, the minimap).
static func cloud_colour(kind: StringName) -> Color:
	return KINDS.get(kind, KINDS[&"storm"]).cloud


func _enter_tree() -> void:
	add_to_group("storm_weather")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_fog = ColorRect.new()
	_fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FOG
	_fog.material = material
	add_child(_fog)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


## `event`'s weather passes over for `seconds`; `tail`: only its end (it's already overhead).
func play(event: EventData, seconds := 10.0, tail := false) -> void:
	play_kind(event.weather, seconds, tail)


func play_kind(kind: StringName, seconds := 10.0, tail := false) -> void:
	if not KINDS.has(kind):
		return
	_kind_id = kind
	_kind = KINDS[kind]
	_time = 0.0
	_seconds = seconds
	_tail = tail
	_seed = randf() * 100.0
	_drops.clear()
	for i: int in maxi(int(_kind.rain), int(_kind.get("snow", 0))):
		_drops.append(Vector2(randf(), randf()))
	visible = true
	Sound.play(_kind.sound)


func is_playing() -> bool:
	return _time >= 0.0


func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if _time >= _seconds:
		_time = -1.0
		visible = false
		return
	_update_fog()
	_fx.queue_redraw()


## 0..1: how far it has closed in (1 = only VISIBLE_TILES can be seen).
func closed() -> float:
	var opening := clampf((_seconds - _time) / (3.0 if _tail else CLEAR), 0.0, 1.0)
	if _tail:
		return opening
	var closing := clampf(_time / CLOSE_IN, 0.0, 1.0)
	var calm_eye := 1.0
	if _kind.get("spiral", false):  # a hurricane's eye passes over halfway: a moment of calm
		calm_eye = 1.0 - 0.6 * clampf(1.0 - absf(_time / _seconds - 0.5) / 0.08, 0.0, 1.0)
	return minf(closing, opening) * calm_eye


## Where the ranger is on screen, and how big a tile is there.
func _ranger_on_screen() -> Array:
	var ranger := ControlledBody.active(get_tree())
	var transform := get_viewport().get_canvas_transform()
	var at := transform * ranger.global_position if ranger else size / 2.0
	return [at, Terrain.TILE * transform.get_scale().x]


func _update_fog() -> void:
	var seen: Array = _ranger_on_screen()
	var far := size.length()
	var clear: float = VISIBLE_TILES * seen[1]
	var shut := closed()
	var material := _fog.material as ShaderMaterial
	material.set_shader_parameter("fog_colour", _kind.fog)
	material.set_shader_parameter("centre", seen[0])
	material.set_shader_parameter("rect_size", size)
	material.set_shader_parameter("radius", lerpf(far, clear, shut))
	material.set_shader_parameter("soft", seen[1] * FADE_TILES)
	material.set_shader_parameter("strength", clampf(shut * 1.5, 0.0, 1.0))
	material.set_shader_parameter("time", _time + _seed)
	material.set_shader_parameter("flash", 1.0 if _kind.get("flash", false) and fmod(_time + _seed, 2.3) < 0.09 and shut > 0.5 else 0.0)


func _draw_fx() -> void:
	if _time < 0.0:
		return
	var s := clampf(closed() * 1.4, 0.0, 1.0)
	var area := size
	var t := _time
	# Which way the wind blows (a hurricane's turns round once its eye has passed).
	var dir := -1.0 if _kind.get("spiral", false) and t > _seconds * 0.5 else 1.0
	# Rain: streaks falling, slanting with the wind (brown in a flood).
	var slant: float = _kind.slant * dir
	var rain_colour := Color(0.7, 0.6, 0.45, 0.6 * s) if _kind.get("mud", false) else Color(0.75, 0.82, 0.92, 0.55 * s)
	for i in mini(_drops.size(), int(_kind.rain)):
		var d := _drops[i]
		var x := fposmod(d.x * area.x + t * 300.0 * slant, area.x)
		var y := fposmod(d.y * area.y + t * 900.0, area.y)
		_fx.draw_line(Vector2(x, y), Vector2(x - 12.0 * slant, y - 18.0), rain_colour, 1.0)
	# Wind: long pale gusts.
	for i: int in _kind.wind:
		var y := fposmod(i * 97.3 + _seed * 13.0, area.y)
		var x := fposmod(i * 211.0 + t * 700.0 * dir, area.x + 400.0) - 200.0
		_fx.draw_line(Vector2(x, y), Vector2(x + 120.0 * dir, y + 6.0), Color(1, 1, 1, 0.25 * s), 2.0)
	# Lightning: a jagged bolt with the flash.
	if _kind.get("flash", false) and fmod(t + _seed, 2.3) < 0.12 and s > 0.5:
		var x := fposmod(_seed * 37.0 + floorf((t + _seed) / 2.3) * 271.0, area.x)
		var bolt := PackedVector2Array([Vector2(x, 0)])
		var y := 0.0
		while y < area.y * 0.6:
			y += randf_range(30, 60)
			bolt.append(Vector2(x + randf_range(-26, 26), y))
		if bolt.size() > 1:
			_fx.draw_polyline(bolt, Color(1, 1, 0.85, 0.9), 3.0)
	# Heavy swell: rolling swell lines moving up the screen, and spray.
	for i: int in _kind.get("swell", 0):
		var y := fposmod(area.y - (t * 90.0 + i * area.y / 7.0), area.y + 60.0) - 30.0
		var line := PackedVector2Array()
		for step in 33:
			var x := area.x * step / 32.0
			line.append(Vector2(x, y + sin(x * 0.02 + t * 2.0 + i) * 10.0))
		_fx.draw_polyline(line, Color(0.92, 0.97, 1.0, 0.45 * s), 4.0)
	for i: int in _kind.get("spray", 0):
		var at := Vector2(fposmod(i * 131.7 + t * 260.0, area.x), fposmod(i * 89.3 - t * 140.0, area.y))
		_fx.draw_rect(Rect2(at, Vector2(3, 3)), Color(1, 1, 1, 0.5 * s))
	# Flash flood: muddy water running past from inland, carrying twigs.
	if _kind.get("mud", false):
		var front := area.y * clampf(t / maxf(_seconds - CLEAR, 1.0), 0.0, 1.0)
		var sheet := PackedVector2Array([Vector2(0, 0), Vector2(area.x, 0)])
		for step in range(32, -1, -1):
			var x := area.x * step / 32.0
			sheet.append(Vector2(x, front + sin(x * 0.03 + t * 3.0) * 14.0))
		_fx.draw_colored_polygon(sheet, Color(0.45, 0.33, 0.18, 0.35 * s))
		for i in 18:
			var at := Vector2(fposmod(i * 173.0 + sin(t + i) * 30.0, area.x), front - fposmod(i * 61.0, 160.0))
			_fx.draw_rect(Rect2(at, Vector2(10, 3)), Color(0.36, 0.25, 0.14, 0.9 * s))
	# Hurricane: spinning cloud bands, and leaves flying past.
	if _kind.get("spiral", false):
		var middle := area / 2.0
		for arm in 4:
			var turn := t * 0.9 * dir + arm * TAU / 4.0
			for ring in 5:
				var r := 120.0 + ring * area.length() / 9.0
				_fx.draw_arc(middle, r, turn + ring * 0.5, turn + ring * 0.5 + 1.1, 16, Color(0.75, 0.8, 0.86, 0.22 * s), 10.0)
	for i: int in _kind.get("leaves", 0):
		var p := fposmod(t * (0.5 + fposmod(i * 0.37, 0.4)) + i * 0.13, 1.0)
		var x := p * (area.x + 100.0) - 50.0
		if dir < 0.0:
			x = area.x - x
		var at := Vector2(x, fposmod(i * 53.0, area.y) + sin(t * 3.0 + i) * 20.0)
		_fx.draw_rect(Rect2(at, Vector2(7, 3)), Color(0.35, 0.6, 0.3, 0.85 * s))
	# Oil: a dark slick with a rainbow sheen drifting across.
	if _kind.get("sheen", false):
		for i in 9:
			var y := fposmod(i * area.y / 9.0 + t * 12.0, area.y)
			var line := PackedVector2Array()
			for step in 25:
				var x := area.x * step / 24.0
				line.append(Vector2(x, y + sin(x * 0.015 + t * 0.8 + i * 1.7) * 18.0))
			_fx.draw_polyline(line, Color.from_hsv(fposmod(i * 0.13 + t * 0.05, 1.0), 0.55, 0.9, 0.35 * s), 3.0)
	# Blizzard: snow blowing past, and a crack running through the ice.
	for i: int in _kind.get("snow", 0):
		var d := _drops[i]
		var x := fposmod(d.x * area.x + t * 380.0 + sin(t * 2.0 + i) * 20.0, area.x)
		var y := fposmod(d.y * area.y + t * 160.0, area.y)
		_fx.draw_rect(Rect2(Vector2(x, y), Vector2(3, 3)), Color(1, 1, 1, 0.85 * s))
	if _kind.get("crack", false) and not _tail:
		var grow := clampf((t / _seconds - 0.3) / 0.3, 0.0, 1.0)
		if grow > 0.0:
			var crack := PackedVector2Array()
			for step in int(24 * grow) + 1:
				var x := area.x * step / 24.0
				crack.append(Vector2(x, area.y * 0.62 + (fposmod(step * 37.0 + _seed, 40.0) - 20.0)))
			if crack.size() > 1:
				_fx.draw_polyline(crack, Color(1, 1, 1, 0.9 * s), 6.0)
				_fx.draw_polyline(crack, Color(0.12, 0.2, 0.3, 0.95 * s), 3.0)
