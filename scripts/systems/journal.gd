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

## Each island as it was made, the same picture for everyone (assets/ui/islands/<id>_start.png,
## rendered by tools/make_start_pictures.gd; RegionData.start_frame is the part of the world
## it shows), with the ranger drawn where they were at the end of their first day there
## (start_spot, saved). The Observatory shows it.
const START_PICTURES := "res://assets/ui/islands/%s_start.png"
## Largest side of a start picture, in pixels (the world is drawn 1:1 below this).
const ISLAND_PHOTO_MAX := 2048
## Region id -> where the ranger was when their first day there ended.
var _start_spots: Dictionary[StringName, Vector2] = {}


func _ready() -> void:
	GameClock.new_day.connect(func(_day: int) -> void: _first_day_ended())


## The day ended: on an island with no spot yet, this is where the ranger's first day ended.
func _first_day_ended() -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var region := Regions.nearest(ranger.global_position)
	if Regions.is_discovered(region) and not _start_spots.has(region.id):
		_start_spots[region.id] = ranger.global_position


## `region_id`'s start picture (null: not made yet).
func start_picture(region_id: StringName) -> Texture2D:
	var path := START_PICTURES % region_id
	return DataFiles.res(path) as Texture2D if ResourceLoader.exists(path) else null


## Where the ranger goes on `region`'s start picture: where their first day there ended (or,
## from before that was kept, where they first arrived).
func start_spot(region: RegionData) -> Vector2:
	if _start_spots.has(region.id):
		return _start_spots[region.id]
	return region.arrival if region.arrival != Vector2.ZERO else region.center


## Renders `region`'s start picture (tools/make_start_pictures.gd): the island as it was made,
## before any of the ranger's changes, in a damaged island's muted colours, with its start
## litter (the same every time: seeded by the island). Returns {"image", "frame"} ({} without
## a screen).
func render_start_picture(region: RegionData) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {}
	seed(String(region.id).hash())
	var island: Node2D = null
	for ground: TileMapLayer in get_tree().get_nodes_in_group("ground"):
		var middle := ground.to_global(ground.map_to_local(ground.get_used_rect().get_center()))
		if Regions.nearest(middle) == region and ground.get_parent().scene_file_path != "":
			island = ground.get_parent()
			break
	if not island:
		return {}
	var copy: Node2D = (DataFiles.res(island.scene_file_path) as PackedScene).instantiate()
	var ecosystem := copy.get_node_or_null("Ecosystem")
	if ecosystem:
		ecosystem.free()
	_just_pictures(copy)
	copy.position = island.global_position
	var ground := copy.get_node_or_null("Ground") as TileMapLayer
	if ground:
		ground.modulate = IslandHealth.DAMAGED_TINT
		# The litter there was when the ranger arrived: on the beaches and floating round it.
		var litter := region.arrival_litter
		if litter <= 0:
			litter = int(island.get_parent().get("start_litter")) if island.get_parent().get("start_litter") != null else 50
		_scatter_litter(copy, ground, region, litter)
	# The few animals there were at the start (the tool renders a new game's world).
	for animal: Node2D in get_tree().get_nodes_in_group("animals"):
		if animal.visible and not animal.get("unborn") and Regions.nearest(animal.global_position) == region:
			var sprite := animal.get_node_or_null("Sprite2D") as Sprite2D
			if sprite:
				var picture := sprite.duplicate() as Sprite2D
				_just_pictures(picture)
				picture.position = sprite.global_position - copy.position
				picture.material = null
				copy.add_child(picture)
	var shot := SubViewport.new()
	shot.world_2d = World2D.new()  # its own world: nothing of the game's sees it
	var start := region.arrival if region.arrival != Vector2.ZERO else region.center
	# Framed round its land and where the ranger arrived.
	var land_ground := island.get_node("Ground") as TileMapLayer
	var used := land_ground.get_used_rect()
	var frame := Rect2(land_ground.to_global(land_ground.map_to_local(used.position)), Vector2.ZERO)
	frame = frame.expand(land_ground.to_global(land_ground.map_to_local(used.end))).expand(start).grow(96.0)
	var zoom := minf(1.0, ISLAND_PHOTO_MAX / maxf(frame.size.x, frame.size.y))
	shot.size = Vector2i(frame.size * zoom)
	shot.render_target_update_mode = SubViewport.UPDATE_ONCE
	shot.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	shot.add_child(copy)
	var camera := Camera2D.new()
	camera.position = frame.get_center()
	camera.zoom = Vector2.ONE * zoom
	shot.add_child(camera)
	add_child(shot)
	camera.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := shot.get_texture().get_image()
	shot.queue_free()
	randomize()
	if not image or image.is_empty():
		return {}
	return {"image": image, "frame": frame}


