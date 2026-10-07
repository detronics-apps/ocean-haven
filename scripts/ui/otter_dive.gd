class_name OtterDive
extends ActivityScreen
## Otter Dive (Finn, from the old jetty on the Kelp Forest): dive like a sea otter. Hold to swim
## down, let go to float up; grab the urchins on the sea floor and come up for air before it
## runs out (out of air, you just float up: nothing goes wrong). Bumping a kelp stalk slows you
## for a moment. Litter drifts through the forest: swimming into it the otter gets caught for a
## moment and wriggles free, losing one of its HEARTS. The story play counts urchins for Finn
## (the urchin pressure survey: collect the level's number). After that each level is endless:
## how many urchins can you collect, and how long can you go without getting caught three
## times? (Activities.record_most "urchins" / "seconds"; collecting the level's number of
## urchins in one go opens the next.) Fish swim by and birds fly over the water.

## Level config: (urchins to collect: the story's goal, then what opens the next level; kelp
## stalks per screen; current strength 1-5, which also brings more litter).
const AIR_SECONDS := 7.0
const OTTER_X := 0.22
const SURFACE := 0.14
const FLOOR := 0.9
const HEARTS := 3
## Held fast in litter this long, then safe for SAFE_AFTER more.
const CAUGHT_SECONDS := 0.8
const SAFE_AFTER := 1.5
const FISH_SPRITES := ["res://data/animals/blue_rockfish.tres", "res://data/animals/juvenile_snapper.tres"]
const LITTER_ICONS := ["res://assets/items/plastic_bag.svg", "res://assets/items/six_pack_rings.svg", "res://assets/items/ghost_net.svg"]

var _arena: Control
var _holding := false
var _y := 0.14
var _velocity := 0.0
var _air := AIR_SECONDS
var _scroll := 0.0
var _slow := 0.0
var _goal := 0
var _got := 0
## Things in the water: {"x": world x, "y": 0..1, "kind": "urchin" / "kelp" / "litter",
## "h": kelp height, "phase": its sway, "icon": litter picture}.
var _things: Array[Dictionary] = []
var _speed := 0.18
var _density := 3
var _current := 1
var _note := ""
var _paddle := 0.0
var _time := 0.0
var _hearts := HEARTS
var _caught := 0.0
var _safe := 0.0
## Fish and birds going by: {"x", "y", "speed", "kind": "fish" / "bird", "texture"}.
var _life: Array[Dictionary] = []
var _litter_icons: Array[Texture2D] = []
var _fish_textures: Array[Texture2D] = []


func _enter_tree() -> void:
	add_to_group("activity_otter_dive")


func _how_to_play() -> String:
	if _story():
		return "Hold to dive, let go to float up. Grab %d urchins on the sea floor, and come up for air before it runs out. Kelp slows you down; keep clear of litter: it catches you (3 hearts)." % _goal
	return "Hold to dive, let go to float up. How many urchins can you grab, and how long can you last? Litter catches you and costs a heart: after 3 the dive is over."


func _story() -> bool:
	return activity != null and not Activities.story_done(activity)


func _level_note(i: int) -> String:
	var urchins := Activities.most(activity, i, "urchins")
	if urchins <= 0.0:
		return "New!"
	return "Most %d urchins\nLasted %d s" % [roundi(urchins), roundi(Activities.most(activity, i, "seconds"))]


func _start_board(config: Vector3i) -> void:
	_goal = config.x
	_density = config.y
	_current = config.z
	_speed = 0.14 + 0.03 * config.z
	_got = 0
	_y = SURFACE
	_velocity = 0.0
	_air = AIR_SECONDS
	_scroll = 0.0
	_slow = 0.0
	_time = 0.0
	_hearts = HEARTS
	_caught = 0.0
	_safe = 0.0
	_note = ""
	_things.clear()
	_life.clear()
	if _litter_icons.is_empty():
		for path: String in LITTER_ICONS:
			_litter_icons.append(load(path))
		for path: String in FISH_SPRITES:
			_fish_textures.append((load(path) as AnimalData).sprite)
	_place_ahead(0.4, 3.0)
	for i in 4:
		_add_life(randf_range(0.0, 1.0))
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.clip_contents = true
	_arena.gui_input.connect(_on_arena_input)
	_arena.draw.connect(_draw_arena)
	_board.add_child(_arena)


