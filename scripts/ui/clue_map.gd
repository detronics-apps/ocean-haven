class_name ClueMap
extends Control
## The Clue Board as one connected map (docs/CLUE_BOARD.md §1). A spine of 9 slots in reading
## order (the opening, nodes 1-7, the final question), each slot's visible cards in a cluster
## across it, and threads between cards: "led to" (solid), "evidence from" (dotted: a card whose
## evidence or answer waits on another card) and "planted -> payoff" (gold, dashed: leads_to "~id").
## Landscape lays the spine left to right, portrait top to bottom; only the mapping changes.
## Fixed zoom steps (+ / -), drag to pan, tap a slot to zoom to it, tap a card for its details.
## It looks like a cork pin board in a wooden frame: paper notes, tilted a little, pinned with brass
## pins and joined with red string (cream: a question, blue: answered, tan: a field note, ochre:
## the final question).

## The slots' titles (0 = the opening, 8 = the final question).
const SLOTS := ["Where did the turtles go?", "There's more out there", "Living things depend on each other",
	"Watch first", "Stop it where it starts", "What we do matters", "One ocean", "We're part of it",
	"Who created all of this?"]
const CARD := Vector2(280, 130)
const GAP := Vector2(40, 30)
const PIN := Vector2(230, 64)
## Zoom steps: 0 = the whole board fits (set on layout), then node and close-up.
var zoom_steps: Array[float] = [0.4, 0.8, 1.15]
var step := 0

const COLOURS := {
	&"question": Color("f1e6c8"), &"clue": Color("d9c194"), &"answered": Color("9cc3e0"),
	&"final": Color("e9c278"), &"tag": Color("dcc69a"), &"tag_dim": Color(0.86, 0.78, 0.6, 0.28),
	&"cork": Color("a8794c"), &"speck": Color("7d5534"), &"wood": Color("6b4426"), &"wood_light": Color("8a5a33"),
	&"ink": Color("2a241c"), &"string": Color("b3262b"), &"brass": Color("c9a24a"),
}
## The wooden frame's width, and the title plank.
const FRAME := 16.0
const TITLE := "BLUEHAVEN — CLUE BOARD"

var _canvas: Control
var _threads: Control
var _detail: PanelContainer
var _detail_text: VBoxContainer
## Card id -> its Control on the canvas; slot index -> its pin.
var _cards := {}
var _pins := {}
var _focus: StringName = &""
var _dragging := false
var _drag_from := Vector2.ZERO
var _moved := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cork := Control.new()  # the cork board (stays put while the notes pan and zoom)
	cork.name = "Cork"
	cork.set_anchors_preset(Control.PRESET_FULL_RECT)
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cork.draw.connect(_draw_cork.bind(cork))
	add_child(cork)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_threads = Control.new()  # the string and the pins, over the notes (moved last on rebuild)
	_threads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threads.draw.connect(_draw_threads)
	_canvas.add_child(_threads)
	var frame := Control.new()  # the wooden frame and its planks, over the edges
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame.bind(frame))
	add_child(frame)
	resized.connect(func() -> void:
		cork.queue_redraw()
		frame.queue_redraw())
	var zoom_bar := HBoxContainer.new()
	zoom_bar.name = "ZoomBar"
	zoom_bar.add_theme_constant_override("separation", 6)
	add_child(zoom_bar)
	for sign in [1, -1]:
		var button := Button.new()
		button.name = "ZoomOut" if sign < 0 else "ZoomIn"
		button.text = "−" if sign < 0 else "+"
		button.custom_minimum_size = Vector2(48, 48)
		button.focus_mode = Control.FOCUS_NONE
		_paper_button(button, Color("e7dcc0"))
		button.pressed.connect(func() -> void: set_step(step + sign))
		zoom_bar.add_child(button)
	_detail = PanelContainer.new()
	_detail.name = "Detail"
	_detail.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = COLOURS[&"question"]
	style.set_corner_radius_all(3)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	style.shadow_offset = Vector2(3, 5)
	_detail.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	_detail_text = VBoxContainer.new()
	_detail_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_text.add_theme_constant_override("separation", 10)
	scroll.add_child(_detail_text)
	add_child(_detail)
	resized.connect(rebuild)
	rebuild()


