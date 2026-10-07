class_name EchoDive
extends ActivityScreen
## Echo Dive (Imani, at the Deep-Ocean Outpost): take the submarine down the canyon from the
## surface. Steer in all four directions (hold a finger where you want it to go, or the move
## keys): down goes faster, up rises again, and it sinks slowly by itself, the canyon walls
## sliding past. Sunlight fades as you go down; below it only the sub's lamp and the sonar's
## ping, lighting everything up for a moment every PING_EVERY seconds, show the walls, the lost
## gear to pick up (each piece takes GEAR_BONUS seconds off the time) and the deep's animals,
## swimming at the depths where they really live. Bumping a wall only slows the sub. Each level
## is 1,000 m deeper; the story dive finds the lost cargo module at 1,000 m (Imani's cargo
## search), then it's for fun, with best times.

## Level config: (target depth in hundreds of metres, lost gear pieces, sinking speed 1-5).
const SUB_Y := 0.38
const SUB_HALF := 0.03
## The sub's speed down the canyon, metres a second at speed 1, and more per speed step.
const SINK := 40.0
const SINK_STEP := 10.0
## Sinking by itself, diving (down held) and rising (up held), times that speed.
const DRIFT := 0.4
const DIVE := 1.6
const RISE := 0.8
## Across the screen a second (a fraction of its width).
const STEER := 0.6
const METRES_PER_SCREEN := 420.0
const PING_EVERY := 1.6
const PING_FADE := 1.3
const GEAR_BONUS := 1.5
## Sunlight is gone by this depth (only the lamp and the sonar show anything below).
const DARK_AT := 900.0
## Canyon wall points every this many metres.
const WALL_STEP := 40.0

## What's passed on the way down, at real depths: zones, and the animals the ranger knows,
## swimming across (their own sprites; `scale` = how big, `left`: the picture faces left).
const SIGHTS := [
	{"depth": 70.0, "name": "Bottlenose dolphin", "animal": "bottlenose_dolphin", "scale": 3.0, "note": "Mostly in the top 100 m, though they can dive to about 300 m"},
	{"depth": 150.0, "name": "Reef shark", "animal": "reef_shark", "scale": 3.0, "note": "Grey reef sharks live on reefs down to about 280 m"},
	{"depth": 200.0, "name": "Sunlight ends", "note": "Below about 200 m there's too little light for plants to grow"},
	{"depth": 550.0, "name": "Bluntnose sixgill shark", "animal": "sixgill_shark", "scale": 3.0, "note": "Usually lives 200 to 1,100 m down"},
	{"depth": 750.0, "name": "Giant squid", "animal": "giant_squid", "scale": 3.0, "left": true, "note": "Lives about 300 to 1,000 m down"},
	{"depth": 1000.0, "name": "Midnight zone", "note": "From 1,000 m down no sunlight reaches at all: darker than any night"},
	{"depth": 1150.0, "name": "Sperm whale", "animal": "sperm_whale", "scale": 3.0, "note": "Hunts squid 300 to 1,200 m down, holding its breath for up to an hour"},
	{"depth": 1450.0, "name": "Anglerfish", "animal": "anglerfish", "scale": 3.0, "note": "Many live about 1,000 to 2,000 m down, luring food with a glowing lure"},
	{"depth": 1950.0, "name": "Sperm whale, diving deep", "animal": "sperm_whale", "scale": 3.0, "note": "Sperm whales can dive to about 2,000 m"},
	{"depth": 2350.0, "name": "Sixgill shark, very deep", "animal": "sixgill_shark", "scale": 3.0, "note": "Bluntnose sixgills have been seen down to about 2,500 m"},
	{"depth": 3000.0, "name": "The deep sea floor", "note": "Most of the ocean floor lies 3,000 to 6,000 m down"},
	{"depth": 3700.0, "name": "Average ocean depth", "note": "The ocean is about 3,700 m deep on average"},
	{"depth": 4000.0, "name": "The abyss", "note": "From 4,000 m: near freezing, in total darkness, under crushing pressure"},
]

var _arena: Control
var _x := 0.5
var _depth := 0.0
## The view's depth: it follows the sub, a little behind, so the sub moves on the screen too.
var _view := 0.0
var _target := 1000.0
var _speed := 1
var _slow := 0.0
var _time := 0.0
var _ping := 0.0
## Where a held finger is (the sub heads for it), or null.
var _finger: Variant = null
## Canyon walls: how far each side reaches in (0..1 of the width) every WALL_STEP metres.
var _walls: Array[Vector2] = []
## Lost gear: {"depth", "x", "item": texture}.
var _gear: Array[Dictionary] = []
var _got := 0
var _seen := {}
var _note := ""
var _textures := {}
var _cargo: Texture2D
var _gear_textures: Array[Texture2D] = []


