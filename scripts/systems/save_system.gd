extends Node
## Autoload "SaveGame": saves progress to user://save.json and restores it on start.
## Autosaves after progress (collecting, discovering, building), every few seconds,
## and when the game is closed or sent to the background.
## On the web it also keeps a copy in the browser's localStorage, which is written
## instantly (the user:// copy reaches IndexedDB asynchronously, and phones can kill
## a page before that finishes); loading uses whichever copy is newest.

signal saved

const PATH := "user://save.json"
const VERSION := 1
const AUTOSAVE_SECONDS := 10.0
const CODE_PREFIX := "BH1:"

## World debris picked up so far (node names), so it doesn't come back.
var _collected: Array[String] = []
## World animals freed from fishing line (node names), so they stay free.
var _freed: Array[String] = []
## Island trees the ranger cut down (paths from the world), so they stay gone.
var _cut_trees: Array[String] = []
## Tiles the ranger changed (moving sand): "<island>/<ground>" -> {"x,y": [atlas x, atlas y]}.
var _tile_edits: Dictionary = {}
## Every island's own rowboat (not the Starting Island's "Boat", nor built ones): where it is.
func _island_boats(world: Node) -> Dictionary:
	var boats := {}
	for boat: Boat in get_tree().get_nodes_in_group("boat"):
		if boat.get_parent() == world and boat.name != "Boat":
			boats[String(boat.name)] = [boat.global_position.x, boat.global_position.y, boat.controlled]
	return boats


## An extra rowboat the ranger was in (loading).
var _aboard_extra: Boat
var _world: Node
## No save was found when the game started.
var new_game := false
var _dirty := false
var _since_save := 0.0


## Called by the world when it starts. Only the real game world (the main scene)
## is saved: tests and tools that build a world by hand never touch the save.
## Returns whether this is the real game (and so the save is in use).
func attach(world: Node) -> bool:
	if world != get_tree().current_scene:
		return false
	_world = world
	new_game = not load_from(world, PATH)
	Inventory.changed.connect(func(_i, _c): _dirty = true)
	Journal.discovered.connect(func(_a): _dirty = true)
	Journal.observed.connect(func(_a): _dirty = true)
	Journal.photographed.connect(func(_a, _c): _dirty = true)
	Funding.changed.connect(func(_b): _dirty = true)
	Fleet.objective_completed.connect(func(_r, _d): _dirty = true)
	Fleet.upgraded.connect(func(_d, _l): _dirty = true)
	Missions.sent.connect(func(_m): _dirty = true)
	RareEvents.warned.connect(func(_e): _dirty = true)
	People.talked.connect(func(_p): _dirty = true)
	Journal.moment_caught.connect(func(_a, _m): _dirty = true)
	Activities.finished.connect(func(_a, _l, _s, _st): _dirty = true)
	Rescues.found.connect(func(_r): _dirty = true)
	Rescues.released.connect(func(_r, _n): _dirty = true)
	Rescues.cared.connect(func(_r): _dirty = true)
	RareEvents.struck.connect(func(_e, _d): _dirty = true)
	Missions.returned.connect(func(_m, _f): _dirty = true)
	Journal.nested.connect(func(_a): _dirty = true)
	Journal.hatched.connect(func(_a, _c): _dirty = true)
	Journal.gifted.connect(func(_a): _dirty = true)
	RangerProfile.look_changed.connect(func(): _dirty = true)
	(world.get_node("BuildMode") as BuildMode).built.connect(func(_b): _dirty = true)
	return true


func mark_collected(debris: Node) -> void:
	# World litter by name; litter that belongs to something (the wreck) by "<it>/<name>".
	var parent := debris.get_parent()
	_collected.append(String(debris.name) if not parent.is_in_group("wreck_sites")
		else "%s/%s" % [parent.name, debris.name])


func record_tile(ground: TileMapLayer, local_cell: Vector2i, atlas: Vector2i) -> void:
	var key := "%s/%s" % [ground.get_parent().name, ground.name]
	if not _tile_edits.has(key):
		_tile_edits[key] = {}
	_tile_edits[key]["%d,%d" % [local_cell.x, local_cell.y]] = [atlas.x, atlas.y]
	get_tree().call_group("terrain_edges", "cell_changed", ground, local_cell)  # rounded corners
	_dirty = true


