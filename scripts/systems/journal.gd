extends Node
## Autoload "Journal": species the ranger has discovered (the Ocean Journal's contents).

signal discovered(animal: AnimalData)

var _found: Dictionary[StringName, AnimalData] = {}


func discover(animal: AnimalData) -> void:
	if _found.has(animal.id):
		return
	_found[animal.id] = animal
	discovered.emit(animal)


func has(id: StringName) -> bool:
	return _found.has(id)


## Discovered species ids, for the save file.
func ids() -> Array:
	return _found.keys()


## Replaces discoveries from a save file (no "new discovery" notes).
## Species are looked up as data/animals/<id>.tres.
func restore(species_ids: Array) -> void:
	_found.clear()
	for id in species_ids:
		var path := "res://data/animals/%s.tres" % id
		if ResourceLoader.exists(path):
			_found[StringName(id)] = load(path)
