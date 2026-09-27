extends CanvasLayer
## "Create your ranger": a big preview plus a row per choice (< value >).
## Opens on a new game and from the HUD's "Change look" button; pauses the game while open.
## Rows come from RangerProfile.CHOICES, so a new kind of choice needs no UI work.

const PREVIEW_SCALE := 7.0

var _values: Dictionary[String, Control] = {}
var _done: Button


func _enter_tree() -> void:
	add_to_group("avatar_creator")


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	_build()
	RangerProfile.look_changed.connect(_refresh)
	_refresh()


func open() -> void:
	visible = true
	get_tree().paused = true
	_done.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	RangerProfile.finish_creation()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("1f3a4d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 32)
	margin.add_child(layout)

	# Left: title, preview, buttons.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 300
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(left)
	var title := Label.new()
	title.text = "Create your ranger"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	left.add_child(title)
	var preview_box := Control.new()
	preview_box.custom_minimum_size = Vector2(300, 260)
	left.add_child(preview_box)
	var preview: Node2D = load("res://scenes/player/avatar.tscn").instantiate()
	preview.scale = Vector2.ONE * PREVIEW_SCALE
	preview.position = Vector2(150, 250)  # feet at the bottom centre of the box
	preview_box.add_child(preview)
	left.add_child(_button("Surprise me!", RangerProfile.randomize_look))
	_done = _button("Let's go!", close)
	_done.name = "Done"
	left.add_child(_done)

	# Right: two columns of choices.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(grid)
	for key: String in RangerProfile.CHOICES:
		grid.add_child(_row(key))


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