func _enter_tree() -> void:
	add_to_group("activity_echo_dive")


func _how_to_play() -> String:
	return "Hold your finger where you want the submarine to go (or use the move keys): down to dive, up to rise. The sonar pings and lights up the dark for a moment. Pick up lost gear on the way!"


func _start_board(config: Vector3i) -> void:
	_target = config.x * 100.0
	_speed = maxi(config.z, 1)
	_x = 0.5
	_depth = 0.0
	_view = 0.0
	_slow = 0.0
	_time = 0.0
	_ping = 0.0
	_got = 0
	_finger = null
	_seen.clear()
	_note = ""
	for sight: Dictionary in SIGHTS:
		if sight.has("animal") and not _textures.has(sight.animal):
			_textures[sight.animal] = (load("res://data/animals/%s.tres" % sight.animal) as AnimalData).sprite
	_cargo = load("res://assets/items/lost_cargo_module.svg")
	_gear_textures = [load("res://assets/items/ghost_net.svg"), load("res://assets/items/fishing_line.svg")]
	_make_walls()
	_gear.clear()
	var pieces := maxi(config.y, 1)
	for i in pieces:
		var d := lerpf(120.0, _target - 80.0, (i + randf_range(0.2, 0.8)) / pieces)
		var gap := gap_at(d)
		_gear.append({"depth": d, "x": lerpf(gap.x + 0.06, gap.y - 0.06, randf()), "item": _gear_textures.pick_random()})
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.clip_contents = true
	_arena.gui_input.connect(_on_input)
	_arena.draw.connect(_draw_arena)
	_board.add_child(_arena)


## Rocky canyon walls with a ledge here and there; always room to get past.
func _make_walls() -> void:
	_walls.clear()
	var left := 0.12
	var right := 0.12
	var d := 0.0
	while d <= _target + METRES_PER_SCREEN:
		left = clampf(left + randf_range(-0.04, 0.04), 0.04, 0.26)
		right = clampf(right + randf_range(-0.04, 0.04), 0.04, 0.26)
		var ledge := Vector2.ZERO
		if d > 100.0 and randf() < 0.28:  # a ledge sticking out of one side
			ledge = Vector2(randf_range(0.1, 0.2), 0.0) if randf() < 0.5 else Vector2(0.0, randf_range(0.1, 0.2))
		_walls.append(Vector2(left, right) + ledge)
		d += WALL_STEP


## Open water across the canyon at `metres`: (left edge, right edge), 0..1 of the width.
func gap_at(metres: float) -> Vector2:
	var at := clampf(metres / WALL_STEP, 0.0, _walls.size() - 1.001)
	var i := floori(at)
	var w := _walls[i].lerp(_walls[mini(i + 1, _walls.size() - 1)], at - i)
	return Vector2(w.x, 1.0 - w.y)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_finger = event.position if event.pressed else null
	elif event is InputEventMouseMotion and _finger != null:
		_finger = event.position


func _process(delta: float) -> void:
	super(delta)
	if not _playing or not _arena:
		return
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move == Vector2.ZERO and _finger != null:  # towards the finger
		var towards: Vector2 = _finger - sub_on_screen()
		move = towards / maxf(towards.length(), 1.0) * clampf(towards.length() / 60.0, 0.0, 1.0)
	step(delta, move)
	_arena.queue_redraw()


