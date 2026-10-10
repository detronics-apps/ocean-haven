class_name ClueMap
extends Control
## The Clue Board as one connected map (docs/CLUE_BOARD.md §1), round like a mind map (the
## owner's layout): the globe in the middle ("It's all connected", the loading screen's globe), the
## story round it clockwise from the top (the turtle first: where did they go?), each node's notes
## fanning outward from its tag, every node strung to the globe, and one string off to the side of
## the globe, across a blank space, to "Who created all of this?" (once the end credits have
## started). A node shows only once it has a note: no placeholders. Landscape lays the circle out a
## little wide, portrait a little tall. Threads join cards that lead to or wait on each other.
## Fixed zoom steps (+ / -), drag to pan, tap a slot to zoom to it, tap a card for its details.
## It looks like a cork pin board in a wooden frame: paper notes, tilted a little, pinned with brass
## pins and joined with red string (cream: a question, blue: answered, tan: a field note, ochre:
## the final question).

## The slots' titles (0 = the opening, 8 = the final question).
const SLOTS := ["Where did the turtles go?", "There's more out there", "Living things depend on each other",
	"Watch first", "Stop it where it starts", "What we do matters", "One ocean", "We're part of it",
	"It's all connected", "Who created all of this?"]
const CARD := Vector2(280, 130)
const GAP := Vector2(40, 30)
const PIN := Vector2(230, 64)

## Zoom steps: 0 = the whole board fits (set on layout), then node and close-up.
var zoom_steps: Array[float] = [0.4, 0.8, 1.15]
var step := 0

const COLOURS := {
	&"question": Color("f1e6c8"), &"clue": Color("d9c194"), &"answered": Color("9cc3e0"),
	&"final": Color("e9c278"), &"tag": Color("dcc69a"), &"label": Color("f4ead2"),
	&"cork": Color("a8794c"), &"speck": Color("7d5534"), &"wood": Color("6b4426"), &"wood_light": Color("8a5a33"),
	&"ink": Color("2a241c"), &"string": Color("b3262b"), &"brass": Color("c9a24a"),
}
## A note's picture (the game's own picture of the animal or thing), bottom right; several are
## fanned out like a hand of cards.
const PICTURE := 64.0
## The string's width on screen, whatever the zoom (so closer in it's thinner beside the notes).
const STRING_PX := 7.0
## The note everything comes together in, and the question after it.
const GLOBE := &"conclusion_globe"
const GLOBE_NOTE := Vector2(300, 240)
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
	# Centres first, round the globe at 0, 0, then shifted to the margin.
	var tag_centres := {}
	var card_centres := {}
	var radius := Vector2(1100.0, 760.0) if landscape() else Vector2(760.0, 1100.0)
	for slot in 8:
		var cards: Array = by_slot.get(slot, [])
		if cards.is_empty():
			continue  # (no placeholders: a node shows once it has a note)
		var angle := deg_to_rad(-90.0 + slot * 45.0)  # the turtle at the top, then clockwise
		var out := Vector2(cos(angle), sin(angle))
		tag_centres[slot] = out * radius
		# Its notes fan outward from the tag: rows away from the globe, two side by side once there are 4+.
		var across := out.orthogonal()
		var columns := 2 if cards.size() >= 4 else 1
		var row_step := absf(out.x) * (CARD.x + GAP.x) + absf(out.y) * (CARD.y + GAP.y)
		var column_step := absf(across.x) * (CARD.x + GAP.x) + absf(across.y) * (CARD.y + GAP.y)
		var first := absf(out.x) * (PIN.x + CARD.x) / 2.0 + absf(out.y) * (PIN.y + CARD.y) / 2.0 + GAP.y
		for i in cards.size():
			var row := i / columns
			var column := (i % columns) - (columns - 1) / 2.0
			card_centres[cards[i].id] = out * radius + out * (first + row * row_step) + across * column * column_step
	# The globe in the middle; the question off to its side, across a blank space.
	for one: ClueData in by_slot.get(8, []):
		card_centres[one.id] = Vector2.ZERO
	for one: ClueData in by_slot.get(9, []):
		card_centres[one.id] = Vector2(CARD.x * 1.9, -CARD.y * 1.2)
	var low := Vector2(INF, INF)
	var high := -low
	for centre: Vector2 in tag_centres.values():
		low = low.min(centre - PIN / 2.0)
		high = high.max(centre + PIN / 2.0)
	for centre: Vector2 in card_centres.values():
		low = low.min(centre - CARD / 2.0)
		high = high.max(centre + CARD / 2.0)
	var margin := Vector2(GAP.x, GAP.y + 40)  # (clear of the frame's title plank)
	for slot in tag_centres:
		_pins[slot] = _pin(slot, tag_centres[slot] - PIN / 2.0 - low + margin)
	for slot in SLOTS.size():
		for one: ClueData in by_slot.get(slot, []):
			_cards[one.id] = _card(one, card_centres[one.id] - CARD / 2.0 - low + margin)
	var extent := high - low + margin * 2.0
	_canvas.move_child(_threads, -1)  # (string and pins over the notes)
	if _cards.has(GLOBE):  # (the globe in the middle stays on top of all the string that meets there)
		_canvas.move_child(_cards[GLOBE], -1)
	_threads.size = extent
	_canvas.size = extent
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