func landscape() -> bool:
	return size.x >= size.y


## Lays every visible card out again (after a change, or when the phone turns).
func rebuild() -> void:
	if not is_inside_tree() or size == Vector2.ZERO:
		return
	for child in _canvas.get_children():
		if child != _threads:
			child.free()
	_cards.clear()
	_pins.clear()
	var clues := Clues
	var by_slot := {}
	for one: ClueData in clues.cards():
		if clues.is_visible(one.id):
			by_slot[one.node] = by_slot.get(one.node, []) + [one]
	var main := 0.0  # how far along the spine (portrait: rows used so far)
	var extent := Vector2.ZERO
	for slot in SLOTS.size():
		var cards: Array = by_slot.get(slot, [])
		var pin_at: Vector2
		if landscape():
			pin_at = Vector2(slot * (CARD.x + GAP.x), 0)
		else:
			pin_at = Vector2(0, main)
		_pins[slot] = _pin(slot, pin_at, not cards.is_empty())
		for i in cards.size():
			var at: Vector2
			if landscape():
				at = pin_at + Vector2(0, PIN.y + GAP.y + i * (CARD.y + GAP.y))
			else:
				at = pin_at + Vector2(PIN.x + GAP.x + (i % 2) * (CARD.x + GAP.x), (i / 2) * (CARD.y + GAP.y))
			_cards[cards[i].id] = _card(cards[i], at)
			extent = extent.max(at + CARD)
		extent = extent.max(pin_at + PIN)
		if not landscape():
			main += maxf(PIN.y, ceilf(cards.size() / 2.0) * (CARD.y + GAP.y)) + GAP.y
	_canvas.move_child(_threads, -1)  # (string and pins over the notes)
	_threads.size = extent + GAP
	_canvas.size = extent + GAP
	var inside := size - Vector2(FRAME, FRAME) * 2.0 - Vector2(0, 70)  # (within the frame and planks)
	zoom_steps[0] = clampf(minf(inside.x / _canvas.size.x, inside.y / _canvas.size.y), 0.15, 0.6)
	(get_node("ZoomBar") as Control).position = size - Vector2(108, 52) - Vector2(FRAME, FRAME) - Vector2(8, 8)
	_apply_zoom()
	if _focus != &"" and _cards.has(_focus):
		centre_on(_cards[_focus])
	elif step == 0:
		_canvas.position = (size - _canvas.size * _canvas.scale) / 2.0
	_place_detail()
	_threads.queue_redraw()


func _pin(slot: int, at: Vector2, lit: bool) -> Control:
	var pin := Button.new()
	pin.name = "Slot%d" % slot
	pin.position = at
	pin.size = PIN
	pin.focus_mode = Control.FOCUS_NONE
	pin.clip_text = true
	pin.text = SLOTS[slot].to_upper() if lit else "…"
	pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pin.pivot_offset = PIN / 2.0
	pin.rotation_degrees = _tilt("slot%d" % slot) * 0.6
	_paper_button(pin, COLOURS[&"tag"] if lit else COLOURS[&"tag_dim"], lit)
	pin.add_theme_font_size_override("font_size", 16)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (taps are worked out by the map: drags pan)
	_canvas.add_child(pin)
	return pin


func _card(one: ClueData, at: Vector2) -> Control:
	var state := _state_of(one)
	var panel := Panel.new()  # (fixed size: every card the same, the details panel has the full text)
	panel.name = "Card_" + String(one.id)
	panel.position = at
	panel.size = CARD
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (taps are worked out by the map: drags pan)
	panel.add_theme_stylebox_override("panel", _paper(COLOURS[state]))
	panel.pivot_offset = CARD / 2.0
	panel.rotation_degrees = _tilt(String(one.id))
	var label := Label.new()
	label.name = "Text"
	label.text = card_text(one)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", COLOURS[&"ink"])
	label.add_theme_font_size_override("font_size", 17 if state == &"answered" else 19)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if state == &"answered" else HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14
	label.offset_top = 20  # (below the pin)
	label.offset_right = -14 - (40 if one.picture else 0)
	label.offset_bottom = -10
	if one.picture:  # a little sketch in the corner (e.g. the hook-shaped tag)
		var sketch := TextureRect.new()
		sketch.texture = one.picture
		sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sketch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sketch.modulate = Color(0.55, 0.42, 0.28, 0.85)  # (pencil-brown, like a sketch)
		sketch.position = Vector2(CARD.x - 56, CARD.y - 56)
		sketch.size = Vector2(46, 46)
		sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(sketch)
	panel.set_meta("state", state)
	_canvas.add_child(panel)
	var count: int = Clues.evidence_texts(one).size()
	if count > 0 and state == &"question":
		var badge := Label.new()
		badge.text = "● %d" % count
		badge.add_theme_color_override("font_color", COLOURS[&"string"])
		badge.position = Vector2(10, CARD.y - 28)
		panel.add_child(badge)
	return panel


