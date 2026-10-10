class_name EndCredits
extends CanvasLayer
## The end credits (data/ending/final_word.tres): the screen goes black, stars come out, and the
## text rolls slowly up and away into the distance, centred in big gold letters, like the
## opening crawl of an old space film. Slow enough for slow readers; the speed button (bottom
## left) goes x1 -> x2 -> x3 -> x4 -> x5 -> x1 (also a tap on the text, or the interact key). Played once when the final chapter first opens, and again from
## the Observatory's "End credits" button. Close (top right) or the end returns to the game.

signal finished

const CREDITS: CreditsData = preload("res://data/ending/final_word.tres")
const GOLD := Color("f2c94c")
const BRIGHT := Color("ffe9a8")
const SHADOW := Color("6b4a10")
## Black before the text starts, seconds.
const BLACK_SECONDS := 2.5
## Rolling speed, in body-text line heights a second (slow readers: about 2.3 s a line).
const LINES_PER_SECOND := 0.43
const SPEEDS := [1.0, 2.0, 3.0, 4.0, 5.0]
## They start rolling at x3 (the owner's choice); the button steps on from there.
const START_SPEED := 2
## How quickly the text shrinks into the distance (in screen heights: smaller = sooner).
const DEPTH := 0.9

var _rows: Array[Dictionary] = []  # {"text", "size", "colour", "gap" (before), "rule"}
var _total := 0.0
var _offset := 0.0  # how far the text has rolled, px at full size
var _time := 0.0
var _speed := 0  # index into SPEEDS
var _stars: Array[Vector3] = []
var _canvas: Control
var _speed_button: Button
var _close: Button
var _laid_for := Vector2.ZERO


func _ready() -> void:
	layer = 20
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.name = "Crawl"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_crawl)
	_canvas.gui_input.connect(_on_input)
	add_child(_canvas)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.custom_minimum_size = Vector2(96, 48)
	close.modulate = Color(1, 1, 1, 0.55)
	close.pressed.connect(stop)
	add_child(close)
	_close = close
	_speed_button = Button.new()
	_speed_button.name = "Speed"
	_speed_button.custom_minimum_size = Vector2(88, 56)
	_speed_button.add_theme_font_size_override("font_size", 24)
	_speed_button.modulate = Color(1, 0.92, 0.7, 0.8)
	_speed_button.pressed.connect(toggle_speed)
	add_child(_speed_button)
	_place_buttons()
	get_viewport().size_changed.connect(_place_buttons)
	for i in 160:
		_stars.append(Vector3(randf(), randf(), randf_range(0.3, 1.0)))


## Close top right and the speed button bottom left, inside a phone's rounded corners, notch
## and home bar (SafeArea), in portrait and landscape.
func _place_buttons() -> void:
	var m := SafeArea.margins(get_viewport(), 12.0)
	_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close.offset_left = -m.z - _close.custom_minimum_size.x
	_close.offset_right = -m.z
	_close.offset_top = m.y
	_close.offset_bottom = m.y + _close.custom_minimum_size.y
	_speed_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_speed_button.offset_left = m.x
	_speed_button.offset_right = m.x + _speed_button.custom_minimum_size.x
	_speed_button.offset_top = -m.w - _speed_button.custom_minimum_size.y
	_speed_button.offset_bottom = -m.w


func play() -> void:
	Fleet.mark(&"credits_rolled")  # (the Clue Board's last string: "Who created all of this?")
	_offset = 0.0
	_time = 0.0
	_speed = START_SPEED
	_laid_for = Vector2.ZERO
	visible = true
	get_tree().paused = true
	_place_buttons()
	_update_note()


func stop() -> void:
	if not visible:
		return
	visible = false
	finished.emit()


func is_playing() -> bool:
	return visible


func is_fast() -> bool:
	return _speed > 0


## How fast it rolls now: 1 to 5.
func speed() -> float:
	return SPEEDS[_speed]


## How far through the text it has rolled, 0..1.
func progress() -> float:
	return clampf(_offset / maxf(_total, 1.0), 0.0, 1.0)


## The text as it rolls: [{"text", "size", ...}] (tests read it).
func rows() -> Array[Dictionary]:
	return _rows


func _on_input(event: InputEvent) -> void:
	# (A phone's tap also arrives as a mouse click: counting the touch too stepped twice.)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_speed()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		toggle_speed()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("ui_cancel"):
		stop()
		get_viewport().set_input_as_handled()


## A tap: twice as fast, or back to normal.
func toggle_speed() -> void:
	_speed = (_speed + 1) % SPEEDS.size()
	_update_note()


