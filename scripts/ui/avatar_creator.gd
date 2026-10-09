extends CanvasLayer
## "Create your ranger": a big preview plus a row per choice (< value >).
## Opens on a new game and from the HUD's "Change look" button; pauses the game while open.
## Rows come from RangerProfile.CHOICES, so a new kind of choice needs no UI work.

signal closed

const PREVIEW_SCALE := 7.0
const MARGIN := 12
## Width of one choice row: < value >.
const CHOICE_WIDTH := 232.0

var _values: Dictionary[String, Control] = {}
var _done: Button
var _layout: BoxContainer
var _left: VBoxContainer
var _title: Label
var _name: LineEdit
var _preview_box: Control
var _preview: Node2D
var _grid: GridContainer


func _enter_tree() -> void:
	add_to_group("avatar_creator")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_build()
	RangerProfile.look_changed.connect(_refresh)
	_refresh()


func open() -> void:
	_name.text = RangerProfile.ranger_name
	visible = true
	get_tree().paused = true
	_done.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	RangerProfile.finish_creation()
	closed.emit()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("1f3a4d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)
	_layout = BoxContainer.new()
	_layout.add_theme_constant_override("separation", 16)
	margin.add_child(_layout)

	# Preview side: title, preview, buttons (always on screen).
	_left = VBoxContainer.new()
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_layout.add_child(_left)
	_title = Label.new()
	_title.text = "Create your ranger"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left.add_child(_title)
	_name = LineEdit.new()
	_name.name = "Name"
	_name.placeholder_text = "Your ranger's name"
	_name.max_length = RangerProfile.NAME_LENGTH
	_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.custom_minimum_size = Vector2(0, 48)  # big enough for fingers
	_name.text_changed.connect(RangerProfile.set_ranger_name)
	_name.text_submitted.connect(func(_t: String) -> void: _name.release_focus())
	_left.add_child(_name)
	TextPrompt.attach(_name, "Your ranger's name")
	_preview_box = Control.new()
	_left.add_child(_preview_box)
	_preview = DataFiles.res("res://scenes/player/avatar.tscn").instantiate()
	_preview_box.add_child(_preview)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_left.add_child(buttons)
	var surprise := _button("Surprise me!", RangerProfile.randomize_look)
	surprise.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(surprise)
	_done = _button("Let's go!", close)
	_done.name = "Done"
	_done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_done)

	# Choices: as many columns as fit, scrolling if they don't all fit.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	OverlayScreen._widen_scroll_bar(scroll.get_v_scroll_bar())
	_layout.add_child(scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	for key: String in RangerProfile.CHOICES:
		_grid.add_child(_row(key))
	get_viewport().size_changed.connect(_fit)
	_fit()


## Fits the screen: side by side when wide, preview on top when tall; a smaller
## preview on small screens (phones).
func _fit() -> void:
	var screen := get_viewport().get_visible_rect().size - Vector2.ONE * MARGIN * 2
	_layout.vertical = screen.y > screen.x
	var small := minf(screen.x, screen.y) < 480
	var preview_scale := PREVIEW_SCALE * (0.55 if small else 1.0)
	var width := minf(300.0, screen.x)
	_left.custom_minimum_size.x = width
	_preview_box.custom_minimum_size = Vector2(width, 31.0 * preview_scale)
	_preview.scale = Vector2.ONE * preview_scale
	_preview.position = Vector2(width / 2.0, 30.5 * preview_scale)  # feet at the bottom centre
	_title.add_theme_font_size_override("font_size", 20 if small else 28)
	var grid_width := screen.x - (0.0 if _layout.vertical else width + 16.0)
	_grid.columns = clampi(int(grid_width / (CHOICE_WIDTH + 24.0)), 1, 2)


func _row(key: String) -> Control:
	var row := VBoxContainer.new()
	row.name = "Row_" + key
	var label := Label.new()
	label.text = RangerProfile.CHOICES[key][0]
	row.add_child(label)
	var picker := HBoxContainer.new()
	row.add_child(picker)
	var prev := _button("<", func() -> void: RangerProfile.set_choice(key, RangerProfile.look[key] - 1))
	prev.name = "Prev"
	picker.add_child(prev)
	var value: Control
	if RangerProfile.CHOICES[key][2]:
		value = Label.new()
		(value as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(value as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		value = ColorRect.new()
	value.custom_minimum_size = Vector2(120, 48)
	picker.add_child(value)
	_values[key] = value
	var next := _button(">", func() -> void: RangerProfile.set_choice(key, RangerProfile.look[key] + 1))
	next.name = "Next"
	picker.add_child(next)
	return row


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(56, 48)  # big enough for fingers
	b.pressed.connect(on_press)
	return b


func _refresh() -> void:
	for key in _values:
		var value := _values[key]
		if value is Label:
			(value as Label).text = RangerProfile.pick_name(key)
		else:
			(value as ColorRect).color = RangerProfile.pick(key)
