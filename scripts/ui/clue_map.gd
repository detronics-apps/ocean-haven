class_name ClueMap
extends Control
## The Clue Board as one connected map (docs/CLUE_BOARD.md), in the owner's sections: People,
## Trash, Animals, Places, Storms, Plants, Land & Water, Disturbance and Better ways sit round the
## globe in the middle ("It's all connected", the loading screen's globe, pinned big), Animals at
## the top so the turtle's question (big) starts the board. Each section's notes fan outward from
## its tag; a section shows only once it holds a note (no placeholders). The strings are the links
## between sections, each from a note to the sections its story touches (ClueData.links), every
## section to the globe, and one string off to the side of the globe, across a blank space, to "Who
## created all of this?" (once the end credits have started). Landscape lays the circle a little
## wide, portrait a little tall. Notes say little: a short question, then a short answer (the full
## sentences are in the details, on a tap), and their pictures say the rest: one card for each thing
## seen (ClueData.evidence_pictures), growing as the ranger finds more. Notes in one group
## (ClueData.group: the new trees, the rescues seen again) show as one note. Zoomed right out, one
## string joins two sections that have anything in common; closer in, each note's own strings show.
## Fixed zoom steps (+ / -), drag to pan, tap a slot to zoom to it, tap a card for its details.
## It looks like a cork pin board in a wooden frame: paper notes, tilted a little, pinned with brass
## pins and joined with red string (cream: a question, blue: answered, tan: a field note, ochre:
## the final question).

## The sections, clockwise round the globe from the top (ClueData.section: their ids).
const SECTIONS := [&"animals", &"plants", &"places", &"trash", &"storms", &"better_ways", &"people",
	&"land_water", &"disturbance"]
const SECTION_NAMES := {&"animals": "Animals", &"plants": "Plants", &"places": "Places", &"trash": "Trash",
	&"storms": "Storms", &"better_ways": "Better ways", &"people": "People", &"land_water": "Land & Water",
	&"disturbance": "Disturbance", &"centre": "It's all connected"}
const CARD := Vector2(280, 130)
const GAP := Vector2(40, 30)
const PIN := Vector2(300, 86)

## Zoom steps: 0 = the whole board fits (set on layout), then node and close-up.
var zoom_steps: Array[float] = [0.4, 0.6, 0.9, 1.15]
## Closest zoom, and how much each step zooms in (about 1.5x: no big jump).
const ZOOM_MAX := 1.15
const ZOOM_STEP := 1.5
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
const STRING_PX := 3.5
## The note everything comes together in, and the question after it.
const GLOBE := &"conclusion_globe"
const GLOBE_NOTE := Vector2(440, 360)
## The note the board starts with (the turtle's question), bigger than the rest.
const START_NOTE := Vector2(420, 230)
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
	var strings := Button.new()  # simple (section to section) or detailed (each note's own) strings
	strings.name = "StringsToggle"
	strings.custom_minimum_size = Vector2(0, 48)
	strings.focus_mode = Control.FOCUS_NONE
	_paper_button(strings, Color("e7dcc0"))
	strings.text = _strings_label()
	strings.pressed.connect(func() -> void:
		detailed = not detailed
		strings.text = _strings_label()
		_place_zoom_bar()
		_threads.queue_redraw())
	zoom_bar.add_child(strings)
	zoom_bar.move_child(strings, 0)
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
	var by_section := {}
	var groups_shown := {}
	for one: ClueData in clues.cards():
		if not clues.is_visible(one.id):
			continue
		if one.group != &"":  # (a group shows as one note: its first visible card stands for it)
			if groups_shown.has(one.group):
				continue
			groups_shown[one.group] = true
		by_section[one.section] = by_section.get(one.section, []) + [one]
	# Centres first, round the globe at 0, 0, then shifted to the margin. The circle is as small as
	# it can be with no two sections' notes overlapping (it grows a little at a time until they don't).
	var tag_centres := {}
	var card_centres := {}
	var shape := Vector2(1.0, 0.72) if landscape() else Vector2(0.72, 1.0)
	var radius := 300.0
	for attempt in 60:
		tag_centres.clear()
		card_centres.clear()
		_place_sections(by_section, shape * radius, tag_centres, card_centres)
		if not _overlapping(tag_centres, card_centres):
			break
		radius *= 1.08
	var low := Vector2(INF, INF)
	var high := -low
	for centre: Vector2 in tag_centres.values():
		low = low.min(centre - PIN / 2.0)
		high = high.max(centre + PIN / 2.0)
	for id in card_centres:
		var half := note_size(clues.card(id)) / 2.0
		low = low.min(card_centres[id] - half)
		high = high.max(card_centres[id] + half)
	var margin := Vector2(GAP.x, GAP.y + 40)  # (clear of the frame's title plank)
	for section in tag_centres:
		_pins[section] = _pin(section, tag_centres[section] - PIN / 2.0 - low + margin)
	for id in card_centres:
		var one := clues.card(id)
		_cards[id] = _card(one, card_centres[id] - note_size(one) / 2.0 - low + margin)
	var extent := high - low + margin * 2.0
	_canvas.move_child(_threads, -1)  # (string and pins over the notes)
	if _cards.has(GLOBE):  # (the globe in the middle stays on top of all the string that meets there)
		_canvas.move_child(_cards[GLOBE], -1)
	_threads.size = extent
	_canvas.size = extent
	var inside := size - Vector2(FRAME, FRAME) * 2.0 - Vector2(0, 70)  # (within the frame and planks)
	var fit := clampf(minf(inside.x / _canvas.size.x, inside.y / _canvas.size.y), 0.1, 0.6)
	zoom_steps = [fit]
	while zoom_steps[-1] * ZOOM_STEP < ZOOM_MAX * 0.95:
		zoom_steps.append(zoom_steps[-1] * ZOOM_STEP)
	zoom_steps.append(ZOOM_MAX)
	step = mini(step, zoom_steps.size() - 1)
	_place_zoom_bar()
	_apply_zoom()
	if _focus != &"" and _cards.has(_focus):
		centre_on(_cards[_focus])
	elif step == 0:
		_canvas.position = (size - _canvas.size * _canvas.scale) / 2.0
	_place_detail()
	_threads.queue_redraw()


