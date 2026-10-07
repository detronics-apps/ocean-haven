class_name EchoDive
extends ActivityScreen
## Echo Dive (Imani, at the Deep-Ocean Outpost): take the submarine down the canyon to the sea
## floor, then do it faster and faster. The view sinks by itself and never goes back up; the
## sub moves anywhere on the screen (hold a finger where it should go, or the move keys): the
## lower on the screen it is, the faster it sinks (up slows it, down speeds it up), left and
## right steer. Below the sunlight nothing can be seen unless the sonar's light is on: it
## flashes on and off, on for LIGHT_SHARE of the time (90 % at level 1 down to 50 % at level 5).
## Lost gear sinks slowly, so a missed piece can still be caught by waiting under it (each takes
## GEAR_BONUS seconds off the time). Each bump (a wall, wreckage, a boulder) costs one of the
## sub's HEARTS; repair kits (wrenches) deeper down give one back; with none left the sub needs
## repairs and heads back up: the dive's record is then the depth it reached
## (Activities.reached), until the level's sea floor is reached once; after that it's the time.
## The deep's animals swim past at the depths where they really live. Each level is 1,000 m
## deeper, sinks faster and has more in the way; the story dive finds the lost cargo module at
## 1,000 m (Imani's cargo search).

## Level config: (target depth in hundreds of metres, wreckage and boulders, sinking speed 1-5).
const SUB_HALF := 0.03
## Where the sub starts on the screen (0 top .. 1 bottom), and how far up / down it can go.
const SUB_START := 0.3
const SCREEN_TOP := 0.08
const SCREEN_BOTTOM := 0.9
## How fast the view sinks, metres a second at speed 1, and more per speed step...
const SINK := 50.0
const SINK_STEP := 12.0
## ... times this with the sub at the top of the screen, up to FAST at the bottom.
const SLOW := 0.4
const FAST := 2.0
## Up and down the screen a second (a fraction of its height; never faster up than it sinks).
const CLIMB := 0.7
## Bumps the sub can take, at most MAX_HEARTS with repair kits; and how long after a bump
## nothing more can hurt it (it blinks).
const HEARTS := 3
const MAX_HEARTS := 5
const SAFE_AFTER := 1.5
## Repair kits: one per 1,000 m of the level, below this share of its depth.
const WRENCH_FROM := 0.35
## Across the screen a second (a fraction of its width).
const STEER := 0.6
const METRES_PER_SCREEN := 420.0
## The sonar light: one flash every LIGHT_CYCLE seconds, on for this share of it, by level.
const LIGHT_CYCLE := 2.0
const LIGHT_SHARE: Array[float] = [0.9, 0.8, 0.7, 0.6, 0.5]
const GEAR_BONUS := 1.5
## Lost gear sinks at this share of the view's speed.
const GEAR_SINK := 0.25
## Lost gear pieces per 1,000 m.
const GEAR_PER_KM := 4
## Sunlight is gone by this depth (only the sonar's light shows anything below).
const DARK_AT := 250.0
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
## The depth at the top of the view (it sinks by itself), and the sub's place on the screen.
var _top := 0.0
var _sy := SUB_START
var _target := 1000.0
var _speed := 1
var _slow := 0.0
var _bump_wait := 0.0
var _time := 0.0
var _light_share := 0.9
var _was_on := false
## Where a held finger is (the sub heads for it), or null.
var _finger: Variant = null
## Canyon walls: how far each side reaches in (0..1 of the width) every WALL_STEP metres.
var _walls: Array[Vector2] = []
## Lost gear: {"depth", "x", "item": texture}.
var _gear: Array[Dictionary] = []
## In the way: {"depth", "x", "drift" (across, a second), "kind": "wreck" / "rock", "size"}.
var _obstacles: Array[Dictionary] = []
## Repair kits: {"depth", "x"}.
var _wrenches: Array[Dictionary] = []
var _hearts := HEARTS
var _got := 0
var _bumps := 0
var _seen := {}
var _note := ""
var _textures := {}
var _cargo: Texture2D
var _gear_textures: Array[Texture2D] = []


