class_name GlassSort
extends ActivityScreen
## Glass Sort (Kai, at the Glassworks): jars of broken glass and sand, all mixed up. Tap a jar,
## then another, to pour its top layer across (only onto the same colour, or into an empty
## jar, and only while there's room). Sort every jar to one colour. Real glass recycling sorts
## glass by colour too: mixed colours melt into murky glass. "Start again" puts the jars back.
## Every board is shuffled from a sorted one, so it can always be solved. The story play makes
## the Glassworks' first batch at once; after that it's for fun. Drawn in the Glassworks: a
## brick wall with the furnace glowing, finished bottles on a shelf; the jars stand on the
## workbench, glass pieces fly across in an arc when poured, a jar that won't take them shakes,
## and a jar sorted to one colour gets its cork and sparkles.

const COLOURS: Array[Color] = [Color("dff4fb"), Color("4caf6a"), Color("b8742a"), Color("3d78d8"), Color("e8c84a"), Color("c45ab0")]
const GLASS := Color(0.85, 0.95, 1.0, 0.35)
const PICKED := Color("f2d58a")

## The jars, each a list of colour indices from the bottom up.
var jars: Array = []
var _start: Array = []
var _depth := 4
var _picked := -1
var _area: Control
var _time := 0.0
## Glass pieces flying from jar to jar: {"from", "to", "t", "colour"}; jars shaking (jar ->
## time left); sparkles {"pos", "vel", "life"}; jars already corked (so they sparkle once).
var _flying: Array[Dictionary] = []
var _shake := {}
var _sparks: Array[Dictionary] = []
var _corked := {}


func _enter_tree() -> void:
	add_to_group("activity_glass_sort")


func _how_to_play() -> String:
	return "Tap a jar, then another, to pour the top layer across: only onto the same colour, or into an empty jar. Sort every jar to one colour."


## (colours, empty jars, layers per jar)
func _start_board(config: Vector3i) -> void:
	_depth = config.z
	_deal(config.x, config.y)
	_picked = -1
	_flying.clear()
	_shake.clear()
	_sparks.clear()
	_cork_sorted()
	_area = Control.new()
	_area.name = "Jars"
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.clip_contents = true
	_area.gui_input.connect(_on_input)
	_area.draw.connect(_draw_jars)
	_board.add_child(_area)
	_add_button("Start again", restart, "Restart")


## A sorted set of jars, then shuffled by pouring backwards (so there's always a way back).
func _deal(colours: int, empty: int) -> void:
	for attempt in 20:
		jars.clear()
		for c in colours:
			var jar: Array[int] = []
			for i in _depth:
				jar.append(c)
			jars.append(jar)
		for i in empty:
			jars.append([] as Array[int])
		for step in colours * _depth * 8:
			var from := randi() % jars.size()
			var to := randi() % jars.size()
			if from == to or jars[from].is_empty() or jars[to].size() >= _depth:
				continue
			var colour: int = jars[from].back()
			var below: Array = jars[from].slice(0, jars[from].size() - 1)
			if not below.is_empty() and below.back() != colour:
				continue  # pouring it back would not be allowed: keep it reversible
			jars[from].pop_back()
			jars[to].append(colour)
		if not solved():
			break
	_start = jars.duplicate(true)


## Jars already sorted to one colour have their cork in.
func _cork_sorted() -> void:
	_corked.clear()
	for i in jars.size():
		var jar: Array = jars[i]
		if jar.size() == _depth and jar.all(func(c: int) -> bool: return c == jar[0]):
			_corked[i] = true


func restart() -> void:
	jars = _start.duplicate(true)
	_picked = -1
	_cork_sorted()
	if _area:
		_area.queue_redraw()


func pick(jar: int) -> void:
	if not _playing:
		return
	if _picked < 0:
		if not jars[jar].is_empty():
			_picked = jar
	elif _picked == jar:
		_picked = -1
	else:
		pour(_picked, jar)
		_picked = -1
	if _area:
		_area.queue_redraw()


