extends OverlayScreen
## The Ocean Journal: every species in data/animals/. Discovered ones show what
## you've learned (observed, photos, helped); the rest are "???" to find.


func _enter_tree() -> void:
	add_to_group("journal_screen")


func _fill() -> void:
	var species := DataFiles.load_all("res://data/animals")
	var found := species.filter(func(a: AnimalData) -> bool: return Journal.has(a.id)).size()
	_title.text = "Ocean Journal  (%d of %d found)" % [found, species.size()]
	for animal: AnimalData in species:
		_content.add_child(_entry(animal))


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
	if Journal.nests(animal.id) > 0:
		progress += "    Nests: %d    Hatchlings: %d" % [Journal.nests(animal.id), Journal.hatched_count(animal.id)]
	lines.append(progress)
	var entry := card(animal.sprite, lines)
	entry.name = "Entry_" + animal.id
	return entry
