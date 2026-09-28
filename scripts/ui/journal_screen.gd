extends OverlayScreen
## The Ocean Journal: each discovered island's objective (and the discovery it gave),
## then every species in data/animals/. Discovered ones show what you've learned
## (observed, photos, helped); the rest are "???" to find.


func _enter_tree() -> void:
	add_to_group("journal_screen")


func _fill() -> void:
	var species := DataFiles.load_all("res://data/animals")
	var found := species.filter(func(a: AnimalData) -> bool: return Journal.has(a.id)).size()
	_title.text = "Ocean Journal  (%d of %d found)" % [found, species.size()]
	for region: RegionData in Regions.all():
		if Regions.is_discovered(region) and not region.goals.is_empty():
			_content.add_child(_objective(region))
	for animal: AnimalData in species:
		_content.add_child(_entry(animal))
	_content.add_child(_backup_card())


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
	if not Journal.has(animal.id):
		var unknown := card(null, ["???", "Not discovered yet. Keep exploring!"], true)
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
