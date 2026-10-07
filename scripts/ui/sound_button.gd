class_name SoundButton
extends Button
## The speaker in the menu bar: opens a small sound panel under it (sound on / off, music
## volume, sound volume). The speaker shows a cross while the sound is off. The settings
## live in Sound and are saved with the game.

var _panel: PanelContainer
var _mute: Button
var _music: HSlider
var _sounds: HSlider


func _ready() -> void:
	name = "SoundButton"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(52, 44)
	tooltip_text = "Sound"
	pressed.connect(toggle_panel)
	Sound.settings_changed.connect(_refresh)
	_build_panel.call_deferred()


func _draw() -> void:
	var c := size / 2.0 + Vector2(-6, 0)
	var ink := Color(1, 1, 1, 0.92)
	# The speaker: a box and a cone.
	draw_rect(Rect2(c + Vector2(-8, -4), Vector2(5, 8)), ink)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -4), c + Vector2(4, -10), c + Vector2(4, 10), c + Vector2(-3, 4)]), ink)
	if Sound.muted:
		draw_line(c + Vector2(8, -5), c + Vector2(17, 5), Color("ff9a8a"), 3.0)
		draw_line(c + Vector2(8, 5), c + Vector2(17, -5), Color("ff9a8a"), 3.0)
	else:
		var loud := maxf(Sound.music_volume, Sound.sound_volume)
		for i in 3:
			if loud > i / 3.0:
				draw_arc(c + Vector2(4, 0), 6.0 + i * 5.0, -0.8, 0.8, 10, ink, 2.0)


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "SoundPanel"
	_panel.visible = false
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -12.0 - 300.0
	_panel.offset_right = -12.0
	_panel.offset_top = 106.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.16, 0.22, 0.95)
	style.border_color = Color("6fd3e8")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Sound"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	_mute = Button.new()
	_mute.name = "Mute"
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.custom_minimum_size = Vector2(0, 48)
	_mute.pressed.connect(func() -> void: Sound.set_muted(not Sound.muted))
	box.add_child(_mute)
	_music = _slider(box, "Music", Sound.music_volume, Sound.set_music_volume)
	_sounds = _slider(box, "Sounds", Sound.sound_volume, func(value: float) -> void:
		Sound.set_sound_volume(value)
		Sound.play(&"pickup"))  # hear how loud it is
	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size = Vector2(0, 44)
	done.pressed.connect(toggle_panel)
	box.add_child(done)
	get_tree().get_first_node_in_group("hud").add_child(_panel)
	_refresh()


func _slider(box: VBoxContainer, label: String, value: float, changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var text := Label.new()
	text.text = label
	text.custom_minimum_size.x = 70
	row.add_child(text)
	var slider := HSlider.new()
	slider.name = label
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(160, 44)  # a finger-wide strip: a tap anywhere sets it
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.25)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color("6fd3e8")
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	slider.value_changed.connect(changed)
	row.add_child(slider)
	return slider


func toggle_panel() -> void:
	if not _panel:
		return
	_panel.visible = not _panel.visible
	if not _panel.visible:
		SaveGame.request_save()


func panel() -> PanelContainer:
	return _panel


func _refresh() -> void:
	queue_redraw()
	if not _mute:
		return
	_mute.text = "Sound is off - tap to turn it on" if Sound.muted else "Sound is on - tap to turn it off"
	_music.set_value_no_signal(Sound.music_volume)
	_sounds.set_value_no_signal(Sound.sound_volume)
	_music.editable = not Sound.muted
	_sounds.editable = not Sound.muted
