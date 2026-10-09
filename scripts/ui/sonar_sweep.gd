class_name SonarSweep
extends ActivityScreen
## Sonar Sweep (Maya, at the Marine Search & Rescue Station): sweep a stretch of coast with the
## rescue boat's sonar. The sea is seen from above, by the shore: waves move over it, fish
## shadows swim under it and gulls fly over. Tap the sea to ping it: the boat goes there, a ring
## spreads out, and the sea floor shows with a number: how many hidden things lie next to it
## (like Minesweeper, but nothing goes wrong). Each ping adds a second; when you're sure, Mark a
## square to find what's there for free (a buoy; a wrong mark adds a few seconds and shows
## "nothing here"). Find everything. The story play finds the wreck; after that it's for fun
## and personal bests.

const WRECK := preload("res://assets/effects/wreck/wreck.svg")
const LITTER := ["res://data/items/ghost_net.tres", "res://data/items/plastic_bottle.tres", "res://data/items/fishing_line.tres"]
const SEA := Color("1d5e86")
const SEA_DEEP := Color("174c6e")
const FLOOR := Color("d9c49a")
const FLOOR_DARK := Color("c4ad84")
const NUMBER_COLOURS: Array[Color] = [Color.WHITE, Color("2f7fd0"), Color("2f9a4a"), Color("d04a3a"), Color("7a3ab0"), Color("b0702a"), Color("2a8a8a"), Color("4a4a4a"), Color("1a1a1a")]

var _cols := 0
var _rows := 0
## Cell -> what's hidden there (a texture).
var _things := {}
var _shown := {}
var _found := 0
var _marking := false
var _arena: Control
var _ping_button: Button
var _mark_button: Button
var _time := 0.0
## Sonar rings spreading out: {"cell", "age"}; "nothing here" notes: {"cell", "age"}.
var _rings: Array[Dictionary] = []
var _misses: Array[Dictionary] = []
## Sparkles where something was found: {"pos", "vel", "life"}.
var _sparks: Array[Dictionary] = []
var _boat := Vector2(-0.6, 0.0)
var _boat_to := Vector2(-0.6, 0.0)
var _fish: Array[Dictionary] = []


func _enter_tree() -> void:
	add_to_group("activity_sonar_sweep")


func _how_to_play() -> String:
	return "Tap the sea to ping it: the number is how many things are hidden in the squares around it. Each ping adds %d s. Sure where something is? Switch to Mark and tap it (a wrong mark adds %d s)." % [
		roundi(activity.ping_seconds), roundi(activity.miss_seconds)]


func _start_board(config: Vector3i) -> void:
	_cols = config.x
	_rows = config.y
	_things.clear()
	_shown.clear()
	_rings.clear()
	_misses.clear()
	_sparks.clear()
	_found = 0
	_marking = false
	_time = 0.0
	_boat = Vector2(-0.6, _rows / 2.0)
	_boat_to = _boat
	var cells: Array[Vector2i] = []
	for x in _cols:
		for y in _rows:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	var story := not Activities.story_done(activity)
	for i in mini(config.z, cells.size()):
		_things[cells[i]] = WRECK if (story and i == 0) or (not story and i % 4 == 0) else (DataFiles.res(LITTER[i % LITTER.size()]) as ItemData).icon
	_fish.clear()
	for i in 4:
		_fish.append({"pos": Vector2(randf() * _cols, randf() * _rows), "speed": randf_range(0.3, 0.7) * (1.0 if randf() < 0.5 else -1.0)})
	_arena = Control.new()
	_arena.name = "Arena"
	_arena.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena.clip_contents = true
	_arena.gui_input.connect(_on_input)
	_arena.draw.connect(_draw_arena)
	_board.add_child(_arena)
	_ping_button = _add_button("Ping", set_marking.bind(false), "Ping")
	_mark_button = _add_button("Mark", set_marking.bind(true), "Mark")
	set_marking(false)


func set_marking(marking: bool) -> void:
	_marking = marking
	_ping_button.modulate = Color.WHITE if not marking else Color(1, 1, 1, 0.55)
	_mark_button.modulate = Color.WHITE if marking else Color(1, 1, 1, 0.55)


## The size of a square and where the sea starts (a strip of shore on the left).
func _layout() -> Array:
	var size := _arena.size if _arena else Vector2(800, 400)
	var cell := floorf(minf((size.x - 80.0) / _cols, size.y / _rows))
	var width := cell * _cols
	var origin := Vector2((size.x - width) / 2.0 + 30.0, (size.y - cell * _rows) / 2.0)
	return [cell, origin]


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var layout := _layout()
		var at: Vector2 = (event.position - layout[1]) / float(layout[0])
		var cell := Vector2i(floori(at.x), floori(at.y))
		if cell.x >= 0 and cell.y >= 0 and cell.x < _cols and cell.y < _rows:
			tap(cell)


