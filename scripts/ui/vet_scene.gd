class_name VetScene
extends Control
## The rescue companion in the vet room (RescueScreen): on a towel on the counter, or in a fish
## tank for water animals (RescueData.tank). It breathes, blinks, and grows a little every day
## (Rescues.growth). Egg-layers start as an egg that hatches once it's named
## (RescueData.from_egg). Care is done with your hands, not buttons: drag the food to its mouth
## (or shake it over the tank: RescueData.sprinkle), stroke it or put something comforting by it
## (RescueData.comfort_kind / comfort_tool), drag the plaster onto its wound and the dropper to
## its mouth. Each one done calls `cared` with the action (the screen then does Rescues.care).

signal cared(action: StringName)
## Something was tried in the wrong place: what to do instead.
signal hint(text: String)

## Stroking this far over it (pixels) comforts it.
const STROKE_DISTANCE := 650.0
## Shaking food over the tank this long feeds it.
const SPRINKLE_SECONDS := 1.2
const HATCH_SECONDS := 3.0
const TOOLS: Array[StringName] = [&"feed", &"comfort", &"patch", &"medicine"]
const WALL := Color("dfeef0")
const WALL_TILE := Color("cfe2e6")
const COUNTER := Color("9a6a42")
const COUNTER_EDGE := Color("6e4a2c")

var rescue: RescueData
var _time := 0.0
var _blink := 2.0
## The tool being dragged ("" = none), where it is, and how far it's been stroked or shaken.
var _dragging: StringName = &""
var _at := Vector2.ZERO
var _stroked := 0.0
var _shaken := 0.0
var _last := Vector2.ZERO
var _crumbs: Array[Dictionary] = []
var _hearts: Array[Dictionary] = []
var _hatching := -1.0
## The colour just above each eye (its eyelid when it blinks).
var _lids: Array[Color] = []


