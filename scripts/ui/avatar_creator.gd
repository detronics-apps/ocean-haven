extends CanvasLayer
## The Avatar Builder (the owner's layout): the ranger in a wooden frame with their name under
## it, tabs (Body, Hair, Headwear, Outfit, Accessories) of picture tiles and colour swatches,
## Surprise me!, Back (undo and close) and Confirm along the bottom. Only the front is
## shown and chosen: the side and back views follow from the same choices (Avatar).
## Opens on a new game and from the HUD's "Look" button; pauses the game while open.

signal closed

const MARGIN := 12.0
const SAGE := Color("cdd8c4")
const WOOD := Color("6b4a2e")
const TAN := Color("c9a57c")
const TILE := Color("bf9b72")
const GOLD := Color("f6c445")
const INK := Color("3b2614")
## Tab -> its look keys (RangerProfile.CHOICES), in order.
const TABS := {
	"Body": ["skin", "eyes"],
	"Hair": ["hair", "hair_colour"],
	"Headwear": ["hat", "hat_colour"],
	"Outfit": ["top", "shirt", "jacket", "jacket_colour", "bottoms", "trousers", "shoes"],
	"Accessories": ["glasses", "pack", "backpack", "badge", "boat"],
	"Controls": [],
}
## The Controls tab: how to play on each kind of device (the game shows no control hints of its
## own, e.g. on the boat).
const CONTROLS := {
	"Phone or tablet": [
		"Tap a spot to walk there; keep your finger down and the ranger follows it.",
		"Tap the boat to get in, and tap it again to go ashore.",
		"The buttons at the bottom right do what's nearby: board, take a photo, free an animal, sleep...",
		"+ and - on the left zoom in and out.",
	],
	"Keyboard": [
		"Arrow keys or W A S D: walk or row.",
		"E, Space or Enter: the most important thing nearby (board, go ashore, take a photo...).",
		"+ and -: zoom in and out.",
	],
	"Controller": [
		"Left stick or D-pad: walk or row.",
		"A: the most important thing nearby.",
	],
}
## What a tile shows of the avatar: [view, centre y (feet at 0), scale]. Head keys by default.
const HEAD := [Avatar.View.FRONT, -27.0, 3.6]
const REGIONS := {
	"top": [Avatar.View.FRONT, -14.0, 4.2], "jacket": [Avatar.View.FRONT, -14.0, 4.2],
	"badge": [Avatar.View.FRONT, -14.0, 4.2], "bottoms": [Avatar.View.FRONT, -6.0, 5.0],
	"shoes": [Avatar.View.FRONT, -3.0, 6.0], "pack": [Avatar.View.BACK, -14.0, 4.0],
}
const TAB_ICONS := {"Body": "skin", "Hair": "hair", "Headwear": "hat", "Outfit": "jacket", "Accessories": "pack"}

var _tab := "Body"
var _before: Dictionary = {}
var _done: Button
var _layout: BoxContainer
var _left: VBoxContainer
var _title: Label
var _subtitle: Label
var _name: LineEdit
var _preview_box: Control
var _preview: Avatar
var _tabs: HBoxContainer
var _content: VBoxContainer
var _margin: MarginContainer
var _small := false


func _enter_tree() -> void:
	add_to_group("avatar_creator")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_build()
	RangerProfile.look_changed.connect(_show_tab)


func open() -> void:
	_before = RangerProfile.look.duplicate()
	_name.text = RangerProfile.ranger_name
	visible = true
	get_tree().paused = true
	_show_tab()
	_done.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	RangerProfile.finish_creation()
	closed.emit()


## Back: the look as it was when the builder opened.
func _back() -> void:
	RangerProfile.set_look(_before)
	close()


