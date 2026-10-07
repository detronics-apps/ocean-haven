class_name IceMatch
extends ActivityScreen
## Ice Match (Sanna, at the Polar Research Station; the activity id is still "floe_fit"): a
## match-three on the station's ice map. Tap a piece, then one next to it, to swap them; three
## or more of the same in a row or column clear, the rest fall down and new ones drop in. Clear
## enough blocks of old ice (the white squares) to finish. A swap that makes no row just swaps
## back; the board always has a move (it's reshuffled if not). The story play is Sanna's drill
## planning; after that it's for fun, with best times.

## Pieces: old ice, a snowflake, Arctic cod, krill, a stone, a tern feather.
const KINDS := ["old ice", "snowflake", "cod", "krill", "stone", "feather"]
const COLOURS: Array[Color] = [Color("f4f8fb"), Color("9fd8f0"), Color("8fa6b8"), Color("f08a8a"), Color("8a7a68"), Color("f2d58a")]
const BACK := Color("1f4f6a")
const PICKED := Color("f2d58a")
const OLD_ICE := 0

var cols := 6
var rows := 6
var kinds := 4
## grid[x][y]: the kind of piece (y 0 at the top).
var grid: Array = []
## Old ice cleared so far, and how much is needed.
var cleared := 0
var goal := 10
var _picked := Vector2i(-1, -1)
var _area: Control
var _tile := 48.0


func _enter_tree() -> void:
	add_to_group("activity_floe_fit")


func _how_to_play() -> String:
	return "Tap a piece, then one next to it, to swap them. Three or more of the same in a row clear. Clear %d blocks of old ice (the white squares)." % goal


## (size, kinds of piece, old ice to clear)
func _start_board(config: Vector3i) -> void:
	cols = config.x
	rows = config.x
	kinds = clampi(config.y, 3, KINDS.size())
	goal = config.z
	cleared = 0
	_picked = Vector2i(-1, -1)
	_fill_board()
	_area = Control.new()
	_area.name = "Map"
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.gui_input.connect(_on_input)
	_area.draw.connect(_draw_map)
	_board.add_child(_area)
	_info.text = _how_to_play()


## A board with no rows ready-made, and at least one move.
func _fill_board() -> void:
	for attempt in 50:
		grid.clear()
		for x in cols:
			var column: Array[int] = []
			for y in rows:
				column.append(0)
			grid.append(column)
		for x in cols:
			for y in rows:
				var options: Array[int] = []
				for k in kinds:
					if not _would_match(x, y, k):
						options.append(k)
				grid[x][y] = options.pick_random() if not options.is_empty() else randi() % kinds
		if find_move().size() == 2:
			return


func _would_match(x: int, y: int, k: int) -> bool:
	return (x >= 2 and grid[x - 1][y] == k and grid[x - 2][y] == k) or (y >= 2 and grid[x][y - 1] == k and grid[x][y - 2] == k)


func pick(cell: Vector2i) -> void:
	if not _playing or not _inside(cell):
		return
	if _picked == Vector2i(-1, -1):
		_picked = cell
	elif _picked == cell:
		_picked = Vector2i(-1, -1)
	elif absi(_picked.x - cell.x) + absi(_picked.y - cell.y) == 1:
		swap(_picked, cell)
		_picked = Vector2i(-1, -1)
	else:
		_picked = cell
	if _area:
		_area.queue_redraw()


## Swaps two neighbours; if that makes a row they clear (and whatever falls into place after),
## else they swap back. Returns whether anything cleared.
func swap(a: Vector2i, b: Vector2i) -> bool:
	if not _playing or not _inside(a) or not _inside(b) or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	_exchange(a, b)
	if _matches().is_empty():
		_exchange(a, b)  # no row: back they go
		return false
	while true:
		var found := _matches()
		if found.is_empty():
			break
		for cell: Vector2i in found:
			if grid[cell.x][cell.y] == OLD_ICE:
				cleared += 1
			grid[cell.x][cell.y] = -1
		_fall()
	if cleared >= goal:
		_complete()
	elif find_move().is_empty():
		_fill_board()  # no moves left: a fresh shuffle
	if _area:
		_area.queue_redraw()
	return true


