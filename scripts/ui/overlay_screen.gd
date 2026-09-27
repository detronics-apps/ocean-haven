class_name OverlayScreen
extends CanvasLayer
## A full-screen menu page (Build, Journal): title, scrollable content, Close button.
## Pauses the game while open. Subclasses fill `_content` in `_fill()`, called on every open.

var _title: Label
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
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
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
	page.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)


func open() -> void:
	for child in _content.get_children():
		child.free()
	_fill()
	visible = true
	get_tree().paused = true
	_close.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _fill() -> void:
	pass


## A rounded card row: optional picture on the left, text on the right.
static func card(picture: Texture2D, lines: Array[String], dim := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = picture
	pic.custom_minimum_size = Vector2(80, 80)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
