extends OverlayScreen
## The Ocean Journal, in tabs. Island: the island the ranger is on now, its health
## and objective (and the discovery it gave), and the save code. Animals: every species in
## data/animals/; discovered ones show what you've learned (observed, photos, helped),
## the rest are "???" to find. Plants: data/plants/ likewise. Ocean (once every fleet
## upgrade is installed): the whole ocean, island by island.

const ISLAND := &"island"
const ANIMALS := &"animals"
const PLANTS := &"plants"
const OCEAN := &"ocean"
const TAB_NAMES := {ISLAND: "This island", ANIMALS: "Animals", PLANTS: "Plants", OCEAN: "Ocean"}

## The tab showing (kept between visits).
var tab := ISLAND
var _tab_buttons := {}
## Animals / Plants: only what's been found (a toggle, kept between visits).
var only_found := false
## The animal whose page is open (null = the list).
var page: AnimalData = null
var _found_toggle: CheckButton


func _enter_tree() -> void:
	add_to_group("journal_screen")


func _ready() -> void:
	super()
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for id: StringName in [ISLAND, ANIMALS, PLANTS, OCEAN]:
		var button := Button.new()
		button.name = "Tab_" + id
		button.text = TAB_NAMES[id]
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(120, 44)
		button.pressed.connect(show_tab.bind(id))
		tabs.add_child(button)
		_tab_buttons[id] = button
	_found_toggle = CheckButton.new()
	_found_toggle.name = "OnlyFound"
	_found_toggle.text = "Only what I've found"
	_found_toggle.focus_mode = Control.FOCUS_NONE
	_found_toggle.toggled.connect(func(on: bool) -> void:
		only_found = on
		refresh())
	tabs.add_child(_found_toggle)
	_page.add_child(tabs)
	_page.move_child(tabs, 1)  # under the title


## Switches to the Island or Animals tab.
func show_tab(id: StringName) -> void:
	tab = id
	page = null
	if visible:
		refresh()


## Opens an animal's own page (its photo moments and what it's like in real life).
func open_animal(animal: AnimalData) -> void:
	tab = ANIMALS
	page = animal
	if visible:
		refresh()
	else:
		open()


## The whole-ocean tab opens once the fleet has every upgrade.
static func ocean_open() -> bool:
	return Fleet.level() >= DataFiles.load_all("res://data/discoveries").size()


func _fill() -> void:
	_tab_buttons[OCEAN].visible = ocean_open()
	if tab == OCEAN and not ocean_open():
		tab = ISLAND
	(_tab_buttons[tab] as Button).set_pressed_no_signal(true)
	var species := DataFiles.load_all("res://data/animals")
	var found := species.filter(func(a: AnimalData) -> bool: return Journal.in_journal(a.id)).size()
	_title.text = "Ocean Journal  (%d of %d found)" % [found, species.size()]
	_found_toggle.visible = tab in [ANIMALS, PLANTS] and page == null
	_found_toggle.set_pressed_no_signal(only_found)
	if tab == ANIMALS:
		if page:
			_animal_page(page)
			return
		for animal: AnimalData in species:
			if not only_found or Journal.in_journal(animal.id):
				_content.add_child(_entry(animal))
		return
	if tab == PLANTS:
		for plant: PlantData in DataFiles.load_all("res://data/plants"):
			if not only_found or Journal.has_plant(plant.id):
				_content.add_child(_plant_entry(plant))
		return
	if tab == OCEAN:
		_ocean()
		return
	var ranger := ControlledBody.active(get_tree())
	var region := Regions.nearest(ranger.global_position if ranger else Vector2.ZERO)
	if not region.health.is_empty():
		_content.add_child(_health(region))
	if not region.goals.is_empty():
		_content.add_child(_objective(region))
	if region.health.is_empty() and region.goals.is_empty():
		_content.add_child(card(region.map_icon, [region.display_name, region.description,
			"Nothing to measure here yet: more is coming to this island soon."]))
	var guesses := _predictions(region)
	if guesses:
		_content.add_child(guesses)
	var seasons := _seasons(region)
	if seasons:
		_content.add_child(seasons)
	var rescues := _rescues()
	if rescues:
		_content.add_child(rescues)
	_content.add_child(_backup_card())