func _exchange(a: Vector2i, b: Vector2i) -> void:
	var kept: int = grid[a.x][a.y]
	grid[a.x][a.y] = grid[b.x][b.y]
	grid[b.x][b.y] = kept


## Every piece in a row or column of three or more the same.
func _matches() -> Dictionary:
	var found := {}
	for x in cols:
		for y in rows:
			var k: int = grid[x][y]
			if k < 0:
				continue
			if x + 2 < cols and grid[x + 1][y] == k and grid[x + 2][y] == k:
				var end := x
				while end < cols and grid[end][y] == k:
					found[Vector2i(end, y)] = true
					end += 1
			if y + 2 < rows and grid[x][y + 1] == k and grid[x][y + 2] == k:
				var end := y
				while end < rows and grid[x][end] == k:
					found[Vector2i(x, end)] = true
					end += 1
	return found


## Pieces fall into the gaps; new ones drop in from the top.
func _fall() -> void:
	for x in cols:
		var kept: Array[int] = []
		for y in rows:
			if grid[x][y] >= 0:
				kept.append(grid[x][y])
		while kept.size() < rows:
			kept.push_front(randi() % kinds)
		for y in rows:
			grid[x][y] = kept[y]


## A swap that makes a row ([a, b]), or [] if there's none.
func find_move() -> Array:
	for x in cols:
		for y in rows:
			for step: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var a := Vector2i(x, y)
				var b := a + step
				if not _inside(b):
					continue
				_exchange(a, b)
				var makes := not _matches().is_empty()
				_exchange(a, b)
				if makes:
					return [a, b]
	return []


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func _origin() -> Vector2:
	_tile = floorf(minf(_area.size.x / cols, (_area.size.y - 30.0) / rows))
	return Vector2((_area.size.x - _tile * cols) / 2.0, 30.0)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event.position - _origin()) / _tile
		pick(Vector2i(floori(at.x), floori(at.y)))


func _draw_map() -> void:
	if grid.is_empty():
		return
	var origin := _origin()
	_area.draw_rect(Rect2(origin, Vector2(cols, rows) * _tile), BACK)
	for x in cols:
		for y in rows:
			var k: int = grid[x][y]
			var rect := Rect2(origin + Vector2(x, y) * _tile, Vector2.ONE * _tile).grow(-3.0)
			if Vector2i(x, y) == _picked:
				_area.draw_rect(rect.grow(2.0), PICKED)
			_draw_piece(k, rect)
	_area.draw_string(ThemeDB.fallback_font, Vector2(8, 22), "Old ice cleared: %d / %d" % [mini(cleared, goal), goal],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_piece(k: int, rect: Rect2) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.38
	var colour := COLOURS[k % COLOURS.size()]
	match k:
		0:  # old ice: a white block
			_area.draw_rect(rect.grow(-rect.size.x * 0.12), colour)
			_area.draw_rect(Rect2(rect.position + rect.size * 0.18, rect.size * Vector2(0.4, 0.12)), Color("cfe6f2"))
		1:  # snowflake
			for i in 3:
				var d := Vector2.from_angle(PI * i / 3.0) * r
				_area.draw_line(c - d, c + d, colour, 3.0)
		2:  # Arctic cod
			_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(r * 0.5, -r * 0.45), c + Vector2(r * 0.7, 0), c + Vector2(r * 0.5, r * 0.45)]), colour)
			_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 1.2, -r * 0.4), c + Vector2(-r * 1.2, r * 0.4)]), colour)
		3:  # krill
			for i in 4:
				_area.draw_circle(c + Vector2(-r * 0.6 + i * r * 0.4, sin(i) * 3.0), r * 0.28, colour)
		4:  # stone
			_area.draw_circle(c, r * 0.8, colour)
		_:  # feather
			_area.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), colour, 3.0)
			_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.2, -r * 0.6), c + Vector2(r * 0.9, -r * 0.9), c + Vector2(r * 0.4, r * 0.1)]), colour)