func _enter_tree() -> void:
	add_to_group("activity_echo_dive")


func _how_to_play() -> String:
	return "Hold your finger where you want the submarine to go (or use the move keys). It keeps sinking: down dives faster, up holds your depth. In the dark you only see while the sonar light is on. The lower you are, the faster you sink. Each bump costs a heart; wrenches repair the sub."


func _start_board(config: Vector3i) -> void:
	_target = config.x * 100.0
	_speed = maxi(config.z, 1)
	_light_share = LIGHT_SHARE[clampi(level, 0, LIGHT_SHARE.size() - 1)]
	_x = 0.5
	_sy = SUB_START
	_top = -SUB_START * METRES_PER_SCREEN  # the sub starts at the surface
	_slow = 0.0
	_bump_wait = 0.0
	_time = 0.0
	_was_on = false
	_got = 0
	_bumps = 0
	_hearts = HEARTS
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
	var pieces := maxi(roundi(_target / 1000.0 * GEAR_PER_KM), 1)
	for i in pieces:
		var d := lerpf(120.0, _target - 120.0, (i + randf_range(0.2, 0.8)) / pieces)
		var gap := gap_at(d)
		_gear.append({"depth": d, "x": lerpf(gap.x + 0.06, gap.y - 0.06, randf()), "item": _gear_textures.pick_random()})
	_obstacles.clear()
	var count := maxi(config.y, 0)
	for i in count:
		var d := lerpf(150.0, _target - 100.0, (i + randf_range(0.1, 0.9)) / maxf(count, 1.0))
		var gap := gap_at(d)
		_obstacles.append({"depth": d, "x": lerpf(gap.x + 0.08, gap.y - 0.08, randf()), "drift": randf_range(-0.06, 0.06),
			"kind": "wreck" if randf() < 0.5 else "rock", "size": randf_range(0.8, 1.3)})
	_wrenches.clear()
	var kits := maxi(roundi(_target / 1000.0), 1)
	for i in kits:
		var d := lerpf(_target * WRENCH_FROM, _target - 80.0, (i + randf_range(0.3, 0.7)) / kits)
		var gap := gap_at(d)
		_wrenches.append({"depth": d, "x": lerpf(gap.x + 0.08, gap.y - 0.08, randf())})
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
		left = clampf(left + randf_range(-0.04, 0.04), 0.04, 0.24)
		right = clampf(right + randf_range(-0.04, 0.04), 0.04, 0.24)
		var ledge := Vector2.ZERO
		if d > 100.0 and randf() < 0.25:  # a ledge sticking out of one side
			ledge = Vector2(randf_range(0.08, 0.18), 0.0) if randf() < 0.5 else Vector2(0.0, randf_range(0.08, 0.18))
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


## The view's sinking speed now, metres a second: faster the lower the sub is on the screen
## (slowed for a moment after a bump).
func sink_speed() -> float:
	var low := clampf((_sy - SCREEN_TOP) / (SCREEN_BOTTOM - SCREEN_TOP), 0.0, 1.0)
	return (SINK + SINK_STEP * (_speed - 1)) * lerpf(SLOW, FAST, low) * (0.3 if _slow > 0.0 else 1.0)


