extends SceneTree
## Renders every island's start picture (a new game's world with every island found: the island
## as it was made, muted, its start litter, its few starting animals and its people; the same for
## every player) to assets/ui/islands/<id>_start.png, and writes the part
## of the world each shows into its region (RegionData.start_frame). Re-run after changing an
## island's shape. Needs a screen:
##   xvfb-run -a godot --path . --script res://tools/make_start_pictures.gd

func _initialize() -> void:
	await process_frame
	var journal := root.get_node("Journal")
	root.get_node("RangerProfile").created = true  # (no avatar creator over the world)
	var regions: GDScript = load("res://scripts/world/regions.gd")
	regions.restore(regions.all().map(func(r: Resource) -> String: return String(r.id)))
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	root.get_node("GameClock").time_of_day = 0.4  # (daylight)
	for i in 30:  # (every island found: their ecosystems put in their few starting animals)
		await process_frame
	world.get_node("Player").visible = false  # (the Observatory draws the ranger itself)
	for region: Resource in load("res://scripts/world/regions.gd").all():
		var made: Dictionary = await journal.render_start_picture(region)
		if made.is_empty():
			push_error("no picture for %s (no screen?)" % region.id)
			continue
		made.image.save_png("res://assets/ui/islands/%s_start.png" % region.id)
		var frame: Rect2 = made.frame
		var path: String = region.resource_path
		var text := FileAccess.get_file_as_string(path)
		var line := "start_frame = Rect2(%s, %s, %s, %s)" % [frame.position.x, frame.position.y, frame.size.x, frame.size.y]
		var regex := RegEx.create_from_string("(?m)^start_frame = .*$")
		if regex.search(text):
			text = regex.sub(text, line)
		else:
			text = text.strip_edges() + "\n" + line + "\n"  # (the [resource] section is the file's last)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		print("%s: %dx%d, frame %s" % [region.id, made.image.get_width(), made.image.get_height(), frame])
	quit()
