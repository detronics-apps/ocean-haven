class_name OverlayScreen
extends CanvasLayer
## A full-screen menu page (Build, Journal): title, scrollable content, Close button.
## Pauses the game while open. Subclasses fill `_content` in `_fill()`, called on every open.

var _title: Label
## Title row, then the scrolling content (subclasses may add rows in between).
var _page: VBoxContainer
var _content: VBoxContainer
var _close: Button


func _ready() -> void:
	layer = 8
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	var background := ColorRect.new()
	background.color = Color("1f3a4d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	margin.add_child(_page)
	var header := HBoxContainer.new()
	_page.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = Button.new()
	_close.text = "Close"
	_close.custom_minimum_size = Vector2(96, 48)
	_close.pressed.connect(close)
	header.add_child(_close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_widen_scroll_bar(scroll.get_v_scroll_bar())
	_page.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)


## A scroll bar wide enough to grab with a finger.
const SCROLL_BAR_WIDTH := 36


static func _widen_scroll_bar(bar: VScrollBar) -> void:
	bar.custom_minimum_size.x = SCROLL_BAR_WIDTH
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(SCROLL_BAR_WIDTH / 2)
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(0.85, 0.92, 1.0, 0.75 if state == "grabber" else 0.95)
		grab.set_corner_radius_all(SCROLL_BAR_WIDTH / 2)
		grab.content_margin_left = SCROLL_BAR_WIDTH / 2.0
		grab.content_margin_right = SCROLL_BAR_WIDTH / 2.0
		bar.add_theme_stylebox_override(state, grab)


func open() -> void:
	refresh()
	visible = true
	get_tree().paused = true
	Sound.play(&"open", -6.0)
	_close.grab_focus()


## Rebuilds the content.
func refresh() -> void:
	for child in _content.get_children():
		child.free()
	_fill()


func close() -> void:
	if visible:
		Sound.play(&"close", -6.0)
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _fill() -> void:
	pass


## A rounded card row: optional picture on the left, text on the right.
## `backdrop`: a light tile behind the picture, so dark animals (cormorants, sharks) show up.
static func card(picture: Texture2D, lines: Array[String], dim := false, backdrop := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = picture
	pic.custom_minimum_size = Vector2(80, 80)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if backdrop and picture:
		row.add_child(light_tile(pic))
	else:
		row.add_child(pic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	for i in lines.size():
		var label := Label.new()
		label.text = lines[i]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == 0:
			label.add_theme_font_size_override("font_size", 20)
		text.add_child(label)
	if dim:
		panel.modulate = Color(1, 1, 1, 0.55)
	return panel


## `child` on a light, rounded tile (pictures of dark animals on the dark menus).
static func light_tile(child: Control) -> PanelContainer:
	var tile := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("dcebf0")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	tile.add_theme_stylebox_override("panel", style)
	tile.add_child(child)
	return tile
