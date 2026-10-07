class_name IceMatch
extends ActivityScreen
## Ice Match (Sanna, at the Polar Research Station; the activity id is still "floe_fit"): a
## match-three on the station's ice map. Tap a piece, then one next to it, to swap them; three
## or more of the same in a row or column clear, the rest fall down and new ones drop in. Clear
## enough blocks of old ice (the white squares) to finish. A swap that makes no row just swaps
## back; the board always has a move (it's reshuffled if not). Drawn on the sea ice: snow falls,
## terns fly over, a seal rests on the floe beside it; pieces slide when swapped, burst when they
## clear and drop into place, and old ice cracks apart. The story play is Sanna's drill
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
var _time := 0.0
## Cell -> how many squares it still has to fall (eases to 0); the last swap sliding back into
## place ([a, b, t]); bursts: {"pos", "vel", "life", "colour"}; notes: {"text", "pos", "life"}.
var _drop := {}
var _sliding: Array = []
var _bursts: Array[Dictionary] = []
var _notes: Array[Dictionary] = []
var _snow: Array[Vector2] = []
var _cod: Texture2D
var _seal: Texture2D


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
	_drop.clear()
	_sliding = []
	_bursts.clear()
	_notes.clear()
	_snow.clear()
	for i in 40:
		_snow.append(Vector2(randf(), randf()))
	_cod = (load("res://data/animals/arctic_cod.tres") as AnimalData).sprite
	_seal = (load("res://data/animals/ringed_seal.tres") as AnimalData).sprite
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
		_sliding = [a, b, 1.0]
		Sound.play(&"not_yet", -6.0)
		return false
	_sliding = [b, a, 1.0]
	var chain := 0
	while true:
		var found := _matches()
		if found.is_empty():
			break
		chain += 1
		var ice := 0
		for cell: Vector2i in found:
			if grid[cell.x][cell.y] == OLD_ICE:
				cleared += 1
				ice += 1
			_burst(cell, grid[cell.x][cell.y])
			grid[cell.x][cell.y] = -1
		if ice > 0:
			_note("+%d old ice" % ice, found.keys()[0])
		if chain > 1:
			_note("Combo x%d!" % chain, found.keys()[found.size() - 1])
		_fall()
	Sound.play(&"plop" if chain == 1 else &"pickup")
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


## Pieces fall into the gaps; new ones drop in from the top (drawn falling: _drop).
func _fall() -> void:
	for x in cols:
		var kept: Array[int] = []
		var from: Array[int] = []
		for y in rows:
			if grid[x][y] >= 0:
				kept.append(grid[x][y])
				from.append(y)
		var missing := rows - kept.size()
		for i in missing:  # new ones drop in from above the board
			kept.push_front(randi() % kinds)
			from.push_front(-1 - i)
		for y in rows:
			grid[x][y] = kept[y]
			var fell := y - from[y]
			if fell > 0:
				_drop[Vector2i(x, y)] = maxf(float(_drop.get(Vector2i(x, y), 0.0)), float(fell))


func _burst(cell: Vector2i, kind: int) -> void:
	for i in 6:
		_bursts.append({"pos": Vector2(cell) + Vector2(0.5, 0.5), "vel": Vector2.from_angle(randf() * TAU) * randf_range(1.0, 3.0),
			"life": randf_range(0.4, 0.8), "colour": COLOURS[maxi(kind, 0) % COLOURS.size()]})


func _note(text: String, cell: Vector2i) -> void:
	_notes.append({"text": text, "pos": Vector2(cell) + Vector2(0.5, 0.2), "life": 1.2})


