class_name RescueScreen
extends OverlayScreen
## The rescue companion in the vet room (Rescues, VetScene): the young animal on the counter
## (or in a fish tank), its three bars (health, fed, calm: they change as you watch, see
## Rescues), its day in care and the four things the ranger does for it by hand: drag the food to its mouth,
## comfort it, put a plaster on its wound, the dropper to its mouth (the buttons below do the
## same, for keyboards and controllers). The first visit names it; egg-layers then hatch; after
## its days in care, the ranger takes it home, tagged.

const TABLE := Color("cfd8dc")
const TABLE_EDGE := Color("90a4ae")
const BAR_COLOURS := {&"health": Color("e05a5a"), &"fed": Color("e8a33a"), &"calm": Color("4aa3df")}

var _feedback := ""
var _live := 0.0


func _enter_tree() -> void:
	add_to_group("rescue_screen")


func _ready() -> void:
	super()
	_title.text = "Rescue"
	_ready_landscape()


## Keeps the bars and buttons up to date while it's open: the fed bar goes down as you watch.
func _process(delta: float) -> void:
	_live -= delta
	if _live > 0.0 or not visible:
		return
	_live = 0.5
	for name: StringName in Rescues.BARS:
		var bar := _content.find_child(String(name), true, false) as ProgressBar
		if bar:
			bar.value = Rescues.bar(name)
	var grid := _content.find_child("Care", true, false)
	if grid:
		for action: StringName in Rescues.ACTIONS:
			var pick := grid.get_node_or_null(String(action).capitalize()) as Button
			if pick:
				pick.disabled = not Rescues.can_do(action)
	var mood := _content.find_child("Mood", true, false) as Label
	if mood:
		mood.text = _mood_text()


## What it needs now, in a line.
func _mood_text() -> String:
	var name := Rescues.pet_name()
	if Rescues.distressed():
		return "%s is hungry and losing strength: comfort it, then feed it." % name
	if Rescues.too_upset_to_eat() and Rescues.bar(&"fed") < 100:
		return "%s is too upset to eat: comfort it first (calm %d of %d)." % [name, Rescues.bar(&"calm"), Rescues.EATS_FROM]
	if Rescues.bar(&"fed") < 100 and Rescues.short_of_funding(&"feed") != "":
		return "%s is hungry. %s: earn some first." % [name, Rescues.short_of_funding(&"feed")]
	if Rescues.bar(&"fed") < 100:
		return "%s is calm and ready to eat." % name
	return "%s is full and content. Its fed bar goes down through the day." % name


func open_rescue() -> void:
	_feedback = ""
	open()


func _ready_landscape() -> void:
	(_content.get_parent() as Control).resized.connect(_fit_room)
	get_viewport().size_changed.connect(func() -> void:
		if visible:
			refresh.call_deferred())  # (turned: the room fits the screen again)


## A phone on its side (or a wide screen): the room fills the screen, the bars inside it.
func _wide() -> bool:
	var view := get_viewport().get_visible_rect().size
	return view.x > view.y * 1.3


## The height the room gets on a wide screen: all of the scrolling page below the title, so
## the bars and everything to drag fit on one screen (the buttons are below it, a scroll away).
## Kept in step with the page's real size (_fit_room): right after the phone turns, the page
## still has the old height.
func _room_height() -> float:
	var scroll := _content.get_parent() as Control
	return maxf(scroll.size.y - 8.0, 240.0)


func _fit_room() -> void:
	var table := _content.get_node_or_null("VetTable") as Control
	if table and table.has_meta("fills_page"):
		var height := _room_height()
		if absf(table.custom_minimum_size.y - height) > 1.0:
			table.custom_minimum_size.y = height


func _fill() -> void:
	var one := Rescues.in_care()
	if not one:
		_title.text = "Rescue"
		_add_text(_feedback if _feedback != "" else "No animal is in your care right now.")
		return
	var species := one.species.display_name.to_lower()
	_title.text = "%s, the young %s" % [Rescues.pet_name(), species] if Rescues.is_named() else "A young %s" % species
	var table := _vet_table(one)
	_content.add_child(table)
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
	var in_room := _wide() and not Rescues.is_ready()
	var room_panel: VBoxContainer = null
	if in_room:
		table.set_meta("fills_page", true)
		table.custom_minimum_size.y = _room_height()
		_fit_room.call_deferred()
		(table.get_node("VetScene") as Control).custom_minimum_size.y = 0.0  # (the table sets the height)
		room_panel = _room_panel(table.get_node("VetScene"))
		var day_line := Label.new()
		day_line.text = "Day %d of %d" % [day, one.days]
		day_line.add_theme_font_size_override("font_size", 15)
		room_panel.add_child(day_line)
		room_panel.add_child(_bars(true))
	else:
		_add_text("Day %d of %d in care: %s is growing a little every day." % [day, one.days, Rescues.pet_name()], 22)
	if day - 1 < one.day_texts.size():
		_add_text(one.day_texts[day - 1].replace("{name}", Rescues.pet_name()))
	if not in_room:
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
		if in_room:
			tip.text = "Drag the things to %s." % ("the tank" if one.tank else "it")
			tip.add_theme_font_size_override("font_size", 12)
			room_panel.add_child(tip)
		else:
			_content.add_child(tip)
		var grid := GridContainer.new()
		grid.name = "Care"
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for action: StringName in Rescues.ACTIONS:
			var label: String = one.get("%s_label" % action)
			if action == &"patch" and Rescues.wounds_left() <= 0:
				continue  # (nothing left to patch: no button)
			if Rescues.cost(action) > 0:
				label += " (%d funding)" % Rescues.cost(action)
			var pick := _button(label, func() -> void:
				_feedback = Rescues.care(action)
				refresh.call_deferred())
			pick.name = String(action).capitalize()
			pick.disabled = not Rescues.can_do(action)
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(pick)
		_content.add_child(grid)
		var mood := Label.new()
		mood.name = "Mood"
		mood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mood.add_theme_color_override("font_color", Color("f2d58a"))
		mood.text = _mood_text()
		if in_room:
			mood.add_theme_font_size_override("font_size", 13)
			room_panel.add_child(mood)
			room_panel.move_child(mood, 2)  # (under the bars, above the drag hint)
		else:
			_content.add_child(mood)
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
	scene.soothed.connect(func() -> void:
		Rescues.care(&"comfort")
		_live = 0.0)  # (the bars catch up at once)
	scene.hint.connect(func(text: String) -> void:
		var tip := _content.find_child("Hint", true, false) as Label
		if tip:
			tip.text = text)
	table.add_child(scene)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return table


## A see-through panel on the room's wall (top left) for the day, the bars and what it needs.
func _room_panel(scene: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "RoomPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.22, 0.78)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size.x = 200  # small: the animal is what matters here
	scene.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_ignore_mouse.call_deferred(panel)  # drags on the room go through it
	return box


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


## Health, fed and calm, 0-100 (updated live: `_process`).
func _bars(compact := false) -> Control:
	var box := VBoxContainer.new()
	box.name = "Bars"
	box.add_theme_constant_override("separation", 3 if compact else 4)
	for name: StringName in Rescues.BARS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6 if compact else 10)
		var label := Label.new()
		label.text = Rescues.BAR_NAMES[name]
		label.custom_minimum_size.x = 52 if compact else 80
		if compact:
			label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.name = String(name)
		bar.max_value = 100
		bar.value = Rescues.bar(name)
		bar.custom_minimum_size = Vector2(130, 14) if compact else Vector2(240, 22)
		if compact:
			bar.add_theme_font_size_override("font_size", 11)
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