## A tap on a square: ping it (or mark it, in Mark mode).
func tap(cell: Vector2i) -> void:
	if not _playing or _shown.has(cell):
		return
	_boat_to = Vector2(cell) + Vector2(0.5, 0.5)
	if _marking and not _things.has(cell):
		seconds += activity.miss_seconds  # nothing there: it costs a little time, that's all
		_misses.append({"cell": cell, "age": 0.0})
		Sound.play(&"not_yet", -4.0)
		return
	elif not _marking:
		seconds += activity.ping_seconds
		_rings.append({"cell": cell, "age": 0.0})
		Sound.play(&"ping", -6.0)
	if _things.has(cell):
		_find(cell)
	else:
		_reveal(cell)
	if _found == _things.size():
		Sound.play(&"sparkle", -2.0, 0.0)
		_complete()


## How many hidden things are in the squares around `cell`.
func around(cell: Vector2i) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx != 0 or dy != 0) and _things.has(cell + Vector2i(dx, dy)):
				count += 1
	return count


func hidden_cells() -> Array:
	return _things.keys()


func _reveal(cell: Vector2i) -> void:
	if _shown.has(cell) or cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows or _things.has(cell):
		return
	_shown[cell] = true
	if around(cell) == 0:  # open water all round: the sonar sweeps on by itself
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_reveal(cell + Vector2i(dx, dy))


func _find(cell: Vector2i) -> void:
	_shown[cell] = true
	_found += 1
	Sound.play(&"pickup")
	for i in 10:
		_sparks.append({"pos": Vector2(cell) + Vector2(0.5, 0.5), "vel": Vector2.from_angle(randf() * TAU) * randf_range(0.6, 1.6), "life": randf_range(0.5, 1.0)})


func _process(delta: float) -> void:
	super(delta)
	if not _arena or not visible:
		return
	_time += delta
	_boat = _boat.lerp(_boat_to, minf(delta * 3.0, 1.0))
	for ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return r.age < 1.2)
	for miss in _misses:
		miss.age += delta
	_misses = _misses.filter(func(m: Dictionary) -> bool: return m.age < 1.0)
	for spark in _sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	for fish in _fish:
		fish.pos.x = fposmod(fish.pos.x + fish.speed * delta, _cols + 2.0)
	_arena.queue_redraw()