func _pin(slot: int, at: Vector2) -> Control:
	var pin := Button.new()
	pin.name = "Slot%d" % slot
	pin.position = at
	pin.size = PIN
	pin.focus_mode = Control.FOCUS_NONE
	pin.clip_text = true
	pin.text = SLOTS[slot].to_upper()
	pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pin.pivot_offset = PIN / 2.0
	pin.rotation_degrees = _tilt("slot%d" % slot) * 0.6
	_paper_button(pin, COLOURS[&"tag"])
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
	label.offset_right = -14 - (PICTURE - 6.0 if one.picture or not one.pictures.is_empty() else 0.0)
	label.offset_bottom = -10
	if one.kind == &"globe":  # the loading screen's globe, pinned up big in full colour, the words under it
		panel.position -= (GLOBE_NOTE - CARD) / 2.0
		panel.size = GLOBE_NOTE
		panel.pivot_offset = GLOBE_NOTE / 2.0
		var globe := TextureRect.new()
		globe.texture = one.picture
		globe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		globe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		globe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		globe.position = Vector2(GLOBE_NOTE.x / 2.0 - 75, 26)
		globe.size = Vector2(150, 150)
		globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(globe)
		label.offset_top = GLOBE_NOTE.y - 46
		label.offset_right = -14
		label.add_theme_font_size_override("font_size", 24)
		var pin := Control.new()  # (its own pin: it's on top of the string)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin.draw.connect(func() -> void: _draw_pin(pin, Vector2(GLOBE_NOTE.x / 2.0, 12.0)))
		panel.add_child(pin)
	elif one.picture_style == &"tag" and one.picture:
		panel.add_child(_luggage_tag(one.picture))
	elif one.picture or not one.pictures.is_empty():
		panel.add_child(_picture_fan(([one.picture] if one.picture else []) + Array(one.pictures)))
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


## The game's own pictures, bottom right of a note: one as it is, several fanned out like a hand
## of cards, each on its own little card.
func _picture_fan(pictures: Array) -> Control:
	var fan := Control.new()
	fan.name = "Pictures"
	fan.position = CARD - Vector2(PICTURE + 10, PICTURE + 8)
	fan.size = Vector2(PICTURE, PICTURE)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var count := pictures.size()
	for i in count:
		var spread := i - (count - 1) / 2.0
		var holder: Control = Control.new() if count == 1 else Panel.new()
		holder.size = Vector2(PICTURE, PICTURE) if count == 1 else Vector2(PICTURE * 0.7, PICTURE * 0.9)
		holder.position = (fan.size - holder.size) / 2.0 + Vector2(spread * 9.0, absf(spread) * 3.0)
		holder.pivot_offset = Vector2(holder.size.x / 2.0, holder.size.y)
		holder.rotation_degrees = spread * 13.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if holder is Panel:
			holder.add_theme_stylebox_override("panel", _paper(COLOURS[&"label"]))
		var image := TextureRect.new()
		image.texture = pictures[i]
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(image)
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if count > 1:
			image.offset_left = 3
			image.offset_top = 3
			image.offset_right = -3
			image.offset_bottom = -3
		fan.add_child(holder)
	return fan


## A luggage tag hanging on the note, with `picture` on it (the old net's tag: the hook island).
func _luggage_tag(picture: Texture2D) -> Control:
	var tag := Panel.new()
	tag.name = "Tag"
	tag.size = Vector2(PICTURE * 0.85, PICTURE * 1.1)
	tag.position = CARD - Vector2(tag.size.x + 14, tag.size.y + 4)
	tag.pivot_offset = Vector2(tag.size.x / 2.0, 0)
	tag.rotation_degrees = -12.0
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _paper(Color("e8d3a0"))
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.border_color = Color("8a6a3a")
	style.set_border_width_all(2)
	tag.add_theme_stylebox_override("panel", style)
	var hole := Panel.new()  # (the eyelet the string went through)
	hole.size = Vector2(9, 9)
	hole.position = Vector2(tag.size.x / 2.0 - 4.5, 7)
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color("5a4128")
	ring.set_corner_radius_all(5)
	hole.add_theme_stylebox_override("panel", ring)
	tag.add_child(hole)
	var logo := TextureRect.new()
	logo.texture = picture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.position = Vector2(5, 20)
	logo.size = tag.size - Vector2(10, 26)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(logo)
	return tag


## &"question", &"clue" (a planted detail, no question yet), &"answered" or &"final".
func _state_of(one: ClueData) -> StringName:
	if one.kind == &"final" or one.kind == &"globe":
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
		return one.clue_text.to_upper() if one.kind == &"globe" else one.clue_text
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
	_threads.queue_redraw()  # (the string keeps its width on screen)


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
	# It all comes together: every node joins the globe once it's pinned up.
	if _cards.has(GLOBE):
		for slot in _pins:
			_thread(_pins[slot], _cards[GLOBE], &"to_globe")
	# A brass pin on every note and tag, over the string.
	for note: Control in _cards.values() + _pins.values():
		if note != _cards.get(GLOBE):
			_draw_pin(_threads, pin_point(note))


## A brass pin head at `head`, drawn on `on`.
func _draw_pin(on: CanvasItem, head: Vector2) -> void:
	on.draw_circle(head + Vector2(2, 3), 10.0, Color(0, 0, 0, 0.35))
	on.draw_circle(head, 10.0, (COLOURS[&"brass"] as Color).darkened(0.3))
	on.draw_circle(head - Vector2(1.5, 1.5), 7.0, COLOURS[&"brass"])
	on.draw_circle(head - Vector2(3.5, 3.5), 2.5, Color(1, 0.95, 0.75, 0.9))


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
	# Every string the same, and the same width on screen at every zoom (`kind` only says why it's there).
	var width := STRING_PX / _canvas.scale.x
	_threads.draw_polyline(points, (COLOURS[&"string"] as Color).darkened(0.45), width * 1.4, true)
	_threads.draw_polyline(points, COLOURS[&"string"], width, true)


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