## Predict, then watch: the ranger's guesses here, and what really happened (no score).
func _predictions(region: RegionData) -> Control:
	var list := People.predictions(region.id)
	if list.is_empty():
		return null
	var lines: Array[String] = ["Your predictions"]
	for one in list:
		lines.append("%s asked: %s" % [one.who, one.question])
		lines.append("  You guessed: %s" % one.guess)
		lines.append("  What happened: %s" % one.outcome if one.outcome != "" else "  Still watching...")
	var card_node := card(null, lines)
	card_node.name = "Predictions"
	return card_node


## The island's seasonal moments (data/seasons/): when, and whether the ranger has seen one.
func _seasons(region: RegionData) -> Control:
	var lines: Array[String] = ["Through the year"]
	for event in SeasonEvent.all():
		if event.region != region.id:
			continue
		var seen := Fleet.has_flag(StringName("seen_%s" % event.id))
		lines.append("%s (%s)%s" % [event.title, event.when_text(), ": on now!" if event.is_on() else (": seen" if seen else "")])
		if seen:
			lines.append("  " + event.fact)
	if lines.size() == 1:
		return null
	var card_node := card(null, lines)
	card_node.name = "Seasons"
	return card_node


## The young animal in the ranger's care, and the ones they've released (their own stories).
func _rescues() -> Control:
	var lines: Array[String] = ["Rescues"]
	var caring := Rescues.in_care()
	if caring and Rescues.is_named():
		lines.append("In your care: %s, %s (day %d of %d)" % [Rescues.pet_name(), caring.species.display_name.to_lower(),
			Rescues.day_now(), caring.days])
	for id in Rescues.done:
		var rescue := Rescues.rescue(id)
		if rescue:
			lines.append("Released: %s, %s, on day %d, %s" % [Rescues.done[id].get("name", ""), rescue.species.display_name.to_lower(),
				int(Rescues.done[id].get("day", 0)), Rescues.shape_text(float(Rescues.done[id].get("shape", 0.7)))])
			var seen: Array = Rescues.done[id].get("seen", [])
			if not seen.is_empty():
				lines.append("  Seen since near: %s" % ", ".join(seen.map(func(r: String) -> String:
					return (load("res://data/regions/%s.tres" % r) as RegionData).display_name)))
	if lines.size() == 1:
		return null
	var picture: Texture2D = caring.species.picture() if caring else null
	return card(picture, lines)


## Backing up progress as a save code (see SaveGame.export_code).
func _backup_card() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var note := Label.new()
	note.text = "Keep your progress safe: copy your save code into a notes app now and then. " \
		+ "Load it here if your progress is ever lost, or to carry on on another device."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var copy := BuildMode._big_button("Copy save code", Color("3f8a4a"))
	copy.pressed.connect(func() -> void: status.text = _copy_code())
	row.add_child(copy)
	_code_status = status
	var paste := BuildMode._big_button("Load save code", Color("2a78a8"))
	paste.pressed.connect(func() -> void: status.text = _load_code())
	row.add_child(paste)
	box.add_child(status)
	return panel


func _copy_code() -> String:
	var code := SaveGame.export_code()
	if OS.has_feature("web"):  # a real page box: phones can't be trusted with long text otherwise
		WebCodeBox.show_code(code)
		return "Your save code is in the box: copy it, or save it as a file."
	DisplayServer.clipboard_set(code)
	return "Save code copied. Paste it somewhere safe, like your notes app."


func _load_code() -> String:
	if OS.has_feature("web"):
		WebCodeBox.ask_code()
		_waiting_for_code = true
		return "Paste your save code in the box, then tap Load."
	return _use_code(DisplayServer.clipboard_get())


## Loads a pasted code; says what's wrong with it if it can't.
func _use_code(code: String) -> String:
	if code.strip_edges() == "":
		return "Nothing was pasted."
	var problem := SaveGame.code_problem(code)
	if problem != "":
		return problem
	SaveGame.import_code(code)
	return "Loading your progress..."


## Waiting for the web box to hand over a code.
var _waiting_for_code := false
var _code_check := 0.0
var _code_status: Label


func _process(delta: float) -> void:
	if not _waiting_for_code or not OS.has_feature("web"):
		return
	_code_check -= delta
	if _code_check > 0.0:
		return
	_code_check = 0.3
	var code := WebCodeBox.take()
	if code != "":
		_waiting_for_code = false
		var said := _use_code(code)
		if is_instance_valid(_code_status):
			_code_status.text = said