func _process(delta: float) -> void:
	super(delta)
	if not _area or not visible:
		return
	_time += delta
	for cell in _drop.keys():
		_drop[cell] = maxf(float(_drop[cell]) - delta * 9.0, 0.0)
	if not _sliding.is_empty():
		_sliding[2] = maxf(float(_sliding[2]) - delta * 7.0, 0.0)
	for b in _bursts:
		b.pos += b.vel * delta
		b.vel.y += 6.0 * delta
		b.life -= delta
	_bursts = _bursts.filter(func(b: Dictionary) -> bool: return b.life > 0.0)
	for n in _notes:
		n.pos.y -= delta * 0.8
		n.life -= delta
	_notes = _notes.filter(func(n: Dictionary) -> bool: return n.life > 0.0)
	for i in _snow.size():
		_snow[i] = Vector2(fposmod(_snow[i].x + sin(_time + i) * 0.0008, 1.0), fposmod(_snow[i].y + delta * 0.05, 1.0))
	_area.queue_redraw()


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
	var board := Rect2(origin, Vector2(cols, rows) * _tile)
	# The sea ice round the board: a floe each side, a seal resting on one, terns over the top.
	_area.draw_rect(Rect2(Vector2(0, origin.y), Vector2(_area.size.x, board.size.y)), Color("2a5a7a"))
	for side in 2:
		var floe := Rect2(Vector2(0.0 if side == 0 else board.end.x + 12.0, origin.y + board.size.y * 0.35), Vector2(origin.x - 12.0, board.size.y * 0.5))
		if floe.size.x > 20.0:
			_area.draw_rect(floe, Color("e8f2f8"))
			_area.draw_rect(Rect2(floe.position + Vector2(0, floe.size.y - 8.0), Vector2(floe.size.x, 8.0)), Color("b8d4e4"))
	if origin.x > 90.0:
		var sw := _seal.get_width() * 2.5
		var sh := _seal.get_height() * 2.5
		_area.draw_texture_rect(_seal, Rect2(Vector2(origin.x / 2.0 - sw / 2.0, origin.y + board.size.y * 0.35 - sh * 0.6 + sin(_time * 1.5) * 1.5), Vector2(sw, sh)), false)
	for i in 2:
		var g := Vector2(fposmod(_time * 40.0 + i * 300.0, _area.size.x + 60.0) - 30.0, origin.y + 12.0 + i * 16.0)
		var flap := sin(_time * 8.0 + i) * 5.0
		_area.draw_line(g + Vector2(-9, -flap), g, Color.WHITE, 2.0)
		_area.draw_line(g, g + Vector2(9, -flap), Color.WHITE, 2.0)
	_area.draw_rect(board.grow(4.0), Color("cfe6f2"))  # the board: frosted ice tiles
	_area.draw_rect(board, BACK)
	for x in cols:
		for y in rows:
			var tile := Rect2(origin + Vector2(x, y) * _tile, Vector2.ONE * _tile).grow(-1.0)
			_area.draw_rect(tile, BACK.lightened(0.06) if (x + y) % 2 == 0 else BACK)
	for x in cols:
		for y in rows:
			var k: int = grid[x][y]
			var shift := Vector2(0, -float(_drop.get(Vector2i(x, y), 0.0)))
			if not _sliding.is_empty() and float(_sliding[2]) > 0.0:
				var t: float = _sliding[2]
				if Vector2i(x, y) == _sliding[0]:
					shift += Vector2(_sliding[1] - _sliding[0]) * t
				elif Vector2i(x, y) == _sliding[1]:
					shift += Vector2(_sliding[0] - _sliding[1]) * t
			var rect := Rect2(origin + (Vector2(x, y) + shift) * _tile, Vector2.ONE * _tile).grow(-3.0)
			if rect.position.y < origin.y - _tile * 0.5:
				continue  # (still falling in from above the board)
			if Vector2i(x, y) == _picked:
				var pulse := 2.0 + sin(_time * 8.0) * 2.0
				_area.draw_rect(rect.grow(pulse), PICKED)
			_draw_piece(k, rect)
	for b in _bursts:
		var colour: Color = b.colour
		colour.a = b.life
		_area.draw_rect(Rect2(origin + b.pos * _tile - Vector2(3, 3), Vector2(6, 6)), colour)
	for n in _notes:
		_area.draw_string(ThemeDB.fallback_font, origin + n.pos * _tile - Vector2(50, 0), n.text, HORIZONTAL_ALIGNMENT_CENTER, 100, 18, Color(1.0, 0.85, 0.4, minf(n.life, 1.0)))
	for flake in _snow:  # snow falling over it all
		_area.draw_circle(Vector2(flake.x * _area.size.x, origin.y + flake.y * board.size.y), 1.6, Color(1, 1, 1, 0.7))
	_area.draw_string(ThemeDB.fallback_font, Vector2(8, 22), "Old ice cleared: %d / %d" % [mini(cleared, goal), goal],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _draw_piece(k: int, rect: Rect2) -> void:
	var c := rect.get_center()
	var r := rect.size.x * 0.38
	var colour := COLOURS[k % COLOURS.size()]
	match k:
		0:  # old ice: a thick white block with cracks and a shine
			var block := rect.grow(-rect.size.x * 0.08)
			_area.draw_rect(block, Color("b8d4e4"))
			_area.draw_rect(Rect2(block.position, block.size - Vector2(0, block.size.y * 0.18)), colour)
			_area.draw_rect(Rect2(rect.position + rect.size * 0.18, rect.size * Vector2(0.4, 0.1)), Color("ffffff"))
			_area.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.1), c + Vector2(-r * 0.1, -r * 0.2), c + Vector2(r * 0.3, r * 0.3)]), Color("9fc4d8"), 2.0)
		1:  # snowflake, with little side branches
			for i in 6:
				var d := Vector2.from_angle(PI * i / 3.0 + _time * 0.3)
				_area.draw_line(c, c + d * r, colour, 3.0)
				_area.draw_line(c + d * r * 0.6, c + d * r * 0.6 + d.rotated(0.7) * r * 0.25, colour, 2.0)
				_area.draw_line(c + d * r * 0.6, c + d * r * 0.6 + d.rotated(-0.7) * r * 0.25, colour, 2.0)
		2:  # Arctic cod: its own picture
			var w := rect.size.x * 0.9
			var h := w * _cod.get_height() / maxf(_cod.get_width(), 1.0)
			_area.draw_texture_rect(_cod, Rect2(c - Vector2(w, h) / 2.0 + Vector2(0, sin(_time * 3.0 + c.x) * 1.5), Vector2(w, h)), false)
		3:  # krill: a little curled shrimp with legs and an eye
			for i in 5:
				var seg := c + Vector2.from_angle(PI * 0.9 + i * 0.35) * r * 0.6 + Vector2(r * 0.1, 0)
				_area.draw_circle(seg, r * (0.26 - i * 0.03), colour)
			for i in 4:
				_area.draw_line(c + Vector2(-r * 0.3 + i * r * 0.2, r * 0.1), c + Vector2(-r * 0.35 + i * r * 0.2, r * 0.45), colour.darkened(0.2), 1.5)
			_area.draw_circle(c + Vector2(r * 0.55, -r * 0.2), 2.0, Color("1a1a1a"))
		4:  # a sea-worn stone
			_area.draw_circle(c + Vector2(0, 2), r * 0.8, colour.darkened(0.25))
			_area.draw_circle(c, r * 0.8, colour)
			_area.draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.25, colour.lightened(0.2))
		_:  # feather
			_area.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), colour, 3.0)
			_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.2, -r * 0.6), c + Vector2(r * 0.9, -r * 0.9), c + Vector2(r * 0.4, r * 0.1)]), colour)