## One step of the dive (tests drive it): `move` x -1 left .. 1 right, y -1 up .. 1 down.
func step(delta: float, move: Vector2) -> void:
	_time += delta
	var on := light_on()
	if on and not _was_on:
		Sound.play(&"ping", -8.0, 0.0)
	_was_on = on
	var before := depth()
	var speed := sink_speed()
	_slow = maxf(_slow - delta, 0.0)
	_bump_wait = maxf(_bump_wait - delta, 0.0)
	# The view sinks by itself (until the sea floor shows near the bottom of the screen).
	_top = minf(_top + speed * delta, _target - SCREEN_BOTTOM * METRES_PER_SCREEN + 30.0)
	# Up and down the screen (lower = faster); never up faster than the view sinks.
	var climb := CLIMB if move.y > 0.0 else minf(CLIMB, speed / METRES_PER_SCREEN)
	_sy = clampf(_sy + move.y * climb * delta, SCREEN_TOP, SCREEN_BOTTOM)
	if depth() < before:  # never back up: the sub can't rise
		_sy = (before - _top) / METRES_PER_SCREEN
	_x = clampf(_x + move.x * STEER * delta, SUB_HALF, 1.0 - SUB_HALF)
	var gap := gap_at(depth())
	if _x - SUB_HALF < gap.x or _x + SUB_HALF > gap.y:  # a wall: slowed for a moment, nudged back
		_x = clampf(_x, gap.x + SUB_HALF + 0.005, gap.y - SUB_HALF - 0.005)
		_bump("the canyon wall")
	for thing: Dictionary in _obstacles:
		var room := gap_at(thing.depth)
		thing.x += thing.drift * delta
		if thing.x < room.x + 0.05 or thing.x > room.y - 0.05:
			thing.drift = -thing.drift
			thing.x = clampf(thing.x, room.x + 0.05, room.y - 0.05)
		if absf(thing.depth - depth()) < 18.0 * thing.size and absf(thing.x - _x) < 0.045 * thing.size + SUB_HALF:
			_bump("an old wreck" if thing.kind == "wreck" else "a boulder")
	for kit: Dictionary in _wrenches.duplicate():
		if absf(kit.depth - depth()) < 22.0 and absf(kit.x - _x) < 0.06:
			_wrenches.erase(kit)
			_hearts = mini(_hearts + 1, MAX_HEARTS)
			_note = "A repair kit! The sub is patched up: +1 heart."
			Sound.play(&"free")
	if not _playing:
		return
	for piece: Dictionary in _gear.duplicate():
		piece.depth = minf(piece.depth + speed * GEAR_SINK * delta, _target - 20.0)  # sinking slowly
		if absf(piece.depth - depth()) < 22.0 and absf(piece.x - _x) < 0.06:
			_gear.erase(piece)
			_got += 1
			seconds = maxf(seconds - GEAR_BONUS, 0.0)
			_note = "Lost gear picked up: %d (-%.1f s). It won't catch any more animals." % [_got, GEAR_BONUS]
			Sound.play(&"pickup")
	for sight: Dictionary in SIGHTS:
		if depth() >= sight.depth and not _seen.has(sight.name):
			_seen[sight.name] = true
			_note = "%s, %d m: %s." % [sight.name, sight.depth, sight.note]
	if depth() >= _target - 25.0:  # on the sea floor
		for sight: Dictionary in SIGHTS:
			if sight.depth <= _target:
				_seen[sight.name] = true
		Activities.reached(activity, level, _target)
		_complete()


## Bumped into something: slowed down for a moment, and one heart lost (none for a moment
## after). With none left the sub needs repairs: it heads back up, and the depth it reached
## is kept as the record until the level's sea floor has been reached.
func _bump(what: String) -> void:
	_slow = maxf(_slow, 0.7)
	if _bump_wait > 0.0 or not _playing:
		return
	_bump_wait = SAFE_AFTER
	_bumps += 1
	_hearts -= 1
	Sound.play(&"dig", -4.0)
	if _hearts > 0:
		_note = "Bump! You hit %s: %d heart%s left. Wait for the light to see what's ahead." % [what, _hearts, "" if _hearts == 1 else "s"]
		return
	var metres := roundi(depth())
	var deeper := Activities.reached(activity, level, depth())
	var lines: Array[String] = ["The submarine needs repairs, so it's heading back up to the Outpost.",
		"You reached %d m%s." % [metres, " (your deepest yet!)" if deeper else ""]]
	if Activities.best(activity, level) < INF:
		lines.append("Your best time to the sea floor: %.1f s." % Activities.best(activity, level))
	else:
		lines.append("Deepest so far: %d m of %d m. Reach the sea floor and your time becomes the record." % [roundi(Activities.best_depth(activity, level)), roundi(_target)])
	lines.append("Tip: stay higher on the screen where it's dark: you sink more slowly and have time to see what's ahead.")
	_stop(lines)


func hearts() -> int:
	return _hearts


