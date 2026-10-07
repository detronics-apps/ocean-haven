class_name TalkBox
extends CanvasLayer
## A talk with someone (People.talk): one speech bubble at a time at the bottom of the screen,
## with their name and job; a tap anywhere shows the next. The game waits while they talk.
## When it's over, any question they asked turns into an objective a moment later.

var _lines: Array[Dictionary] = []
var _at := 0
var _panel: PanelContainer
var _who: Label
var _text: Label
var _more: Label
## The ranger's two replies to pick from (on their lines).
var _choices: HBoxContainer
## The frame it opened on (the key press that opened it doesn't also skip the first line).
var _opened_at := -1


func _enter_tree() -> void:
	add_to_group("talk_box")


func _ready() -> void:
	layer = 7
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	var catcher := Control.new()  # taps anywhere go to the talk, not to walking
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_input)
	add_child(catcher)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24.0
	_panel.offset_right = -24.0
	_panel.offset_top = -210.0
	_panel.offset_bottom = -40.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.97, 0.95, 0.88, 0.97)
	box.border_color = Color("3b3f47")
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 18)
	_who.add_theme_color_override("font_color", Color("8a5a1c"))
	column.add_child(_who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Color("23262c"))
	column.add_child(_text)
	_choices = HBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 16)
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_choices)
	_more = Label.new()
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_font_size_override("font_size", 15)
	_more.add_theme_color_override("font_color", Color("6b6f78"))
	column.add_child(_more)


## Starts a talk with `person`: `lines` from People.talk.
func open(_person: PersonData, lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		People.finish_talk()
		return
	_lines = lines
	_at = 0
	_show()
	visible = true
	_opened_at = Engine.get_process_frames()
	get_tree().paused = true


func is_open() -> bool:
	return visible


## Shows the next line, or ends the talk after the last.
func next() -> void:
	_at += 1
	if _at >= _lines.size():
		close()
	else:
		_show()


func close() -> void:
	visible = false
	get_tree().paused = false
	_lines = []
	People.finish_talk()


func _show() -> void:
	Sound.play(&"talk")
	var line: Dictionary = _lines[_at]
	_who.text = line.who if line.job == "" else "%s · %s" % [line.who, line.job]
	for child in _choices.get_children():
		child.queue_free()
	var options: Array = line.get("options", [])
	_choices.visible = not options.is_empty()
	_text.visible = options.is_empty()
	_more.visible = options.is_empty()
	_text.text = line.text
	_more.text = "Tap to close" if _at == _lines.size() - 1 else "Tap to go on"
	for i in options.size():  # the ranger's reply: pick one
		var pick := Button.new()
		pick.name = "Choice%d" % i
		pick.text = options[i]
		pick.custom_minimum_size = Vector2(220, 64)
		pick.add_theme_font_size_override("font_size", 22)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(choose.bind(i))
		_choices.add_child(pick)
		if i == 0:
			pick.grab_focus.call_deferred()  # (controller and keyboard: pick with the arrows)


## Picks the ranger's reply `index` and goes on.
func choose(index: int) -> void:
	People.chose(_lines[_at], index)
	next()


## Whether the ranger is picking a reply (a tap elsewhere doesn't skip it).
func is_choosing() -> bool:
	return visible and not _lines.is_empty() and not (_lines[_at].get("options", []) as Array).is_empty()


func _on_input(event: InputEvent) -> void:
	if Engine.get_process_frames() == _opened_at:
		return
	if is_choosing():
		return  # pick one of the replies
	# (a tap on a phone arrives as a mouse click, like everywhere else in the game)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		next()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not is_choosing() and Engine.get_process_frames() != _opened_at \
			and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		next()