## &"question", &"clue" (a planted detail, no question yet), &"answered" or &"final".
func _state_of(one: ClueData) -> StringName:
	if one.kind == &"final":
		return &"final"
	if Clues.is_answered(one.id):
		return &"answered"
	if not Clues.is_open(one.id):
		return &"clue"
	return &"question"


## What a card says on the map.
static func card_text(one: ClueData) -> String:
	if Clues.is_answered(one.id):
		return Clues.statement(one)
	if not Clues.is_open(one.id):
		return one.clue_text
	return question_of(one).to_upper()


## The card's question, its names filled in ({rescue:id}).
static func question_of(one: ClueData) -> String:
	return Clues.fill(one, one.question, [])


# --- Zoom, pan, focus ---

func set_step(to: int) -> void:
	var centre := (size / 2.0 - _canvas.position) / _canvas.scale.x
	step = clampi(to, 0, zoom_steps.size() - 1)
	_apply_zoom()
	if step == 0:
		_canvas.position = (size - _canvas.size * _canvas.scale) / 2.0
	else:
		_canvas.position = size / 2.0 - centre * _canvas.scale.x
	_clamp_pan()


func _apply_zoom() -> void:
	_canvas.scale = Vector2.ONE * zoom_steps[step]
	# The overview shows the shape of the story: tokens only, the text comes back closer in.
	for card: Control in _cards.values():
		card.get_node("Text").visible = step > 0


func centre_on(target: Control) -> void:
	_canvas.position = size / 2.0 - (target.position + target.size / 2.0) * _canvas.scale.x
	_clamp_pan()


func _clamp_pan() -> void:
	var shown := _canvas.size * _canvas.scale
	var lo := (size - shown).min(Vector2.ZERO) - Vector2(80, 80)
	var hi := (size - shown).max(Vector2.ZERO) + Vector2(80, 80)
	_canvas.position = _canvas.position.clamp(lo, hi)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_drag_from = event.position
		if event.pressed:
			_moved = 0.0
		elif _moved < 12.0:
			tap(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_canvas.position += event.position - _drag_from
		_moved += (event.position - _drag_from).length()
		_drag_from = event.position
		_clamp_pan()
		accept_event()


## A tap at `at` (in the map's own coordinates): a card shows its details, a slot zooms to it.
func tap(at: Vector2) -> void:
	if _detail.visible and _detail.get_rect().has_point(at):
		return
	var on_canvas := (at - _canvas.position) / _canvas.scale.x
	for id in _cards:
		if (_cards[id] as Control).get_rect().has_point(on_canvas):
			show_detail(id)
			return
	for slot in _pins:
		if (_pins[slot] as Control).get_rect().has_point(on_canvas):
			set_step(maxi(step, 1))
			centre_on(_pins[slot])
			return


# --- Detail panel ---

func show_detail(id: StringName) -> void:
	var one: ClueData = Clues.card(id)
	if one == null:
		return
	_focus = id
	for child in _detail_text.get_children():
		child.free()
	var head := _label(SLOTS[one.node].to_upper(), 15, COLOURS[&"string"])
	_detail_text.add_child(head)
	if one.picture:
		var pic := TextureRect.new()
		pic.texture = one.picture
		pic.custom_minimum_size = Vector2(0, 96)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_detail_text.add_child(pic)
	if Clues.is_answered(id):
		_detail_text.add_child(_label("You wondered: " + question_of(one), 16, Color("6b5a44")))
		_detail_text.add_child(_label(Clues.statement(one), 22, Color("1f4f73")))
	elif Clues.is_open(id):
		_detail_text.add_child(_label(question_of(one), 22, COLOURS[&"ink"]))
	else:
		_detail_text.add_child(_label(one.clue_text, 22, COLOURS[&"ink"]))
	if Clues.is_open(id) and Clues.is_found(id):
		_detail_text.add_child(_label("Field note: " + one.clue_text, 16, Color("6b5a44")))
	for line in Clues.evidence_texts(one):
		_detail_text.add_child(_label("• " + line, 18, COLOURS[&"ink"]))
	for link in _links(one):
		var chip := Button.new()
		chip.text = link.text
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 44)
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # (long questions wrap inside the panel)
		_paper_button(chip, COLOURS[&"tag"])
		var to: StringName = link.id
		chip.pressed.connect(func() -> void:
			if _cards.has(to):
				set_step(maxi(step, 1))
				centre_on(_cards[to])
				show_detail(to))
		_detail_text.add_child(chip)
	var close := Button.new()
	close.text = "Back to the map"
	close.custom_minimum_size = Vector2(0, 48)
	_paper_button(close, Color("e7dcc0"))
	close.pressed.connect(func() -> void:
		_detail.visible = false
		_focus = &"")
	_detail_text.add_child(close)
	_detail.visible = true
	_place_detail()