## Places urchins, kelp and drifting litter from world x `from` to `to` (screen widths).
func _place_ahead(from: float, to: float) -> void:
	var x := from
	while x < to:
		x += randf_range(0.18, 0.32)
		_things.append({"x": x, "y": randf_range(0.78, 0.86), "kind": "urchin"})
		for i in _density / 2:
			_things.append({"x": x + randf_range(-0.12, 0.12), "y": FLOOR, "kind": "kelp", "h": randf_range(0.25, 0.55), "phase": randf() * TAU})
		if x > 0.9 and randf() < 0.18 + 0.07 * _current:  # litter drifting in the current
			_things.append({"x": x + randf_range(0.05, 0.15), "y": randf_range(SURFACE + 0.12, FLOOR - 0.12), "kind": "litter",
				"icon": _litter_icons.pick_random(), "phase": randf() * TAU})


## A fish swimming through the forest, or a bird flying over the water.
func _add_life(x: float) -> void:
	if randf() < 0.6:
		_life.append({"x": x, "y": randf_range(SURFACE + 0.1, FLOOR - 0.15), "speed": randf_range(-0.08, 0.06), "kind": "fish",
			"texture": _fish_textures.pick_random(), "phase": randf() * TAU})
	else:
		_life.append({"x": x, "y": randf_range(0.03, SURFACE - 0.04), "speed": randf_range(0.04, 0.1) * (1.0 if randf() < 0.5 else -1.0),
			"kind": "bird", "phase": randf() * TAU})


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
	_time += delta
	_safe = maxf(_safe - delta, 0.0)
	var out_of_air := _air <= 0.0
	var push := 1.1 if diving and not out_of_air else -0.9  # down while held, buoyant otherwise
	if _caught > 0.0:  # held fast in the litter for a moment
		_caught = maxf(_caught - delta, 0.0)
		push = 0.0
	_velocity = lerpf(_velocity, push, minf(delta * 4.0, 1.0))
	_y = clampf(_y + _velocity * delta * 0.6, SURFACE, FLOOR - 0.04)
	if _y <= SURFACE + 0.01:
		_air = minf(_air + delta * AIR_SECONDS / 1.2, AIR_SECONDS)  # a breath at the surface
	else:
		_air = maxf(_air - delta, 0.0)
	var speed := _speed * (0.35 if _slow > 0.0 else 1.0) * (0.0 if _caught > 0.0 else 1.0)
	_slow = maxf(_slow - delta, 0.0)
	_scroll += speed * delta
	for thing: Dictionary in _things.duplicate():
		var screen_x: float = thing.x - _scroll
		if screen_x < -0.1:
			_things.erase(thing)
			continue
		if thing.kind == "litter":
			thing.y += sin(_time * 1.5 + thing.phase) * 0.02 * delta  # bobbing in the current
		if absf(screen_x - OTTER_X) > 0.04:
			continue
		if thing.kind == "urchin" and absf(thing.y - _y) < 0.07:
			_things.erase(thing)
			_got += 1
			Sound.play(&"pickup")
		elif thing.kind == "kelp" and _y > FLOOR - thing.h and _slow <= 0.0:
			_slow = 0.6  # a bump: slowed down for a moment
		elif thing.kind == "litter" and absf(thing.y - _y) < 0.06 and _safe <= 0.0:
			_things.erase(thing)
			_tangle()
			if not _playing:
				return
	for one: Dictionary in _life.duplicate():
		one.x += (one.speed - speed) * delta  # their own way, and the forest going by
		if one.x < -0.2 or one.x > 1.3:
			_life.erase(one)
			_add_life(1.25 if one.speed - speed < 0.0 else -0.15)
	if _things.filter(func(t: Dictionary) -> bool: return t.kind == "urchin").size() < 4:
		_place_ahead(_scroll + 1.2, _scroll + 2.4)
	if _story() and _got >= _goal:
		_complete()