func wrenches() -> Array[Dictionary]:
	return _wrenches


## The sub's depth, metres.
func depth() -> float:
	return _top + _sy * METRES_PER_SCREEN


func position_x() -> float:
	return _x


## The sub's place on the screen, 0 (top) .. 1 (bottom).
func screen_y() -> float:
	return _sy


func gear_left() -> Array[Dictionary]:
	return _gear


func gear_got() -> int:
	return _got


func obstacles() -> Array[Dictionary]:
	return _obstacles


func bumps() -> int:
	return _bumps


func light_share() -> float:
	return _light_share


func seen() -> Array:
	return _seen.keys()


func sub_on_screen() -> Vector2:
	var size := _arena.size if _arena else Vector2(1, 1)
	return Vector2(_x * size.x, _sy * size.y)


## Whether the sonar light is on now (on for `light_share` of every LIGHT_CYCLE).
func light_on() -> bool:
	return fposmod(_time, LIGHT_CYCLE) < _light_share * LIGHT_CYCLE


## How bright the sonar light is: 1 while on, with a quick fade at either end.
func echo() -> float:
	var t := fposmod(_time, LIGHT_CYCLE)
	var on := _light_share * LIGHT_CYCLE
	if t >= on:
		return 0.0
	return clampf(minf(t, on - t) / 0.08, 0.0, 1.0)


## Daylight at `metres`: 1 at the surface, gone by DARK_AT.
func daylight(metres: float) -> float:
	return clampf(1.0 - metres / DARK_AT, 0.0, 1.0)


## How well something at depth `metres` can be seen: daylight near the top, else only while
## the sonar light is on.
func _seen_at(_at: Vector2, metres: float) -> float:
	return clampf(maxf(daylight(metres), echo()), 0.0, 1.0)


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	var top := _top
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
	if top > 400.0:
		for i in 24:
			var sy := fposmod(i * 97.0 - top * 0.9 * size.y / METRES_PER_SCREEN, size.y)
			var sx := fposmod(i * 211.0 + sin(_time + i) * 8.0, size.x)
			_arena.draw_circle(Vector2(sx, sy), 1.5, Color(0.5, 0.95, 1.0, 0.35 + 0.3 * sin(_time * 2.0 + i)))
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
	# Repair kits.
	for kit: Dictionary in _wrenches:
		var at := Vector2(kit.x * size.x, to_y.call(kit.depth))
		if at.y > -30.0 and at.y < size.y + 30.0:
			var light := _seen_at(at, kit.depth)
			if light > 0.04:
				_draw_wrench(at, Color(0.85, 0.88, 0.92, light))
	# Wreckage and boulders in the way.
	for thing: Dictionary in _obstacles:
		var at := Vector2(thing.x * size.x, to_y.call(thing.depth))
		if at.y < -40.0 or at.y > size.y + 40.0:
			continue
		var light := _seen_at(at, thing.depth)
		if light > 0.04:
			_draw_obstacle(thing, at, light)
	# The sea floor at the target depth (with the cargo module on the story dive).
	var floor_y: float = to_y.call(_target)
	if floor_y < size.y + 20.0:
		_arena.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y + 20.0), Color("3a3028").lerp(Color("1a1612"), clampf(_target / 3000.0, 0.0, 1.0)))
		if not Activities.story_done(activity):
			_arena.draw_texture_rect(_cargo, Rect2(Vector2(size.x * 0.5 - 48, floor_y - 60), Vector2(96, 64)), false)
	# The dark: with the sonar light off, nothing below the sunlight can be seen.
	var shade := 0.0
	while shade < size.y:
		var dark := 1.0 - maxf(daylight(top + shade / size.y * METRES_PER_SCREEN), echo())
		if dark > 0.01:
			_arena.draw_rect(Rect2(0, shade, size.x, 13.0), Color(0.01, 0.015, 0.03, dark * 0.97))
		shade += 12.0
	_draw_sub(size)
	for i in _hearts:  # the sub's hearts, top right
		_draw_heart(Vector2(size.x - 28.0 - i * 34.0, 22.0))
	_arena.draw_string(ThemeDB.fallback_font, Vector2(16, 26), "Depth %d m  /  %d m     Lost gear: %d     Light on %d%% of the time" % [
		roundi(depth()), roundi(_target), _got, roundi(_light_share * 100.0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	if _note != "":
		_arena.draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 16), _note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, Color("f2d58a"))


## A heart (one bump the sub can still take).
func _draw_heart(at: Vector2) -> void:
	var red := Color("ff5d6c")
	_arena.draw_circle(at + Vector2(-6, -3), 7.0, red)
	_arena.draw_circle(at + Vector2(6, -3), 7.0, red)
	_arena.draw_colored_polygon(PackedVector2Array([at + Vector2(-13, -1), at + Vector2(13, -1), at + Vector2(0, 13)]), red)
	_arena.draw_circle(at + Vector2(-7, -5), 2.0, Color(1, 1, 1, 0.7))


## A repair kit: a spanner.
func _draw_wrench(at: Vector2, colour: Color) -> void:
	_arena.draw_set_transform(at, -0.7, Vector2.ONE)
	_arena.draw_rect(Rect2(-16, -3, 26, 6), colour)
	_arena.draw_circle(Vector2(13, 0), 8.0, colour)
	_arena.draw_rect(Rect2(12, -3, 10, 6), Color(0.02, 0.05, 0.1, colour.a))  # the jaw's gap
	_arena.draw_circle(Vector2(-16, 0), 5.0, colour)
	_arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_arena.draw_arc(at, 24.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, colour.a * 0.6), 2.0)