## Visible cards this one came from or leads to: [{id, text}].
func _links(one: ClueData) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for other: ClueData in Clues.cards():
		if other == one or not Clues.is_visible(other.id):
			continue
		for kind in _thread_kinds(other, one):
			list.append({"id": other.id, "text": "Came from: " + _short(other)})
		for kind in _thread_kinds(one, other):
			list.append({"id": other.id, "text": "Leads to: " + _short(other)})
	return list


static func _short(one: ClueData) -> String:
	return Clues.statement(one) if Clues.is_answered(one.id) else question_of(one) if Clues.is_open(one.id) else one.clue_text


## The kinds of thread from `a` to `b`: &"led" (a.leads_to has b), &"planted" ("~b"),
## &"evidence" (b's evidence or triggers wait on a: "clue:a" / "open:a").
static func _thread_kinds(a: ClueData, b: ClueData) -> Array[StringName]:
	var kinds: Array[StringName] = []
	if String(b.id) in a.leads_to:
		kinds.append(&"led")
	if "~" + String(b.id) in a.leads_to:
		kinds.append(&"planted")
	for line in Array(b.evidence) + Array(b.activate):
		if ("clue:%s" % a.id) in line or ("open:%s" % a.id) in line:
			kinds.append(&"evidence")
			break
	return kinds


func _place_detail() -> void:
	var edge := FRAME + 8.0
	if landscape():
		_detail.position = Vector2(size.x * 0.58, edge + 34)
		_detail.size = Vector2(size.x * 0.42 - edge, size.y - edge * 2 - 34)
	else:
		_detail.position = Vector2(edge, size.y * 0.5)
		_detail.size = Vector2(size.x - edge * 2, size.y * 0.5 - edge)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


# --- String, pins and the board ---

func _draw_threads() -> void:
	for a: ClueData in Clues.cards():
		if not _cards.has(a.id):
			continue
		for b: ClueData in Clues.cards():
			if b == a or not _cards.has(b.id):
				continue
			for kind in _thread_kinds(a, b):
				_thread(_cards[a.id], _cards[b.id], kind)
	# Every lit slot joins the final question once it shows (its faint strings).
	if _cards.has(&"final_who"):
		for slot in range(8):
			if (_pins[slot] as Button).text.ends_with("…"):
				continue
			_thread(_pins[slot], _cards[&"final_who"], &"faint")
	# A brass pin on every note and lit tag, over the string.
	for note: Control in _cards.values() + _pins.values():
		if note is Button and (note as Button).text.ends_with("…"):
			continue
		var head := pin_point(note)
		_threads.draw_circle(head + Vector2(2, 3), 8.0, Color(0, 0, 0, 0.35))
		_threads.draw_circle(head, 8.0, (COLOURS[&"brass"] as Color).darkened(0.3))
		_threads.draw_circle(head - Vector2(1.5, 1.5), 5.5, COLOURS[&"brass"])
		_threads.draw_circle(head - Vector2(3, 3), 2.0, Color(1, 0.95, 0.75, 0.9))