## How healthy an island is, and what goes into it.
func _health(region: RegionData) -> Control:
	var tree := get_tree()
	var lines: Array[String] = ["%s: island health %d%%" % [
		region.display_name, roundi(IslandHealth.of(tree, region) * 100.0)]]
	for factor: HealthFactor in region.health:
		lines.append("  - " + IslandHealth.describe(tree, region, factor))
	var entry := card(null, lines)
	entry.name = "Health_" + region.id
	return entry


## An island's objective: each goal and how far along it is, then what it gave.
func _objective(region: RegionData) -> Control:
	var done := Fleet.objective_done(region)
	var lines: Array[String] = ["%s: %s" % [region.display_name, region.objective]]
	for goal: ObjectiveGoal in region.goals:
		lines.append("  - " + Fleet.goal_line(region, goal))
	var found := Fleet.discovery(region.discovery)
	if done and found:
		lines.append("Found: %s. %s" % [found.display_name, found.description])
	elif found:
		lines.append("Complete it to find something special, and to build an Exploration Ship here.")
	var entry := card(found.icon if done and found else null, lines)
	entry.name = "Objective_" + region.id
	return entry


## A species in the list: its picture, name and what it does in the game. Tap it for its page.
func _entry(animal: AnimalData) -> Control:
	if not Journal.in_journal(animal.id):
		var unknown := card(null, ["???", "Spotted, but no photo yet: take one to add it to your Journal." if Journal.has(animal.id)
			else "Not discovered yet. Keep exploring, and take a photo when you find it!"], true)
		unknown.name = "Entry_" + animal.id
		return unknown
	var regular := animal.moments.filter(func(m: PhotoMoment) -> bool: return not m.bonus)
	var moments := regular.filter(func(m: PhotoMoment) -> bool: return Journal.has_moment(animal.id, m.id)).size()
	var bonus := animal.moments.any(func(m: PhotoMoment) -> bool: return m.bonus and Journal.has_moment(animal.id, m.id))
	var lines: Array[String] = [animal.display_name, animal.role if animal.role != "" else animal.fact]
	if not regular.is_empty():
		lines.append("Photo moments: %d / %d%s   ›" % [moments, regular.size(), "  + a bonus photo!" if bonus else ""])
	var entry := card(animal.picture(), lines, false, true)
	entry.name = "Entry_" + animal.id
	_tappable(entry, open_animal.bind(animal).call_deferred)
	return entry


## Calls `action` when `control` is tapped (not when the list is dragged to scroll).
func _tappable(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var pressed_at := [Vector2.INF]
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed_at[0] = event.global_position
			elif pressed_at[0].distance_to(event.global_position) < 16.0:
				action.call())


## An animal's own page: its photo moments, then what it's like in real life.
func _animal_page(animal: AnimalData) -> void:
	var back := BuildMode._big_button("‹  All animals", Color("2a78a8"))
	back.name = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void:
		page = null
		refresh.call_deferred())  # (not while the button is still handling its press)
	_content.add_child(back)
	var picture := TextureRect.new()
	picture.texture = animal.picture()
	picture.custom_minimum_size = Vector2(128, 128)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(light_tile(picture))
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = animal.display_name
	title.add_theme_font_size_override("font_size", 26)
	names.add_child(title)
	var role := Label.new()
	role.text = animal.role
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	names.add_child(role)
	head.add_child(names)
	_content.add_child(head)
	if not animal.moments.is_empty():
		var moments := Label.new()
		moments.text = "Photo moments"
		moments.add_theme_font_size_override("font_size", 20)
		_content.add_child(moments)
		_content.add_child(_album(animal))
	var real: Array[String] = ["In real life"]
	if Journal.has_observed(animal.id):
		real.append("Where it lives: %s." % animal.habitat)
		real.append("What it eats: %s." % animal.diet)
	else:
		real.append("Watch one quietly to learn where it lives and what it eats.")
	_content.add_child(card(null, real))
	var facts: Array[String] = ["Did you know?"]
	for fact in [animal.fact, animal.photo_fact, animal.help_fact]:
		if fact != "":
			facts.append("• " + fact)
	_content.add_child(card(null, facts))
	var progress := "Photos: %d" % Journal.photos(animal.id)
	if Journal.helped_count(animal.id) > 0:
		progress += "    Helped: %d" % Journal.helped_count(animal.id)
	if Journal.gifts(animal.id) > 0:
		progress += "    Litter found: %d" % Journal.gifts(animal.id)
	if Journal.nests(animal.id) > 0:
		progress += "    Nests: %d    Hatchlings: %d" % [Journal.nests(animal.id), Journal.hatched_count(animal.id)]
	var mine: Array[String] = ["Your notes", progress]
	_content.add_child(card(null, mine))