## Pours the top layer (all the same colour on top) from `from` into `to`, as much as fits.
## Returns how much went across.
func pour(from: int, to: int) -> int:
	if from == to or jars[from].is_empty() or jars[to].size() >= _depth:
		_refuse(to)
		return 0
	var colour: int = jars[from].back()
	if not jars[to].is_empty() and jars[to].back() != colour:
		_refuse(to)
		return 0
	var moved := 0
	while not jars[from].is_empty() and jars[from].back() == colour and jars[to].size() < _depth:
		jars[to].append(jars[from].pop_back())
		moved += 1
	for i in moved * 5:  # the glass pieces flying across
		_flying.append({"from": from, "to": to, "t": -i * 0.03, "colour": colour, "spread": randf_range(-0.3, 0.3)})
	Sound.play(&"pickup", -4.0)
	var jar: Array = jars[to]
	if jar.size() == _depth and jar.all(func(c: int) -> bool: return c == jar[0]) and not _corked.has(to):
		_corked[to] = true  # sorted: corked, with a sparkle
		Sound.play(&"sparkle", -4.0, 0.0)
		for i in 12:
			_sparks.append({"jar": to, "pos": Vector2(0.5, 0.0), "vel": Vector2.from_angle(randf() * TAU) * randf_range(0.5, 1.5), "life": randf_range(0.5, 1.0)})
	if solved():
		_complete()
	return moved


## That won't go: the jar shakes.
func _refuse(jar: int) -> void:
	if jar >= 0 and jar < jars.size():
		_shake[jar] = 0.4
		Sound.play(&"not_yet", -6.0)


func _process(delta: float) -> void:
	super(delta)
	if not _area or not visible:
		return
	_time += delta
	for f in _flying:
		f.t += delta * 2.2
	_flying = _flying.filter(func(f: Dictionary) -> bool: return f.t < 1.0)
	for jar in _shake.keys():
		_shake[jar] = float(_shake[jar]) - delta
		if _shake[jar] <= 0.0:
			_shake.erase(jar)
	for spark in _sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	_area.queue_redraw()


## Every jar empty, or full of one colour.
func solved() -> bool:
	for jar: Array in jars:
		if jar.is_empty():
			continue
		if jar.size() != _depth or jar.any(func(c: int) -> bool: return c != jar[0]):
			return false
	return true


func _layout() -> Dictionary:
	var size := _area.size
	var gap := 14.0
	var width := minf((size.x - gap * (jars.size() + 1)) / jars.size(), 70.0)
	var height := minf(size.y - 90.0, width * (_depth + 0.6))
	var left := (size.x - (width * jars.size() + gap * (jars.size() - 1))) / 2.0
	return {"width": width, "height": height, "left": left, "gap": gap, "top": size.y - height - 40.0}


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var layout := _layout()
	var x: float = event.position.x - layout.left
	var jar := int(x / (layout.width + layout.gap))
	if x >= 0.0 and jar < jars.size():
		pick(jar)


