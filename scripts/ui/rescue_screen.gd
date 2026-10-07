class_name RescueScreen
extends OverlayScreen
## The rescue companion in the vet room (Rescues, VetScene): the young animal on the counter
## (or in a fish tank), its three bars (health, fed, calm: they only ever go up), its day in
## care and the four things the ranger does for it each day by hand: drag the food to its mouth,
## comfort it, put a plaster on its wound, the dropper to its mouth (the buttons below do the
## same, for keyboards and controllers). The first visit names it; egg-layers then hatch; after
## its days in care, the ranger takes it home, tagged.

const TABLE := Color("cfd8dc")
const TABLE_EDGE := Color("90a4ae")
const BAR_COLOURS := {&"health": Color("e05a5a"), &"fed": Color("e8a33a"), &"calm": Color("4aa3df")}

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
	_content.add_child(_vet_table(one))
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
	var day := Rescues.day_now()
	if not Rescues.hatched():
		_add_text("Watch: %s is hatching!" % Rescues.pet_name(), 22, Color("f2d58a"))
		return
	_add_text("Day %d of %d in care: %s is growing a little every day." % [day, one.days, Rescues.pet_name()], 22)
	if day - 1 < one.day_texts.size():
		_add_text(one.day_texts[day - 1].replace("{name}", Rescues.pet_name()))
	_content.add_child(_bars())
	if Rescues.is_ready():
		_add_text(one.ready_text.replace("{name}", Rescues.pet_name()))
		_add_text("%s is %s: the better its shape, the more often you'll see it again." % [
			Rescues.pet_name(), Rescues.shape_text(Rescues.shape())], 18, Color("f2d58a"))
		var go := _button("Take %s home" % Rescues.pet_name(), func() -> void:
			var text := one.release_text.replace("{name}", Rescues.pet_name())
			Rescues.release()
			_feedback = text
			refresh.call_deferred())
		go.name = "Release"
		_content.add_child(go)
	else:
		var tip := Label.new()
		tip.name = "Hint"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color("9fe3ff"))
		tip.text = "Care for %s with your hands: drag the things on the counter to %s (or use the buttons)." % [Rescues.pet_name(), "the tank" if one.tank else "it"]
		_content.add_child(tip)
		var grid := GridContainer.new()
		grid.name = "Care"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for action: StringName in Rescues.ACTIONS:
			var label: String = one.get("%s_label" % action)
			if action == &"patch" and Rescues.wounds_left() <= 0:
				label = "No wounds left to patch"
			var pick := _button(label, func() -> void:
				_feedback = Rescues.care(action)
				refresh.call_deferred())
			pick.name = String(action).capitalize()
			pick.disabled = not Rescues.can_do(action)
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(pick)
		_content.add_child(grid)
		if not Rescues.can_care():
			_add_text("That's everything for today. Come back tomorrow: every day of care makes %s stronger." % Rescues.pet_name())
	if _feedback != "":
		_add_text(_feedback, 20, Color("f2d58a"))


## The vet room: the animal on the counter or in its tank, and the things to care for it with.
func _vet_table(one: RescueData) -> Control:
	var table := PanelContainer.new()
	table.name = "VetTable"
	var style := StyleBoxFlat.new()
	style.bg_color = TABLE
	style.border_color = TABLE_EDGE
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	table.add_theme_stylebox_override("panel", style)
	var scene := VetScene.new()
	scene.name = "VetScene"
	scene.rescue = one
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scene.cared.connect(func(action: StringName) -> void:
		if action != &"":
			_feedback = Rescues.care(action)
		refresh.call_deferred())
	scene.hint.connect(func(text: String) -> void:
		var tip := _content.find_child("Hint", true, false) as Label
		if tip:
			tip.text = text)
	table.add_child(scene)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return table


## Health, fed and calm, 0-100 (they only ever go up).
func _bars() -> Control:
	var box := VBoxContainer.new()
	box.name = "Bars"
	for name: StringName in Rescues.BARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = Rescues.BAR_NAMES[name]
		label.custom_minimum_size.x = 80
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.name = String(name)
		bar.max_value = 100
		bar.value = Rescues.bar(name)
		bar.custom_minimum_size = Vector2(240, 22)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fill := StyleBoxFlat.new()
		fill.bg_color = BAR_COLOURS[name]
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		box.add_child(row)
	return box


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
