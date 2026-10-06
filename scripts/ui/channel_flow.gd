class_name ChannelFlow
extends ActivityScreen
## Channel Flow (Rosa, at the Mangrove Waterworks Station): a map of the mangrove channels.
## Tap a channel piece to turn it; sea water flows in from the left through every connected
## piece. Link all the nursery pools to the sea. Every board is made with a way through, then
## scrambled. The story play is Rosa's water flow survey; after that it's for fun.

const N := 1
const E := 2
const S := 4
const W := 8
const MUD := Color("6e5a3e")
const DRY := Color("a08c64")
const WET := Color("4fb3e8")
const POOL_DRY := Color("8a7a58")

var _cols := 0
var _rows := 0
## Cell -> its channel's openings (N/E/S/W bits).
var _pieces := {}
var _pools: Array[Vector2i] = []
var _source := Vector2i.ZERO
var _wet := {}
## Each piece as it was made (the way through), before it was scrambled.
var _solution := {}
var _area: Control
var _tile := 48.0


func _enter_tree() -> void:
	add_to_group("activity_channel_flow")


func _how_to_play() -> String:
	return "Tap a channel to turn it. Sea water comes in from the left: link every nursery pool (the round ones) to the sea."


func _start_board(config: Vector3i) -> void:
	_cols = config.x
	_rows = config.y
	_make(config.z)
	_area = Control.new()
	_area.name = "Map"
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_area.gui_input.connect(_on_input)
	_area.draw.connect(_draw_map)
	_board.add_child(_area)
	_flow()


## Builds a board with a way through: paths from the sea to every pool, then every piece turned.
func _make(pool_count: int) -> void:
	_pieces.clear()
	_pools.clear()
	_source = Vector2i(0, randi() % _rows)
	var tree := {_source: true}
	_pieces[_source] = W
	var free: Array[Vector2i] = []
	for x in range(1, _cols):
		for y in _rows:
			free.append(Vector2i(x, y))
	free.shuffle()
	for i in mini(pool_count, free.size()):
		var pool := free[i]
		_pools.append(pool)
		var path := _path_to(pool, tree)
		for j in path.size() - 1:
			_join(path[j], path[j + 1])
		for cell in path:
			tree[cell] = true
	for x in _cols:  # the rest: odd bits of channel, to make it a puzzle
		for y in _rows:
			var cell := Vector2i(x, y)
			if not _pieces.has(cell) or _pieces[cell] == 0:
				_pieces[cell] = [N | S, E | W, N | E, E | S][randi() % 4]
	_solution = _pieces.duplicate()
	for cell: Vector2i in _pieces:  # scrambled
		for turn in randi() % 4:
			_pieces[cell] = rotated(_pieces[cell])
	if _all_linked():  # (already solved by chance: turn one pool's piece)
		_pieces[_pools[0]] = rotated(_pieces[_pools[0]])


## The shortest way (random among equals) from `from` to any cell in `tree`.
func _path_to(from: Vector2i, tree: Dictionary) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if tree.has(cell):
			var path: Array[Vector2i] = [cell]
			while path[-1] != from:
				path.append(came[path[-1]])
			return path
		var steps: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		steps.shuffle()
		for step in steps:
			var next := cell + step
			if next.x >= 0 and next.y >= 0 and next.x < _cols and next.y < _rows and not came.has(next):
				came[next] = cell
				queue.append(next)
	return [from]


func _join(a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	var bit_a: int = {Vector2i.UP: N, Vector2i.RIGHT: E, Vector2i.DOWN: S, Vector2i.LEFT: W}[d]
	var bit_b: int = {N: S, E: W, S: N, W: E}[bit_a]
	_pieces[a] = int(_pieces.get(a, 0)) | bit_a
	_pieces[b] = int(_pieces.get(b, 0)) | bit_b


## A piece turned a quarter clockwise.
static func rotated(mask: int) -> int:
	return ((mask << 1) | (mask >> 3)) & 15


## Turns the piece at `cell` (a tap).
func turn(cell: Vector2i) -> void:
	if not _playing or not _pieces.has(cell):
		return
	_pieces[cell] = rotated(_pieces[cell])
	_flow()
	if _all_linked():
		_complete()


## Water from the sea through every connected channel.
func _flow() -> void:
	_wet.clear()
	if int(_pieces[_source]) & W:
		var queue: Array[Vector2i] = [_source]
		_wet[_source] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			var mask: int = _pieces[cell]
			for pair: Array in [[N, S, Vector2i.UP], [E, W, Vector2i.RIGHT], [S, N, Vector2i.DOWN], [W, E, Vector2i.LEFT]]:
				var next: Vector2i = cell + pair[2]
				if mask & pair[0] and _pieces.has(next) and int(_pieces[next]) & pair[1] and not _wet.has(next):
					_wet[next] = true
					queue.append(next)
	if _area:
		_area.queue_redraw()


func _all_linked() -> bool:
	_flow()
	return _pools.all(func(p: Vector2i) -> bool: return _wet.has(p))


func pools() -> Array[Vector2i]:
	return _pools


func linked() -> int:
	return _pools.filter(func(p: Vector2i) -> bool: return _wet.has(p)).size()


func pieces() -> Dictionary:
	return _pieces


## The way through it was made with (each piece's openings).
func solution() -> Dictionary:
	return _solution


func _origin() -> Vector2:
	_tile = floorf(minf((_area.size.x - 40.0) / _cols, _area.size.y / _rows))
	return Vector2((_area.size.x - _tile * _cols) / 2.0 + 20.0, (_area.size.y - _tile * _rows) / 2.0)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event.position - _origin()) / _tile
		turn(Vector2i(floori(at.x), floori(at.y)))


func _draw_map() -> void:
	if _cols == 0:
		return
	var origin := _origin()
	# The sea on the left.
	_area.draw_rect(Rect2(Vector2(origin.x - 20.0, origin.y), Vector2(20.0, _tile * _rows)), Color("1f5f78"))
	for cell: Vector2i in _pieces:
		var rect := Rect2(origin + Vector2(cell) * _tile, Vector2.ONE * _tile)
		_area.draw_rect(rect.grow(-1.0), MUD)
		var centre := rect.get_center()
		var colour := WET if _wet.has(cell) else DRY
		var width := _tile * 0.28
		for pair: Array in [[N, Vector2.UP], [E, Vector2.RIGHT], [S, Vector2.DOWN], [W, Vector2.LEFT]]:
			if int(_pieces[cell]) & pair[0]:
				_area.draw_line(centre, centre + pair[1] * _tile / 2.0, colour, width)
		_area.draw_circle(centre, width / 2.0, colour)
		if cell in _pools:
			_area.draw_circle(centre, _tile * 0.3, WET if _wet.has(cell) else POOL_DRY)
	_area.draw_string(ThemeDB.fallback_font, Vector2(16, 24), "Pools linked: %d / %d" % [linked(), _pools.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
