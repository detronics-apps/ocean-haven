class_name RescueScreen
extends OverlayScreen
## The rescue companion's screen (Rescues): the young animal in care, how it's doing (its
## stage, growing as it recovers), and today's care moment (a choice between two things; the
## wrong one only explains why not). The first visit names it; when it's ready, the ranger
## releases it. Nothing ever gets worse, and missing a day is fine: the staff look after it.

var _feedback := ""


func _enter_tree() -> void:
	add_to_group("rescue_screen")


func _ready() -> void:
	super()
	_title.text = "Rescue"


func open_rescue() -> void:
	_feedback = ""
	open()


func _fill() -> void:
	var one := Rescues.in_care()
	if not one:
		_title.text = "Rescue"
		_add_text(_feedback if _feedback != "" else "No animal is in your care right now.")
		return
	var species := one.species.display_name.to_lower()
	_title.text = "%s, the young %s" % [Rescues.pet_name(), species] if Rescues.is_named() else "A young %s" % species
	var picture := TextureRect.new()
	picture.texture = one.species.sprite
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grown := clampf(Rescues.days_in() / maxf(one.days, 1.0), 0.0, 1.0)
	picture.custom_minimum_size = Vector2(1, 1) * lerpf(70.0, 150.0, grown)
	_content.add_child(picture)
	if not Rescues.is_named():
		_add_text(one.intro)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var field := LineEdit.new()
		field.name = "NameField"
		field.placeholder_text = "Give it a name"
		field.max_length = 16
		field.custom_minimum_size = Vector2(240, 56)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(field)
		TextPrompt.attach(field, "Give it a name")
		var ok := _button("Name it", func() -> void:
			Rescues.name_it(field.text)
			refresh.call_deferred())
		ok.name = "NameIt"
		row.add_child(ok)
		_content.add_child(row)
		return
	var stage := Rescues.stage_now()
	_add_text("Day %d of %d in care · %s" % [mini(int(Rescues.days_in()) + 1, one.days), one.days, one.stage_names[stage]], 22)
	_add_text(one.stage_texts[stage].replace("{name}", Rescues.pet_name()))
	if Rescues.is_ready():
		_add_text(one.ready_text.replace("{name}", Rescues.pet_name()))
		var go := _button("Release %s" % Rescues.pet_name(), func() -> void:
			var text := one.release_text.replace("{name}", Rescues.pet_name())
			Rescues.release()
			_feedback = text
			refresh.call_deferred())
		go.name = "Release"
		_content.add_child(go)
	elif Rescues.can_care():
		_add_text(one.care_questions[stage].replace("{name}", Rescues.pet_name()), 22)
		var choices := [[one.care_right[stage], true], [one.care_wrong[stage], false]]
		if GameClock.day % 2 == 0:
			choices.reverse()  # (the right one isn't always first)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for choice: Array in choices:
			var pick := _button(choice[0], func() -> void:
				_feedback = Rescues.care(choice[1])
				refresh.call_deferred())
			pick.name = "Right" if choice[1] else "Other"
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pick)
		_content.add_child(row)
	else:
		_add_text("You've helped %s today. Come back tomorrow: the staff look after %s while you're away." % [
			Rescues.pet_name(), Rescues.pet_name()])
	if _feedback != "":
		_add_text(_feedback, 20, Color("f2d58a"))


func _add_text(text: String, size := 18, colour := Color.WHITE) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	_content.add_child(label)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 64)
	button.add_theme_font_size_override("font_size", 20)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	return button