## Island trees are recorded as "<island>/<tree>" (e.g. "StarterIsland/Palm3").
func mark_cut(tree: Node) -> void:
	_cut_trees.append("%s/%s" % [tree.get_parent().name, tree.name])
	_dirty = true


## The world's own animals (not hatchlings) that are tangled right now: name -> item id.
func _tangled_animals(world: Node) -> Dictionary:
	var tangles := {}
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.tangled and animal.tangle_item and not animal.young and animal.get_parent() == world:
			tangles[String(animal.name)] = animal.tangle_item.id
	return tangles


func mark_freed(animal: Node) -> void:
	_freed.append(String(animal.name))
	_dirty = true


## Saves at the next frame (e.g. after the sound settings changed).
func request_save() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if not _world:
		return
	_since_save += delta
	if _dirty or _since_save >= AUTOSAVE_SECONDS:
		save_to(_world, PATH)


func _notification(what: int) -> void:
	if _world and what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save_to(_world, PATH)


func save_to(world: Node, path: String) -> bool:
	_dirty = false
	_since_save = 0.0
	var player: Node2D = world.get_node("Player")
	var boat: Boat = world.get_node("Boat")
	var buildings: Array[Dictionary] = []
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		var entry := {"id": building.data.id, "cell": [building.cell.x, building.cell.y],
			"funds": building.pending_funds, "tier": building.tier, "built_day": building.built_day,
			"damaged": building.damaged, "secured": building.secured, "closed": building.gate_closed,
			"stock": building.stock, "loaded": building.loaded, "batch_done_at": building.batch_done_at}
		var extra := building.boat()
		if extra:  # an extra rowboat stays where the ranger left it
			entry["boat"] = [extra.global_position.x, extra.global_position.y]
			entry["aboard"] = extra.controlled
		buildings.append(entry)
	var litter: Array[Dictionary] = []
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.spawned and not debris.is_queued_for_deletion():
			litter.append({"item": debris.item.id, "pos": [debris.position.x, debris.position.y],
				"floating": debris.floating})
	var nests: Array[Dictionary] = []
	for nest: Nest in get_tree().get_nodes_in_group("nests"):
		nests.append({"species": nest.species.id, "pos": [nest.position.x, nest.position.y], "laid_at": nest.laid_at,
			"protected_until": nest.protected_until, "storm_hit": nest.storm_hit})
	var young: Array[Dictionary] = []
	var nest_days := {}
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.leaving:
			continue  # already heading out to sea
		if animal.young or animal.born_at >= 0.0:  # hatched here: growing, or grown up
			young.append({"species": animal.data.id, "pos": [animal.position.x, animal.position.y],
				"home": [animal.home().x, animal.home().y], "born_at": animal.born_at,
				"adult": not animal.young, "radius": animal.home_radius, "last_nest": animal.last_nest_day,
				"injured": animal.injured, "name": String(animal.name),
				"tangled": animal.tangle_item.id if animal.tangled and animal.tangle_item else ""})
		else:
			nest_days[animal.name] = animal.last_nest_day
	var state := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"inventory": Inventory.to_dict(),
		"stored": Inventory.stored_to_dict(),
		"discovered": Journal.ids(),
		"journal": Journal.details(),
		"collected_debris": _collected,
		"freed_animals": _freed,
		"tangled_animals": _tangled_animals(world),
		"injured_animals": get_tree().get_nodes_in_group("animals").filter(func(a: Animal) -> bool:
			return a.injured and a.born_at < 0.0 and a.get_parent() == world).map(func(a: Animal) -> String: return String(a.name)),
		"cut_trees": _cut_trees,
		"tile_edits": _tile_edits,
		"washed_in_litter": litter,
		"funding": Funding.to_dict(),
		"nests": nests,
		"young_animals": young,
		"nest_days": nest_days,
		"tree_nests": _tree_nests(),
		"ecosystems": _ecosystems(world),
		"buildings": buildings,
		"player": [player.global_position.x, player.global_position.y],
		"water_until": ControlledBody.water_until,
		"boat": [boat.global_position.x, boat.global_position.y],
		"aboard": boat.controlled,
		"island_boats": _island_boats(world),
		"day": GameClock.day,
		"time_of_day": GameClock.time_of_day,
		"avatar": RangerProfile.look,
		"avatar_created": RangerProfile.created,
		"ranger_name": RangerProfile.ranger_name,
		"discovered_regions": Regions.discovered_ids(),
		"arrived_animals": Arrivals.arrived_names(),
		"fleet": Fleet.to_dict(),
		"mission": Missions.to_dict(),
		"rare_events": RareEvents.to_dict(),
		"people": People.to_dict(),
		"activities": Activities.to_dict(),
		"rescues": Rescues.to_dict(),
		"litter_collected": Inventory.litter_collected,
		"litter_picked": Inventory.picked.duplicate(),
		"litter_picked_on": Inventory.picked_on.duplicate(),
		"zoom": CameraZoom.level,
		"sound": Sound.save_state(),
	}
	# Desktop: write a temp file then swap it in, so a crash mid-save can't corrupt the save.
	# Web: write the save itself — the browser's storage is only updated when a file is
	# closed after writing (a rename isn't copied over until the next save, and phones
	# close pages abruptly).
	var ok := _write(path, JSON.stringify(state, "\t"))
	saved.emit()
	return ok