func _update_note() -> void:
	_speed_button.text = "x%d" % roundi(SPEEDS[_speed])


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _laid_for != _canvas.size:
		_layout()
	if _time > BLACK_SECONDS:
		_offset += delta * LINES_PER_SECOND * _body_size() * 1.5 * speed()
		if _offset > _total + _canvas.size.y * DEPTH * 2.3:
			stop()
			return
	_canvas.queue_redraw()


func _body_size() -> float:
	return clampf(minf(_canvas.size.x, _canvas.size.y * 1.6) / 21.0, 26.0, 64.0)


## Wraps the text into rows for the screen's width (again whenever the window changes).
func _layout() -> void:
	_laid_for = _canvas.size
	_rows.clear()
	var font := ThemeDB.fallback_font
	var body := _body_size()
	var width := _canvas.size.x * 0.82
	var gap := 0.0
	for raw: String in CREDITS.text.split("\n"):
		var line := raw.strip_edges()
		if line == "":
			gap += body * 0.55
			continue
		if line == "---":
			_rows.append({"text": "", "size": body, "colour": GOLD, "gap": gap + body * 0.4, "rule": true})
			gap = body * 0.4
			continue
		var size := body
		var colour := GOLD
		if line.begins_with("# "):
			line = line.substr(2)
			size = body * 1.7
		elif line.begins_with("### "):
			line = line.substr(4)
			size = body * 1.3
		if line.begins_with("> "):
			line = line.substr(2)
		if line.contains("**"):
			line = line.replace("**", "")
			colour = BRIGHT
			size *= 1.08
		var words := line.split(" ", false)
		var current := ""
		var first := true
		for word in words:
			var trial := word if current == "" else current + " " + word
			if current != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size)).x > width:
				_rows.append({"text": current, "size": size, "colour": colour, "gap": gap if first else 0.0, "rule": false})
				first = false
				gap = 0.0
				current = word
			else:
				current = trial
		_rows.append({"text": current, "size": size, "colour": colour, "gap": gap if first else 0.0, "rule": false})
		gap = 0.0
	_total = 0.0
	for row in _rows:
		_total += row.gap + row.size * 1.25


func _draw_crawl() -> void:
	var size := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var fade_in := clampf((_time - 0.6) / 1.5, 0.0, 1.0)
	for star in _stars:  # stars come out, twinkling
		var twinkle := 0.6 + 0.4 * sin(_time * (1.0 + star.z * 2.0) + star.x * 40.0)
		_canvas.draw_rect(Rect2(Vector2(star.x * size.x, star.y * size.y), Vector2.ONE * (1.0 + star.z * 1.5)),
			Color(1, 1, 1, star.z * twinkle * fade_in * 0.8))
	if _time < BLACK_SECONDS or _rows.is_empty():
		return
	# The text rolls away into the distance: a row that has risen `d` px (at full size) is at
	# depth z = 1 + d / reach, drawn 1/z the size, and the rows below it shrink the same way, so
	# it climbs reach * ln(z) up the screen (never overlapping) and fades out near the top.
	var font := ThemeDB.fallback_font
	var bottom := size.y * 1.02
	var reach := size.y * DEPTH
	var y := 0.0  # distance of this row's top from the start of the text
	for row in _rows:
		y += row.gap
		var d: float = _offset - y  # how far this row has risen above the bottom edge
		var height: float = row.size * 1.25
		y += height
		if d < -height:
			break  # still below the screen (and so are all the rows after it)
		var z := 1.0 + maxf(d, 0.0) / reach
		var screen_y := bottom - (reach * log(z) if d > 0.0 else d)
		if screen_y < 0.0:
			continue  # gone into the distance
		var scale := 1.0 / z
		var alpha := clampf(screen_y / (size.y * 0.3), 0.0, 1.0)
		if row.rule:
			var half := size.x * 0.12 * scale
			_canvas.draw_line(Vector2(size.x / 2.0 - half, screen_y - 8.0 * scale), Vector2(size.x / 2.0 + half, screen_y - 8.0 * scale),
				Color(GOLD, 0.7 * alpha), maxf(2.0 * scale, 1.0))
			_canvas.draw_circle(Vector2(size.x / 2.0, screen_y - 8.0 * scale), 4.0 * scale, Color(GOLD, alpha))
			continue
		var text_size := int(row.size)
		var text_width := font.get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		_canvas.draw_set_transform(Vector2(size.x / 2.0, screen_y), 0.0, Vector2(scale, scale))
		var at := Vector2(-text_width / 2.0, 0.0)
		_canvas.draw_string_outline(font, at, row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 6, Color(SHADOW, alpha))
		_canvas.draw_string(font, at, row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(row.colour, alpha))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
