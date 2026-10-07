class_name ChannelFlow
extends ActivityScreen
## Channel Flow (Rosa, at the Mangrove Waterworks Station): a map of the mangrove channels.
## Tap a channel piece to turn it; sea water flows in from the left through every connected
## piece. Link all the nursery pools to the sea. Every board is made with a way through, then
## scrambled. Drawn as the mud flats: a piece swings round when turned, water runs along the
## linked channels, and a young snapper swims into each pool as it's linked; mangroves grow at
## the edges and a flamingo wades by. The story play is Rosa's water flow survey; after that
## it's for fun.

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
## The cells on the way through (the pieces a hint can turn).
var _way := {}
var _area: Control
var _tile := 48.0
var _time := 0.0
## Cell -> how far it still has to swing round (1 = just turned, easing to 0).
var _spin := {}
## Pools linked so far (a fish swims in and it sparkles the first time).
var _linked_before := {}
var _sparks: Array[Dictionary] = []
var _fish_texture: Texture2D
var _flamingo: Texture2D


func _enter_tree() -> void:
	add_to_group("activity_channel_flow")


func _how_to_play() -> String:
	return "Tap a channel to turn it. Sea water comes in from the left: link every nursery pool (the round ones) to the sea. Every map has a way through; stuck? Tap \"Show me one\"."


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
	_area.clip_contents = true
	_board.add_child(_area)
	_spin.clear()
	_linked_before.clear()
	_sparks.clear()
	_fish_texture = (load("res://data/animals/juvenile_snapper.tres") as AnimalData).sprite
	_flamingo = (load("res://data/animals/american_flamingo.tres") as AnimalData).sprite
	_add_button("Show me one (+5 s)", hint, "Hint")
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
	_way = tree.duplicate()
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


## Every board has a way through: a hint turns one piece on it into place (+5 seconds).
## Returns whether there was one left to turn.
func hint() -> bool:
	if not _playing:
		return false
	var cells := _way.keys()
	cells.shuffle()
	for cell: Vector2i in cells:
		if _pieces[cell] != _solution[cell]:
			_pieces[cell] = _solution[cell]
			seconds += 5.0
			_flow()
			if _all_linked():
				_complete()
			return true
	return false


## Turns the piece at `cell` (a tap).
func turn(cell: Vector2i) -> void:
	if not _playing or not _pieces.has(cell):
		return
	_pieces[cell] = rotated(_pieces[cell])
	_spin[cell] = 1.0
	Sound.play(&"tap", -2.0)
	_flow()
	if _all_linked():
		_complete()


func _process(delta: float) -> void:
	super(delta)
	if not _area or not visible:
		return
	_time += delta
	for cell in _spin.keys():
		_spin[cell] = maxf(float(_spin[cell]) - delta * 6.0, 0.0)
	for spark in _sparks:
		spark.pos += spark.vel * delta
		spark.life -= delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	_area.queue_redraw()


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
	for pool in _pools:  # newly linked pools: a splash, a sparkle
		if _wet.has(pool) and not _linked_before.has(pool):
			_linked_before[pool] = true
			if _area:
				Sound.play(&"arrive", -4.0)
				for i in 10:
					_sparks.append({"pos": Vector2(pool) + Vector2(0.5, 0.5), "vel": Vector2.from_angle(randf() * TAU) * randf_range(0.5, 1.5), "life": randf_range(0.5, 1.0)})
		elif not _wet.has(pool):
			_linked_before.erase(pool)
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
	_tile = floorf(minf((_area.size.x - 40.0) / _cols, (_area.size.y - 64.0) / _rows))  # (room for the mangroves)
	return Vector2((_area.size.x - _tile * _cols) / 2.0 + 20.0, (_area.size.y - _tile * _rows) / 2.0)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event.position - _origin()) / _tile
		turn(Vector2i(floori(at.x), floori(at.y)))


