class_name OtterDive
extends ActivityScreen
## Otter Dive (Finn, from the old jetty on the Kelp Forest): dive like a sea otter. Hold to swim
## down, let go to float up; grab the urchins on the sea floor and come up for air before it
## runs out (out of air, you just float up: nothing goes wrong). Bumping a kelp stalk slows you
## for a moment. Collect them all. The story play counts the urchins for Finn (the urchin
## pressure survey); after that it's for fun: levels and best times.

## Level config: (urchins to collect, kelp stalks per screen, current strength 1-5).
const AIR_SECONDS := 7.0
const OTTER_X := 0.22
const SURFACE := 0.14
const FLOOR := 0.9

var _arena: Control
var _holding := false
var _y := 0.14
var _velocity := 0.0
var _air := AIR_SECONDS
var _scroll := 0.0
var _slow := 0.0
var _goal := 0
var _got := 0
## Things in the water: {"x": world x, "y": 0..1, "kind": "urchin" / "kelp", "h": kelp height}.
var _things: Array[Dictionary] = []
var _speed := 0.18
var _density := 3
var _note := ""


func _enter_tree() -> void:
	add_to_group("activity_otter_dive")


func _how_to_play() -> String:
	return "Hold to dive, let go to float up. Grab the urchins on the sea floor, and come up for air before your air runs out. Kelp slows you down."


func _start_board(config: Vector3i) -> void:
	_goal = config.x
	_density = config.y
	_speed = 0.14 + 0.03 * config.z
	_got = 0
	_y = SURFACE
	_velocity = 0.0
	_air = AIR_SECONDS
	_scroll = 0.0
	_slow = 0.0
	_things.clear()
	_place_ahead(0.4, 3.0)
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.gui_input.connect(_on_arena_input)
	_arena.draw.connect(_draw_arena)
	_board.add_child(_arena)


## Places urchins and kelp from world x `from` to `to` (screen widths).
func _place_ahead(from: float, to: float) -> void:
	var x := from
	while x < to:
		x += randf_range(0.18, 0.32)
		_things.append({"x": x, "y": randf_range(0.78, 0.86), "kind": "urchin"})
		for i in _density / 2:
			_things.append({"x": x + randf_range(-0.12, 0.12), "y": FLOOR, "kind": "kelp", "h": randf_range(0.25, 0.55)})


func _on_arena_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed


## Holding to dive (also the interact key / controller button).
func set_holding(holding: bool) -> void:
	_holding = holding


func _process(delta: float) -> void:
	super(delta)
	if not _playing or not _arena:
		return
	step(delta, _holding or Input.is_action_pressed("interact") or Input.is_action_pressed("ui_accept"))
	_arena.queue_redraw()


## One step of the dive (tests drive it directly).
func step(delta: float, diving: bool) -> void:
	var out_of_air := _air <= 0.0
	var push := 1.1 if diving and not out_of_air else -0.9  # down while held, buoyant otherwise
	_velocity = lerpf(_velocity, push, minf(delta * 4.0, 1.0))
	_y = clampf(_y + _velocity * delta * 0.6, SURFACE, FLOOR - 0.04)
	if _y <= SURFACE + 0.01:
		_air = minf(_air + delta * AIR_SECONDS / 1.2, AIR_SECONDS)  # a breath at the surface
	else:
		_air = maxf(_air - delta, 0.0)
	var speed := _speed * (0.35 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_scroll += speed * delta
	for thing: Dictionary in _things.duplicate():
		var screen_x: float = thing.x - _scroll
		if screen_x < -0.1:
			_things.erase(thing)
			continue
		if absf(screen_x - OTTER_X) > 0.04:
			continue
		if thing.kind == "urchin" and absf(thing.y - _y) < 0.07:
			_things.erase(thing)
			_got += 1
		elif thing.kind == "kelp" and _y > FLOOR - thing.h and _slow <= 0.0:
			_slow = 0.6  # a bump: slowed down for a moment
	if _things.filter(func(t: Dictionary) -> bool: return t.kind == "urchin").size() < 4:
		_place_ahead(_scroll + 1.2, _scroll + 2.4)
	if _got >= _goal:
		_complete()


func collected() -> int:
	return _got


func air() -> float:
	return _air


func depth() -> float:
	return _y


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	_arena.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * SURFACE)), Color("9fd8f0"))
	_arena.draw_rect(Rect2(Vector2(0, size.y * SURFACE), Vector2(size.x, size.y * (1.0 - SURFACE))), Color("1f5f78"))
	_arena.draw_rect(Rect2(Vector2(0, size.y * FLOOR), Vector2(size.x, size.y * (1.0 - FLOOR))), Color("6e6250"))
	for thing: Dictionary in _things:
		var x: float = (thing.x - _scroll) * size.x
		if x < -20.0 or x > size.x + 20.0:
			continue
		if thing.kind == "kelp":
			var top: float = (FLOOR - thing.h) * size.y
			_arena.draw_line(Vector2(x, size.y * FLOOR), Vector2(x + 6.0, top), Color("6f9a3a"), 5.0)
		else:
			var at := Vector2(x, thing.y * size.y)
			_arena.draw_circle(at, 9.0, Color("7b3f8c"))
			for i in 8:
				_arena.draw_line(at, at + Vector2.from_angle(TAU * i / 8.0) * 14.0, Color("5a2a6a"), 2.0)
	var otter := Vector2(OTTER_X * size.x, _y * size.y)
	_arena.draw_circle(otter, 14.0, Color("7a5132"))
	_arena.draw_circle(otter + Vector2(12, -4), 8.0, Color("8c6040"))
	_arena.draw_circle(otter + Vector2(15, -6), 2.0, Color.BLACK)
	# Air and urchins.
	var bar := Rect2(Vector2(16, 12), Vector2(160, 14))
	_arena.draw_rect(bar, Color(0, 0, 0, 0.4))
	_arena.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _air / AIR_SECONDS, bar.size.y)), Color("8fd3ff"))
	_arena.draw_string(get_theme_default_font(), Vector2(190, 25), "Air    Urchins %d / %d" % [_got, _goal], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


static func get_theme_default_font() -> Font:
	return ThemeDB.fallback_font
