extends SceneTree
## Avatar: choices change the ranger and boat, choices wrap around, every part has its side and
## back views, the builder's tiles and buttons work, it pauses the game while open,
## Back undoes, and Confirm finishes creation.
## Run: godot --headless --path . --script res://tests/test_avatar.gd

var _failed := false


func _initialize() -> void:
	await process_frame
	var profile := root.get_node("RangerProfile")  # autoload: looked up at runtime
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var options: Resource = profile.options
	var look: Node = world.get_node("Player/Look")

	profile.set_choice("hair", 2)
	_expect((look.get_node("Hair") as Sprite2D).texture == options.hair_styles[2], "hair style applied")
	profile.set_choice("hat", 0)
	_expect(not (look.get_node("Hat") as Sprite2D).visible, "no hat")
	profile.set_choice("glasses", 3)
	_expect((look.get_node("Glasses") as Sprite2D).visible, "glasses worn")
	profile.set_choice("skin", -1)
	_expect(profile.look["skin"] == options.skin_tones.size() - 1, "choices wrap around")
	profile.set_choice("boat", 1)
	var hull: Sprite2D = world.get_node("Boat/Look/Hull")
	_expect(hull.modulate == options.boat_colours[1], "boat colour applied")

	# Every part has a front, side, step and back view (hair: and its back layer).
	var ok := true
	for list in ["hair_styles", "hats", "tops", "jackets", "bottoms", "shoes", "glasses", "packs", "badges"]:
		for texture: Texture2D in options.get(list):
			if texture and texture.get_width() != 32 * (8 if list in ["hair_styles", "tops", "jackets"] else 4):
				ok = false
				print("  wrong views: ", texture.resource_path)
	_expect(ok, "every part has its four views")
	look.set_view(3)
	_expect((look.get_node("Hair") as Sprite2D).frame == 3 and look.get_node("HairBack").get_index() > look.get_node("Top").get_index(),
		"back view: long hair over the body")
	look.set_view(0)
	_expect(look.get_node("HairBack").get_index() < look.get_node("Skin").get_index(), "front view: long hair behind")

	var creator: Node = world.get_node("AvatarCreator")
	_expect(not creator.visible, "creator hidden outside a new game")
	creator.open()
	_expect(creator.visible and paused, "creator open, game paused")
	var skin_before: int = profile.look["skin"]
	(creator.find_child("Row_skin", true, false).get_child(0) as Button).pressed.emit()
	_expect(profile.look["skin"] == 0 and skin_before != 0, "a skin swatch changes skin")
	(creator.find_child("Tab_Hair", true, false) as Button).pressed.emit()
	(creator.find_child("Row_hair", true, false).get_child(4) as Button).pressed.emit()
	_expect(profile.look["hair"] == 4, "a hair tile changes the hair")
	_expect(creator.find_child("Surprise", true, false) != null, "Surprise me! is there")
	(creator.find_child("Back", true, false) as Button).pressed.emit()
	_expect(profile.look["skin"] == skin_before and profile.look["hair"] == 2 and not creator.visible, "Back undoes and closes")
	creator.open()
	(creator.find_child("Done", true, false) as Button).pressed.emit()
	_expect(profile.created and not creator.visible and not paused, "Confirm finishes and unpauses")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