func _write(path: String, text: String) -> bool:
	var web := OS.has_feature("web")
	if web:
		_web_backup_write(path, text)
	var target := path if web else path + ".tmp"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if not file:
		push_error("Can't write save: %s" % error_string(FileAccess.get_open_error()))
		return web  # the localStorage copy still counts
	file.store_string(text)
	file.close()
	return web or DirAccess.rename_absolute(target, path) == OK


## The progress as a text code the player can keep somewhere safe (a notes app, an email)
## and paste back later: after the browser cleared its storage, or on another device.
func export_code() -> String:
	if _world:
		save_to(_world, PATH)
	return encode(_newest_save_text(PATH))


static func encode(text: String) -> String:
	return CODE_PREFIX + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


## Replaces the save with a code from export_code() and restarts the world from it.
## Returns false, changing nothing, if the code isn't a readable save.
func import_code(code: String) -> bool:
	var text := decode(code)
	if text == "":
		return false
	_write(PATH, text)
	_world = null  # so the old world isn't autosaved over it
	get_tree().paused = false
	get_tree().reload_current_scene.call_deferred()
	return true


## The save text inside a code, or "" if it isn't one.
static func decode(code: String) -> String:
	var packed := _packed(code)
	if packed.is_empty():
		return ""
	var text := packed.decompress_dynamic(16_000_000, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var state: Variant = JSON.parse_string(text) if text else null
	return text if state is Dictionary and int(state.get("version", -1)) == VERSION else ""


## What's wrong with a pasted code ("" = nothing: it loads).
static func code_problem(code: String) -> String:
	if not code.contains(CODE_PREFIX):
		return "That isn't a BlueHaven save code: a code starts with BH1:"
	var packed := _packed(code)
	if packed.is_empty() or packed.decompress_dynamic(16_000_000, FileAccess.COMPRESSION_GZIP).is_empty():
		return "That code looks cut off: copy all of it (it's one long line), or use Save as file."
	if decode(code) == "":
		return "That save code is from a different version of the game and can't be loaded here."
	return ""


## The bytes in a code: from "BH1:" on, keeping only the code's own letters (a phone or notes app
## may add spaces, line breaks, quotes or invisible characters when copying).
static func _packed(code: String) -> PackedByteArray:
	var at := code.find(CODE_PREFIX)
	if at < 0:
		return PackedByteArray()
	var body := ""
	for c in code.substr(at + CODE_PREFIX.length()):
		if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c in ["+", "/", "="]:
			body += c
	var cut := body.find("=")
	if cut >= 0:  # padding ends it (anything pasted after it isn't part of the code)
		var end := cut
		while end < body.length() and body[end] == "=":
			end += 1
		body = body.substr(0, end)
	while body.length() % 4 != 0:
		body += "="
	return Marshalls.base64_to_raw(body)


## Web: the same save text in localStorage (synchronous, survives abrupt closes).
func _web_backup_write(path: String, text: String) -> void:
	JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (e) {}" % [
		JSON.stringify("bluehaven:" + path), JSON.stringify(text)])


func _web_backup_read(path: String) -> String:
	var text: Variant = JavaScriptBridge.eval(
		"(function () { try { return localStorage.getItem(%s) || ''; } catch (e) { return ''; } })()"
		% JSON.stringify("bluehaven:" + path))
	return text if text is String else ""


