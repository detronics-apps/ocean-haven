class_name EchoDive
extends OtterDive
## Echo Dive (Imani, at the Deep-Ocean Outpost): pilot the submarine through a pitch-dark
## canyon. Hold to rise, let go to sink. Every few seconds the sonar pings and the canyon walls
## light up for a moment (the sub's small lamp shows what's right beside it); bumping a wall only
## slows you. Pick up the lost gear on the way. The story dive follows the echoes to the lost
## cargo module (Imani's cargo search); after that it's for fun.

const PING_EVERY := 1.6
const PING_FADE := 1.3
const SUB_X := 0.22

## Canyon walls: {"x": world x, "top": 0..1, "bottom": 0..1} every WALL_STEP.
const WALL_STEP := 0.2
var _walls: Array[Dictionary] = []
var _ping := 0.0
var _gap := 0.45


func _enter_tree() -> void:
	add_to_group("activity_echo_dive")


func _how_to_play() -> String:
	return "Hold to rise, let go to sink. The sonar pings by itself and lights up the canyon walls for a moment: steer between them and pick up the lost gear."


func _start_board(config: Vector3i) -> void:
	_gap = clampf(0.62 - 0.05 * config.z, 0.34, 0.6)
	_walls.clear()
	_extend_walls(0.0, 3.0)
	super(config)
	_y = 0.5
	_ping = 0.0


func _extend_walls(from: float, to: float) -> void:
	var x := from if _walls.is_empty() else float(_walls[-1].x) + WALL_STEP
	var middle: float = 0.5 if _walls.is_empty() else (float(_walls[-1].top) + float(_walls[-1].bottom)) / 2.0
	while x < to:
		middle = clampf(middle + randf_range(-0.09, 0.09), 0.18 + _gap / 2.0, 0.92 - _gap / 2.0)
		_walls.append({"x": x, "top": middle - _gap / 2.0, "bottom": middle + _gap / 2.0})
		x += WALL_STEP


## The canyon's open water at world x: (top, bottom).
func gap_at(x: float) -> Vector2:
	for i in _walls.size() - 1:
		if x >= _walls[i].x and x <= _walls[i + 1].x:
			var t: float = (x - _walls[i].x) / WALL_STEP
			return Vector2(lerpf(_walls[i].top, _walls[i + 1].top, t), lerpf(_walls[i].bottom, _walls[i + 1].bottom, t))
	return Vector2(0.3, 0.7)


func _place_ahead(from: float, to: float) -> void:
	var x := from
	while x < to:
		x += randf_range(0.35, 0.6)
		var gap := gap_at(x)
		_things.append({"x": x, "y": lerpf(gap.x + 0.06, gap.y - 0.06, randf()), "kind": "gear"})


func step(delta: float, rising: bool) -> void:
	var push := -0.9 if rising else 0.7
	_velocity = lerpf(_velocity, push, minf(delta * 4.0, 1.0))
	_y = clampf(_y + _velocity * delta * 0.6, 0.05, 0.95)
	var speed := _speed * (0.35 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_scroll += speed * delta
	_ping -= delta
	if _ping <= -PING_EVERY:
		_ping = 0.0
	var gap := gap_at(_scroll + SUB_X)
	if _y < gap.x + 0.03 or _y > gap.y - 0.03:  # a bump against the wall: slowed, nudged back
		_y = clampf(_y, gap.x + 0.03, gap.y - 0.03)
		_velocity = 0.0
		_slow = 0.5
	for thing: Dictionary in _things.duplicate():
		var screen_x: float = thing.x - _scroll
		if screen_x < -0.1:
			_things.erase(thing)
		elif absf(screen_x - SUB_X) < 0.04 and absf(thing.y - _y) < 0.08:
			_things.erase(thing)
			_got += 1
	if float(_walls[-1].x) < _scroll + 2.0:
		_extend_walls(0.0, _scroll + 3.0)
		_walls = _walls.filter(func(w: Dictionary) -> bool: return w.x > _scroll - 0.5)
	if _things.size() < 3:
		_place_ahead(_scroll + 1.2, _scroll + 2.4)
	if _got >= _goal:
		_complete()


## How bright the sonar's echo is now (1 just after a ping, fading to 0).
func echo() -> float:
	return clampf(1.0 + _ping / PING_FADE, 0.0, 1.0)


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	_arena.draw_rect(Rect2(Vector2.ZERO, size), Color("05070c"))
	var sub := Vector2(SUB_X * size.x, _y * size.y)
	var glow := echo()
	var step_px := 6.0
	var x := 0.0
	while x < size.x:
		var gap := gap_at(_scroll + x / size.x)
		var near := clampf(1.0 - absf(x - sub.x) / (size.x * 0.12), 0.0, 1.0)  # the sub's own lamp
		var light := maxf(glow * 0.9, near * 0.6)
		if light > 0.02:
			var rock := Color("3f5f78").lerp(Color("8fd3ff"), glow * 0.4)
			rock.a = light
			_arena.draw_rect(Rect2(Vector2(x, 0), Vector2(step_px, gap.x * size.y)), rock)
			_arena.draw_rect(Rect2(Vector2(x, gap.y * size.y), Vector2(step_px, size.y * (1.0 - gap.y))), rock)
		x += step_px
	for thing: Dictionary in _things:
		var at := Vector2((thing.x - _scroll) * size.x, thing.y * size.y)
		var seen := maxf(glow, clampf(1.0 - at.distance_to(sub) / (size.x * 0.15), 0.0, 1.0))
		if seen > 0.05:
			_arena.draw_rect(Rect2(at - Vector2(9, 7), Vector2(18, 14)), Color(0.85, 0.8, 0.6, seen))
			_arena.draw_line(at - Vector2(9, 0), at + Vector2(9, 0), Color(0.4, 0.35, 0.25, seen), 2.0)
	_arena.draw_circle(sub, 30.0, Color(1.0, 0.95, 0.6, 0.08))
	_arena.draw_rect(Rect2(sub - Vector2(16, 8), Vector2(32, 16)), Color("f2c94c"))
	_arena.draw_rect(Rect2(sub + Vector2(-4, -14), Vector2(10, 6)), Color("f2c94c"))
	_arena.draw_circle(sub + Vector2(10, 0), 4.0, Color("8fd3ff"))
	if glow > 0.0:
		_arena.draw_arc(sub, (1.0 - glow) * size.x * 0.6 + 20.0, 0.0, TAU, 48, Color(0.56, 0.83, 1.0, glow * 0.5), 2.0)
	_arena.draw_string(ThemeDB.fallback_font, Vector2(16, 26), "Lost gear %d / %d" % [_got, _goal], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