## Its photo moments: the kept photo of each one caught, and a hint for the ones still to find.
func _album(animal: AnimalData) -> Control:
	var row := HFlowContainer.new()
	row.name = "Album"
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	for moment: PhotoMoment in animal.moments:
		var caught := Journal.has_moment(animal.id, moment.id)
		if moment.bonus:
			if caught:  # (a bonus photo only shows once taken: nothing to find)
				row.add_child(_bonus_photo(animal, moment))
			continue
		var cell := VBoxContainer.new()
		var picture := TextureRect.new()
		picture.texture = Journal.moment_picture(animal.id, moment.id) if caught else animal.picture()
		if not picture.texture:
			picture.texture = animal.picture()
		picture.custom_minimum_size = Vector2(160, 120)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not caught:
			picture.modulate = Color(0, 0, 0, 0.45)  # a silhouette: still to find
		cell.add_child(light_tile(picture) if not caught or picture.texture == animal.picture() else picture)
		var label := Label.new()
		label.text = moment.title if caught else moment.title + "?"
		label.custom_minimum_size.x = 160
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		label.modulate = Color.WHITE if caught else Color(1, 1, 1, 0.6)
		cell.add_child(label)
		row.add_child(cell)
	return row


## A bonus photo (a seasonal moment) in a gold frame.
func _bonus_photo(animal: AnimalData, moment: PhotoMoment) -> Control:
	var cell := VBoxContainer.new()
	cell.name = "Bonus"
	var frame := PanelContainer.new()
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color("3a2c10")
	gold.border_color = Color("e8b93a")
	gold.set_border_width_all(4)
	gold.set_corner_radius_all(4)
	gold.set_content_margin_all(4)
	frame.add_theme_stylebox_override("panel", gold)
	var picture := TextureRect.new()
	picture.texture = Journal.moment_picture(animal.id, moment.id)
	if not picture.texture:
		picture.texture = animal.picture()
	picture.custom_minimum_size = Vector2(160, 120)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(picture)
	cell.add_child(frame)
	var label := Label.new()
	label.text = "Bonus: " + moment.title
	label.custom_minimum_size.x = 168
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("ffd27a"))
	cell.add_child(label)
	return cell


func _plant_entry(plant: PlantData) -> Control:
	if not Journal.has_plant(plant.id):
		var unknown := card(null, ["???", "Not discovered yet. Keep exploring!"], true)
		unknown.name = "Plant_" + plant.id
		return unknown
	var entry := card(plant.picture, [plant.display_name, plant.role, "Grows: %s." % plant.habitat, plant.fact], false, true)
	entry.name = "Plant_" + plant.id
	return entry


## Every island at a glance, and what the ranger has done across the whole ocean.
func _ocean() -> void:
	var tree := get_tree()
	var species := DataFiles.load_all("res://data/animals")
	var plants := DataFiles.load_all("res://data/plants")
	var helped := 0
	var hatched := 0
	var photos := 0
	for animal: AnimalData in species:
		helped += Journal.helped_count(animal.id)
		hatched += Journal.hatched_count(animal.id)
		photos += Journal.photos(animal.id)
	var total := card(null, ["The whole ocean", "Fleet upgrades: %d of %d. Species found: %d of %d. Plants found: %d of %d." % [
		Fleet.level(), DataFiles.load_all("res://data/discoveries").size(),
		species.filter(func(a: AnimalData) -> bool: return Journal.in_journal(a.id)).size(), species.size(),
		plants.filter(func(p: PlantData) -> bool: return Journal.has_plant(p.id)).size(), plants.size()],
		"Litter collected: %d. Animals helped: %d. Hatchlings: %d. Photos: %d." % [Inventory.litter_collected, helped, hatched, photos]])
	total.name = "OceanTotals"
	_content.add_child(total)
	for region: RegionData in Regions.all():
		if not Regions.is_discovered(region):
			continue
		var health := IslandHealth.of(tree, region)
		var lines: Array[String] = [region.display_name]
		if health >= 0.0:
			lines.append("Health %d%%, heading for %d%%." % [roundi(health * 100.0), roundi(IslandHealth.heading(tree, region) * 100.0)])
		lines.append("Objective: %s." % ("done" if Fleet.objective_done(region) else "not yet") if not region.goals.is_empty() else "")
		var entry := card(region.map_icon, lines)
		entry.name = "Ocean_" + region.id
		_content.add_child(entry)
