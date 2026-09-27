extends SceneTree
## Avatar: choices change the ranger and boat, choices wrap around, and the
## creator's buttons work, pause the game while open and finish creation.
## Run: godot --headless --path . --script res://tests/test_avatar.gd

var _failed := false


func _initialize() -> void:
	await process_frame
	var profile := root.get_node("RangerProfile")  # autoload: looked up at runtime
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var options: Resource = profile.options
	var look: Node = world.get_node("Player/Look")

	profile.set_choice("hair", 2)
	_expect((look.get_node("Hair") as Sprite2D).texture == options.hair_styles[2], "hair style applied")
	profile.set_choice("hat", 0)
	_expect((look.get_node("Hat") as Sprite2D).texture == null, "no hat")
	profile.set_choice("skin", -1)
	_expect(profile.look["skin"] == options.skin_tones.size() - 1, "choices wrap around")
	profile.set_choice("boat", 1)
	var hull: Sprite2D = world.get_node("Boat/Look/Hull")
	_expect(hull.modulate == options.boat_colours[1], "boat colour applied")

	var creator: Node = world.get_node("AvatarCreator")
	_expect(not creator.visible, "creator hidden outside a new game")
	creator.open()
	_expect(creator.visible and paused, "creator open, game paused")
	var skin_before: int = profile.look["skin"]
	(creator.find_child("Row_skin", true, false).find_child("Next", true, false) as Button).pressed.emit()
	_expect(profile.look["skin"] == posmod(skin_before + 1, options.skin_tones.size()), "'>' button changes skin")
	(creator.find_child("Done", true, false) as Button).pressed.emit()
	_expect(profile.created and not creator.visible and not paused, "'Let's go!' finishes and unpauses")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