func _ready() -> void:
	name = "VetScene"
	custom_minimum_size = Vector2(620, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if rescue and rescue.vet_picture:
		var image := rescue.vet_picture.get_image()
		for eye in rescue.eyes:  # the skin colour above each eye, for its eyelid
			var at := Vector2i((Vector2(image.get_size()) * (eye - Vector2(0, 0.07))).clamp(Vector2.ZERO, Vector2(image.get_size() - Vector2i.ONE))) if image else Vector2i.ZERO
			_lids.append(image.get_pixelv(at) if image else Color.WHITE)


func _process(delta: float) -> void:
	_time += delta
	_blink -= delta
	if _blink < -0.14:
		_blink = randf_range(2.0, 4.5)
	if rescue and rescue.from_egg and Rescues.is_named() and not Rescues.hatched():
		if _hatching < 0.0:
			_hatching = 0.0
		_hatching += delta
		if _hatching >= HATCH_SECONDS:
			Rescues.hatch()
			_burst(_animal_rect().get_center(), 10)
			Sound.play(&"hatch")
			cared.emit(&"")  # (the screen refreshes: it's out!)
	for crumb in _crumbs:
		crumb.vel.y += 160.0 * delta
		crumb.pos += crumb.vel * delta
		crumb.life -= delta
	_crumbs = _crumbs.filter(func(c: Dictionary) -> bool: return c.life > 0.0)
	for heart in _hearts:
		heart.pos.y -= 40.0 * delta
		heart.life -= delta
	_hearts = _hearts.filter(func(h: Dictionary) -> bool: return h.life > 0.0)
	if _dragging == &"feed" and rescue and rescue.sprinkle and _over_tank_top(_at):
		_shaken += delta
		if randf() < 0.5:
			_crumbs.append({"pos": _at + Vector2(randf_range(-8, 8), 10), "vel": Vector2(randf_range(-10, 10), 20), "life": 1.4})
		if _shaken >= SPRINKLE_SECONDS:
			_done(&"feed")
	queue_redraw()


# ------------------------------------------------------------------ where things are

func _counter_top() -> float:
	return size.y * 0.62


## The tank (water animals), standing on the counter.
func _tank_rect() -> Rect2:
	var w := minf(size.x * 0.5, 340.0)
	var h := size.y * 0.5
	return Rect2(Vector2((size.x - w) / 2.0, _counter_top() - h + 10.0), Vector2(w, h))


## Its picture's place: smaller at first, bigger every day; in the tank's water for water animals.
func _animal_rect() -> Rect2:
	var grown := lerpf(0.55, 1.0, Rescues.growth())
	var full := minf(size.y * 0.5, 190.0) * grown
	var breathe := 1.0 + sin(_time * 2.2) * 0.025
	var middle := Vector2(size.x / 2.0, _counter_top() - full * 0.42)
	if rescue and rescue.tank:
		var tank := _tank_rect()
		middle = tank.get_center() + Vector2(sin(_time * 0.8) * 18.0, sin(_time * 1.3) * 6.0 + 8.0)
		full = minf(full, tank.size.y * 0.75)
	var size_now := Vector2(full, full * breathe)
	return Rect2(middle - size_now / 2.0, size_now)


func _point(fraction: Vector2) -> Vector2:
	var r := _animal_rect()
	return r.position + r.size * fraction


func _tool_slot(i: int) -> Vector2:
	var y := _counter_top() + (size.y - _counter_top()) * 0.55
	return Vector2(size.x * (0.12 + 0.11 * i) if i < 2 else size.x * (0.66 + 0.11 * (i - 2)), y)


func _over_tank_top(at: Vector2) -> bool:
	var tank := _tank_rect()
	return at.x > tank.position.x and at.x < tank.end.x and at.y < tank.position.y + 30.0 and at.y > tank.position.y - 80.0


# ------------------------------------------------------------------ hands-on care

func _gui_input(event: InputEvent) -> void:
	if not rescue:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in TOOLS.size():
				if event.position.distance_to(_tool_slot(i)) < 34.0 and Rescues.can_do(TOOLS[i]):
					_dragging = TOOLS[i]
					_at = event.position
					_last = event.position
					_stroked = 0.0
					_shaken = 0.0
					accept_event()
					return
		elif _dragging != &"":
			_drop(event.position)
			_dragging = &""
			accept_event()
	elif event is InputEventMouseMotion and _dragging != &"":
		_at = event.position
		if _dragging == &"comfort" and rescue.comfort_kind == &"stroke" and _animal_rect().grow(10.0).has_point(_at):
			_stroked += _at.distance_to(_last)
			if randf() < 0.08:
				_burst(_at, 1)
			if _stroked >= STROKE_DISTANCE:
				_done(&"comfort")
				_dragging = &""
		_last = _at
		accept_event()


## Let go of a tool at `at`: did it reach the right place?
func _drop(at: Vector2) -> void:
	match _dragging:
		&"feed":
			if rescue.sprinkle:
				hint.emit("Hold the food over the top of the tank and shake it in.")
			elif at.distance_to(_point(rescue.mouth)) < 46.0:
				_done(&"feed")
			else:
				hint.emit("Bring the food right to its mouth.")
		&"medicine":
			if at.distance_to(_point(rescue.mouth)) < 46.0 or (rescue.tank and _tank_rect().has_point(at)):
				_done(&"medicine")
			else:
				hint.emit("Bring the dropper to its mouth." if not rescue.tank else "Drip the medicine into the tank.")
		&"patch":
			if at.distance_to(_point(rescue.wound_at)) < 46.0:
				_done(&"patch")
			else:
				hint.emit("Put the plaster on the sore spot (the red mark).")
		&"comfort":
			if rescue.comfort_kind == &"place":
				var target := _tank_rect() if rescue.tank else _animal_rect().grow(40.0)
				if target.has_point(at):
					_done(&"comfort")
				else:
					hint.emit("Put it right by %s." % Rescues.pet_name())
			else:
				hint.emit("Stroke it gently, back and forth, a little longer.")


func _done(action: StringName) -> void:
	_dragging = &""
	_burst(_animal_rect().get_center() + Vector2(0, -_animal_rect().size.y * 0.3), 6)
	cared.emit(action)


func _burst(at: Vector2, count: int) -> void:
	for i in count:
		_hearts.append({"pos": at + Vector2(randf_range(-30, 30), randf_range(-10, 10)), "life": randf_range(0.8, 1.4)})


## Does `action` the way it's done by hand (tests, and keyboard / controller users).
func do_care(action: StringName) -> void:
	if Rescues.can_do(action):
		_done(action)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if not rescue:
		return
	# The vet room: a tiled wall, a window with the sea, a shelf, the counter.
	draw_rect(Rect2(Vector2.ZERO, size), WALL)
	for x in range(0, int(size.x), 40):
		for y in range(0, int(_counter_top()), 40):
			if (x / 40 + y / 40) % 2 == 0:
				draw_rect(Rect2(x, y, 40, 40), WALL_TILE)
	var window := Rect2(size.x * 0.72, size.y * 0.06, size.x * 0.22, size.y * 0.26)
	draw_rect(window, Color("8fd3ff"))
	draw_rect(Rect2(window.position + Vector2(0, window.size.y * 0.55), Vector2(window.size.x, window.size.y * 0.45)), Color("2f8fb8"))
	draw_rect(window, Color("ffffff"), false, 5.0)
	draw_line(window.position + Vector2(window.size.x / 2.0, 0), window.position + Vector2(window.size.x / 2.0, window.size.y), Color.WHITE, 3.0)
	draw_rect(Rect2(size.x * 0.05, size.y * 0.2, size.x * 0.2, 8), COUNTER_EDGE)  # a shelf, with jars
	for i in 3:
		draw_rect(Rect2(size.x * 0.06 + i * 26, size.y * 0.2 - 24, 18, 24), [Color("b3e5c7"), Color("f5d48a"), Color("c8b6e8")][i])
	draw_rect(Rect2(0, _counter_top(), size.x, size.y - _counter_top()), COUNTER)
	draw_rect(Rect2(0, _counter_top(), size.x, 8), COUNTER_EDGE)
	for i in 6:
		draw_line(Vector2(0, _counter_top() + 30 + i * 22), Vector2(size.x, _counter_top() + 30 + i * 22), COUNTER_EDGE.lerp(COUNTER, 0.6), 1.0)
	if rescue.tank:
		_draw_tank()
	else:
		var mat := Rect2(Vector2(size.x * 0.3, _counter_top() - 14.0), Vector2(size.x * 0.4, 26))
		draw_rect(mat, Color("7fc8d8"))  # a soft towel
		for i in 6:
			draw_line(mat.position + Vector2(i * mat.size.x / 6.0, 0), mat.position + Vector2(i * mat.size.x / 6.0, mat.size.y), Color("a8dce6"), 3.0)
	if rescue.from_egg and not Rescues.hatched():
		_draw_egg()
	else:
		_draw_animal()
	if _comforted_today() and rescue.comfort_kind == &"place":
		_draw_tool(rescue.comfort_tool, _comfort_spot(), 1.0, true)
	if rescue.tank:
		_draw_tank_glass()
	for crumb in _crumbs:
		draw_circle(crumb.pos, 2.5, Color("f2a65a"))
	# The tray of things to care for it with.
	for i in TOOLS.size():
		var action := TOOLS[i]
		var at := _tool_slot(i)
		var can := Rescues.can_do(action)
		draw_circle(at, 32.0, Color(1, 1, 1, 0.25 if can else 0.1))
		if _dragging != action:
			_draw_tool(_tool_kind(action), at, 1.0 if can else 0.35)
		if not can and Rescues.hatched() and Rescues.is_named():
			draw_line(at + Vector2(14, 12), at + Vector2(20, 18), Color("7fe0a0"), 4.0)  # done: a tick
			draw_line(at + Vector2(20, 18), at + Vector2(30, 4), Color("7fe0a0"), 4.0)
		var label: String = ["Food", "Comfort", "Plaster", "Medicine"][i]
		draw_string(ThemeDB.fallback_font, at + Vector2(-34, 46), label, HORIZONTAL_ALIGNMENT_CENTER, 68, 13, Color(1, 1, 1, 0.9 if can else 0.5))
	if _dragging != &"":
		_draw_tool(_tool_kind(_dragging), _at, 1.0)
	for heart in _hearts:
		ActivityScreen.draw_heart(self, heart.pos)


func _comforted_today() -> bool:
	return Rescues.hatched() and Rescues.is_named() and not Rescues.can_do(&"comfort") and not Rescues.is_ready()


func _comfort_spot() -> Vector2:
	if rescue.tank:
		var tank := _tank_rect()
		return Vector2(tank.end.x - 40.0, tank.end.y - 50.0) if rescue.comfort_tool == &"twig" else Vector2(tank.get_center().x, tank.position.y + 8.0)
	return _animal_rect().position + Vector2(-10, _animal_rect().size.y * 0.8)


func _tool_kind(action: StringName) -> StringName:
	match action:
		&"feed":
			return StringName("food_" + String(rescue.food_kind)) if not rescue.sprinkle else &"shaker"
		&"comfort":
			return rescue.comfort_tool
		&"patch":
			return &"plaster"
	return &"dropper"


func _draw_animal() -> void:
	var r := _animal_rect()
	var texture := rescue.vet_picture if rescue.vet_picture else rescue.species.sprite
	if not rescue.tank:  # its shadow on the towel
		draw_set_transform(Vector2(r.get_center().x, _counter_top() - 6.0), 0.0, Vector2(1.0, 0.18))
		draw_circle(Vector2.ZERO, r.size.x * 0.36, Color(0, 0, 0, 0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(texture, r, false)
	if _blink < 0.0:  # blinking
		for i in rescue.eyes.size():
			var at := r.position + r.size * rescue.eyes[i]
			draw_rect(Rect2(at - Vector2(r.size.x * 0.06, r.size.y * 0.045), Vector2(r.size.x * 0.12, r.size.y * 0.09)), _lids[i] if i < _lids.size() else Color.WHITE)
			draw_line(at + Vector2(-r.size.x * 0.05, 0), at + Vector2(r.size.x * 0.05, 0), Color("2a1d14"), 2.0)
	if Rescues.wounds_left() > 0 and not Rescues.is_ready():  # the sore spot
		var w := r.position + r.size * rescue.wound_at
		draw_circle(w, 7.0, Color(0.85, 0.2, 0.2, 0.75))
		draw_circle(w, 11.0, Color(0.85, 0.2, 0.2, 0.25))
	elif Rescues.is_named() and rescue.wounds > 0:  # patched: a plaster
		_draw_tool(&"plaster", r.position + r.size * rescue.wound_at, 0.7)


## The egg on the towel: it rocks, cracks, and the young one pushes out.
func _draw_egg() -> void:
	var middle := Vector2(size.x / 2.0, _counter_top() - 48.0)
	var t := clampf(_hatching / HATCH_SECONDS, 0.0, 1.0) if _hatching >= 0.0 else 0.0
	var rock := sin(_time * (3.0 + t * 14.0)) * (0.05 + t * 0.25)
	draw_set_transform(middle, rock, Vector2.ONE)
	var egg := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		egg.append(Vector2(cos(a) * 34.0, sin(a) * (44.0 if sin(a) < 0.0 else 38.0)))
	draw_colored_polygon(egg, rescue.egg_colour)
	draw_polyline(egg + PackedVector2Array([egg[0]]), rescue.egg_colour.darkened(0.3), 2.0)
	for i in 5:  # speckles
		draw_circle(Vector2(-18 + i * 9, -10 + (i % 2) * 14), 2.0, rescue.egg_colour.darkened(0.2))
	if t > 0.3:  # cracks
		draw_polyline(PackedVector2Array([Vector2(-20, -8), Vector2(-10, -16), Vector2(0, -6), Vector2(10, -18), Vector2(22, -8)]), Color("5a4a3a"), 2.0)
	if t > 0.65:
		draw_polyline(PackedVector2Array([Vector2(-6, -16), Vector2(-2, -28), Vector2(4, -20)]), Color("5a4a3a"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _hatching < 0.0:
		draw_string(ThemeDB.fallback_font, middle + Vector2(-120, 70), "Something is moving inside...", HORIZONTAL_ALIGNMENT_CENTER, 240, 15, Color("5a4a3a"))


func _draw_tank() -> void:
	var tank := _tank_rect()
	draw_rect(Rect2(tank.position + Vector2(0, 16), tank.size - Vector2(0, 16)), Color("2a8ab8").lerp(Color("0b3a5a"), 0.3 if rescue.comfort_tool != &"cloth" else 0.6))
	for i in 8:  # light in the water
		var x := tank.position.x + fposmod(i * 47.0 + _time * 12.0, tank.size.x)
		draw_line(Vector2(x, tank.position.y + 16), Vector2(x + 20, tank.end.y - 20), Color(1, 1, 1, 0.05), 6.0)
	draw_rect(Rect2(Vector2(tank.position.x, tank.end.y - 24), Vector2(tank.size.x, 24)), Color("d9c49a"))  # sand
	for i in 14:
		draw_circle(Vector2(tank.position.x + 10 + i * tank.size.x / 14.0, tank.end.y - 10 - (i % 3) * 4), 3.0 + i % 2, Color("b8a07a"))
	for i in 3:  # seagrass / rocks
		var base := Vector2(tank.position.x + 30 + i * tank.size.x * 0.32, tank.end.y - 20)
		if rescue.comfort_tool == &"twig":
			for j in 3:
				var points := PackedVector2Array()
				for k in 6:
					points.append(base + Vector2(j * 6 + sin(_time * 1.5 + k * 0.7 + j) * k * 1.6, -k * 14))
				draw_polyline(points, Color("4f9a4a"), 4.0)
		else:
			draw_circle(base + Vector2(0, 4), 16.0, Color("6e6a62"))
	for i in 6:  # bubbles
		var rise := fposmod(_time * 30.0 + i * 37.0, tank.size.y - 30.0)
		draw_arc(Vector2(tank.end.x - 30 + sin(_time + i) * 4.0, tank.end.y - 24 - rise), 3.0, 0.0, TAU, 10, Color(1, 1, 1, 0.7), 1.5)


func _draw_tank_glass() -> void:
	var tank := _tank_rect()
	draw_rect(Rect2(tank.position + Vector2(0, 14), Vector2(tank.size.x, 4)), Color(1, 1, 1, 0.6))  # the water's surface
	draw_rect(tank, Color(0.85, 0.95, 1.0, 0.9), false, 4.0)
	draw_line(tank.position + Vector2(14, 24), tank.position + Vector2(14, tank.size.y - 40), Color(1, 1, 1, 0.35), 5.0)
	draw_rect(Rect2(tank.position - Vector2(6, 8), Vector2(tank.size.x + 12, 10)), Color("4a5a66"))  # the lid's rim
	draw_rect(Rect2(Vector2(tank.position.x - 8, tank.end.y - 2), Vector2(tank.size.x + 16, 10)), Color("4a5a66"))  # its stand


## The things on the tray, drawn simply: food of each kind, a brush, a feather duster, a cloth,
## a twig, ice, a plaster, a dropper, a food shaker.
func _draw_tool(kind: StringName, at: Vector2, alpha: float, placed := false) -> void:
	var c := func(hex: String) -> Color:
		var colour := Color(hex)
		colour.a = alpha
		return colour
	match kind:
		&"food_shrimp":
			for i in 3:
				var p := at + Vector2(-12 + i * 12, (i % 2) * 6)
				draw_arc(p, 7.0, -0.5, PI + 0.5, 10, c.call("f28a6a"), 5.0)
		&"food_fish":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-16, 0), at + Vector2(6, -8), at + Vector2(14, 0), at + Vector2(6, 8)]), c.call("9fb8c8"))
			draw_colored_polygon(PackedVector2Array([at + Vector2(-16, 0), at + Vector2(-24, -8), at + Vector2(-24, 8)]), c.call("8aa4b4"))
			draw_circle(at + Vector2(8, -2), 1.5, c.call("1a1a1a"))
		&"food_squid":
			draw_rect(Rect2(at - Vector2(12, 8), Vector2(24, 10)), c.call("f0d8e0"))
			for i in 4:
				draw_line(at + Vector2(-9 + i * 6, 2), at + Vector2(-10 + i * 6, 14), c.call("e8c0d0"), 2.0)
		&"food_clam":
			draw_arc(at + Vector2(0, 4), 14.0, PI, TAU, 12, c.call("d8c8a8"), 8.0)
			draw_line(at + Vector2(-14, 4), at + Vector2(14, 4), c.call("8a7a5a"), 2.0)
		&"food_milk":
			draw_rect(Rect2(at - Vector2(8, 16), Vector2(16, 28)), c.call("f4f4ee"))
			draw_rect(Rect2(at - Vector2(4, 22), Vector2(8, 7)), c.call("f2a6b8"))
		&"food_greens":
			for i in 3:
				draw_line(at + Vector2(-8 + i * 8, 12), at + Vector2(-6 + i * 6, -14), c.call("4f9a4a"), 5.0)
		&"shaker":
			draw_rect(Rect2(at - Vector2(10, 16), Vector2(20, 30)), c.call("f2c94c"))
			draw_rect(Rect2(at - Vector2(10, 20), Vector2(20, 6)), c.call("b8b8b8"))
			for i in 3:
				draw_circle(at + Vector2(-5 + i * 5, -18), 1.2, c.call("4a4a4a"))
		&"brush":
			draw_rect(Rect2(at + Vector2(-20, -4), Vector2(26, 8)), c.call("a0703a"))
			draw_rect(Rect2(at + Vector2(6, -9), Vector2(16, 18)), c.call("6e4a2c"))
			for i in 5:
				draw_line(at + Vector2(8 + i * 3, 9), at + Vector2(8 + i * 3, 15), c.call("e8dcc8"), 1.5)
		&"duster":
			draw_line(at + Vector2(-18, 14), at + Vector2(0, 0), c.call("a0703a"), 4.0)
			for i in 6:
				draw_line(at, at + Vector2.from_angle(-1.2 + i * 0.4) * 20.0, c.call("f2a6b8"), 4.0)
		&"cloth":
			draw_rect(Rect2(at - Vector2(22, 12) if not placed else at - Vector2(_tank_rect().size.x / 2.0 if rescue.tank else 30.0, 10), Vector2(44, 24) if not placed else Vector2(_tank_rect().size.x if rescue.tank else 60.0, 14)), c.call("5a6a9a"))
		&"twig":
			draw_line(at + Vector2(-16, 14), at + Vector2(14, -16), c.call("8a6a3a"), 5.0)
			draw_line(at + Vector2(0, 0), at + Vector2(10, 6), c.call("8a6a3a"), 3.0)
		&"ice":
			draw_rect(Rect2(at - Vector2(12, 10), Vector2(24, 20)), c.call("e6f6ff"))
			draw_rect(Rect2(at - Vector2(12, 10), Vector2(24, 20)), c.call("9fd8f0"), false, 2.0)
		&"plaster":
			draw_set_transform(at, -0.5, Vector2.ONE)
			draw_rect(Rect2(-16, -6, 32, 12), c.call("f2d2b0"))
			draw_rect(Rect2(-5, -6, 10, 12), c.call("e8b890"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		&"dropper":
			draw_rect(Rect2(at - Vector2(4, 10), Vector2(8, 22)), c.call("cfe8f5"))
			draw_circle(at + Vector2(0, -14), 7.0, c.call("e05a5a"))
			draw_line(at + Vector2(0, 12), at + Vector2(0, 18), c.call("cfe8f5"), 2.0)
		_:  # a hand
			draw_circle(at, 12.0, c.call("f2c9a0"))
			for i in 4:
				draw_line(at + Vector2(-9 + i * 6, -8), at + Vector2(-9 + i * 6, -18), c.call("f2c9a0"), 5.0)
