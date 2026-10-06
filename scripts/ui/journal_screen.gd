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
	_page.add_child(tabs)
	_page.move_child(tabs, 1)  # under the title


## Switches to the Island or Animals tab.
func show_tab(id: StringName) -> void:
	tab = id
	if visible:
		refresh()


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
	if tab == ANIMALS:
		for animal: AnimalData in species:
			_content.add_child(_entry(animal))
		return
	if tab == PLANTS:
		for plant: PlantData in DataFiles.load_all("res://data/plants"):
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
	var rescues := _rescues()
	if rescues:
		_content.add_child(rescues)
	_content.add_child(_backup_card())


## The young animal in the ranger's care, and the ones they've released (their own stories).
func _rescues() -> Control:
	var lines: Array[String] = ["Rescues"]
	var caring := Rescues.in_care()
	if caring and Rescues.is_named():
		lines.append("In your care: %s, %s (day %d of %d)" % [Rescues.pet_name(), caring.species.display_name.to_lower(),
			mini(int(Rescues.days_in()) + 1, caring.days), caring.days])
	for id in Rescues.done:
		var rescue := Rescues.rescue(id)
		if rescue:
			lines.append("Released: %s, %s, on day %d" % [Rescues.done[id].get("name", ""), rescue.species.display_name.to_lower(),
				int(Rescues.done[id].get("day", 0))])
	if lines.size() == 1:
		return null
	var picture: Texture2D = caring.species.sprite if caring else null
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
	var paste := BuildMode._big_button("Load save code", Color("2a78a8"))
	paste.pressed.connect(func() -> void: status.text = _load_code())
	row.add_child(paste)
	box.add_child(status)
	return panel


func _copy_code() -> String:
	var code := SaveGame.export_code()
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"):  # phones may block the clipboard; the box lets you copy it by hand
		JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(
			"Your save code (select all and copy it if it wasn't copied already):"), JSON.stringify(code)])
	return "Save code copied. Paste it somewhere safe, like your notes app."


func _load_code() -> String:
	var code := DisplayServer.clipboard_get()
	if OS.has_feature("web"):
		var answer: Variant = JavaScriptBridge.eval("prompt(%s, '') || ''" % JSON.stringify(
			"Paste your save code. This replaces your current progress."))
		code = answer if answer is String else ""
	if code.strip_edges() == "":
		return ""
	if SaveGame.import_code(code):
		return "Loading your progress..."
	return "That isn't a BlueHaven save code. Copy the whole code, starting with BH1:"


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


func _entry(animal: AnimalData) -> Control:
	if not Journal.in_journal(animal.id):
		var unknown := card(null, ["???", "Spotted, but no photo yet: take one to add it to your Journal." if Journal.has(animal.id)
			else "Not discovered yet. Keep exploring, and take a photo when you find it!"], true)
		unknown.name = "Entry_" + animal.id
		return unknown
	var lines: Array[String] = [animal.display_name, animal.fact]
	if Journal.has_observed(animal.id):
		lines.append("Habitat: %s.  Diet: %s." % [animal.habitat, animal.diet])
	else:
		lines.append("Watch one quietly to learn where it lives and what it eats.")
	var progress := "Photos: %d" % Journal.photos(animal.id)
	if Journal.helped_count(animal.id) > 0:
		progress += "    Helped: %d" % Journal.helped_count(animal.id)
	if Journal.gifts(animal.id) > 0:
		progress += "    Litter found: %d" % Journal.gifts(animal.id)
	if Journal.nests(animal.id) > 0:
		progress += "    Nests: %d    Hatchlings: %d" % [Journal.nests(animal.id), Journal.hatched_count(animal.id)]
	lines.append(progress)
	var entry := card(animal.sprite, lines)
	entry.name = "Entry_" + animal.id
	return entry


func _plant_entry(plant: PlantData) -> Control:
	if not Journal.has_plant(plant.id):
		var unknown := card(null, ["???", "Not discovered yet. Keep exploring!"], true)
		unknown.name = "Plant_" + plant.id
		return unknown
	var entry := card(plant.picture, [plant.display_name, plant.fact, "Grows: %s." % plant.habitat, plant.role])
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