func _draw_arena() -> void:
	var layout := _layout()
	var cell: float = layout[0]
	var origin: Vector2 = layout[1]
	var sea := Rect2(origin, Vector2(_cols, _rows) * cell)
	# The shore on the left: grass, then sand, then the waterline.
	_arena.draw_rect(Rect2(Vector2(origin.x - 70.0, origin.y), Vector2(70, sea.size.y)), Color("7aa65a"))
	_arena.draw_rect(Rect2(Vector2(origin.x - 34.0, origin.y), Vector2(34, sea.size.y)), Color("e8d6a6"))
	for i in int(sea.size.y / 30.0):  # a palm or two on the grass
		if i % 3 == 0:
			var p := Vector2(origin.x - 52.0, origin.y + 18.0 + i * 30.0)
			_arena.draw_line(p, p + Vector2(4, -14), Color("8a5a2a"), 3.0)
			for a in 5:
				_arena.draw_line(p + Vector2(4, -14), p + Vector2(4, -14) + Vector2.from_angle(-PI + a * PI / 4.0) * 9.0, Color("3f8a3a"), 3.0)
	_arena.draw_rect(sea, SEA)
	for y in _rows:
		for x in _cols:
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			if _shown.has(c):
				_draw_floor(r, c)
			else:
				_arena.draw_rect(r.grow(-1.0), SEA if (x + y) % 2 == 0 else SEA_DEEP)
				var wave := sin(_time * 2.0 + x * 0.9 + y * 1.3)
				_arena.draw_arc(r.get_center() + Vector2(wave * cell * 0.15, -cell * 0.1), cell * 0.18, PI * 1.1, PI * 1.9, 6, Color(1, 1, 1, 0.25), 2.0)
	for fish in _fish:  # fish shadows under the water
		var at: Vector2 = origin + (fish.pos - Vector2(1, 0)) * cell
		if sea.has_point(at) and not _shown.has(Vector2i(floori(fish.pos.x - 1.0), floori(fish.pos.y))):
			var dir := 1.0 if fish.speed > 0.0 else -1.0
			_arena.draw_colored_polygon(PackedVector2Array([at + Vector2(-10 * dir, 0), at + Vector2(6 * dir, -5), at + Vector2(12 * dir, 0), at + Vector2(6 * dir, 5)]), Color(0, 0.1, 0.2, 0.35))
			_arena.draw_colored_polygon(PackedVector2Array([at + Vector2(-10 * dir, 0), at + Vector2(-16 * dir, -5), at + Vector2(-16 * dir, 5)]), Color(0, 0.1, 0.2, 0.35))
	for ring in _rings:  # the sonar's pings
		var at: Vector2 = origin + (Vector2(ring.cell) + Vector2(0.5, 0.5)) * cell
		var t: float = ring.age / 1.2
		_arena.draw_arc(at, cell * (0.3 + t * 2.5), 0.0, TAU, 32, Color(0.6, 0.9, 1.0, 0.8 * (1.0 - t)), 3.0)
	for miss in _misses:
		var at: Vector2 = origin + (Vector2(miss.cell) + Vector2(0.5, 0.5)) * cell
		var shake: float = sin(miss.age * 40.0) * 4.0 * (1.0 - miss.age)
		_arena.draw_line(at + Vector2(-10 + shake, -10), at + Vector2(10 + shake, 10), Color("ff8a7a"), 4.0)
		_arena.draw_line(at + Vector2(10 + shake, -10), at + Vector2(-10 + shake, 10), Color("ff8a7a"), 4.0)
		_arena.draw_string(ThemeDB.fallback_font, at + Vector2(-40, cell * 0.5), "nothing here", HORIZONTAL_ALIGNMENT_CENTER, 80, 12, Color("ffd2c8"))
	for spark in _sparks:
		var at: Vector2 = origin + spark.pos * cell
		_arena.draw_circle(at, 3.0, Color(1.0, 0.95, 0.6, spark.life))
	# The rescue boat, gliding to the last square pinged.
	var boat := origin + _boat * cell
	_arena.draw_colored_polygon(PackedVector2Array([boat + Vector2(-14, -6), boat + Vector2(12, -6), boat + Vector2(18, 0), boat + Vector2(12, 6), boat + Vector2(-14, 6)]), Color("f4f4f4"))
	_arena.draw_rect(Rect2(boat + Vector2(-8, -4), Vector2(10, 8)), Color("e05a3a"))
	_arena.draw_arc(boat + Vector2(-16, 0), 6.0, PI * 0.6, PI * 1.4, 6, Color(1, 1, 1, 0.6), 2.0)  # its wake
	for i in 2:  # gulls over the sea
		var g := Vector2(fposmod(_time * 30.0 + i * 260.0, sea.size.x + 80.0) - 40.0, 14.0 + i * 22.0) + Vector2(origin.x, origin.y)
		var flap := sin(_time * 7.0 + i) * 5.0
		_arena.draw_line(g + Vector2(-9, -flap), g, Color.WHITE, 2.0)
		_arena.draw_line(g, g + Vector2(9, -flap), Color.WHITE, 2.0)
	var mode := "Mark: tap where you're sure something is" if _marking else "Ping: tap the sea"
	_arena.draw_string(ThemeDB.fallback_font, Vector2(16, 22), "Found %d / %d     %s" % [_found, _things.size(), mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


## A square the sonar has seen: sandy sea floor with a shell or two, and its number (or what
## was found there, on a buoy).
func _draw_floor(r: Rect2, c: Vector2i) -> void:
	_arena.draw_rect(r.grow(-1.0), FLOOR if (c.x + c.y) % 2 == 0 else FLOOR_DARK)
	if (c.x * 7 + c.y * 3) % 5 == 0:
		_arena.draw_circle(r.position + r.size * Vector2(0.25, 0.75), r.size.x * 0.06, Color("f2e2c2"))
	if _things.has(c):
		_arena.draw_texture_rect(_things[c], r.grow(-r.size.x * 0.12), false)
		var buoy := r.position + Vector2(r.size.x * 0.82, r.size.y * 0.2)
		_arena.draw_circle(buoy, r.size.x * 0.09, Color("e05a3a"))
		_arena.draw_line(buoy, buoy + Vector2(0, -r.size.y * 0.16), Color("4a4a4a"), 2.0)
		return
	var count := around(c)
	if count > 0:
		var colour: Color = NUMBER_COLOURS[mini(count, NUMBER_COLOURS.size() - 1)]
		_arena.draw_circle(r.get_center(), r.size.x * 0.28, Color(1, 1, 1, 0.65))
		_arena.draw_string(ThemeDB.fallback_font, r.get_center() + Vector2(-r.size.x * 0.5, r.size.y * 0.17), str(count), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.46), colour)
