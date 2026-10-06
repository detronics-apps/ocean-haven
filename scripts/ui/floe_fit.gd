class_name FloeFit
extends ActivityScreen
## Floe Fit (Sanna, at the Polar Research Station): the station's ice map has gaps of open water
## between the old floes. Tap a floe below, then tap where it goes, to fill every gap (a placed
## floe can be tapped to take it back: you can never get stuck). Every board is cut from a real
## way to fill it. The story play is Sanna's drill planning; after that it's for fun.

const OLD_ICE := Color("e9f2f7")
const WATER := Color("1f4f6a")
const FLOE := Color("b9dcf0")
const PICKED := Color("f2d58a")

var _cols := 0
var _rows := 0
## Cells already old ice (not to fill).
var _ice := {}
## Floes to place: Array of Array[Vector2i] (cells relative to their top-left).
var _floes: Array = []
## Placed: floe index -> its top-left cell on the board.
var _placed := {}
## Each floe's place in the way it was cut (for tests).
var _cut_at := {}
var _picked := -1
var _area: Control
var _tile := 40.0


func _enter_tree() -> void:
	add_to_group("activity_floe_fit")


func _how_to_play() -> String:
	return "Tap a floe below, then tap the ice map to put it there. Fill every gap of open water. Tap a placed floe to take it back."


func _start_board(config: Vector3i) -> void:
	_cols = config.x
	_rows = config.y
	_cut(config.z)
	_picked = -1
	_area = Control.new()
	_area.name = "Map"
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.gui_input.connect(_on_input)
	_area.draw.connect(_draw_map)
	_board.add_child(_area)


## Cuts the open water into floes of up to `biggest` cells (that's the way to fill it).
func _cut(biggest: int) -> void:
	_ice.clear()
	_floes.clear()
	_placed.clear()
	_cut_at.clear()
	var water: Array[Vector2i] = []
	for x in _cols:
		for y in _rows:
			if randf() < 0.28:
				_ice[Vector2i(x, y)] = true
			else:
				water.append(Vector2i(x, y))
	var left := {}
	for cell in water:
		left[cell] = true
	water.shuffle()
	for start in water:
		if not left.has(start):
			continue
		var piece: Array[Vector2i] = [start]
		left.erase(start)
		var size := randi_range(mini(2, biggest), biggest)  # (single squares only where nothing else fits)
		while piece.size() < size:
			var options: Array[Vector2i] = []
			for cell in piece:
				for step in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
					if left.has(cell + step) and not options.has(cell + step):
						options.append(cell + step)
			if options.is_empty():
				break
			var next: Vector2i = options[randi() % options.size()]
			piece.append(next)
			left.erase(next)
		var corner := Vector2i(_cols, _rows)
		for cell in piece:
			corner = Vector2i(mini(corner.x, cell.x), mini(corner.y, cell.y))
		var shape: Array[Vector2i] = []
		for cell in piece:
			shape.append(cell - corner)
		_cut_at[_floes.size()] = corner
		_floes.append(shape)
	# Shuffle the tray (the cut positions stay matched).
	var order := range(_floes.size())
	order.shuffle()
	var floes: Array = []
	var cut := {}
	for i in order.size():
		floes.append(_floes[order[i]])
		cut[i] = _cut_at[order[i]]
	_floes = floes
	_cut_at = cut


## Where `floe` was cut from (a way to fill the map).
func cut_at(floe: int) -> Vector2i:
	return _cut_at[floe]


func floe_count() -> int:
	return _floes.size()


func pick(floe: int) -> void:
	if _playing and floe >= 0 and floe < _floes.size() and not _placed.has(floe):
		_picked = floe
		if _area:
			_area.queue_redraw()


## Puts the picked floe with its top-left at `cell`, if it fits there. Returns whether it did.
func place(cell: Vector2i) -> bool:
	if not _playing or _picked < 0 or not _fits(_picked, cell):
		return false
	_placed[_picked] = cell
	_picked = -1
	if _area:
		_area.queue_redraw()
	if filled():
		_complete()
	return true


## Takes the floe covering `cell` back to the tray.
func take_back(cell: Vector2i) -> bool:
	for floe: int in _placed:
		for part: Vector2i in _floes[floe]:
			if _placed[floe] + part == cell:
				_placed.erase(floe)
				if _area:
					_area.queue_redraw()
				return true
	return false


func _covered() -> Dictionary:
	var covered := {}
	for floe: int in _placed:
		for part: Vector2i in _floes[floe]:
			covered[_placed[floe] + part] = floe
	return covered


func _fits(floe: int, at: Vector2i) -> bool:
	var covered := _covered()
	for part: Vector2i in _floes[floe]:
		var cell: Vector2i = at + part
		if cell.x < 0 or cell.y < 0 or cell.x >= _cols or cell.y >= _rows or _ice.has(cell) or covered.has(cell):
			return false
	return true


## Every gap filled.
func filled() -> bool:
	var covered := _covered()
	for x in _cols:
		for y in _rows:
			if not _ice.has(Vector2i(x, y)) and not covered.has(Vector2i(x, y)):
				return false
	return true


func _layout() -> Dictionary:
	var size := _area.size
	var tray_h := size.y * 0.3
	_tile = floorf(minf(size.x * 0.9 / _cols, (size.y - tray_h - 10.0) / _rows))
	var origin := Vector2((size.x - _tile * _cols) / 2.0, 0.0)
	return {"origin": origin, "tray_y": _tile * _rows + 10.0, "tray_h": tray_h}


## The tray's floes waiting to be placed (up to 4 shown), with their slots.
func _tray() -> Array:
	var waiting: Array = []
	for i in _floes.size():
		if not _placed.has(i):
			waiting.append(i)
	return waiting.slice(0, 4)


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var layout := _layout()
	var at: Vector2 = event.position
	if at.y >= layout.tray_y:
		var slot := int(at.x / (_area.size.x / 4.0))
		var tray := _tray()
		if slot < tray.size():
			pick(tray[slot])
		return
	var cell := Vector2i(((at - layout.origin) / _tile).floor())
	if not take_back(cell):
		place(cell)


func _draw_map() -> void:
	if _cols == 0:
		return
	var layout := _layout()
	var covered := _covered()
	for x in _cols:
		for y in _rows:
			var cell := Vector2i(x, y)
			var rect := Rect2(layout.origin + Vector2(cell) * _tile, Vector2.ONE * _tile).grow(-1.0)
			var colour := OLD_ICE if _ice.has(cell) else (FLOE if covered.has(cell) else WATER)
			_area.draw_rect(rect, colour)
	var tray := _tray()
	var slot_w := _area.size.x / 4.0
	var small := minf(_tile * 0.6, layout.tray_h / 5.0)
	for i in tray.size():
		var floe: int = tray[i]
		var base := Vector2(i * slot_w + slot_w * 0.3, layout.tray_y + 10.0)
		for part: Vector2i in _floes[floe]:
			_area.draw_rect(Rect2(base + Vector2(part) * small, Vector2.ONE * small).grow(-1.0), PICKED if floe == _picked else FLOE)
	_area.draw_string(ThemeDB.fallback_font, Vector2(8, layout.tray_y - 14.0), "Floes left: %d" % (_floes.size() - _placed.size()),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
