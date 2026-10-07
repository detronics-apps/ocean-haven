class_name EchoDive
extends ActivityScreen
## Echo Dive (Imani, at the Deep-Ocean Outpost): take the submarine straight down from the
## surface. It sinks by itself; hold the left or right side (or the move keys) to steer round
## the rock ledges sticking out of the canyon walls (a bump only slows it). The light fades as
## you go down, and on the way you pass the deep's animals at the depths where they've really
## been seen. Reach the target depth: the story dive finds the lost cargo module at 1,000 m
## (Imani's cargo search); after that it's for fun, deeper each level, with best times.

## Level config: (target depth in hundreds of metres, ledges per 100 m, sinking speed 1-5).
const SUB_Y := 0.32
const SUB_HALF := 0.035
## Metres a second at speed 1, and more per speed step.
const SINK := 60.0
const SINK_STEP := 15.0
const STEER := 0.55
## Real depths, metres: where each animal is shown (as you pass), with what's known.
const ANIMALS := [
	{"depth": 150.0, "name": "Sunlight ends", "note": "Below about 200 m there's too little light for plants to grow", "colour": Color("9fd8f0")},
	{"depth": 500.0, "name": "Giant squid", "note": "Lives about 300 to 1,000 m down", "colour": Color("c0504a")},
	{"depth": 1000.0, "name": "Midnight zone", "note": "From 1,000 m down it's darker than any night", "colour": Color("4a5a7a")},
	{"depth": 1300.0, "name": "Anglerfish", "note": "Many live about 1,000 to 2,000 m down", "colour": Color("7a5a3a")},
	{"depth": 2000.0, "name": "Sperm whale", "note": "Dives to about 2,000 m, holding its breath for an hour", "colour": Color("6a7a8a")},
	{"depth": 2500.0, "name": "Bluntnose sixgill shark", "note": "Has been seen down to about 2,500 m", "colour": Color("5a6470")},
]

var _arena: Control
var _x := 0.5
var _depth := 0.0
var _target := 1000.0
var _speed := 1
var _slow := 0.0
var _steer := 0.0
## Ledges: {"depth": metres, "side": -1 left / 1 right, "reach": 0..1 how far it sticks out}.
var _ledges: Array[Dictionary] = []
var _seen := {}
var _note := ""


func _enter_tree() -> void:
	add_to_group("activity_echo_dive")


func _how_to_play() -> String:
	return "The submarine sinks by itself. Hold the left or right side to steer round the rock ledges. How deep can you go?"


func _start_board(config: Vector3i) -> void:
	_target = config.x * 100.0
	_speed = maxi(config.z, 1)
	_x = 0.5
	_depth = 0.0
	_slow = 0.0
	_seen.clear()
	_note = ""
	_ledges.clear()
	var per_hundred := maxi(config.y, 1)
	var d := 80.0
	while d < _target + 200.0:
		d += randf_range(60.0, 140.0) / per_hundred
		_ledges.append({"depth": d, "side": -1 if randf() < 0.5 else 1, "reach": randf_range(0.25, 0.5)})
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.gui_input.connect(_on_input)
	_arena.draw.connect(_draw_arena)
	_board.add_child(_arena)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_steer = (-1.0 if event.position.x < _arena.size.x / 2.0 else 1.0) if event.pressed else 0.0


func _process(delta: float) -> void:
	super(delta)
	if not _playing or not _arena:
		return
	var keys := Input.get_axis("move_left", "move_right")
	step(delta, keys if keys != 0.0 else _steer)
	_arena.queue_redraw()


## One step down (tests drive it): `steer` -1 left .. 1 right.
func step(delta: float, steer: float) -> void:
	_x = clampf(_x + steer * STEER * delta, SUB_HALF, 1.0 - SUB_HALF)
	var speed := (SINK + SINK_STEP * (_speed - 1)) * (0.3 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_depth += speed * delta
	for ledge: Dictionary in _ledges:
		if absf(ledge.depth - _depth) < 12.0 and _slow <= 0.0 and _hits(ledge):
			_slow = 0.8  # a bump: slowed down for a moment, pushed back into open water
			_x = (ledge.reach + SUB_HALF + 0.01) if ledge.side < 0 else (1.0 - ledge.reach - SUB_HALF - 0.01)
	for animal: Dictionary in ANIMALS:
		if _depth >= animal.depth and not _seen.has(animal.name):
			_seen[animal.name] = true
			_note = "%s: %s." % [animal.name, animal.note]
	if _depth >= _target:
		_depth = _target
		_complete()


func _hits(ledge: Dictionary) -> bool:
	return _x - SUB_HALF < ledge.reach if ledge.side < 0 else _x + SUB_HALF > 1.0 - ledge.reach


func depth() -> float:
	return _depth


func position_x() -> float:
	return _x


## The ledge nearest below the sub (for tests: steer round it), or {}.
func next_ledge() -> Dictionary:
	for ledge: Dictionary in _ledges:
		if ledge.depth > _depth - 6.0:
			return ledge
	return {}


func seen() -> Array:
	return _seen.keys()


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	var metres_per_screen := 400.0
	var dark := clampf(_depth / 1200.0, 0.0, 1.0)
	_arena.draw_rect(Rect2(Vector2.ZERO, size), Color("2a8ab8").lerp(Color("050a14"), dark))
	var top_depth := _depth - SUB_Y * metres_per_screen
	if top_depth < 0.0:  # the sky and the surface at the start
		_arena.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, -top_depth / metres_per_screen * size.y)), Color("bfe6f5"))
	var to_y := func(metres: float) -> float: return (metres - top_depth) / metres_per_screen * size.y
	for animal: Dictionary in ANIMALS:  # the deep's animals, at their real depths
		var y: float = to_y.call(animal.depth)
		if y < -20.0 or y > size.y + 20.0:
			continue
		_arena.draw_circle(Vector2(size.x * 0.82, y), 10.0, animal.colour)
		_arena.draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.55, y + 26.0), "%s · %d m" % [animal.name, animal.depth],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))
	for ledge: Dictionary in _ledges:
		var y: float = to_y.call(ledge.depth)
		if y < -20.0 or y > size.y + 20.0:
			continue
		var w: float = ledge.reach * size.x
		var rect := Rect2(Vector2(0.0 if ledge.side < 0 else size.x - w, y - 10.0), Vector2(w, 20.0))
		_arena.draw_rect(rect, Color("5a4a3e").lerp(Color("2a2420"), dark))
	var target_y: float = to_y.call(_target)
	if target_y < size.y + 20.0:
		_arena.draw_rect(Rect2(Vector2(0, target_y), Vector2(size.x, size.y - target_y)), Color("3a3028"))
	var sub := Vector2(_x * size.x, SUB_Y * size.y)
	_arena.draw_circle(sub + Vector2(0, 40), 46.0, Color(1.0, 0.95, 0.6, 0.08 + 0.12 * dark))  # its lamp
	_arena.draw_rect(Rect2(sub - Vector2(22, 12), Vector2(44, 24)), Color("f2c94c"))
	_arena.draw_rect(Rect2(sub - Vector2(8, 20), Vector2(16, 8)), Color("e0b03a"))
	_arena.draw_circle(sub + Vector2(10, 0), 6.0, Color("9fd8f0"))
	_arena.draw_string(ThemeDB.fallback_font, Vector2(16, 26), "Depth %d m  /  %d m" % [roundi(_depth), roundi(_target)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if _note != "":
		_arena.draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 16), _note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, Color("f2d58a"))