func _build() -> void:
	var background := ColorRect.new()
	background.color = SAGE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_margin.add_child(page)

	_title = _label("AVATAR BUILDER", 40, GOLD)
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_constant_override("outline_size", 10)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_title)
	_subtitle = _label("BUILD YOUR CHARACTER", 18, INK)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_subtitle)

	_layout = BoxContainer.new()
	_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_layout.add_theme_constant_override("separation", 14)
	page.add_child(_layout)

	# The ranger in a wooden frame, their name under them.
	_left = VBoxContainer.new()
	_left.add_theme_constant_override("separation", 6)
	_layout.add_child(_left)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(TAN.darkened(0.15), WOOD, 6, 10))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(card)
	var inside := VBoxContainer.new()
	card.add_child(inside)
	_preview_box = Control.new()
	_preview_box.clip_contents = true
	_preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_box.resized.connect(_place_preview)
	inside.add_child(_preview_box)
	_preview = Avatar.new()
	_preview_box.add_child(_preview)
	_name = LineEdit.new()
	_name.name = "Name"
	_name.placeholder_text = "Your ranger's name"
	_name.max_length = RangerProfile.NAME_LENGTH
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size = Vector2(0, 44)  # big enough for fingers
	for state in ["normal", "focus"]:
		_name.add_theme_stylebox_override(state, _box(WOOD.darkened(0.3), WOOD, 2, 6))
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_font_size_override("font_size", 20)
	_name.text_changed.connect(RangerProfile.set_ranger_name)
	_name.text_submitted.connect(func(_t: String) -> void: _name.release_focus())
	inside.add_child(_name)
	TextPrompt.attach(_name, "Your ranger's name")

	# Tabs over the tiles.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 0)
	_layout.add_child(right)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size.y = 54
	right.add_child(tab_scroll)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(_tabs)
	for tab: String in TABS:
		_tabs.add_child(_tab_button(tab))
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(TAN, WOOD, 4, 8))
	right.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	OverlayScreen._widen_scroll_bar(scroll.get_v_scroll_bar())
	panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)

	# Surprise me!, Back and Confirm.
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	page.add_child(bottom)
	var surprise := _button("SURPRISE ME!", Color("8a6a48"), RangerProfile.randomize_look)
	surprise.name = "Surprise"
	surprise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(surprise)
	var back := _button("BACK", Color("e2622b"), _back)
	back.name = "Back"
	bottom.add_child(back)
	_done = _button("CONFIRM", Color("4caf50"), close)
	_done.name = "Done"
	bottom.add_child(_done)

	get_viewport().size_changed.connect(_fit)
	_fit()


## Fits the screen: side by side when wide, the ranger on top when tall; smaller on phones.
func _fit() -> void:
	SafeArea.apply(_margin, MARGIN)
	var screen := get_viewport().get_visible_rect().size
	_layout.vertical = screen.y > screen.x
	_small = minf(screen.x, screen.y) < 520
	_title.add_theme_font_size_override("font_size", 26 if _small else 44)
	_subtitle.visible = not _small or _layout.vertical
	if _layout.vertical:
		_left.custom_minimum_size = Vector2(0, screen.y * 0.3)
	else:
		_left.custom_minimum_size = Vector2(minf(280.0, screen.x * 0.28), 0)
	_place_preview()
	_show_tab()


## The ranger standing in the middle of the frame, as big as it fits.
func _place_preview() -> void:
	var box := _preview_box.size
	if box.y <= 0.0:
		return
	var scale := floorf(minf(box.y / 38.0, box.x / 34.0) * 2.0) / 2.0
	_preview.scale = Vector2.ONE * maxf(scale, 1.0)
	_preview.position = Vector2(box.x / 2.0, box.y / 2.0 + 18.0 * _preview.scale.y)


func _tab_button(tab: String) -> Button:
	var b := Button.new()
	b.name = "Tab_" + tab
	b.text = tab.to_upper()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 16)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.pressed.connect(func() -> void:
		_tab = tab
		_show_tab())
	if TAB_ICONS.has(tab):
		var icon := _avatar_picture(RangerProfile.outfit(), REGIONS.get(TAB_ICONS[tab], HEAD), Vector2(40, 40))
		icon.position = Vector2(6, 5)
		b.add_child(icon)
		b.set_meta("icon", icon)
	return b


