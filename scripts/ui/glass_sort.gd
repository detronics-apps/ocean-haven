class_name GlassSort
extends ActivityScreen
## Glass Sort (Kai, at the Glassworks): jars of broken glass and sand, all mixed up. Tap a jar,
## then another, to pour its top layer across (only onto the same colour, or into an empty
## jar, and only while there's room). Sort every jar to one colour. Real glass recycling sorts
## glass by colour too: mixed colours melt into murky glass. "Start again" puts the jars back.
## Every board is shuffled from a sorted one, so it can always be solved. The story play makes
## the Glassworks' first batch at once; after that it's for fun.

const COLOURS: Array[Color] = [Color("dff4fb"), Color("4caf6a"), Color("b8742a"), Color("3d78d8"), Color("e8c84a"), Color("c45ab0")]
const GLASS := Color(0.85, 0.95, 1.0, 0.35)
const PICKED := Color("f2d58a")

## The jars, each a list of colour indices from the bottom up.
var jars: Array = []
var _start: Array = []
var _depth := 4
var _picked := -1
var _area: Control


func _enter_tree() -> void:
	add_to_group("activity_glass_sort")


func _how_to_play() -> String:
	return "Tap a jar, then another, to pour the top layer across: only onto the same colour, or into an empty jar. Sort every jar to one colour."


## (colours, empty jars, layers per jar)
func _start_board(config: Vector3i) -> void:
	_depth = config.z
	_deal(config.x, config.y)
	_picked = -1
	_area = Control.new()
	_area.name = "Jars"
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
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


func restart() -> void:
	jars = _start.duplicate(true)
	_picked = -1
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
		return 0
	var colour: int = jars[from].back()
	if not jars[to].is_empty() and jars[to].back() != colour:
		return 0
	var moved := 0
	while not jars[from].is_empty() and jars[from].back() == colour and jars[to].size() < _depth:
		jars[to].append(jars[from].pop_back())
		moved += 1
	if solved():
		_complete()
	return moved


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
	var height := minf(size.y - 20.0, width * (_depth + 0.6))
	var left := (size.x - (width * jars.size() + gap * (jars.size() - 1))) / 2.0
	return {"width": width, "height": height, "left": left, "gap": gap, "top": (size.y - height) / 2.0}


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
	var layout := _layout()
	var cell: float = (layout.height - 8.0) / _depth
	for i in jars.size():
		var x: float = layout.left + i * (layout.width + layout.gap)
		var lift := -14.0 if i == _picked else 0.0
		var rect := Rect2(x, layout.top + lift, layout.width, layout.height)
		_area.draw_rect(rect, GLASS)
		for j in jars[i].size():
			var y: float = rect.end.y - 4.0 - (j + 1) * cell
			_area.draw_rect(Rect2(x + 4.0, y, layout.width - 8.0, cell - 2.0), COLOURS[jars[i][j] % COLOURS.size()])
		_area.draw_rect(rect, PICKED if i == _picked else Color(1, 1, 1, 0.8), false, 3.0 if i == _picked else 2.0)