## Swam into litter: held for a moment, then wriggles free, one heart less. With none left the
## dive is over (never a failure: it says how well it went).
func _tangle() -> void:
	_hearts -= 1
	_caught = CAUGHT_SECONDS
	_safe = CAUGHT_SECONDS + SAFE_AFTER
	_velocity = 0.0
	Sound.play(&"dig", -4.0)
	if _hearts > 0:
		_note = "Caught in litter! The otter wriggles free: %d heart%s left." % [_hearts, "" if _hearts == 1 else "s"]
		return
	var more_urchins := Activities.record_most(activity, level, "urchins", _got)
	var longer := Activities.record_most(activity, level, "seconds", seconds)
	if _got >= _goal:
		Activities.record_most(activity, level, "cleared", 1.0)
	var lines: Array[String] = ["The otter is tired out from wriggling free of all that litter, and floats up for a rest.",
		"You collected %d urchin%s and lasted %d s.%s" % [_got, "" if _got == 1 else "s", roundi(seconds),
			" New record!" if more_urchins or longer else ""],
		"Your best: %d urchins, %d s." % [roundi(Activities.most(activity, level, "urchins")), roundi(Activities.most(activity, level, "seconds"))]]
	if _story():
		lines = ["The otter got caught in litter three times and needs a rest. Let's try again: %d urchins for Finn!" % _goal]
	elif _got >= _goal and level + 1 < activity.levels.size():
		lines.append("%d urchins or more: level %d is open!" % [_goal, level + 2])
	_stop(lines)
	if not _story() and Activities.cleared(activity, level) and level + 1 < activity.levels.size():
		_add_button("Next level", _show_start.bind(level + 1, ""), "Next")


func collected() -> int:
	return _got


func air() -> float:
	return _air


func depth() -> float:
	return _y


func hearts() -> int:
	return _hearts


func things() -> Array[Dictionary]:
	return _things