func _draw_jars() -> void:
	if jars.is_empty():
		return
	var size := _area.size
	var layout := _layout()
	# The Glassworks: brick wall, the furnace glowing, finished bottles on a shelf, the bench.
	_area.draw_rect(Rect2(Vector2.ZERO, size), Color("8a4a3a"))
	for row in int(size.y / 18.0) + 1:
		for col in int(size.x / 40.0) + 2:
			var bx := col * 40.0 - (20.0 if row % 2 == 1 else 0.0)
			_area.draw_rect(Rect2(bx + 1.0, row * 18.0 + 1.0, 38.0, 16.0), Color("9a5a44") if (row + col) % 3 else Color("a2624a"))
	var furnace := Rect2(Vector2(size.x - 170.0, 20.0), Vector2(140, 130))
	_area.draw_rect(furnace, Color("4a4a50"))
	var glow := 0.75 + sin(_time * 7.0) * 0.08 + sin(_time * 13.0) * 0.05
	_area.draw_circle(furnace.get_center() + Vector2(0, 20), 34.0, Color(1.0, 0.55, 0.15, glow))
	_area.draw_circle(furnace.get_center() + Vector2(0, 20), 22.0, Color(1.0, 0.85, 0.4, glow))
	_area.draw_rect(Rect2(furnace.position + Vector2(-8, -12), Vector2(furnace.size.x + 16, 14)), Color("3a3a40"))
	_area.draw_rect(Rect2(Vector2(20, 40), Vector2(220, 8)), Color("6e4a2c"))  # the shelf of finished bottles
	for i in 6:
		var bottle := Rect2(Vector2(28 + i * 34, 10), Vector2(18, 30))
		_area.draw_rect(bottle, Color(COLOURS[i % COLOURS.size()], 0.85))
		_area.draw_rect(Rect2(bottle.position + Vector2(5, -6), Vector2(8, 7)), Color(COLOURS[i % COLOURS.size()], 0.85))
		_area.draw_rect(Rect2(bottle.position + Vector2(3, 4), Vector2(3, 18)), Color(1, 1, 1, 0.4))
	var bench_top: float = layout.top + layout.height
	_area.draw_rect(Rect2(Vector2(0, bench_top), Vector2(size.x, size.y - bench_top)), Color("7a5232"))
	_area.draw_rect(Rect2(Vector2(0, bench_top), Vector2(size.x, 6)), Color("5a3a22"))
	var cell: float = (layout.height - 8.0) / _depth
	for i in jars.size():
		var x: float = layout.left + i * (layout.width + layout.gap)
		var lift := -14.0 if i == _picked else 0.0
		var shake := sin(_time * 50.0) * 5.0 * float(_shake.get(i, 0.0)) / 0.4
		var rect := Rect2(x + shake, layout.top + lift, layout.width, layout.height)
		if i == _picked:
			_area.draw_rect(rect.grow(6.0), Color(1.0, 0.85, 0.4, 0.25))
		_area.draw_rect(rect, GLASS)
		for j in jars[i].size():  # layers of broken glass: little pieces in each colour
			var y: float = rect.end.y - 4.0 - (j + 1) * cell
			var colour: Color = COLOURS[jars[i][j] % COLOURS.size()]
			var layer := Rect2(rect.position.x + 4.0, y, layout.width - 8.0, cell - 2.0)
			_area.draw_rect(layer, colour.darkened(0.15))
			for k in 6:
				var px := layer.position.x + fposmod(k * 0.37 + j * 0.21 + i * 0.13, 1.0) * (layer.size.x - 8.0) + 4.0
				var py := layer.position.y + fposmod(k * 0.53 + j * 0.31, 1.0) * (layer.size.y - 6.0) + 3.0
				_area.draw_colored_polygon(PackedVector2Array([Vector2(px - 4, py), Vector2(px, py - 4), Vector2(px + 5, py + 1), Vector2(px + 1, py + 4)]), colour.lightened(0.15))
		_area.draw_rect(Rect2(rect.position + Vector2(5, 8), Vector2(5, rect.size.y - 20.0)), Color(1, 1, 1, 0.35))  # the glass's shine
		_area.draw_rect(rect, PICKED if i == _picked else Color(1, 1, 1, 0.8), false, 3.0 if i == _picked else 2.0)
		if _corked.has(i):  # sorted: a cork in the top
			_area.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.2, -10.0), Vector2(rect.size.x * 0.6, 14.0)), Color("c8a06a"))
			_area.draw_rect(Rect2(rect.position + Vector2(rect.size.x * 0.2, -10.0), Vector2(rect.size.x * 0.6, 4.0)), Color("a8804a"))
	for f in _flying:  # glass pieces arcing across
		if f.t < 0.0:
			continue
		var a := Vector2(layout.left + f.from * (layout.width + layout.gap) + layout.width / 2.0, layout.top)
		var b := Vector2(layout.left + f.to * (layout.width + layout.gap) + layout.width / 2.0, layout.top)
		var t: float = f.t
		var at := a.lerp(b, t) + Vector2(f.spread * 20.0, -sin(t * PI) * 70.0)
		_area.draw_rect(Rect2(at - Vector2(3, 3), Vector2(6, 6)), COLOURS[int(f.colour) % COLOURS.size()])
	for spark in _sparks:
		var base := Vector2(layout.left + spark.jar * (layout.width + layout.gap), layout.top)
		_area.draw_circle(base + spark.pos * Vector2(layout.width, 60.0), 3.0, Color(1.0, 0.95, 0.6, spark.life))
	var sorted := 0
	for jar: Array in jars:
		if jar.size() == _depth and jar.all(func(c: int) -> bool: return c == jar[0]):
			sorted += 1
	_area.draw_string(ThemeDB.fallback_font, Vector2(16, size.y - 12.0), "Jars sorted: %d" % sorted, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
