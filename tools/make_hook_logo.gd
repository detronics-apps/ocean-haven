extends SceneTree
## Makes the old net tag's logo (Clue Board, O2): the Deep Sea's hook-shaped island as a plain
## black shape, from its map picture (land black, sea see-through).
## Run: godot --headless --path . --script res://tools/make_hook_logo.gd


func _initialize() -> void:
	var map := Image.load_from_file("res://assets/ui/maps/hook_island.png")
	var logo := Image.create(map.get_width(), map.get_height(), false, Image.FORMAT_RGBA8)
	for y in map.get_height():
		for x in map.get_width():
			var c := map.get_pixel(x, y)
			var land := c.a > 0.5 and (c.g > c.b + 0.04 or c.r > 0.4)  # (green and sandy, not the sea)
			logo.set_pixel(x, y, Color(0.08, 0.07, 0.06, 1.0) if land else Color(0, 0, 0, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/clues"))
	logo.save_png("res://assets/ui/clues/hook_logo.png")
	print("hook logo saved")
	quit()
