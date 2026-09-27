extends SceneTree
## Funding: visitors to the turtle area pay each morning (more turtles, more
## visitors); one paid research photo per species per day; a one-off grant for the
## first hatchlings. The house costs funding + litter and replaces the tent; the
## dock (a plank) costs funding and must connect to the shore.
## Run: godot --headless --path . --script res://tests/test_funding.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var funding := root.get_node("Funding")  # autoloads: looked up at runtime
	var clock := root.get_node("GameClock")
	var journal := root.get_node("Journal")
	var inventory := root.get_node("Inventory")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var build_mode: Node = world.get_node("BuildMode")
	var turtle: Resource = load("res://data/animals/green_turtle.tres")
	funding.restore({})

	# --- Visitors ---
	clock.sleep_until_morning()
	_expect(funding.balance == 0, "no visitors without a protected beach")
	var area: Node2D = build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	clock.day = 1
	clock.time_of_day = 0.9
	clock.sleep_until_morning()
	_expect(funding.balance == 0 and area.pending_funds == 20,
		"visitors leave 20 (+10 per turtle belonging here: none yet) (waiting: %d)" % area.pending_funds)
	var player: Node2D = world.get_node("Player")
	player.global_position = area.global_position + Vector2(-50, 10)
	for i in 3:
		await process_frame
	_expect(funding.balance == 20 and area.pending_funds == 0, "collected by walking up to it (got %d)" % funding.balance)
	player.global_position = Vector2.ZERO

	# --- Research photos: once per species per day ---
	journal.photograph(turtle)
	journal.photograph(turtle)
	_expect(funding.balance == 30, "one paid photo per day (got %d)" % funding.balance)

	# --- Grant for the first hatchlings, once ---
	journal.record_hatch(turtle, 3)
	journal.record_hatch(turtle, 3)
	_expect(funding.balance == 130, "one-off hatchling grant (got %d)" % funding.balance)

	# --- House replaces the tent ---
	build_mode.add_building(load("res://data/buildings/tent.tres"), Vector2i(-1, -1))
	var house: Resource = load("res://data/buildings/house.tres")
	build_mode.start(house)
	_expect(not build_mode.can_place(house, Vector2i(-1, -1)), "house needs 10 litter too")
	inventory.add(load("res://data/items/plastic_bottle.tres"), 10)
	_expect(build_mode.place_at(Vector2i(-1, -1)), "house built where the tent was")
	await process_frame
	var ids := get_nodes_in_group("buildings").map(func(b: Node) -> StringName: return b.data.id)
	_expect(&"house" in ids and not &"tent" in ids, "tent replaced by the house")
	_expect(funding.balance == 10 and inventory.total() == 0, "house cost 120 funding + 10 litter")

	# --- Dock: shallows only, costs funding ---
	var dock: Resource = load("res://data/buildings/dock.tres")
	funding.earn(200, "test")
	build_mode.start(dock)
	_expect(not build_mode.can_place(dock, Vector2i(-3, -3)), "dock can't go on grass")
	_expect(not build_mode.can_place(dock, Vector2i(-30, 0)), "a dock plank must connect to the shore")
	_expect(build_mode.place_at(Vector2i(0, 2)), "dock plank built at the lagoon beach")
	_expect(funding.balance == 190, "a dock plank costs 20 funding (left %d)" % funding.balance)
	_expect(not funding.spend(1000), "can't overspend")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