## Where a note's pin is: the middle of its top edge, turned with the note.
static func pin_point(note: Control) -> Vector2:
	return note.position + note.pivot_offset + (Vector2(note.size.x / 2.0, 12.0) - note.pivot_offset).rotated(note.rotation)


## Red string from pin to pin, sagging a little under its own weight.
func _thread(from: Control, to: Control, kind: StringName) -> void:
	var a := pin_point(from)
	var b := pin_point(to)
	var sag := Vector2(0, minf(60.0, a.distance_to(b) * 0.12))
	var points := PackedVector2Array()
	for i in 21:
		var t := i / 20.0
		points.append(a.lerp(b, t) + sag * sin(t * PI))
	var red: Color = COLOURS[&"string"]
	match kind:
		&"led":
			_threads.draw_polyline(points, red.darkened(0.45), 6.0, true)
			_threads.draw_polyline(points, red, 4.0, true)
		&"evidence":
			_threads.draw_polyline(points, Color(red, 0.8), 3.0, true)
		&"planted":
			for i in range(0, points.size() - 1, 2):
				_threads.draw_line(points[i], points[i + 1], red, 3.0, true)
		&"faint":
			_threads.draw_polyline(points, Color(red, 0.4), 2.5, true)


## A few degrees of tilt, always the same for the same note.
static func _tilt(key: String) -> float:
	return float(absi(hash(key)) % 7) - 3.0


## Paper: flat, nearly square corners, a soft shadow under it.
static func _paper(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(2)
	style.shadow_color = Color(0, 0, 0, 0.35) if colour.a > 0.5 else Color(0, 0, 0, 0)
	style.shadow_size = 5
	style.shadow_offset = Vector2(3, 4)
	style.border_color = colour.darkened(0.18)
	style.set_border_width_all(1)
	return style


static func _paper_button(button: Button, colour: Color, solid := true) -> void:
	var style := _paper(colour)
	style.set_content_margin_all(8)
	for look in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(look, style)
	var ink: Color = COLOURS[&"ink"] if solid else Color(0.17, 0.14, 0.1, 0.45)
	for which in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(which, ink)


## The cork: warm brown, flecked (the same flecks every time).
func _draw_cork(cork: Control) -> void:
	cork.draw_rect(Rect2(Vector2.ZERO, size), COLOURS[&"cork"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in int(size.x * size.y / 900.0):
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var light := rng.randf() < 0.4
		cork.draw_circle(at, rng.randf_range(0.8, 2.2), Color("c39465") if light else COLOURS[&"speck"])


## The wooden frame, the title plank on top and the journal plank below.
func _draw_frame(frame: Control) -> void:
	var wood: Color = COLOURS[&"wood"]
	for rect: Rect2 in [Rect2(0, 0, size.x, FRAME), Rect2(0, size.y - FRAME, size.x, FRAME),
			Rect2(0, 0, FRAME, size.y), Rect2(size.x - FRAME, 0, FRAME, size.y)]:
		frame.draw_rect(rect, wood)
	frame.draw_rect(Rect2(Vector2(FRAME, FRAME), size - Vector2(FRAME, FRAME) * 2.0), wood.darkened(0.4), false, 3.0)
	frame.draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), COLOURS[&"wood_light"], false, 3.0)
	_plank(frame, TITLE, Vector2(size.x / 2.0, 4), 20)
	_plank(frame, "CLUES JOURNAL", Vector2(size.x / 2.0, size.y - 34), 15)


func _plank(frame: Control, text: String, top_middle: Vector2, font_size: int) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 40.0
	var rect := Rect2(top_middle - Vector2(width / 2.0, 0), Vector2(width, font_size + 14))
	frame.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35))
	frame.draw_rect(rect, COLOURS[&"wood_light"])
	frame.draw_rect(rect, (COLOURS[&"wood"] as Color).darkened(0.3), false, 2.0)
	for corner: Vector2 in [rect.position + Vector2(8, rect.size.y / 2), rect.end - Vector2(8, rect.size.y / 2)]:
		frame.draw_circle(corner, 2.5, Color("3a2614"))
	frame.draw_string(font, rect.position + Vector2(20, font_size + 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, Color("f3e3c0"))
