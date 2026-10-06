class_name SonarSweep
extends ActivityScreen
## Sonar Sweep (Maya, at the Marine Search & Rescue Station): sweep a stretch of coast with the
## sonar. Tap the sea to ping it: the number shows how many hidden things lie next to it (like
## Minesweeper, but nothing goes wrong). Each ping adds a second; when you're sure, Mark a
## square to find what's there for free (a wrong mark adds a few seconds). Find everything.
## The story play finds the wreck; after that it's for fun and personal bests.

const WRECK := preload("res://assets/effects/wreck/wreck.svg")
const LITTER := ["res://data/items/ghost_net.tres", "res://data/items/plastic_bottle.tres", "res://data/items/fishing_line.tres"]
const HIDDEN := Color("1d4e6e")
const PINGED := Color("7cc6e8")
const FOUND := Color("f2d58a")

var _cols := 0
var _rows := 0
## Cell -> what's hidden there (a texture).
var _things := {}
var _shown := {}
var _found := 0
var _marking := false
var _tiles := {}
var _ping_button: Button
var _mark_button: Button


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
	_tiles.clear()
	_found = 0
	_marking = false
	var cells: Array[Vector2i] = []
	for x in _cols:
		for y in _rows:
			cells.append(Vector2i(x, y))
	cells.shuffle()
	var story := not Activities.story_done(activity)
	for i in mini(config.z, cells.size()):
		_things[cells[i]] = WRECK if (story and i == 0) or (not story and i % 4 == 0) else (load(LITTER[i % LITTER.size()]) as ItemData).icon
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.add_child(centre)
	var grid := GridContainer.new()
	grid.columns = _cols
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	centre.add_child(grid)
	var room := get_viewport().get_visible_rect().size - Vector2(40, 280)
	var size := clampf(floorf(minf(room.x / _cols, room.y / _rows)) - 3.0, 34.0, 120.0)
	for y in _rows:
		for x in _cols:
			var cell := Vector2i(x, y)
			var tile := Button.new()
			tile.name = "Tile_%d_%d" % [x, y]
			tile.custom_minimum_size = Vector2(size, size)
			tile.focus_mode = Control.FOCUS_NONE
			tile.expand_icon = true
			tile.add_theme_font_size_override("font_size", int(size * 0.5))
			tile.add_theme_color_override("font_color", Color("13293a"))
			_paint(tile, HIDDEN)
			tile.pressed.connect(tap.bind(cell))
			grid.add_child(tile)
			_tiles[cell] = tile
	_ping_button = _add_button("Ping", set_marking.bind(false), "Ping")
	_mark_button = _add_button("Mark", set_marking.bind(true), "Mark")
	set_marking(false)


func set_marking(marking: bool) -> void:
	_marking = marking
	_ping_button.modulate = Color.WHITE if not marking else Color(1, 1, 1, 0.55)
	_mark_button.modulate = Color.WHITE if marking else Color(1, 1, 1, 0.55)


## A tap on a square: ping it (or mark it, in Mark mode).
func tap(cell: Vector2i) -> void:
	if not _playing or _shown.has(cell):
		return
	if _marking and not _things.has(cell):
		seconds += activity.miss_seconds  # nothing there: it costs a little time, that's all
	elif not _marking:
		seconds += activity.ping_seconds
	if _things.has(cell):
		_find(cell)
	else:
		_reveal(cell)
	if _found == _things.size():
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
	if _shown.has(cell) or not _tiles.has(cell) or _things.has(cell):
		return
	_shown[cell] = true
	var count := around(cell)
	var tile: Button = _tiles[cell]
	tile.text = str(count) if count > 0 else ""
	_paint(tile, PINGED)
	if count == 0:  # open water all round: the sonar sweeps on by itself
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_reveal(cell + Vector2i(dx, dy))


func _find(cell: Vector2i) -> void:
	_shown[cell] = true
	_found += 1
	var tile: Button = _tiles[cell]
	tile.icon = _things[cell]
	_paint(tile, FOUND)


static func _paint(tile: Button, colour: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = colour if state != "hover" else colour.lightened(0.1)
		box.set_corner_radius_all(6)
		tile.add_theme_stylebox_override(state, box)
