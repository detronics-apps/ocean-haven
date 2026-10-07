extends SceneTree
## The view zooms in five fixed steps, only with the + / − buttons (or keys); a tap walks the
## ranger all the way there, and holding the finger down the ranger follows it.
## Run: godot --headless --path . --script res://tests/test_zoom_walk.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var zoom: GDScript = load("res://scripts/ui/camera_zoom.gd")
	zoom.set_level(1.0)
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var buttons: Node = world.find_child("CameraZoom", true, false).get_node("Buttons")
	(buttons.get_node("ZoomIn") as Button).pressed.emit()
	_expect(is_equal_approx(zoom.level, 1.4), "+ : one step closer (1.4)")
	for i in 6:
		(buttons.get_node("ZoomOut") as Button).pressed.emit()
	_expect(is_equal_approx(zoom.level, 0.5), "− all the way: the furthest step (0.5)")
	zoom.set_level(1.0)
	await process_frame
	var player: Node2D = world.get_node("Player")
	var start := player.global_position
	player.set("_target", start + Vector2(160, 0))
	player.set("_has_target", true)  # (a tap, then the finger lifted)
	for i in 120:
		await physics_frame
	_expect(player.global_position.distance_to(start + Vector2(160, 0)) < 8.0 or player.global_position.x > start.x + 100.0,
		"a tap walks the ranger all the way, with the finger lifted (%s)" % [player.global_position - start])
	_expect(not player.get("_holding"), "(not holding)")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
