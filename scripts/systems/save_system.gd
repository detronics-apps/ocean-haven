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

## World debris picked up so far (node names), so it doesn't come back.
var _collected: Array[String] = []
## World animals freed from fishing line (node names), so they stay free.
var _freed: Array[String] = []
## Island trees the ranger cut down (paths from the world), so they stay gone.
var _cut_trees: Array[String] = []
var _world: Node
var _dirty := false
var _since_save := 0.0


## Called by the world when it starts. Only the real game world (the main scene)
## is saved: tests and tools that build a world by hand never touch the save.
## Returns whether this is the real game (and so the save is in use).
func attach(world: Node) -> bool:
	if world != get_tree().current_scene:
		return false
	_world = world
	load_from(world, PATH)
	Inventory.changed.connect(func(_i, _c): _dirty = true)
	Journal.discovered.connect(func(_a): _dirty = true)
	Journal.observed.connect(func(_a): _dirty = true)
	Journal.photographed.connect(func(_a, _c): _dirty = true)
	Funding.changed.connect(func(_b): _dirty = true)
	Journal.nested.connect(func(_a): _dirty = true)
	Journal.hatched.connect(func(_a, _c): _dirty = true)
	Journal.gifted.connect(func(_a): _dirty = true)
	RangerProfile.look_changed.connect(func(): _dirty = true)
	(world.get_node("BuildMode") as BuildMode).built.connect(func(_b): _dirty = true)
	return true


func mark_collected(debris: Node) -> void:
	_collected.append(String(debris.name))


## Island trees are recorded as "<island>/<tree>" (e.g. "StarterIsland/Palm3").
func mark_cut(tree: Node) -> void:
	_cut_trees.append("%s/%s" % [tree.get_parent().name, tree.name])
	_dirty = true


func mark_freed(animal: Node) -> void:
	_freed.append(String(animal.name))
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
		buildings.append({"id": building.data.id, "cell": [building.cell.x, building.cell.y],
			"funds": building.pending_funds})
	var litter: Array[Dictionary] = []
	for debris: Debris in get_tree().get_nodes_in_group("debris"):
		if debris.spawned and not debris.is_queued_for_deletion():
			litter.append({"item": debris.item.id, "pos": [debris.position.x, debris.position.y],
				"floating": debris.floating})
	var nests: Array[Dictionary] = []
	for nest: Nest in get_tree().get_nodes_in_group("nests"):
		nests.append({"species": nest.species.id, "pos": [nest.position.x, nest.position.y], "laid_at": nest.laid_at})
	var young: Array[Dictionary] = []
	var nest_days := {}
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if animal.leaving:
			continue  # already heading out to sea
		if animal.young:
			young.append({"species": animal.data.id, "pos": [animal.position.x, animal.position.y],
				"home": [animal.home().x, animal.home().y]})
		else:
			nest_days[animal.name] = animal.last_nest_day
	var state := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"inventory": Inventory.to_dict(),
		"discovered": Journal.ids(),
		"journal": Journal.details(),
		"collected_debris": _collected,
		"freed_animals": _freed,
		"cut_trees": _cut_trees,
		"washed_in_litter": litter,
		"funding": Funding.to_dict(),
		"nests": nests,
		"young_animals": young,
		"nest_days": nest_days,
		"buildings": buildings,
		"player": [player.global_position.x, player.global_position.y],
		"boat": [boat.global_position.x, boat.global_position.y],
		"aboard": boat.controlled,
		"day": GameClock.day,
		"time_of_day": GameClock.time_of_day,
		"avatar": RangerProfile.look,
		"avatar_created": RangerProfile.created,
	}
	# Desktop: write a temp file then swap it in, so a crash mid-save can't corrupt the save.
	# Web: write the save itself — the browser's storage is only updated when a file is
	# closed after writing (a rename isn't copied over until the next save, and phones
	# close pages abruptly).
	var web := OS.has_feature("web")
	var text := JSON.stringify(state, "\t")
	if web:
		_web_backup_write(path, text)
	var target := path if web else path + ".tmp"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if not file:
		push_error("Can't write save: %s" % error_string(FileAccess.get_open_error()))
		return web  # the localStorage copy still counts
	file.store_string(text)
	file.close()
	var ok := web or DirAccess.rename_absolute(target, path) == OK
	saved.emit()
	return ok


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
	var text := _newest_save_text(path)
	if text == "":
		return false
	var state: Variant = JSON.parse_string(text)
	if not state is Dictionary or state.get("version") != VERSION:
		push_warning("Save file unreadable; kept as %s.bad and starting fresh." % path)
		DirAccess.rename_absolute(path, path + ".bad")
		return false

	RangerProfile.restore(state.get("avatar", {}), state.get("avatar_created", false))
	GameClock.day = int(state.get("day", 1))
	GameClock.time_of_day = float(state.get("time_of_day", 0.3))
	Inventory.restore(state.get("inventory", {}))
	Funding.restore(state.get("funding", {}))
	Journal.restore(state.get("discovered", []), state.get("journal", {}))
	for animal_name: String in state.get("freed_animals", []):
		_freed.append(animal_name)
		var animal := world.get_node_or_null(animal_name)
		if animal:
			animal.restore_freed()
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
			baby.young = true
			world.add_child(baby)
			world.move_child(baby, world.get_node("Player").get_index())
			baby.restore_young(Vector2(pos[0], pos[1]), Vector2(home[0], home[1]))
	var build_mode: BuildMode = world.get_node("BuildMode")
	for entry: Dictionary in state.get("buildings", []):
		var data_path := "res://data/buildings/%s.tres" % entry.get("id", "")
		var cell: Array = entry.get("cell", [])
		if ResourceLoader.exists(data_path) and cell.size() == 2:
			var building := build_mode.add_building(load(data_path), Vector2i(int(cell[0]), int(cell[1])))
			building.add_funds(int(entry.get("funds", 0)))
	if "TurtleSanctuarySite" in state.get("built", []):  # saves from before free placement
		build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(8, -1))
	var p: Array = state.get("player", [])
	if p.size() == 2:
		(world.get_node("Player") as Node2D).global_position = Vector2(p[0], p[1])
	var b: Array = state.get("boat", [])
	if b.size() == 2:
		(world.get_node("Boat") as Node2D).global_position = Vector2(b[0], b[1])
	if state.get("aboard", false):
		(world.get_node("Boat") as Boat).restore_aboard()
	# Turtles belong to a protection area; relink hatchlings and mothers to the nearest one.
	for animal: Animal in get_tree().get_nodes_in_group("animals"):
		if (animal.young or animal.last_nest_day >= 0) and animal.data.nest_building != &"":
			animal.link_to_nearest_area()
	return true


func _species(id: String) -> AnimalData:
	var path := "res://data/animals/%s.tres" % id
	return load(path) if id and ResourceLoader.exists(path) else null
