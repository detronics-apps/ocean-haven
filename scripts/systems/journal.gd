extends Node
## Autoload "Journal": what the ranger has learned about each species — discovered,
## quietly observed, photographed, helped (the Ocean Journal's contents).

signal discovered(animal: AnimalData)
signal observed(animal: AnimalData)
signal photographed(animal: AnimalData, count: int)
signal helped(animal: AnimalData, count: int)
signal nested(animal: AnimalData)
signal hatched(animal: AnimalData, count: int)
## An animal helped the ranger (found or dug up litter).
signal gifted(animal: AnimalData)

var _found: Dictionary[StringName, AnimalData] = {}
var _observed: Dictionary[StringName, bool] = {}
var _photos: Dictionary[StringName, int] = {}
var _helped: Dictionary[StringName, int] = {}
var _nests: Dictionary[StringName, int] = {}
var _hatched: Dictionary[StringName, int] = {}
var _gifts: Dictionary[StringName, int] = {}


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


func record_nest(animal: AnimalData) -> void:
	_nests[animal.id] = nests(animal.id) + 1
	nested.emit(animal)


func nests(id: StringName) -> int:
	return _nests.get(id, 0)


func record_hatch(animal: AnimalData, count: int) -> void:
	_hatched[animal.id] = hatched_count(animal.id) + count
	hatched.emit(animal, count)


func hatched_count(id: StringName) -> int:
	return _hatched.get(id, 0)


func record_gift(animal: AnimalData) -> void:
	_gifts[animal.id] = gifts(animal.id) + 1
	gifted.emit(animal)


## How many times this species has found litter for the ranger.
func gifts(id: StringName) -> int:
	return _gifts.get(id, 0)


## Discovered species ids, for the save file.
func ids() -> Array:
	return _found.keys()


## Observations, photos and help counts, for the save file.
func details() -> Dictionary:
	return {"observed": _observed.keys(), "photos": _photos.duplicate(), "helped": _helped.duplicate(),
		"nests": _nests.duplicate(), "hatched": _hatched.duplicate(), "gifts": _gifts.duplicate()}


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
	_restore_counts(_helped, saved_details.get("helped", {}))
	_restore_counts(_nests, saved_details.get("nests", {}))
	_restore_counts(_hatched, saved_details.get("hatched", {}))
	_restore_counts(_gifts, saved_details.get("gifts", {}))


func _restore_counts(into: Dictionary[StringName, int], saved: Dictionary) -> void:
	into.clear()
	for id in saved:
		into[StringName(id)] = int(saved[id])
