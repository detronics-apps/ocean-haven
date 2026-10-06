extends Node
## Autoload "Journal": what the ranger has learned about each species — discovered,
## quietly observed, photographed, helped (the Ocean Journal's contents).

signal discovered(animal: AnimalData)
signal observed(animal: AnimalData)
signal photographed(animal: AnimalData, count: int)
signal helped(animal: AnimalData, count: int)
signal nested(animal: AnimalData)
signal hatched(animal: AnimalData, count: int)
## A plant seen for the first time (PlantData).
signal plant_discovered(plant: PlantData)
## An animal helped the ranger (found or dug up litter).
signal gifted(animal: AnimalData)
## A new photo moment was caught (its first photo is kept).
signal moment_caught(animal: AnimalData, moment: PhotoMoment)

var _found: Dictionary[StringName, AnimalData] = {}
var _observed: Dictionary[StringName, bool] = {}
var _photos: Dictionary[StringName, int] = {}
var _helped: Dictionary[StringName, int] = {}
var _nests: Dictionary[StringName, int] = {}
var _hatched: Dictionary[StringName, int] = {}
var _gifts: Dictionary[StringName, int] = {}
var _plants: Dictionary[StringName, PlantData] = {}
## "species/moment" -> caught (its picture is in PHOTOS, if one could be taken).
var _moments := {}
## Where the kept photos are (one small picture per moment; tests point it elsewhere).
var photos_dir := "user://photos"


func discover(animal: AnimalData) -> void:
	if _found.has(animal.id):
		return
	_found[animal.id] = animal
	discovered.emit(animal)


## Spotted (the ranger has come close to one).
func has(id: StringName) -> bool:
	return _found.has(id)


## In the Ocean Journal: a species only goes in once the ranger has photographed it.
func in_journal(id: StringName) -> bool:
	return photos(id) > 0


func discover_plant(plant: PlantData) -> void:
	if not plant or _plants.has(plant.id):
		return
	_plants[plant.id] = plant
	plant_discovered.emit(plant)


func has_plant(id: StringName) -> bool:
	return _plants.has(id)


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


## Whether the moment `moment_id` of species `id` has been photographed.
func has_moment(id: StringName, moment_id: StringName) -> bool:
	return _moments.has("%s/%s" % [id, moment_id])


## Keeps a new photo moment, and its picture (null: none could be taken, e.g. headless).
func add_moment(animal: AnimalData, moment: PhotoMoment, picture: Image) -> void:
	var key := "%s/%s" % [animal.id, moment.id]
	if _moments.has(key):
		return
	_moments[key] = true
	if picture:
		DirAccess.make_dir_recursive_absolute(photos_dir)
		picture.save_png(_photo_path(animal.id, moment.id))
	moment_caught.emit(animal, moment)


## The kept photo of a moment (null if there's none).
func moment_picture(id: StringName, moment_id: StringName) -> Texture2D:
	var path := _photo_path(id, moment_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image else null


func _photo_path(id: StringName, moment_id: StringName) -> String:
	return "%s/%s_%s.png" % [photos_dir, id, moment_id]


## Photo moments caught, and how many there are, over every species.
func moments_caught() -> int:
	return _moments.size()


static func moments_total() -> int:
	var total := 0
	for animal: AnimalData in DataFiles.load_all("res://data/animals"):
		total += animal.moments.size()
	return total


## How many different species have been photographed.
func photographed_species() -> int:
	return _photos.values().filter(func(n: int) -> bool: return n > 0).size()


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
		"nests": _nests.duplicate(), "hatched": _hatched.duplicate(), "gifts": _gifts.duplicate(),
		"plants": _plants.keys(), "moments": _moments.keys()}


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
	_moments.clear()
	for key in saved_details.get("moments", []):
		_moments[String(key)] = true
	_plants.clear()
	for id in saved_details.get("plants", []):
		var plant_path := "res://data/plants/%s.tres" % id
		if ResourceLoader.exists(plant_path):
			_plants[StringName(id)] = load(plant_path)


func _restore_counts(into: Dictionary[StringName, int], saved: Dictionary) -> void:
	into.clear()
	for id in saved:
		into[StringName(id)] = int(saved[id])