## An old wreck's twisted metal, or a boulder.
func _draw_obstacle(thing: Dictionary, at: Vector2, light: float) -> void:
	var r: float = 26.0 * thing.size
	if thing.kind == "wreck":
		var rust := Color("8a4a2a").lerp(Color("05070c"), 1.0 - light)
		var dark := Color("4a2616").lerp(Color("05070c"), 1.0 - light)
		var points := PackedVector2Array()
		for i in 7:
			var angle := TAU * i / 7.0 + 0.3
			points.append(at + Vector2.from_angle(angle) * r * (0.6 if i % 2 == 0 else 1.0))
		_arena.draw_colored_polygon(points, rust)
		_arena.draw_polyline(points + PackedVector2Array([points[0]]), dark, 2.0)
		for i in 3:  # rivets
			_arena.draw_circle(at + Vector2(-r * 0.3 + i * r * 0.3, -r * 0.1), 2.0, dark)
	else:
		var stone := Color("5a5650").lerp(Color("05070c"), 1.0 - light)
		_arena.draw_circle(at, r * 0.8, stone)
		_arena.draw_circle(at + Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color("6e6a62").lerp(Color("05070c"), 1.0 - light))


## The canyon's rock walls, lit by daylight near the top, below only by the sonar's light;
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
				_arena.draw_rect(Rect2(x0, y, w, slice + 1.0), Color("05070c").lerp(rock, maxf(light, 0.04)))
		y += slice


func _draw_sub(size: Vector2) -> void:
	var sub := sub_on_screen()
	if _bump_wait > 0.0 and fmod(_bump_wait, 0.3) < 0.15:
		return  # blinking: just bumped
	_arena.draw_rect(Rect2(sub - Vector2(22, 12), Vector2(44, 24)), Color("f2c94c"))
	_arena.draw_rect(Rect2(sub - Vector2(8, 20), Vector2(16, 8)), Color("e0b03a"))
	_arena.draw_circle(sub + Vector2(10, 0), 6.0, Color("9fd8f0"))
	_arena.draw_rect(Rect2(sub + Vector2(-28, -4), Vector2(6, 8)), Color("b08a2a"))  # propeller
	var since := fposmod(_time, LIGHT_CYCLE)
	if light_on() and since < 0.6:  # the sonar's ping spreading out as the light comes on
		_arena.draw_arc(sub, since / 0.6 * size.x * 0.6 + 20.0, 0.0, TAU, 48, Color(0.56, 0.83, 1.0, 0.5 * (1.0 - since / 0.6)), 2.0)