## One step of the dive (tests drive it): `move` x -1 left .. 1 right, y -1 up .. 1 down.
func step(delta: float, move: Vector2) -> void:
	_time += delta
	_ping -= delta
	if _ping <= -PING_EVERY:
		_ping = 0.0
		Sound.play(&"ping", -8.0, 0.0)
	var speed := (SINK + SINK_STEP * (_speed - 1)) * (0.3 if _slow > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	var rate := lerpf(DRIFT, DIVE, move.y) if move.y >= 0.0 else lerpf(DRIFT, -RISE, -move.y)
	_depth = maxf(_depth + speed * rate * delta, 0.0)
	_x = clampf(_x + move.x * STEER * delta, SUB_HALF, 1.0 - SUB_HALF)
	var gap := gap_at(_depth)
	if _x - SUB_HALF < gap.x or _x + SUB_HALF > gap.y:  # a bump: slowed for a moment, nudged back
		if _slow <= 0.0:
			_slow = 0.7
		_x = clampf(_x, gap.x + SUB_HALF + 0.005, gap.y - SUB_HALF - 0.005)
	_view = lerpf(_view, _depth, minf(delta * 2.5, 1.0))
	for piece: Dictionary in _gear.duplicate():
		if absf(piece.depth - _depth) < 22.0 and absf(piece.x - _x) < 0.06:
			_gear.erase(piece)
			_got += 1
			seconds = maxf(seconds - GEAR_BONUS, 0.0)
			_note = "Lost gear picked up: %d (-%.1f s). It won't catch any more animals." % [_got, GEAR_BONUS]
			Sound.play(&"pickup")
	for sight: Dictionary in SIGHTS:
		if _depth >= sight.depth and not _seen.has(sight.name):
			_seen[sight.name] = true
			_note = "%s, %d m: %s." % [sight.name, sight.depth, sight.note]
	if _depth >= _target:
		_depth = _target
		_complete()


func depth() -> float:
	return _depth


func position_x() -> float:
	return _x


func gear_left() -> Array[Dictionary]:
	return _gear


func gear_got() -> int:
	return _got


func seen() -> Array:
	return _seen.keys()


## Where the sub is drawn: it moves on the screen as the view follows it.
func sub_on_screen() -> Vector2:
	var size := _arena.size if _arena else Vector2(1, 1)
	var y := clampf(SUB_Y + (_depth - _view) / METRES_PER_SCREEN, 0.15, 0.75)
	return Vector2(_x * size.x, y * size.y)


## How bright the sonar's echo is now (1 just after a ping, fading to 0).
func echo() -> float:
	return clampf(1.0 + _ping / PING_FADE, 0.0, 1.0)


## Daylight at `metres`: 1 at the surface, gone by DARK_AT.
func daylight(metres: float) -> float:
	return clampf(1.0 - metres / DARK_AT, 0.0, 1.0)


## How well something at screen point `at` and depth `metres` can be seen: daylight, the
## lamp near the sub, or the sonar's ping.
func _seen_at(at: Vector2, metres: float) -> float:
	var lamp := clampf(1.0 - at.distance_to(sub_on_screen()) / 170.0, 0.0, 1.0)
	return clampf(maxf(maxf(daylight(metres), lamp), echo() * 0.85), 0.0, 1.0)


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	var top := _view - SUB_Y * METRES_PER_SCREEN
	var to_y := func(metres: float) -> float: return (metres - top) / METRES_PER_SCREEN * size.y
	# The water, darker with depth, in bands.
	var band := 12.0
	var y := 0.0
	while y < size.y:
		var metres := top + y / size.y * METRES_PER_SCREEN
		var colour := Color("2a8ab8").lerp(Color("0b2a4a"), clampf(metres / 600.0, 0.0, 1.0)).lerp(Color("03060c"), clampf((metres - 600.0) / 1400.0, 0.0, 1.0))
		_arena.draw_rect(Rect2(0, y, size.x, band + 1.0), colour if metres >= 0.0 else Color("bfe6f5"))
		y += band
	if top < 0.0:  # the surface and sun rays at the start
		var surface: float = to_y.call(0.0)
		for i in 5:
			var x := size.x * (0.15 + i * 0.18)
			_arena.draw_colored_polygon(PackedVector2Array([Vector2(x, surface), Vector2(x + 30, surface),
				Vector2(x + 90, surface + size.y * 0.7), Vector2(x + 40, surface + size.y * 0.7)]), Color(1, 1, 0.85, 0.07))
	# Glowing specks in the dark (deep-sea animals' own light).
	if _view > 700.0:
		for i in 24:
			var sy := fposmod(i * 97.0 - _view * 0.9 * size.y / METRES_PER_SCREEN, size.y)
			var sx := fposmod(i * 211.0 + sin(_time + i) * 8.0, size.x)
			_arena.draw_circle(Vector2(sx, sy), 1.5, Color(0.5, 0.95, 1.0, 0.35 + 0.3 * sin(_time * 2.0 + i)))
	var lamp := clampf(1.0 - daylight(_depth), 0.0, 1.0)  # the sub's lamp, under everything it lights
	_arena.draw_circle(sub_on_screen(), 170.0, Color(1.0, 0.95, 0.6, 0.05 * lamp))
	_arena.draw_circle(sub_on_screen(), 90.0, Color(1.0, 0.95, 0.6, 0.06 * lamp))
	# The animals, swimming across at their depths.
	for sight: Dictionary in SIGHTS:
		var sy: float = to_y.call(sight.depth)
		if sy < -120.0 or sy > size.y + 120.0:
			continue
		if not sight.has("animal"):
			_arena.draw_dashed_line(Vector2(0, sy), Vector2(size.x, sy), Color(1, 1, 1, 0.25), 2.0, 10.0)
			_arena.draw_string(ThemeDB.fallback_font, Vector2(16, sy - 6), "%s · %d m" % [sight.name, sight.depth], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.75))
			continue
		var texture: Texture2D = _textures[sight.animal]
		var w: float = texture.get_width() * sight.scale
		var h: float = texture.get_height() * sight.scale
		var going_right := int(sight.depth) % 2 == 0
		var swim := fposmod(_time * 45.0 * (1.0 if going_right else -1.0) + sight.depth * 3.0, size.x + w * 2.0) - w
		var at := Vector2(swim, sy)
		var light := _seen_at(at, sight.depth)
		if light < 0.04:
			continue
		var faces_left: bool = sight.get("left", false)
		var flip := going_right == faces_left
		var rect := Rect2(at - Vector2(w, h) / 2.0, Vector2(w, h))
		if flip:
			rect = Rect2(rect.position + Vector2(w, 0), Vector2(-w, h))
		_arena.draw_texture_rect(texture, rect, false, Color(1, 1, 1, light))
		_arena.draw_string(ThemeDB.fallback_font, at + Vector2(-w / 2.0, h / 2.0 + 16.0), "%s · %d m" % [sight.name, sight.depth],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8 * light))
	_draw_walls(size, top)  # in front of the animals: they swim behind the canyon's edge
	# Lost gear to pick up.
	for piece: Dictionary in _gear:
		var at := Vector2(piece.x * size.x, to_y.call(piece.depth))
		if at.y < -30.0 or at.y > size.y + 30.0:
			continue
		var light := _seen_at(at, piece.depth)
		if light > 0.04:
			_arena.draw_texture_rect(piece.item, Rect2(at - Vector2(24, 24), Vector2(48, 48)), false, Color(1, 1, 1, light))
	# The sea floor at the target depth (with the cargo module on the story dive).
	var floor_y: float = to_y.call(_target)
	if floor_y < size.y + 20.0:
		_arena.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y + 20.0), Color("3a3028").lerp(Color("1a1612"), clampf(_target / 3000.0, 0.0, 1.0)))
		if not Activities.story_done(activity):
			_arena.draw_texture_rect(_cargo, Rect2(Vector2(size.x * 0.5 - 48, floor_y - 60), Vector2(96, 64)), false)
	_draw_sub(size)
	_arena.draw_string(ThemeDB.fallback_font, Vector2(16, 26), "Depth %d m  /  %d m     Lost gear: %d" % [roundi(_depth), roundi(_target), _got],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if _note != "":
		_arena.draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 16), _note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, Color("f2d58a"))