## The tiles and swatches of the open tab, the chosen ones outlined in gold.
func _show_tab() -> void:
	if not _content or not visible:
		return
	for b: Button in _tabs.get_children():
		var open := b.name == "Tab_" + _tab
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, _box(TAN if open else TAN.darkened(0.2), WOOD, 4, 6, 50 if b.has_meta("icon") else 0))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
	for child in _content.get_children():
		child.queue_free()
	var outfit := RangerProfile.outfit()
	var tile := Vector2(72, 66) if _small else Vector2(96, 86)
	if _tab == "Controls":
		for device: String in CONTROLS:
			_content.add_child(_label(device.to_upper(), 14, INK))
			for line: String in CONTROLS[device]:
				var l := _label("•  " + line, 16, INK)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_content.add_child(l)
	for key: String in TABS[_tab]:
		if RangerProfile.EARNED.has(key) and not Fleet.has_flag(RangerProfile.EARNED[key]):
			continue
		_content.add_child(_label(String(RangerProfile.CHOICES[key][0]).to_upper(), 14, INK))
		var flow := HFlowContainer.new()
		flow.name = "Row_" + key
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_content.add_child(flow)
		var list: Array = RangerProfile.options.get(RangerProfile.CHOICES[key][1])
		var names_list: String = RangerProfile.CHOICES[key][2]
		for i in list.size():
			var chosen: bool = RangerProfile.look[key] == i
			var b: Button
			if names_list:
				var wearing := outfit.duplicate()
				wearing[key] = list[i]
				if key == "top":
					wearing["jacket"] = null  # (the top itself, not the jacket over it)
				b = _picture_button(wearing, REGIONS.get(key, HEAD), tile, chosen)
				var name_tag := _label(String(RangerProfile.options.get(names_list)[i]), 11, INK)
				name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(name_tag)
			else:
				b = Button.new()
				b.custom_minimum_size = Vector2(44, 44)
				for state in ["normal", "hover", "pressed"]:
					b.add_theme_stylebox_override(state, _box(list[i], GOLD if chosen else WOOD, 4 if chosen else 2, 6))
			b.name = "Choice_%d" % i
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(RangerProfile.set_choice.bind(key, i))
			flow.add_child(b)
	for b: Button in _tabs.get_children():  # (the tab pictures follow the look too)
		if not b.has_meta("icon"):
			continue
		var old: Node = b.get_meta("icon")
		var key: String = TAB_ICONS[String(b.name).trim_prefix("Tab_")]
		var icon := _avatar_picture(outfit, REGIONS.get(key, HEAD), Vector2(40, 40))
		icon.position = Vector2(6, 5)
		b.add_child(icon)
		b.set_meta("icon", icon)
		old.queue_free()


## A tile: part of an avatar wearing `wearing`, framed.
func _picture_button(wearing: Dictionary, region: Array, tile: Vector2, chosen := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = tile
	for state in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(state, _box(TILE, GOLD if chosen else WOOD.lightened(0.15), 4 if chosen else 2, 6))
	b.add_child(_avatar_picture(wearing, region, tile))
	return b


## A clipped window onto an avatar: [view, centre y, scale] of it, centred in `size`.
func _avatar_picture(wearing: Dictionary, region: Array, size: Vector2) -> Control:
	var window := Control.new()
	window.size = size
	window.custom_minimum_size = size
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := Avatar.new()
	look.outfit = wearing
	look.view = region[0]
	var s: float = region[2] * size.y / 86.0
	look.scale = Vector2(s, s)
	look.position = Vector2(size.x / 2.0, size.y / 2.0 - float(region[1]) * s)
	window.add_child(look)
	return window


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, colour: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 52)  # big enough for fingers
	b.add_theme_font_size_override("font_size", 20)
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, _box(colour if state != "pressed" else colour.darkened(0.2), colour.darkened(0.45), 4, 8))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	b.pressed.connect(on_press)
	return b


static func _box(fill: Color, border: Color, width: int, radius: int, left := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(8)
	if left > 0:
		box.content_margin_left = left
	return box
