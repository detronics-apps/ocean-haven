extends SceneTree
## Islands the ranger isn't on sleep (IslandSleep): their animals stop running per-frame code, and
## wake with their own process mode back when the ranger comes; the island left behind sleeps.
## Regions.nearest's quick way (the islands lie in a line across) finds the same island as
## measuring to every island's middle.
## Run: godot --headless --path . --script res://tests/test_island_sleep.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var same := true
	for i in 2000:
		var point := Vector2(randf_range(-8000.0, 34000.0), randf_range(-6000.0, 6000.0))
		var best: Resource = null
		for region: Resource in regions.all():
			if not best or region.center.distance_to(point) < best.center.distance_to(point):
				best = region
		same = same and regions.nearest(point) == best
	_expect(same, "the nearest island, the quick way, is the island nearest")

	var home: Resource = load("res://data/regions/home_island.tres")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	var player: Node2D = world.get_node("Player")
	var sleep: Node = world.get_node("IslandSleep")
	var animal: PackedScene = load("res://scenes/animals/animal.tscn")
	var otter: Node2D = animal.instantiate()
	otter.set("data", load("res://data/animals/sea_otter.tres"))
	otter.position = kelp.center + Vector2(0, 400)
	world.add_child(otter)
	otter.process_mode = Node.PROCESS_MODE_PAUSABLE  # (its own mode, to be given back)
	var turtle: Node2D = animal.instantiate()
	turtle.set("data", load("res://data/animals/green_turtle.tres"))
	turtle.position = home.center + Vector2(0, 400)
	world.add_child(turtle)
	player.global_position = home.center
	for i in 300:  # (a few things a frame: a newcomer is reached within a second or so)
		await process_frame
		if sleep.is_asleep(otter):
			break
	_expect(sleep.is_asleep(otter) and otter.process_mode == Node.PROCESS_MODE_DISABLED,
		"an animal on an island the ranger isn't on sleeps")
	_expect(not sleep.is_asleep(turtle) and turtle.can_process(), "the ranger's own island is awake")

	player.global_position = kelp.center
	for i in 3:
		await process_frame
	_expect(not sleep.is_asleep(otter) and otter.process_mode == Node.PROCESS_MODE_PAUSABLE,
		"the ranger arrives: it wakes, with its own process mode back")
	_expect(sleep.is_asleep(turtle) and not turtle.can_process(), "and the island left behind sleeps")
	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
