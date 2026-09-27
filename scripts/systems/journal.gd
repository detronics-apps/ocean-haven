extends Node
## Autoload "Journal": what the ranger has learned about each species — discovered,
## quietly observed, photographed, helped (the Ocean Journal's contents).

signal discovered(animal: AnimalData)
signal observed(animal: AnimalData)
signal photographed(animal: AnimalData, count: int)
signal helped(animal: AnimalData, count: int)

var _found: Dictionary[StringName, AnimalData] = {}
var _observed: Dictionary[StringName, bool] = {}
var _photos: Dictionary[StringName, int] = {}
var _helped: Dictionary[StringName, int] = {}


func discover(animal: AnimalData) -> void:
	if _found.has(animal.id):
		return
	_found[animal.id] = animal
	discovered.emit(animal)


func has(id: StringName) -> bool:
	return _found.has(id)


func observe(animal: AnimalData) -> void:
	if _observed.has(animal.id):
		return
	_observed[animal.id] = true
	observed.emit(animal)


func has_observed(id: StringName) -> bool:
	return _observed.has(id)


func photograph(animal: AnimalData) -> void:
	_photos[animal.id] = photos(animal.id) + 1
	photographed.emit(animal, _photos[animal.id])


func photos(id: StringName) -> int:
	return _photos.get(id, 0)


func help(animal: AnimalData) -> void:
	_helped[animal.id] = helped_count(animal.id) + 1
	helped.emit(animal, _helped[animal.id])


func helped_count(id: StringName) -> int:
	return _helped.get(id, 0)


## Discovered species ids, for the save file.
func ids() -> Array:
	return _found.keys()


## Observations, photos and help counts, for the save file.
func details() -> Dictionary:
	return {"observed": _observed.keys(), "photos": _photos.duplicate(), "helped": _helped.duplicate()}


## Replaces discoveries from a save file (no "new discovery" notes).
## Species are looked up as data/animals/<id>.tres.
func restore(species_ids: Array, saved_details: Dictionary = {}) -> void:
	_found.clear()
	for id in species_ids:
		var path := "res://data/animals/%s.tres" % id
		if ResourceLoader.exists(path):
			_found[StringName(id)] = load(path)
	_observed.clear()
	for id in saved_details.get("observed", []):
		_observed[StringName(id)] = true
	_photos.clear()
	var photo_counts: Dictionary = saved_details.get("photos", {})
	for id in photo_counts:
		_photos[StringName(id)] = int(photo_counts[id])
	_helped.clear()
	var help_counts: Dictionary = saved_details.get("helped", {})
	for id in help_counts:
		_helped[StringName(id)] = int(help_counts[id])
