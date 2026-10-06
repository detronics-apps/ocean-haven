extends SceneTree
## Patrol boats on other islands rest while the ranger is away (no pickups, no notes); they can
## be taken down; on the Deep Sea one over a dark area (where the animals live) is noisy, one
## kept near the shore much less so.
## Run: godot --headless --path . --script res://tests/test_patrol_quiet.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var deep: Resource = load("res://data/regions/deep_sea.tres")
	regions.discover(deep)
	var eco: Node = world.get_node("HookIsland/Ecosystem")
	var data: Resource = load("res://data/buildings/patrol_boat.tres")
	_expect(data.demolishable, "a patrol boat can be taken down")
	var quiet_before: float = eco.quiet()
	var sector: Node2D = eco.sectors()[2]
	var over: Node = world.get_node("BuildMode").add_building(data, terrain.cell_of(sector.to_global(sector.cells[0])))
	await process_frame
	var noisy: float = quiet_before - eco.quiet()
	over.free()
	var shore_spot: Vector2 = terrain.nearest(self, deep.arrival, ["water"])
	var near: Node = world.get_node("BuildMode").add_building(data, terrain.cell_of(shore_spot))
	await process_frame
	var calm: float = quiet_before - eco.quiet()
	_expect(noisy > 0.0 and calm < noisy / 3.0, "over a dark area a patrol boat is noisy (%.2f), near the shore much less (%.2f)" % [noisy, calm])

	# Away from its island: no pickups.
	world.get_node("Player").global_position = Vector2.ZERO  # back on the Starting Island
	var boat: Node2D = near.get_node("PatrolBoat")
	for i in 90:
		await process_frame
	_expect(not boat.get("_working"), "while the ranger is on another island it rests: no pickups or notes")
	world.get_node("Player").global_position = deep.arrival
	for i in 90:
		await process_frame
	_expect(boat.get("_working"), "back on its island it works again")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