## The canyon's rock walls, lit by daylight near the top, below by the lamp and the ping;
## stripes of rock slide past as the sub goes down.
func _draw_walls(size: Vector2, top: float) -> void:
	var slice := 8.0
	var y := 0.0
	while y < size.y:
		var metres := top + y / size.y * METRES_PER_SCREEN
		if metres >= 0.0:
			var gap := gap_at(metres)
			var stripe := 0.85 + 0.15 * sin(metres * 0.11)  # rock layers
			var rock := Color("6a5a4c").lerp(Color("8fd3ff"), echo() * 0.3) * stripe
			for side in 2:
				var x0 := 0.0 if side == 0 else gap.y * size.x
				var w := gap.x * size.x if side == 0 else size.x - x0
				var edge := Vector2(gap.x * size.x if side == 0 else x0, y)
				var light := _seen_at(edge, metres)  # solid rock, just darker where it isn't lit
				_arena.draw_rect(Rect2(x0, y, w, slice + 1.0), Color("05070c").lerp(rock, maxf(light, 0.08)))
		y += slice


func _draw_sub(size: Vector2) -> void:
	var sub := sub_on_screen()
	_arena.draw_rect(Rect2(sub - Vector2(22, 12), Vector2(44, 24)), Color("f2c94c"))
	_arena.draw_rect(Rect2(sub - Vector2(8, 20), Vector2(16, 8)), Color("e0b03a"))
	_arena.draw_circle(sub + Vector2(10, 0), 6.0, Color("9fd8f0"))
	_arena.draw_rect(Rect2(sub + Vector2(-28, -4), Vector2(6, 8)), Color("b08a2a"))  # propeller
	var glow := echo()
	if glow > 0.0:  # the sonar's ping spreading out
		_arena.draw_arc(sub, (1.0 - glow) * size.x * 0.6 + 20.0, 0.0, TAU, 48, Color(0.56, 0.83, 1.0, glow * 0.5), 2.0)
