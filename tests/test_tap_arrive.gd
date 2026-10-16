extends SceneTree
## A tapped spot is reached and the boat (or ranger) stays still there, also at a phone's 30
## physics steps a second: a step longer than the spot's 2 px margin used to go past it and back
## again for ever, shaking left and right (the owner).
## Run: godot --headless --path . --script res://tests/test_tap_arrive.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var home: Resource = load("res://data/regions/home_island.tres")
	var boat: Node2D = world.get_node("Boat")
	world.get_node("Player").set_aboard(true)
	boat.set("controlled", true)
	var start := Vector2.INF
	for i in 36:  # open water with nothing in the way to the right
		var spot: Vector2 = home.center + Vector2.from_angle(TAU * i / 36.0) * home.waters_radius * 0.7
		if range(0, 40, 4).all(func(dx: int) -> bool: return terrain.at(self, spot + Vector2(dx, 0)) in ["water", ""]):
			start = spot
			break
	_expect(start != Vector2.INF, "open water to sail in")
	Engine.physics_ticks_per_second = 30  # (a phone)
	await physics_frame
	boat.global_position = start
	var target := start + Vector2(160.0 / 30.0 * 3.0 + 2.6, 0)  # (3 whole steps and 2.6 px: it went 2.6 past and back)
	boat.set("_target", target)
	boat.set("_has_target", true)
	for i in 30:
		await physics_frame
	var settled: Vector2 = boat.global_position
	var shake := 0.0
	for i in 10:
		var before: Vector2 = boat.global_position
		await physics_frame
		shake = maxf(shake, boat.global_position.distance_to(before))
	_expect(not boat.get("_has_target") and settled.distance_to(target) < 2.0,
		"the boat reaches the tapped spot (%.1f px from it)" % settled.distance_to(target))
	_expect(shake < 0.01, "and stays still there, no shaking (%.1f px a step)" % shake)
	Engine.physics_ticks_per_second = 60
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
