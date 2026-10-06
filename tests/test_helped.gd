extends SceneTree
## Populations only grow because of the ranger: until the ranger has helped an island (picked
## up Regions.HELPED_AFTER pieces of litter there, or built something there), no new animals
## arrive or settle, however long they wait. Every species starts with at least one (the
## Starting Island's seabird is caught in fishing line), and none ever drops to zero.
## Run: godot --headless --path . --script res://tests/test_helped.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var inventory := root.get_node("Inventory")
	inventory.picked_on.clear()
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var home: Resource = load("res://data/regions/home_island.tres")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	var bird: Node = world.get_node("Seabird0")
	_expect(bird.data.id == &"red_footed_booby" and bird.tangled, "the Starting Island has one seabird, and it needs help")
	_expect(not regions.helped(self, home), "the tent the game starts with doesn't count as helping")
	regions.discover(kelp)
	world.get_node("Player").global_position = kelp.arrival
	for i in 3:
		await process_frame
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var fish: Resource = load("res://data/animals/blue_rockfish.tres")
	var before: int = ecosystem.living(fish).size()
	ecosystem.call("_follow", fish, before + 3)
	_expect(ecosystem.living(fish).size() == before, "kelp fish don't come back on their own")
	for i in 10:
		inventory.add(load("res://data/items/plastic_bottle.tres"))
	_expect(regions.helped(self, kelp) and not regions.helped(self, home), "10 pieces picked up on the Kelp Forest: that island has been helped")
	ecosystem.call("_follow", fish, before + 3)
	_expect(ecosystem.living(fish).size() == before + 1, "now they come back")
	ecosystem.call("_follow", fish, 0)
	for i in 5:
		ecosystem.call("_follow", fish, 0)
	_expect(ecosystem.living(fish).filter(func(a: Node) -> bool: return not a.leaving).size() >= 1, "and never drop to none")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
