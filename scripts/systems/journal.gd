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