## Puts every section's heading on the circle (`radius`: its half width and height) and its notes
## round the heading: in the cells of a grid around it, the cell facing away from the globe first,
## then the ones beside it, the side facing the globe last (a big note takes its cell and the two
## next to it).
func _place_sections(by_section: Dictionary, radius: Vector2, tag_centres: Dictionary, card_centres: Dictionary) -> void:
	var cell := CARD + GAP
	for i in SECTIONS.size():
		var section: StringName = SECTIONS[i]
		var cards: Array = by_section.get(section, [])
		if cards.is_empty():
			continue  # (no placeholders: a section shows once it holds a note)
		var angle := deg_to_rad(-90.0 + i * 360.0 / SECTIONS.size())  # Animals at the top, then clockwise
		var out := Vector2(cos(angle), sin(angle))
		var heading: Vector2 = out * radius
		tag_centres[section] = heading
		var spots: Array[Vector2i] = []
		for gy in range(-2, 3):
			for gx in range(-1, 2):
				if Vector2i(gx, gy) != Vector2i.ZERO:
					spots.append(Vector2i(gx, gy))
		var ring := func(spot: Vector2i) -> float:  # (nearest ring first, outward before inward)
			return maxi(absi(spot.x), absi(spot.y)) * 10.0 - Vector2(spot).normalized().dot(out)
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return ring.call(a) < ring.call(b))
		var taken := {}
		var ordered := cards.filter(func(c: ClueData) -> bool: return c.big) + cards.filter(func(c: ClueData) -> bool: return not c.big)
		for one: ClueData in ordered:
			for spot in spots:
				if taken.has(spot) or (one.big and (taken.has(spot + Vector2i(1, 0)) or taken.has(spot - Vector2i(1, 0)))):
					continue
				taken[spot] = true
				if one.big:  # (wider and taller: the cells either side are its too)
					taken[spot + Vector2i(1, 0)] = true
					taken[spot - Vector2i(1, 0)] = true
				var offset := Vector2(spot) * cell
				if one.big:
					offset.y += signf(offset.y) * (START_NOTE.y - CARD.y) / 2.0
				card_centres[one.id] = heading + offset
				break
	# The globe in the middle; the question off to its side, across a blank space.
	for one: ClueData in by_section.get(&"centre", []):
		card_centres[one.id] = Vector2.ZERO if one.kind == &"globe" else Vector2(GLOBE_NOTE.x * 0.5 + CARD.x * 0.9, -GLOBE_NOTE.y * 0.75)


## Clear cork kept between two sections (half of it round each side's notes).
const SECTION_GAP := 90.0


## Whether any two notes or headings from different sections (or the middle) overlap.
func _overlapping(tag_centres: Dictionary, card_centres: Dictionary) -> bool:
	var boxes: Array = []  # [rect, section]
	for section in tag_centres:
		boxes.append([Rect2(tag_centres[section] - PIN / 2.0, PIN).grow(SECTION_GAP), section])
	for id in card_centres:
		var one := Clues.card(id)
		var size := note_size(one)
		boxes.append([Rect2(card_centres[id] - size / 2.0, size).grow(SECTION_GAP), one.section])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i][1] != boxes[j][1] and (boxes[i][0] as Rect2).intersects(boxes[j][0]):
				return true
	return false