## The newest readable save text: the file, or on the web possibly the localStorage copy.
func _newest_save_text(path: String) -> String:
	var file_text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if not OS.has_feature("web"):
		return file_text
	var backup := _web_backup_read(path)
	return backup if _saved_at(backup) > _saved_at(file_text) else file_text


static func _saved_at(text: String) -> float:
	var state: Variant = JSON.parse_string(text) if text else null
	return float(state.get("saved_at", 0.0)) if state is Dictionary else -1.0


## Restores progress into `world`. Returns false if there's no usable save
## (a damaged one is kept as <path>.bad rather than overwritten).
func load_from(world: Node, path: String) -> bool:
	_collected.clear()
	_freed.clear()
	_cut_trees.clear()
	_tile_edits = {}
	var text := _newest_save_text(path)
	if text == "":
		return false
	var state: Variant = JSON.parse_string(text)
	if not state is Dictionary or state.get("version") != VERSION:
		push_warning("Save file unreadable; kept as %s.bad and starting fresh." % path)
		DirAccess.rename_absolute(path, path + ".bad")
		return false

	RangerProfile.restore(state.get("avatar", {}), state.get("avatar_created", false), str(state.get("ranger_name", "")))
	Regions.restore(state.get("discovered_regions", []))
	Fleet.restore(state.get("fleet", {}))
	Missions.restore(state.get("mission", {}))
	RareEvents.restore(state.get("rare_events", {}))
	People.restore(state.get("people", {}))
	Activities.restore(state.get("activities", {}))
	Rescues.restore(state.get("rescues", {}))
	GameClock.day = int(state.get("day", 1))
	GameClock.time_of_day = float(state.get("time_of_day", 0.3))
	_tile_edits = state.get("tile_edits", {})
	for ground_path: String in _tile_edits:  # before buildings, so decks sit on the right tiles
		var ground := world.get_node_or_null(ground_path) as TileMapLayer
		if not ground:
			continue
		for key: String in _tile_edits[ground_path]:
			var xy := key.split(",")
			var atlas: Array = _tile_edits[ground_path][key]
			ground.set_cell(Vector2i(int(xy[0]), int(xy[1])), 0, Vector2i(int(atlas[0]), int(atlas[1])))
	get_tree().call_group("terrain_edges", "rebuild")  # the changed tiles' rounded corners
	Inventory.restore(state.get("inventory", {}), state.get("stored", {}))
	Inventory.litter_collected = int(state.get("litter_collected", 0))
	Inventory.picked.clear()
	var picked: Dictionary = state.get("litter_picked", {})
	for id in picked:
		Inventory.picked[StringName(id)] = int(picked[id])
	CameraZoom.set_level(float(state.get("zoom", 1.0)))
	Sound.load_state(state.get("sound", {}))
	Inventory.picked_on.clear()
	var picked_on: Dictionary = state.get("litter_picked_on", {})
	for id in picked_on:
		Inventory.picked_on[StringName(id)] = int(picked_on[id])
	Funding.restore(state.get("funding", {}))
	Journal.restore(state.get("discovered", []), state.get("journal", {}))
	Arrivals.restore(world, state.get("arrived_animals", []))  # before anything refers to them by name
	for animal_name: String in state.get("freed_animals", []):
		_freed.append(animal_name)
		var animal := world.get_node_or_null(animal_name)
		if animal:
			animal.restore_freed()
	var tangles: Dictionary = state.get("tangled_animals", {})
	for animal_name: String in tangles:  # caught again after being freed
		var animal := world.get_node_or_null(animal_name)
		var item_path := "res://data/items/%s.tres" % tangles[animal_name]
		if animal and ResourceLoader.exists(item_path):
			animal.tangle(load(item_path))
	for animal_name: String in state.get("injured_animals", []):  # hurt by a storm, not rescued yet
		var animal := world.get_node_or_null(animal_name)
		if animal:
			animal.injure()
	for debris_name: String in state.get("collected_debris", []):
		_collected.append(debris_name)
		var debris := world.get_node_or_null(debris_name)
		if debris:
			debris.queue_free()
	for tree_path: String in state.get("cut_trees", []):
		_cut_trees.append(tree_path)
		var tree := world.get_node_or_null(tree_path)
		if tree:
			tree.queue_free()
	var spawner: LitterSpawner = world.get_node("LitterSpawner")
	for entry: Dictionary in state.get("washed_in_litter", []):
		var item_path := "res://data/items/%s.tres" % entry.get("item", "")
		var pos: Array = entry.get("pos", [])
		if ResourceLoader.exists(item_path) and pos.size() == 2:
			spawner.spawn_at(load(item_path), Vector2(pos[0], pos[1]), bool(entry.get("floating", true)))
	for animal_name: String in state.get("nest_days", {}):
		var animal := world.get_node_or_null(animal_name)
		if animal:
			animal.last_nest_day = int(state["nest_days"][animal_name])
	for entry: Dictionary in state.get("nests", []):
		var species := _species(entry.get("species", ""))
		var pos: Array = entry.get("pos", [])
		if species and pos.size() == 2:
			var nest: Nest = load(Animal.NEST_SCENE).instantiate()
			nest.species = species
			nest.laid_at = float(entry.get("laid_at", 0.0))
			nest.protected_until = float(entry.get("protected_until", -1.0))
			nest.storm_hit = bool(entry.get("storm_hit", false))
			nest.position = Vector2(pos[0], pos[1])
			world.add_child(nest)
			world.move_child(nest, world.get_node("Player").get_index())
	for entry: Dictionary in state.get("young_animals", []):
		var species := _species(entry.get("species", ""))
		var pos: Array = entry.get("pos", [])
		var home: Array = entry.get("home", pos)
		if species and pos.size() == 2 and home.size() == 2:
			var baby: Animal = load(Nest.ANIMAL_SCENE).instantiate()
			baby.data = species
			baby.young = not entry.get("adult", false)
			baby.born_at = float(entry.get("born_at", 0.0))  # older saves: old enough to grow up now
			baby.home_radius = float(entry.get("radius", baby.home_radius))
			baby.last_nest_day = int(entry.get("last_nest", -99))
			baby.injured = bool(entry.get("injured", false))
			if entry.get("name", "") != "" and not world.has_node(String(entry.name)):
				baby.name = String(entry.name)  # (tree nests and the like find it by name)
			world.add_child(baby)
			world.move_child(baby, world.get_node("Player").get_index())
			baby.restore_young(Vector2(pos[0], pos[1]), Vector2(home[0], home[1]))
			var caught_in := "res://data/items/%s.tres" % entry.get("tangled", "")
			if entry.get("tangled", "") != "" and ResourceLoader.exists(caught_in):
				baby.tangle(load(caught_in))
	var build_mode: BuildMode = world.get_node("BuildMode")
	for entry: Dictionary in state.get("buildings", []):
		var data_path := "res://data/buildings/%s.tres" % entry.get("id", "")
		var cell: Array = entry.get("cell", [])
		if ResourceLoader.exists(data_path) and cell.size() == 2:
			var building := build_mode.add_building(load(data_path), Vector2i(int(cell[0]), int(cell[1])))
			building.add_funds(int(entry.get("funds", 0)))
			building.tier = int(entry.get("tier", 1))
			building.built_day = int(entry.get("built_day", -100))  # older saves: palms fully grown
			building.damaged = bool(entry.get("damaged", false))
			building.secured = bool(entry.get("secured", false))
			building.gate_closed = bool(entry.get("closed", false))
			building.stock = int(entry.get("stock", 0))
			building.loaded = int(entry.get("loaded", 0))
			building.batch_done_at = float(entry.get("batch_done_at", -1.0))
			var left: Array = entry.get("boat", [])
			if building.boat() and left.size() == 2:
				building.boat().global_position = Vector2(left[0], left[1])
				if entry.get("aboard", false):
					_aboard_extra = building.boat()
	# Exploration Ships an older version moored for free, with no dock: gone (build your own).
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.must_touch != &"" and not build_mode._touches_building(building.rect(), building.data.must_touch):
			building.remove_from_group("buildings")
			building.queue_free()
	Fleet.check()  # goals already met (e.g. before objectives existed)
	# Exploration Ships built before island objectives, where the objective isn't done yet:
	# removed, and their funding returned.
	var refund := 0
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.needs_objective and Fleet.ship_problem(Regions.nearest(building.global_position)) != "":
			refund += building.data.cost_funding
			building.remove_from_group("buildings")
			building.queue_free()
	if refund > 0:
		Funding.earn(refund, "Exploration Ships now need their island's objective done first (see the Journal). Your ships' funding was returned.")
	# Islands found before the fleet had the upgrade they need: to be explored again.
	var relocked := false
	for region: RegionData in Regions.all():
		if Regions.is_discovered(region) and Fleet.missing_for(region):
			Regions.forget(region)
			relocked = true
	if relocked:
		get_tree().call_group("hud", "show_toast", "Some islands need your fleet's upgrades first. Explore them again once your fleet is ready!")
	if "TurtleSanctuarySite" in state.get("built", []):  # saves from before free placement
		build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(8, -1))
	ControlledBody.water_until = float(state.get("water_until", -1.0))
	var p: Array = state.get("player", [])
	if p.size() == 2:
		(world.get_node("Player") as Node2D).global_position = Vector2(p[0], p[1])
	var b: Array = state.get("boat", [])
	if b.size() == 2:
		(world.get_node("Boat") as Node2D).global_position = Vector2(b[0], b[1])
	var island_boats: Dictionary = state.get("island_boats", {})
	for boat_name: String in island_boats:
		var island_boat := world.get_node_or_null(boat_name) as Boat
		var entry: Array = island_boats[boat_name]
		if island_boat and entry.size() == 3:
			island_boat.global_position = Vector2(entry[0], entry[1])
			if entry[2]:
				_aboard_extra = island_boat
	# Older saves: the ranger's own rowboat sailed along on voyages. It belongs to the
	# Starting Island now (every island has its own).
	var own := world.get_node("Boat") as Boat
	var moved_home := Regions.nearest(own.global_position).id != &"home_island"
	if moved_home:
		var was_at := Regions.nearest(own.global_position)
		own.global_position = (load("res://data/regions/home_island.tres") as RegionData).boat_mooring
		if state.get("aboard", false):  # they were out in it: ashore where they landed
			(world.get_node("Player") as Node2D).global_position = was_at.arrival
	if state.get("aboard", false) and not moved_home:
		own.restore_aboard()
	elif is_instance_valid(_aboard_extra):
		_aboard_extra.restore_aboard()
	_aboard_extra = null
	# Turtles belong to a protection area; relink hatchlings and mothers to the nearest one.
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if (animal.young or animal.born_at >= 0.0 or animal.last_nest_day >= 0) and animal.home_building() != &"":
			animal.link_to_nearest_area()
	var ecosystems: Dictionary = state.get("ecosystems", {})
	for eco_path: String in ecosystems:
		var ecosystem := world.get_node_or_null(eco_path)
		if ecosystem and ecosystem.has_method("restore"):
			ecosystem.restore(ecosystems[eco_path])
	# Seabirds' nests stay in the palms they were in (or moved to).
	var tree_nests: Dictionary = state.get("tree_nests", {})
	for bird_name: String in tree_nests:
		var bird := world.get_node_or_null(bird_name)
		var at: Array = tree_nests[bird_name]
		if bird and bird.has_method("set_nest_tree") and at.size() == 2:
			var palm := PalmTree.free_grown_near(get_tree(), Vector2(at[0], at[1]))
			if palm and palm.global_position.distance_to(Vector2(at[0], at[1])) < 8.0:
				bird.set_nest_tree(palm)
	# On an island that isn't discovered any more: back home.
	var ranger := ControlledBody.active(get_tree())
	var here := Regions.nearest(ranger.global_position if ranger else Vector2.ZERO)
	if not Regions.is_discovered(here):
		VoyageMap.arrive(get_tree(), Regions.all()[0])
	return true


## Each island's ecosystem (e.g. the Kelp Forest's beds), by its path in the world.
func _ecosystems(world: Node) -> Dictionary:
	var saved := {}
	for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
		saved[String(world.get_path_to(ecosystem))] = ecosystem.to_dict()
	return saved


## Bird name -> where its nest tree stands.
func _tree_nests() -> Dictionary:
	var nests := {}
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.data.nests_in_trees and is_instance_valid(animal.nest_tree) and animal.nest_tree.nest_of == animal:
			nests[String(animal.name)] = [animal.nest_tree.global_position.x, animal.nest_tree.global_position.y]
	return nests


func _species(id: String) -> AnimalData:
	var path := "res://data/animals/%s.tres" % id
	return load(path) if id and ResourceLoader.exists(path) else null
