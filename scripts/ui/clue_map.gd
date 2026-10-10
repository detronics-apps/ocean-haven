class_name ClueMap
extends Control
## The Clue Board as one connected map (docs/CLUE_BOARD.md §1). A spine of 9 slots in reading
## order (the opening, nodes 1-7, the final question), each slot's visible cards in a cluster
## across it, and threads between cards: "led to" (solid), "evidence from" (dotted: a card whose
## evidence or answer waits on another card) and "planted -> payoff" (gold, dashed: leads_to "~id").
## Landscape lays the spine left to right, portrait top to bottom; only the mapping changes.
## Fixed zoom steps (+ / -), drag to pan, tap a slot to zoom to it, tap a card for its details.

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
	&"question": Color("f3e9cf"), &"clue": Color("f6dd8c"), &"answered": Color("8fc6ee"),
	&"final": Color("f2d58a"), &"pin": Color("2f5a73"), &"pin_lit": Color("4f9cc4"),
}

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
	var back := ColorRect.new()
	back.color = Color("173042")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_threads = Control.new()
	_threads.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_threads.draw.connect(_draw_threads)
	_canvas.add_child(_threads)
	var zoom_bar := HBoxContainer.new()
	zoom_bar.position = Vector2(8, 8)
	add_child(zoom_bar)
	for sign in [-1, 1]:
		var button := Button.new()
		button.name = "ZoomOut" if sign < 0 else "ZoomIn"
		button.text = "−" if sign < 0 else "+"
		button.custom_minimum_size = Vector2(52, 52)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: set_step(step + sign))
		zoom_bar.add_child(button)
	_detail = PanelContainer.new()
	_detail.name = "Detail"
	_detail.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("223f52")
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
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
	_threads.size = extent + GAP
	_canvas.size = extent + GAP
	zoom_steps[0] = clampf(minf(size.x / _canvas.size.x, size.y / _canvas.size.y), 0.15, 0.6)
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
	pin.text = ("◯ " if slot == 0 else "★ " if slot == 8 else "%d  " % slot) + (SLOTS[slot] if lit else "…")
	var style := StyleBoxFlat.new()
	style.bg_color = COLOURS[&"pin_lit"] if lit else COLOURS[&"pin"].darkened(0.3)
	style.set_corner_radius_all(32)
	pin.add_theme_stylebox_override("normal", style)
	pin.add_theme_stylebox_override("hover", style)
	pin.add_theme_stylebox_override("pressed", style)
	pin.add_theme_color_override("font_color", Color.WHITE if lit else Color(1, 1, 1, 0.45))
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
	var style := StyleBoxFlat.new()
	style.bg_color = COLOURS[state]
	style.set_corner_radius_all(8)
	style.set_border_width_all(3)
	style.border_color = style.bg_color.darkened(0.35) if state != &"question" else Color("b9a77c")
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Text"
	label.text = card_text(one)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", Color("1c2b36"))
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 10
	label.offset_top = 8
	label.offset_right = -10
	label.offset_bottom = -8
	panel.set_meta("state", state)
	_canvas.add_child(panel)
	var count: int = Clues.evidence_texts(one).size()
	if count > 0 and state == &"question":
		var badge := Label.new()
		badge.text = "● %d" % count
		badge.add_theme_color_override("font_color", Color("6b5a2e"))
		badge.position = Vector2(CARD.x - 52, CARD.y - 30)
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
		return "📌 " + one.clue_text
	return "? " + question_of(one)


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
	var head := _label(SLOTS[one.node], 16, Color("a9c8da"))
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
		_detail_text.add_child(_label("You wondered: " + question_of(one), 16, Color("cfe3ef")))
		_detail_text.add_child(_label(Clues.statement(one), 22, Color("8fc6ee")))
	elif Clues.is_open(id):
		_detail_text.add_child(_label(question_of(one), 22, Color("f3e9cf")))
	else:
		_detail_text.add_child(_label(one.clue_text, 22, Color("f6dd8c")))
	if Clues.is_open(id) and Clues.is_found(id):
		_detail_text.add_child(_label("📌 " + one.clue_text, 16, Color("f6dd8c")))
	for line in Clues.evidence_texts(one):
		_detail_text.add_child(_label("• " + line, 18, Color.WHITE))
	for link in _links(one):
		var chip := Button.new()
		chip.text = link.text
		chip.focus_mode = Control.FOCUS_NONE
		chip.custom_minimum_size = Vector2(0, 44)
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
	if landscape():
		_detail.position = Vector2(size.x * 0.58, 8)
		_detail.size = Vector2(size.x * 0.42 - 8, size.y - 16)
	else:
		_detail.position = Vector2(8, size.y * 0.5)
		_detail.size = Vector2(size.x - 16, size.y * 0.5 - 8)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	return label


# --- Threads ---

func _draw_threads() -> void:
	for a: ClueData in Clues.cards():
		if not _cards.has(a.id):
			continue
		for b: ClueData in Clues.cards():
			if b == a or not _cards.has(b.id):
				continue
			for kind in _thread_kinds(a, b):
				_thread(_cards[a.id], _cards[b.id], kind)
	# Every lit slot joins the final question once it shows (its faint threads).
	if _cards.has(&"final_who"):
		for slot in range(8):
			if (_pins[slot] as Button).text.ends_with("…"):
				continue
			_thread(_pins[slot], _cards[&"final_who"], &"faint")


func _thread(from: Control, to: Control, kind: StringName) -> void:
	var a := from.position + from.size / 2.0
	var b := to.position + to.size / 2.0
	var bend := (b - a).orthogonal().normalized() * minf(80.0, a.distance_to(b) * 0.2)
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(a.lerp(b, t) + bend * sin(t * PI))
	match kind:
		&"led":
			_threads.draw_polyline(points, Color("e9dcc0"), 4.0, true)
		&"evidence":
			for i in range(0, points.size() - 1, 2):
				_threads.draw_line(points[i], points[i + 1], Color("a9c8da"), 3.0, true)
		&"planted":
			for i in range(0, points.size() - 1, 3):
				_threads.draw_line(points[i], points[mini(i + 2, points.size() - 1)], Color("f2d58a"), 4.0, true)
		&"faint":
			_threads.draw_polyline(points, Color(0.95, 0.84, 0.54, 0.25), 2.0, true)