func _draw_arena() -> void:
	var size := _arena.size
	if size.x <= 0.0:
		return
	# Sky, water getting darker with depth, light rays and the sea floor.
	_arena.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * SURFACE)), Color("bfe6f5"))
	var bands := 10
	for i in bands:
		var top := SURFACE + (FLOOR - SURFACE) * i / bands
		_arena.draw_rect(Rect2(0, top * size.y, size.x, (FLOOR - SURFACE) / bands * size.y + 1.0), Color("2f7f9a").lerp(Color("163f52"), float(i) / bands))
	for i in 4:
		var x := fposmod(i * 0.29 - _scroll * 0.2, 1.2) * size.x - 60.0
		_arena.draw_colored_polygon(PackedVector2Array([Vector2(x, SURFACE * size.y), Vector2(x + 40, SURFACE * size.y),
			Vector2(x + 120, FLOOR * size.y), Vector2(x + 70, FLOOR * size.y)]), Color(1, 1, 0.85, 0.05))
	for i in 24:  # little waves on the surface
		var wx := fposmod(i * 0.05 - _scroll * 0.5, 1.2) * size.x - 20.0
		_arena.draw_arc(Vector2(wx, SURFACE * size.y + 2.0), 8.0, PI, TAU, 6, Color(1, 1, 1, 0.5), 2.0)
	_arena.draw_rect(Rect2(Vector2(0, size.y * FLOOR), Vector2(size.x, size.y * (1.0 - FLOOR))), Color("6e6250"))
	for i in 30:  # pebbles
		var px := fposmod(i * 0.037 - _scroll, 1.1) * size.x
		_arena.draw_circle(Vector2(px, size.y * (FLOOR + 0.02 + (i % 3) * 0.02)), 2.0 + i % 3, Color("8a7c66"))
	for one: Dictionary in _life:
		if one.kind == "bird":
			_draw_bird(Vector2(one.x * size.x, one.y * size.y), one.speed > 0.0, one.phase)
	for thing: Dictionary in _things:
		if thing.kind == "kelp":
			_draw_kelp(thing, size)
	for one: Dictionary in _life:
		if one.kind == "fish":
			var texture: Texture2D = one.texture
			var at := Vector2(one.x * size.x, one.y * size.y + sin(_time * 2.0 + one.phase) * 4.0)
			var w := texture.get_width() * 3.0
			var h := texture.get_height() * 3.0
			var rect := Rect2(at - Vector2(w, h) / 2.0, Vector2(w, h))
			if one.speed < 0.0:  # facing the way it swims (the pictures face right)
				rect = Rect2(rect.position + Vector2(w, 0), Vector2(-w, h))
			_arena.draw_texture_rect(texture, rect, false, Color(1, 1, 1, 0.85))
	for thing: Dictionary in _things:
		var x: float = (thing.x - _scroll) * size.x
		if x < -40.0 or x > size.x + 40.0:
			continue
		if thing.kind == "urchin":
			var at := Vector2(x, thing.y * size.y)
			_arena.draw_circle(at, 9.0, Color("7b3f8c"))
			for i in 8:
				_arena.draw_line(at, at + Vector2.from_angle(TAU * i / 8.0) * 14.0, Color("5a2a6a"), 2.0)
		elif thing.kind == "litter":
			var at := Vector2(x, thing.y * size.y)
			_arena.draw_set_transform(at, sin(_time + thing.phase) * 0.3, Vector2.ONE)
			_arena.draw_texture_rect(thing.icon, Rect2(-20, -20, 40, 40), false)
			_arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var otter_at := Vector2(OTTER_X * size.x, _y * size.y)
	if not (_safe > 0.0 and _caught <= 0.0 and fmod(_safe, 0.3) < 0.15):  # blinks while safe
		_draw_otter(otter_at)
	if _caught > 0.0:  # caught: a loop of net round it
		_arena.draw_arc(otter_at, 26.0, 0.0, TAU, 16, Color(0.85, 0.85, 0.75, 0.9), 2.0)
		_arena.draw_line(otter_at + Vector2(-24, -8), otter_at + Vector2(24, 8), Color(0.85, 0.85, 0.75, 0.9), 2.0)
	# Air, urchins, hearts, and the last thing that happened.
	var bar := Rect2(Vector2(16, 12), Vector2(160, 14))
	_arena.draw_rect(bar, Color(0, 0, 0, 0.4))
	_arena.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _air / AIR_SECONDS, bar.size.y)), Color("8fd3ff"))
	var count := "Urchins %d / %d" % [_got, _goal] if _story() else "Urchins %d    %d s" % [_got, roundi(seconds)]
	_arena.draw_string(get_theme_default_font(), Vector2(190, 25), "Air    " + count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	for i in _hearts:
		draw_heart(_arena, Vector2(size.x - 28.0 - i * 34.0, 22.0))
	if _note != "":
		_arena.draw_string(get_theme_default_font(), Vector2(16, size.y - 12), _note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, Color("f2d58a"))


## A giant kelp stalk: a holdfast on the floor, a stipe waving up in the current (more at the
## top), blades on alternate sides and a float (gas bladder) at each blade.
func _draw_kelp(thing: Dictionary, size: Vector2) -> void:
	var base := Vector2((thing.x - _scroll) * size.x, FLOOR * size.y)
	if base.x < -80.0 or base.x > size.x + 80.0:
		return
	var height: float = thing.h * size.y
	var segments := 9
	var points := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / segments
		var sway := sin(_time * 1.6 + thing.phase + t * 3.0) * 14.0 * t + sin(_time * 0.7 + thing.phase) * 6.0 * t * t
		points.append(base + Vector2(sway, -height * t))
	_arena.draw_circle(base + Vector2(0, 2), 7.0, Color("4a3a24"))  # holdfast
	_arena.draw_polyline(points, Color("6b4f1f"), 4.0)  # the stipe
	for i in range(1, segments + 1):
		var at := points[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		var flutter := sin(_time * 2.2 + thing.phase + i) * 0.3
		var tip := at + Vector2.from_angle(-PI / 2.0 + side * (1.0 + flutter)) * 22.0
		var mid := (at + tip) / 2.0
		var across := (tip - at).orthogonal().normalized() * 5.0
		_arena.draw_colored_polygon(PackedVector2Array([at, mid + across, tip, mid - across]), Color("8a9a3a").lerp(Color("6f8a2a"), float(i) / segments))
		_arena.draw_circle(at + (tip - at) * 0.12, 3.0, Color("a8a04a"))  # its float
	if thing.h > 0.4:  # tall ones spread a canopy just under the surface
		var top := points[segments]
		for i in 3:
			_arena.draw_line(top, top + Vector2(-18 + i * 18, 6 + absf(i - 1) * 4), Color("8a9a3a"), 3.0)


## A gull, side on, wings flapping.
func _draw_bird(at: Vector2, right: bool, phase: float) -> void:
	var flap := sin(_time * 7.0 + phase) * 7.0
	var dir := 1.0 if right else -1.0
	_arena.draw_line(at + Vector2(-10, -flap), at, Color("e8eef2"), 3.0)
	_arena.draw_line(at, at + Vector2(10, -flap), Color("e8eef2"), 3.0)
	_arena.draw_circle(at, 4.0, Color("f5f8fa"))
	_arena.draw_circle(at + Vector2(5 * dir, -1), 2.5, Color("f5f8fa"))
	_arena.draw_line(at + Vector2(7 * dir, -1), at + Vector2(10 * dir, 0), Color("f2c94c"), 2.0)  # beak
	_arena.draw_line(at + Vector2(-10, -flap), at + Vector2(-13, -flap + 2), Color("3a3a3a"), 2.0)  # wingtips
	_arena.draw_line(at + Vector2(10, -flap), at + Vector2(13, -flap + 2), Color("3a3a3a"), 2.0)


## The otter: a long brown body tilted the way it's swimming, a paler face with whiskers, a
## flat tail, hind feet paddling and a trail of bubbles while it's under.
func _draw_otter(at: Vector2) -> void:
	_paddle += get_process_delta_time() * (9.0 if _velocity > 0.2 else 4.0)
	var tilt := clampf(_velocity * 0.5, -0.5, 0.6)
	var fur := Color("7a5132")
	var dark := Color("5c3b22")
	var pale := Color("d9c3a3")
	_arena.draw_set_transform(at, tilt, Vector2.ONE)
	var kick := sin(_paddle) * 5.0
	_arena.draw_colored_polygon(PackedVector2Array([Vector2(-30, -3), Vector2(-46, -6 + kick * 0.4), Vector2(-46, 3 + kick * 0.4), Vector2(-30, 4)]), dark)  # tail
	_arena.draw_colored_polygon(PackedVector2Array([Vector2(-26, 4), Vector2(-34, 10 + kick), Vector2(-28, 12 + kick), Vector2(-22, 6)]), dark)  # hind feet
	_arena.draw_colored_polygon(PackedVector2Array([Vector2(-26, -4), Vector2(-34, -10 - kick), Vector2(-28, -11 - kick), Vector2(-22, -5)]), dark)
	_arena.draw_rect(Rect2(-28, -8, 36, 16), fur)  # body
	_arena.draw_circle(Vector2(-28, 0), 8.0, fur)
	_arena.draw_rect(Rect2(-22, 2, 26, 5), Color("8c6040"))  # belly
	_arena.draw_colored_polygon(PackedVector2Array([Vector2(0, 7), Vector2(6, 13 - kick * 0.5), Vector2(10, 11 - kick * 0.5), Vector2(6, 6)]), dark)  # front paw
	_arena.draw_circle(Vector2(14, -2), 10.0, fur)  # head
	_arena.draw_circle(Vector2(18, 0), 6.5, pale)  # face
	_arena.draw_circle(Vector2(9, -10), 3.0, dark)  # ear
	_arena.draw_circle(Vector2(18, -4), 1.8, Color.BLACK)  # eye
	_arena.draw_circle(Vector2(24, 0), 2.0, Color("2a1d14"))  # nose
	for i in 3:  # whiskers
		_arena.draw_line(Vector2(22, 2), Vector2(32, -2 + i * 3), Color(1, 1, 1, 0.8), 1.0)
	_arena.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _y > SURFACE + 0.03:  # bubbles rising behind it
		for i in 4:
			var rise := fmod(_paddle * 6.0 + i * 13.0, 50.0)
			_arena.draw_arc(at + Vector2(-20.0 - i * 6.0, -rise), 2.0 + i * 0.5, 0.0, TAU, 10, Color(1, 1, 1, 0.6), 1.0)


static func get_theme_default_font() -> Font:
	return ThemeDB.fallback_font