## A note's size: the globe and the turtle's starting question are bigger than the rest.
static func note_size(one: ClueData) -> Vector2:
	return GLOBE_NOTE if one.kind == &"globe" else START_NOTE if one.big else CARD


func _pin(section: StringName, at: Vector2) -> Control:
	var pin := Button.new()
	pin.name = "Section_" + String(section)
	pin.position = at
	pin.size = PIN
	pin.focus_mode = Control.FOCUS_NONE
	pin.clip_text = true
	pin.text = SECTION_NAMES[section].to_upper()
	pin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pin.pivot_offset = PIN / 2.0
	pin.rotation_degrees = _tilt(String(section)) * 0.6
	_paper_button(pin, COLOURS[&"tag"])
	pin.add_theme_font_size_override("font_size", 26)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (taps are worked out by the map: drags pan)
	_canvas.add_child(pin)
	return pin


func _card(one: ClueData, at: Vector2) -> Control:
	var state := _state_of(one)
	var panel := Panel.new()  # (fixed size: every card the same, the details panel has the full text)
	panel.name = "Card_" + String(one.id)
	panel.position = at
	var note := note_size(one)
	panel.size = note
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (taps are worked out by the map: drags pan)
	panel.add_theme_stylebox_override("panel", _paper(COLOURS[state]))
	panel.pivot_offset = note / 2.0
	panel.rotation_degrees = _tilt(String(one.id))
	var label := Label.new()
	label.name = "Text"
	label.text = card_text(one)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", COLOURS[&"ink"])
	label.add_theme_font_size_override("font_size", 21)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # (a few words: question or answer)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 14
	label.offset_top = 20  # (below the pin)
	var fan_pictures := pictures_of(one)
	label.offset_right = -14 - (PICTURE - 6.0 if not fan_pictures.is_empty() else 0.0)
	label.offset_bottom = -10
	if one.kind == &"globe":  # the loading screen's globe, pinned up big in full colour, the words under it
		var globe := TextureRect.new()
		globe.texture = one.picture
		globe.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		globe.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		globe.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		globe.position = Vector2(GLOBE_NOTE.x / 2.0 - 130, 28)
		globe.size = Vector2(260, 260)
		globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(globe)
		label.offset_top = GLOBE_NOTE.y - 58
		label.offset_right = -14
		label.add_theme_font_size_override("font_size", 30)
		var pin := Control.new()  # (its own pin: it's on top of the string)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pin.draw.connect(func() -> void: _draw_pin(pin, Vector2(GLOBE_NOTE.x / 2.0, 12.0)))
		panel.add_child(pin)
	elif one.big and one.picture:  # the turtle's question: big words, a big turtle
		var image := TextureRect.new()
		image.texture = one.picture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.position = Vector2(note.x - 168, note.y / 2.0 - 70)
		image.size = Vector2(150, 150)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(image)
		label.offset_right = -176
		label.add_theme_font_size_override("font_size", 30)
		var seen := pictures_of(one, false)  # (what the turtle's story has turned up: the net)
		if not seen.is_empty():
			var fan := _picture_fan(seen)
			fan.position = Vector2(16, note.y - PICTURE - 12)
			panel.add_child(fan)
			label.offset_bottom = -(PICTURE + 14)  # (the words above the picture cards)
	elif one.picture_style == &"tag" and one.picture:
		panel.add_child(_luggage_tag(one.picture))
	elif not fan_pictures.is_empty():
		var fan := _picture_fan(fan_pictures)
		fan.position = note - Vector2(PICTURE + 10, PICTURE + 8)
		panel.add_child(fan)
	panel.set_meta("state", state)
	_canvas.add_child(panel)
	var count: int = Clues.evidence_texts(one).size()
	if count > 0 and state == &"question":
		var badge := Label.new()
		badge.text = "● %d" % count
		badge.add_theme_color_override("font_color", COLOURS[&"string"])
		badge.position = Vector2(10, note.y - 28)
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


## The cards a note stands for: itself, or every visible card of its group.
static func members(one: ClueData) -> Array[ClueData]:
	var list: Array[ClueData] = []
	if one.group == &"":
		list.append(one)
		return list
	for other: ClueData in Clues.cards():
		if other.group == one.group and Clues.is_visible(other.id):
			list.append(other)
	return list


static func _any_answered(one: ClueData) -> bool:
	return members(one).any(func(m: ClueData) -> bool: return Clues.is_answered(m.id))


static func _any_open(one: ClueData) -> bool:
	return members(one).any(func(m: ClueData) -> bool: return Clues.is_open(m.id))


