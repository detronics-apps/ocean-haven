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

## A picture of each island as it was when the ranger first got there (before helping it:
## litter and all), for the Observatory: the whole island at full size, sharp enough to zoom in.
## Taken once, never replaced.
## How much of the island's waters the picture takes in (1 = all of them).
const ISLAND_FRAMING := 0.6
## Largest side of the picture, in pixels (the world is drawn 1:1 below this).
const ISLAND_PHOTO_MAX := 2048
## Seconds on an island before its picture is taken (the litter has washed in, the view settled).
const SETTLE_SECONDS := 6.0
const CHECK_EVERY := 3.0
var _island_check := 0.0
var _here := &""
var _here_for := 0.0
var _taking := false


func island_photo_path(region_id: StringName) -> String:
	return "%s/island_%s_arrival.png" % [photos_dir, region_id]


## The picture of `region_id` from the ranger's first visit, or null.
func island_photo(region_id: StringName) -> Texture2D:
	var path := island_photo_path(region_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image else null


func _process(delta: float) -> void:
	_island_check += delta
	if _island_check < CHECK_EVERY:
		return
	_island_check = 0.0
	if get_tree().paused:
		return  # (a menu or a talk is on screen)
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var region := Regions.nearest(ranger.global_position)
	if not Regions.is_discovered(region) or not Regions.in_reach(region, ranger.global_position):
		_here = &""
		return
	if region.id != _here:
		_here = region.id
		_here_for = 0.0
	_here_for += CHECK_EVERY
	if _here_for < SETTLE_SECONDS:
		return
	if not FileAccess.file_exists(island_photo_path(region.id)) and not Regions.helped(get_tree(), region):
		take_island_photo(region)


## Keeps a picture of the whole island now (an offscreen camera over the world, so no menus
## and nothing on screen changes) as `region`'s first-visit picture. False without a screen.
func take_island_photo(region: RegionData) -> bool:
	var viewport := get_viewport()
	if not viewport or DisplayServer.get_name() == "headless" or _taking:
		return false
	_taking = true
	var shot := SubViewport.new()
	var across := region.waters_radius * 2.0 * ISLAND_FRAMING
	var zoom := minf(1.0, ISLAND_PHOTO_MAX / across)  # (1:1 pixels unless the island is huge)
	shot.size = Vector2i(Vector2(across, across * 0.8) * zoom)
	shot.world_2d = viewport.world_2d
	shot.render_target_update_mode = SubViewport.UPDATE_ONCE
	shot.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var camera := Camera2D.new()
	camera.position = region.center
	camera.zoom = Vector2.ONE * zoom
	shot.add_child(camera)
	add_child(shot)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := shot.get_texture().get_image()
	shot.queue_free()
	_taking = false
	if not image or image.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(photos_dir)
	return image.save_png(island_photo_path(region.id)) == OK


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
	var first := not _moments.has(key)
	_moments[key] = true
	if picture:  # the latest photo of it is the one kept
		DirAccess.make_dir_recursive_absolute(photos_dir)
		picture.save_png(_photo_path(animal.id, moment.id))
		_pictures.erase(key)
	if first:
		moment_caught.emit(animal, moment)


## The kept photo of a moment (null if there's none).
func moment_picture(id: StringName, moment_id: StringName) -> Texture2D:
	var key := "%s/%s" % [id, moment_id]
	if _pictures.has(key):
		return _pictures[key]
	var path := _photo_path(id, moment_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	_pictures[key] = ImageTexture.create_from_image(image) if image else null
	return _pictures[key]


## Loaded photos (dropped when a newer one is taken).
var _pictures := {}


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
