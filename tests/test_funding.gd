extends SceneTree
## Funding: visitors to the turtle area pay each morning (more turtles and a healthier
## island, more visitors); the Dolphin Viewing Area earns more with dolphins in view; one paid research photo per species per day; a one-off grant for the
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
	load("res://scripts/animals/arrivals.gd").restore(world, ["Dolphin1", "Dolphin3", "Crab2"])  # the pod and crabs of a recovered island
	var build_mode: Node = world.get_node("BuildMode")
	var turtle: Resource = load("res://data/animals/green_turtle.tres")
	funding.restore({})

	# --- Visitors ---
	clock.sleep_until_morning()
	_expect(funding.balance == 0, "no visitors without a protected beach")
	var area: Node2D = build_mode.add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(14, -1))
	clock.day = 1
	clock.time_of_day = 0.9
	var expected: int = area.visitors_today()
	clock.sleep_until_morning()
	var paid: int = area.pending_funds
	_expect(funding.balance == 0 and paid >= 20 and paid == expected,
		"visitors leave 20 (+10 per turtle belonging here: none yet), a little more for island health (waiting: %d)" % paid)
	var player: Node2D = world.get_node("Player")
	player.global_position = area.global_position + Vector2(-50, 10)
	for i in 3:
		await process_frame
	_expect(funding.balance == paid and area.pending_funds == 0, "collected by walking up to it (got %d)" % funding.balance)
	player.global_position = Vector2.ZERO
	# A healthier island (its litter cleaned up) draws more visitors.
	for debris: Node in get_nodes_in_group("debris"):
		debris.free()
	_expect(area.visitors_today() > paid, "a cleaner island, more visitors (%d)" % area.visitors_today())
	funding.restore({"balance": 20})

	# --- Dolphin Viewing Area: more visitors with dolphins in view ---
	var viewing: Resource = load("res://data/buildings/dolphin_viewing_area.tres")
	_expect(viewing.facility == &"funding" and area.data.facility == &"funding", "both are funding facilities")
	var deck: Node2D = build_mode.add_building(viewing, Vector2i(14, 3))
	for id in ["Dolphin1", "Dolphin2", "Dolphin3"]:
		(world.get_node(id) as Node2D).global_position = Vector2(-3000, 0)
	var dolphin: Node2D = world.get_node("Dolphin1")
	var none_in_view: int = deck.animals_in_view()
	dolphin.global_position = deck.global_position + Vector2(200, 0)
	_expect(none_in_view == 0 and deck.animals_in_view() == 1, "counts the dolphins in view")
	var with_dolphins: int = deck.visitors_today()
	dolphin.global_position = deck.global_position + Vector2(2000, 0)
	_expect(deck.visitors_today() < with_dolphins, "fewer dolphins in view, fewer visitors")
	build_mode.start(viewing)
	_expect(build_mode.at_limit(viewing), "one Dolphin Viewing Area")
	build_mode.cancel()
	deck.queue_free()
	await process_frame

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
	_expect(not build_mode.can_place(house, Vector2i(-1, -1)), "and 3 wood")
	inventory.add(load("res://data/items/wood.tres"), 5)
	_expect(inventory.count(&"wood") == 3, "can only carry 3 wood")
	_expect(build_mode.place_at(Vector2i(-1, -1)), "house built where the tent was")
	await process_frame
	var ids := get_nodes_in_group("buildings").map(func(b: Node) -> StringName: return b.data.id)
	_expect(&"house" in ids and not &"tent" in ids, "tent replaced by the house")
	_expect(funding.balance == 10 and inventory.total() == 0 and inventory.count(&"wood") == 0,
		"house cost 120 funding + 10 litter + 3 wood")

	# --- The house stores wood; building uses carried wood, then stored ---
	var home: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"house")[0]
	player.global_position = home.global_position + Vector2(-50, 20)
	inventory.add(load("res://data/items/wood.tres"), 3)
	var labels: Array = home.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Store 3 wood" in labels, "offers to store wood (%s)" % [labels])
	home.actions().filter(func(a: Dictionary) -> bool: return a.label == "Store 3 wood")[0].do.call()
	_expect(inventory.count(&"wood") == 0 and inventory.stored(&"wood") == 3, "wood stored in the house")
	_expect(home.storage() == 10, "a house stores 10 of each")
	home.tier = 3
	_expect(home.storage() == 30 and home.stats().begins_with("Lv 3/3"), "at level 3 it stores 30 (and shows its level)")
	home.tier = 1
	inventory.add(load("res://data/items/wood.tres"), 1)
	_expect(inventory.use(&"wood", 2) and inventory.count(&"wood") == 0 and inventory.stored(&"wood") == 2,
		"building uses carried wood first, then stored")
	home.actions().filter(func(a: Dictionary) -> bool: return a.label == "Take 2 wood")[0].do.call()
	_expect(inventory.count(&"wood") == 2 and inventory.stored(&"wood") == 0, "took the wood back out")
	inventory.add(load("res://data/items/plastic_bottle.tres"), 1)  # a dock plank needs 1 litter + 1 wood

	# --- Dock: shallows only, costs funding ---
	var dock: Resource = load("res://data/buildings/dock.tres")
	funding.earn(200, "test")
	build_mode.start(dock)
	_expect(not build_mode.can_place(dock, Vector2i(-3, -3)), "dock can't go on grass")
	_expect(not build_mode.can_place(dock, Vector2i(-30, 0)), "a dock plank must connect to the shore")
	_expect(build_mode.place_at(Vector2i(0, 2)), "dock plank built at the lagoon beach")
	_expect(funding.balance == 190, "a dock plank costs 20 funding (left %d)" % funding.balance)
	_expect(not funding.spend(1000), "can't overspend")

	# --- Recycling centre: turn litter into funding ---
	var centre: Resource = load("res://data/buildings/recycling_centre.tres")
	build_mode.cancel()
	inventory.add(load("res://data/items/plastic_bag.tres"), 10)
	inventory.add(load("res://data/items/wood.tres"), 1)  # 1 left from the dock + 1 = the 2 it needs
	build_mode.start(centre)
	_expect(build_mode.place_at(Vector2i(-3, -3)), "recycling centre built (10 litter)")
	inventory.add(load("res://data/items/plastic_bottle.tres"), 7)
	var building: Node2D = get_nodes_in_group("buildings").filter(func(b: Node) -> bool: return b.data.id == &"recycling_centre")[0]
	player.global_position = building.global_position + Vector2(-50, 20)
	var before: int = funding.balance
	var actions: Array = building.actions()
	_expect(actions.size() > 0 and actions[0].label == "Recycle 7 litter (+21 funding)",
		"offers to recycle what you carry (%s)" % [actions.map(func(a: Dictionary) -> String: return a.label)])
	actions[0].do.call()
	_expect(funding.balance == before + 21 and inventory.total() == 0, "7 litter recycled into 21 funding")

	# --- Upgrades: 3 tiers, each +1 funding per piece; they cost funding + wood ---
	labels = building.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Upgrade (2/3)" in labels, "offers an upgrade (%s)" % [labels])
	inventory.take_item(&"wood", inventory.available(&"wood"))
	funding.restore({"balance": 500})
	building.upgrade()
	_expect(building.tier == 1 and funding.balance == 500, "no upgrade without the wood it needs")
	inventory.add(load("res://data/items/wood.tres"), 3)
	building.upgrade()
	_expect(building.tier == 2 and funding.balance == 420 and inventory.count(&"wood") == 1, "upgraded for 80 funding + 2 wood")
	inventory.add(load("res://data/items/wood.tres"), 1)
	building.upgrade()
	_expect(building.tier == 3 and building.recycle_value() == 5, "top tier recycles for 5 per piece")
	_expect(building.get_node("Sprite2D").texture == building.data.tier_textures[2], "each tier has its own picture")
	labels = building.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(not labels.any(func(l: String) -> bool: return l.begins_with("Upgrade")), "no upgrade past 3/3")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
