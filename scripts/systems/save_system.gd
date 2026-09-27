extends Node
## Autoload "SaveGame": saves progress to user://save.json and restores it on start.
## Autosaves after progress (collecting, discovering, building), every few seconds,
## and when the game is closed or sent to the background.

const PATH := "user://save.json"
const VERSION := 1
const AUTOSAVE_SECONDS := 10.0

## World debris picked up so far (node names), so it doesn't come back.
var _collected: Array[String] = []
## World animals freed from fishing line (node names), so they stay free.
var _freed: Array[String] = []
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
	Inventory.item_added.connect(func(_i, _c): _dirty = true)
	Journal.discovered.connect(func(_a): _dirty = true)
	Journal.observed.connect(func(_a): _dirty = true)
	Journal.photographed.connect(func(_a, _c): _dirty = true)
	RangerProfile.look_changed.connect(func(): _dirty = true)
	(world.get_node("BuildMode") as BuildMode).built.connect(func(_b): _dirty = true)
	return true


func mark_collected(debris: Node) -> void:
	_collected.append(String(debris.name))


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
		buildings.append({"id": building.data.id, "cell": [building.cell.x, building.cell.y]})
	var state := {
		"version": VERSION,
		"inventory": Inventory.to_dict(),
		"discovered": Journal.ids(),
		"journal": Journal.details(),
		"collected_debris": _collected,
		"freed_animals": _freed,
		"buildings": buildings,
		"player": [player.global_position.x, player.global_position.y],
		"boat": [boat.global_position.x, boat.global_position.y],
		"aboard": boat.controlled,
		"day": GameClock.day,
		"time_of_day": GameClock.time_of_day,
		"avatar": RangerProfile.look,
		"avatar_created": RangerProfile.created,
	}
	# Write a temp file then swap it in, so a crash mid-save can't corrupt the save.
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if not file:
		push_error("Can't write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	return DirAccess.rename_absolute(tmp, path) == OK


## Restores progress into `world`. Returns false if there's no usable save
## (a damaged one is kept as <path>.bad rather than overwritten).
func load_from(world: Node, path: String) -> bool:
	_collected.clear()
	_freed.clear()
	if not FileAccess.file_exists(path):
		return false
	var state: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not state is Dictionary or state.get("version") != VERSION:
		push_warning("Save file unreadable; kept as %s.bad and starting fresh." % path)
		DirAccess.rename_absolute(path, path + ".bad")
		return false

	RangerProfile.restore(state.get("avatar", {}), state.get("avatar_created", false))
	GameClock.day = int(state.get("day", 1))
	GameClock.time_of_day = float(state.get("time_of_day", 0.3))
	Inventory.restore(state.get("inventory", {}))
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
	var build_mode: BuildMode = world.get_node("BuildMode")
	for entry: Dictionary in state.get("buildings", []):
		var data_path := "res://data/buildings/%s.tres" % entry.get("id", "")
		var cell: Array = entry.get("cell", [])
		if ResourceLoader.exists(data_path) and cell.size() == 2:
			build_mode.add_building(load(data_path), Vector2i(int(cell[0]), int(cell[1])))
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
	return true
