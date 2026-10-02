class_name StormWeather
extends Control
## The weather of a rare event, shown over the game when it strikes (EventData.weather): a
## coastal storm's driving rain and dark sky, heavy swell's rolling waves and spray, a flash
## flood's muddy downpour, a hurricane's wind, rain and flying leaves, an oil spill's dark sheen on the swell. A few seconds, then it clears.

const KINDS := {
	&"storm": {"sky": Color(0.18, 0.22, 0.3, 0.55), "rain": 140, "slant": 0.35, "wind": 6, "waves": 0, "leaves": 0, "flash": true},
	&"swell": {"sky": Color(0.15, 0.3, 0.38, 0.4), "rain": 30, "slant": 0.2, "wind": 10, "waves": 7, "leaves": 0, "flash": false},
	&"flood": {"sky": Color(0.32, 0.26, 0.18, 0.5), "rain": 220, "slant": 0.08, "wind": 2, "waves": 3, "leaves": 0, "flash": false},
	&"oil": {"sky": Color(0.12, 0.08, 0.14, 0.45), "rain": 0, "slant": 0.0, "wind": 2, "waves": 6, "leaves": 0, "flash": false},
	&"hurricane": {"sky": Color(0.16, 0.2, 0.26, 0.6), "rain": 260, "slant": 1.2, "wind": 26, "waves": 5, "leaves": 24, "flash": true},
}
const SECONDS := 7.0
const DELAY := 1.2
var _delay := 0.0

var _kind := {}
var _time := -1.0
var _drops: Array[Vector2] = []
var _seed := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	RareEvents.struck.connect(func(event: EventData, _damaged: int) -> void: play(event.weather))


## Plays the weather of `kind` (a storm, swell, flood or hurricane).
func play(kind: StringName) -> void:
	if not KINDS.has(kind):
		return
	_kind = KINDS[kind]
	_time = 0.0
	_delay = DELAY  # storms strike at dawn: let the sleep fade clear first
	_seed = randf() * 100.0
	_drops.clear()
	for i: int in _kind.rain:
		_drops.append(Vector2(randf(), randf()))
	visible = true


func is_playing() -> bool:
	return _time >= 0.0


func _process(delta: float) -> void:
	if _time < 0.0:
		return
	if _delay > 0.0:
		_delay -= delta
		return
	_time += delta
	if _time >= SECONDS:
		_time = -1.0
		visible = false
		return
	queue_redraw()


## 0..1: in over the first second, out over the last two.
func _strength() -> float:
	return clampf(minf(_time / 1.0, (SECONDS - _time) / 2.0), 0.0, 1.0)


func _draw() -> void:
	if _time < 0.0 or _delay > 0.0:
		return
	var s := _strength()
	var area := size
	var sky: Color = _kind.sky
	draw_rect(Rect2(Vector2.ZERO, area), Color(sky, sky.a * s))
	# Lightning: a quick flash now and then.
	if _kind.flash and fmod(_time + _seed, 2.3) < 0.08:
		draw_rect(Rect2(Vector2.ZERO, area), Color(1, 1, 1, 0.35 * s))
	# Rain: streaks falling (and slanting with the wind).
	var slant: float = _kind.slant
	for d in _drops:
		var x := fmod(d.x * area.x + _time * 260.0 * slant + area.x, area.x)
		var y := fmod(d.y * area.y + _time * 900.0, area.y)
		draw_line(Vector2(x, y), Vector2(x - 10.0 * slant, y - 16.0), Color(0.75, 0.82, 0.92, 0.55 * s), 1.0)
	# Wind: long pale gusts blowing across.
	for i: int in _kind.wind:
		var y: float = fmod(i * 97.3 + _seed * 13.0, area.y)
		var x: float = fmod(i * 211.0 + _time * 700.0, area.x + 400.0) - 200.0
		draw_line(Vector2(x, y), Vector2(x + 120.0, y + 6.0), Color(1, 1, 1, 0.25 * s), 2.0)
	# Waves: rolling white crests along the bottom.
	for i: int in _kind.waves:
		var y: float = area.y - 24.0 - i * 26.0
		var shift: float = fmod(_time * (60.0 + i * 15.0), 80.0)
		var x: float = -80.0 + shift
		while x < area.x:
			draw_arc(Vector2(x, y), 22.0, PI * 1.05, PI * 1.95, 8, Color(0.9, 0.96, 1.0, 0.5 * s), 3.0)
			x += 80.0
	# Leaves and debris flying past (hurricanes).
	for i: int in _kind.leaves:
		var t: float = fmod(_time * (0.5 + fmod(i * 0.37, 0.4)) + i * 0.13, 1.0)
		var at := Vector2(t * (area.x + 100.0) - 50.0, fmod(i * 53.0, area.y) + sin(_time * 3.0 + i) * 20.0)
		draw_rect(Rect2(at, Vector2(6, 3)).abs(), Color(0.35, 0.6, 0.3, 0.8 * s))