func _draw_map() -> void:
	if _cols == 0:
		return
	var origin := _origin()
	var board := Rect2(origin, Vector2(_cols, _rows) * _tile)
	# The sea on the left, with waves.
	_area.draw_rect(Rect2(Vector2(origin.x - 24.0, origin.y), Vector2(24.0, board.size.y)), Color("1f6f8a"))
	for i in int(board.size.y / 18.0):
		var y := origin.y + i * 18.0 + fposmod(_time * 10.0, 18.0)
		_arena_wave(Vector2(origin.x - 14.0, y))
	# Mangroves along the top and bottom of the flats.
	for i in _cols + 1:
		for top in [true, false]:
			var base := Vector2(origin.x + i * _tile, origin.y - 4.0 if top else board.end.y + 4.0)
			_mangrove(base, top)
	for cell: Vector2i in _pieces:
		var rect := Rect2(origin + Vector2(cell) * _tile, Vector2.ONE * _tile)
		_area.draw_rect(rect.grow(-1.0), MUD if (cell.x + cell.y) % 2 == 0 else MUD.darkened(0.06))
		for k in 3:  # specks in the mud
			var speck := rect.position + rect.size * Vector2(fposmod(cell.x * 0.37 + k * 0.29, 0.9) + 0.05, fposmod(cell.y * 0.53 + k * 0.31, 0.9) + 0.05)
			_area.draw_circle(speck, 1.5, MUD.darkened(0.25))
		var centre := rect.get_center()
		var wet := _wet.has(cell)
		var width := _tile * 0.3
		var angle := -float(_spin.get(cell, 0.0)) * PI / 2.0  # swinging round into place
		_area.draw_set_transform(centre, angle, Vector2.ONE)
		var bank := Color("4a3a24") if not wet else Color("2a6a8a")
		var ends: Array[Vector2] = []
		for pair: Array in [[N, Vector2.UP], [E, Vector2.RIGHT], [S, Vector2.DOWN], [W, Vector2.LEFT]]:
			if int(_pieces[cell]) & pair[0]:
				ends.append(pair[1] * _tile / 2.0)
		for end in ends:  # the channel's banks first, then the water (or dry bed) on top
			_area.draw_line(Vector2.ZERO, end, bank, width + 6.0)
		_area.draw_circle(Vector2.ZERO, width / 2.0 + 3.0, bank)
		for end in ends:
			_area.draw_line(Vector2.ZERO, end, WET if wet else DRY, width)
		_area.draw_circle(Vector2.ZERO, width / 2.0, WET if wet else DRY)
		for end in ends:
			if wet:  # water running along it, out from the sea
				for d in 3:
					var t := fposmod(_time * 0.8 + d / 3.0, 1.0)
					_area.draw_circle(end * t, width * 0.14, Color(1, 1, 1, 0.55))
			else:  # dry and cracked
				_area.draw_line(end * 0.35 + end.orthogonal().normalized() * 3.0, end * 0.65 - end.orthogonal().normalized() * 3.0, DRY.darkened(0.2), 1.5)
		_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if cell in _pools:  # a nursery pool: stones round it; once linked, a young snapper
			_area.draw_circle(centre, _tile * 0.36, Color("8a7a5a"))
			_area.draw_circle(centre, _tile * 0.3, WET if wet else POOL_DRY)
			for k in 8:
				_area.draw_circle(centre + Vector2.from_angle(TAU * k / 8.0) * _tile * 0.34, _tile * 0.05, Color("a89878"))
			if wet:
				var swim := _time * 1.5 + cell.x
				var fish_at := centre + Vector2(cos(swim), sin(swim)) * _tile * 0.15
				var w := _fish_texture.get_width() * _tile / 40.0
				var h := _fish_texture.get_height() * _tile / 40.0
				var rect_f := Rect2(fish_at - Vector2(w, h) / 2.0, Vector2(w, h))
				if sin(swim) > 0.0:
					rect_f = Rect2(rect_f.position + Vector2(w, 0), Vector2(-w, h))
				_area.draw_texture_rect(_fish_texture, rect_f, false)
	for spark in _sparks:
		_area.draw_circle(origin + spark.pos * _tile, 3.0, Color(1.0, 0.95, 0.6, spark.life))
	# A flamingo wading along the bottom.
	var walk := fposmod(_time * 20.0, board.size.x + 80.0) - 40.0
	var fw := _flamingo.get_width() * 1.5
	var fh := _flamingo.get_height() * 1.5
	_area.draw_texture_rect(_flamingo, Rect2(Vector2(origin.x + walk, board.end.y + 6.0 - fh * 0.6), Vector2(fw, fh)), false, Color(1, 1, 1, 0.9))
	_area.draw_string(ThemeDB.fallback_font, Vector2(16, 24), "Pools linked: %d / %d" % [linked(), _pools.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)


func _arena_wave(at: Vector2) -> void:
	_area.draw_arc(at, 6.0, PI * 1.2, PI * 1.8, 5, Color(1, 1, 1, 0.4), 2.0)


## A little red mangrove at the edge of the flats: arching prop roots and a round crown.
func _mangrove(base: Vector2, top: bool) -> void:
	var up := -1.0 if top else 1.0
	for k in 3:
		_area.draw_arc(base + Vector2(-6 + k * 6, 0), 6.0, PI if not top else 0.0, TAU if not top else PI, 6, Color("6a4a2a"), 2.0)
	_area.draw_circle(base + Vector2(0, 10.0 * up), 9.0, Color("3f7a3a"))
	_area.draw_circle(base + Vector2(-5, 8.0 * up), 6.0, Color("4f8a4a"))
