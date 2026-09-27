extends Node
## Autoload "SaveGame": saves progress to user://save.json and restores it on start.
## Autosaves after progress (collecting, discovering, building), every few seconds,
## and when the game is closed or sent to the background.

const PATH := "user://save.json"
const VERSION := 1
const AUTOSAVE_SECONDS := 10.0

## World debris picked up so far (node names), so it doesn't come back.
var _collected: Array[String] = []
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
	RangerProfile.look_changed.connect(func(): _dirty = true)
	for site: BuildSite in get_tree().get_nodes_in_group("build_sites"):
		site.built.connect(func(_b): _dirty = true)
	return true


func mark_collected(debris: Node) -> void:
	_collected.append(String(debris.name))


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
	var built: Array[String] = []
	for site: BuildSite in get_tree().get_nodes_in_group("build_sites"):
		if site.is_built:
			built.append(String(site.name))
	var state := {
		"version": VERSION,
		"inventory": Inventory.to_dict(),
		"discovered": Journal.ids(),
		"collected_debris": _collected,
		"built": built,
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
	Journal.restore(state.get("discovered", []))
	for debris_name: String in state.get("collected_debris", []):
		_collected.append(debris_name)
		var debris := world.get_node_or_null(debris_name)
		if debris:
			debris.queue_free()
	for site: BuildSite in get_tree().get_nodes_in_group("build_sites"):
		if String(site.name) in state.get("built", []):
			site.restore_built()
	var p: Array = state.get("player", [])
	if p.size() == 2:
		(world.get_node("Player") as Node2D).global_position = Vector2(p[0], p[1])
	var b: Array = state.get("boat", [])
	if b.size() == 2:
		(world.get_node("Boat") as Node2D).global_position = Vector2(b[0], b[1])
	if state.get("aboard", false):
		(world.get_node("Boat") as Boat).restore_aboard()
	return true