## &"question", &"clue" (a planted detail, no question yet), &"answered" or &"final".
func _state_of(one: ClueData) -> StringName:
	if one.kind == &"final" or one.kind == &"globe":
		return &"final"
	if _any_answered(one):
		return &"answered"
	if not _any_open(one):
		return &"clue"
	return &"question"


## What a note says on the board: its short question, then its short answer (the details have
## the full sentences).
static func card_text(one: ClueData) -> String:
	if one.kind == &"globe":
		return (one.short if one.short != "" else one.clue_text).to_upper()
	if _any_answered(one):
		return one.short if one.short != "" else Clues.statement(one)
	if one.picture_style == &"tag" and one.title == "":
		return ""  # (the tag says it)
	return (one.title if one.title != "" else question_of(one)).to_upper()


## A note's picture cards: its own, then one for each thing seen so far (in the order seen),
## across its group, each picture once.
static func pictures_of(one: ClueData, include_own := true) -> Array:
	var list: Array = []
	for member in members(one):
		if include_own:
			for own in ([member.picture] if member.picture else []) + Array(member.pictures):
				if not own in list:
					list.append(own)
		for id in Clues._state.get(member.id, {}).get("ev", []):
			var seen: Texture2D = member.evidence_pictures.get(id)
			if seen and not seen in list:
				list.append(seen)
	return list


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
	var head := _label(String(SECTION_NAMES.get(one.section, "")).to_upper(), 15, COLOURS[&"string"])
	_detail_text.add_child(head)
	var pictures := pictures_of(one)
	if not pictures.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for picture: Texture2D in pictures:
			var pic := TextureRect.new()
			pic.texture = picture
			pic.custom_minimum_size = Vector2(72, 72)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(pic)
		_detail_text.add_child(row)
	for member in members(one):
		if Clues.is_answered(member.id):
			_detail_text.add_child(_label("You wondered: " + question_of(member), 16, Color("6b5a44")))
			_detail_text.add_child(_label(Clues.statement(member), 22, Color("1f4f73")))
		elif Clues.is_open(member.id):
			_detail_text.add_child(_label(question_of(member), 22, COLOURS[&"ink"]))
		else:
			_detail_text.add_child(_label(member.clue_text, 22, COLOURS[&"ink"]))
		if Clues.is_open(member.id) and Clues.is_found(member.id):
			_detail_text.add_child(_label("Field note: " + member.clue_text, 16, Color("6b5a44")))
		for line in Clues.evidence_texts(member):
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

## Detailed strings (each note's own, when zoomed in) or simple (section to section only). Kept
## while the game runs.
static var detailed := false


static func _strings_label() -> String:
	return "Strings: detailed" if detailed else "Strings: simple"


## The zoom and string buttons, bottom right inside the frame.
func _place_zoom_bar() -> void:
	var bar := get_node("ZoomBar") as Control
	bar.reset_size()
	bar.position = size - bar.get_combined_minimum_size() - Vector2(FRAME, FRAME) - Vector2(8, 8)


## How strong the string is: solid when zoomed right out, fainter the closer in (so the words on
## the notes show through it).
func string_alpha() -> float:
	if step == 0 or zoom_steps.size() < 2:
		return 1.0
	return lerpf(0.4, 0.18, float(step - 1) / maxf(zoom_steps.size() - 2, 1.0))


func _draw_threads() -> void:
	# The links between sections. Simple (and always right out): one string for each two sections
	# with anything in common, tag to tag. Detailed, closer in: from each note to the tag of every
	# section its story touches.
	var joined := {}
	for id in _cards:
		for section: StringName in Clues.card(id).links:
			if not _pins.has(section):
				continue
			if step > 0 and detailed:
				_thread(_cards[id], _pins[section], &"link")
				continue
			var own: StringName = Clues.card(id).section
			var pair := [String(own), String(section)]
			pair.sort()
			if _pins.has(own) and not joined.has(pair):
				joined[pair] = true
				_thread(_pins[own], _pins[section], &"sections")
	# It all comes together: every section joins the globe once it's pinned up; then the question.
	if _cards.has(GLOBE):
		for section in _pins:
			_thread(_pins[section], _cards[GLOBE], &"to_globe")
		for next: String in Clues.card(GLOBE).leads_to:
			if _cards.has(StringName(next)):
				_thread(_cards[GLOBE], _cards[StringName(next)], &"led")
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
	var alpha := string_alpha()
	_threads.draw_polyline(points, Color((COLOURS[&"string"] as Color).darkened(0.45), alpha), width * 1.4, true)
	_threads.draw_polyline(points, Color(COLOURS[&"string"], alpha), width, true)


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