## `count` pieces of litter drawn on a first-visit picture: some on the beaches, the rest
## floating in the island's waters.
func _scatter_litter(copy: Node2D, ground: TileMapLayer, region: RegionData, count: int) -> void:
	var kinds := DataFiles.load_all("res://data/items").filter(func(i: ItemData) -> bool:
		return i.is_litter and not i.ranger_cleans and i.icon != null)
	if kinds.is_empty():
		return
	var beach: Array[Vector2] = []
	for cell in ground.get_used_cells():
		if ground.get_cell_tile_data(cell).get_custom_data("terrain") == "sand":
			beach.append(copy.position + ground.position + ground.map_to_local(cell))
	var used := ground.get_used_rect()  # (inside the picture's frame: round its land)
	var origin := copy.position + ground.position
	var shown := Rect2(origin + ground.map_to_local(used.position), Vector2.ZERO).expand(origin + ground.map_to_local(used.end)).grow(80.0)
	for i in count:
		var spot := Vector2.INF
		if not beach.is_empty() and randf() < 0.35:
			spot = beach.pick_random() + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		else:
			for attempt in 20:
				var at := region.center + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * region.waters_radius * 0.85
				var cell := ground.local_to_map(at - copy.position - ground.position)
				var tile := ground.get_cell_tile_data(cell)
				if shown.has_point(at) and (not tile or tile.get_custom_data("terrain") == "water"):
					spot = at
					break
		if spot == Vector2.INF:
			continue
		var piece := Sprite2D.new()
		piece.texture = (kinds.pick_random() as ItemData).icon
		piece.position = spot - copy.position  # (a child of the island copy)
		piece.rotation = randf_range(-0.6, 0.6)
		copy.add_child(piece)


## Only its pictures: no scripts, no groups (nothing in the game finds it).
static func _just_pictures(node: Node) -> void:
	for group in node.get_groups():
		node.remove_from_group(group)
	node.set_script(null)
	for child in node.get_children():
		_just_pictures(child)


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
## Photo moments caught (not counting bonus photos).
func moments_caught() -> int:
	var caught := 0
	for animal: AnimalData in DataFiles.load_all("res://data/animals"):
		for moment: PhotoMoment in animal.moments:
			if not moment.bonus and has_moment(animal.id, moment.id):
				caught += 1
	return caught


static func moments_total() -> int:
	var total := 0
	for animal: AnimalData in DataFiles.load_all("res://data/animals"):
		total += animal.moments.filter(func(m: PhotoMoment) -> bool: return not m.bonus).size()
	return total


## How many different species have been photographed.
func photographed_species() -> int:
	return _photos.values().filter(func(n: int) -> bool: return n > 0).size()


func photos(id: StringName) -> int:
	return _photos.get(id, 0)


func help(animal: AnimalData) -> void:
	_helped[animal.id] = helped_count(animal.id) + 1
	helped.emit(animal, _helped[animal.id])


## Every animal the ranger has freed or helped, all kinds together (the Observatory).
func total_helped() -> int:
	var total := 0
	for id in _helped:
		total += _helped[id]
	return total


## Young hatched, all kinds together.
func total_hatched() -> int:
	var total := 0
	for id in _hatched:
		total += _hatched[id]
	return total


## Kinds of animal found.
func found_count() -> int:
	return _found.size()


func helped_count(id: StringName) -> int:
	return _helped.get(id, 0)


## Where the last nest or hatch happened (so notes only show for the ranger's island).
var event_at := Vector2.INF


func record_nest(animal: AnimalData, at := Vector2.INF) -> void:
	_nests[animal.id] = nests(animal.id) + 1
	event_at = at
	nested.emit(animal)


func nests(id: StringName) -> int:
	return _nests.get(id, 0)


func record_hatch(animal: AnimalData, count: int, at := Vector2.INF) -> void:
	_hatched[animal.id] = hatched_count(animal.id) + count
	event_at = at
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
		"plants": _plants.keys(), "moments": _moments.keys(),
		"start_spots": _start_spots.keys().map(func(id: StringName) -> Array: return [String(id), _start_spots[id].x, _start_spots[id].y])}


## Replaces discoveries from a save file (no "new discovery" notes).
## Species are looked up as data/animals/<id>.tres.
func restore(species_ids: Array, saved_details: Dictionary = {}) -> void:
	_found.clear()
	for id in species_ids:
		var path := "res://data/animals/%s.tres" % id
		if ResourceLoader.exists(path):
			_found[StringName(id)] = DataFiles.res(path)
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
	_start_spots.clear()
	for entry in saved_details.get("start_spots", []):
		_start_spots[StringName(entry[0])] = Vector2(float(entry[1]), float(entry[2]))
	_plants.clear()
	for id in saved_details.get("plants", []):
		var plant_path := "res://data/plants/%s.tres" % id
		if ResourceLoader.exists(plant_path):
			_plants[StringName(id)] = DataFiles.res(plant_path)


func _restore_counts(into: Dictionary[StringName, int], saved: Dictionary) -> void:
	into.clear()
	for id in saved:
		into[StringName(id)] = int(saved[id])
