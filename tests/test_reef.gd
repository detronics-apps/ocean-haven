extends SceneTree
## The Tropical Reef: coral patches grow back as far as they're planted (fragments from a Coral
## Restoration Site, by boat), as fast as clean water and parrotfish allow; parrotfish build the
## sea floor up into sand; the Glassworks turns 3 sand into glass-making (then buys extra sand);
## giant clams in a Water Treatment Facility make Clean Water; both together unlock reusable
## bottles; a shark leads the ranger to lost gear; seahorses live in seagrass Protection Areas.
## Run: godot --headless --path . --script res://tests/test_reef.gd --quit-after 300000

const PATH := "user://test_reef.json"

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var clock := root.get_node("GameClock")
	var fleet := root.get_node("Fleet")
	var inventory := root.get_node("Inventory")
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	fleet.restore({})
	load("res://scripts/world/regions.gd").discover(reef)
	root.get_node("Funding").restore({"balance": 5000})
	inventory.restore({}, {"wood": 100})
	var player: Node2D = world.get_node("Player")
	player.global_position = reef.arrival
	for i in 3:
		await process_frame
	world.get_node("ReefLitter").fill(reef.arrival_litter)
	var eco: Node = world.get_node("ReefIsland/Ecosystem")
	var build_mode: Node = world.get_node("BuildMode")
	var patches: Array = eco.patches()

	# --- Arriving: a bare reef, every species there but struggling, health near 0 ---
	_expect(patches.size() >= 8 and eco.coral_health() < 0.2, "%d reef patches, mostly bare (coral %d%%)" % [patches.size(), roundi(eco.coral_health() * 100.0)])
	var shark: Node2D = eco.living(load("res://data/animals/reef_shark.tres"))[0]
	var seahorse: Node2D = eco.living(load("res://data/animals/seahorse.tres"))[0]
	_expect(shark.tangled and seahorse.tangled, "a shark caught in fishing line, a seahorse caught in a bag")
	var start: float = health.of(self, reef)
	_expect(start < 0.12, "island health starts near 0 (%d%%)" % roundi(start * 100.0))

	# --- Coral: grows back as far as it's planted, faster with clean water ---
	for d in get_nodes_in_group("debris"):
		d.free()
	await process_frame
	var patch: Node2D = patches[0]
	player.global_position = patch.global_position + Vector2(20, 0)
	inventory.add(load("res://data/items/coral_fragment.tres"), 3)
	var labels: Array = patch.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(labels.size() == 1 and labels[0].begins_with("Plant coral fragment"), "beside a patch carrying a fragment: plant it (%s)" % [labels])
	for i in 3:
		patch.plant()
	_expect(is_equal_approx(patch.planted, 0.9) and inventory.count(&"coral_fragment") == 0, "3 fragments planted")
	var before: float = patch.coral
	for i in 16:
		eco.tick(0.25)
	_expect(patch.coral > before + 0.3, "it grows back over days in clean water (%.2f -> %.2f)" % [before, patch.coral])

	# --- Coral Restoration Site: grows fragments every morning ---
	var site_data: Resource = load("res://data/buildings/coral_restoration_site.tres")
	var site_cell := Vector2i((patches[1].global_position / 32.0).floor()) + Vector2i(2, 0)
	var site: Node = null
	for dx in range(0, 6):
		if not site and build_mode.placement_problem(site_data, site_cell + Vector2i(dx, 0)) == "":
			site = build_mode.add_building(site_data, site_cell + Vector2i(dx, 0))
	_expect(site != null, "a Coral Restoration Site in the lagoon")
	clock.day += 1
	clock.new_day.emit(clock.day)
	_expect(site.stock == 1, "it grows a coral fragment each morning (%d)" % site.stock)
	player.global_position = site.global_position + Vector2(30, 0)
	labels = site.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Take 1 coral fragment" in labels, "take it (%s)" % [labels])

	# --- Parrotfish follow the coral and build the sea floor up into sand ---
	for p in patches:
		p.planted = 1.0
		p.coral = 0.8
	eco.settle()
	_expect(eco.working(load("res://data/animals/parrotfish.tres")).size() >= 2, "more coral, more parrotfish")
	var ground: TileMapLayer = world.get_node("ReefIsland/Ground")
	var steps := 0
	for i in 30:
		if eco.build_up_near(patches[2]):
			steps += 1
	var sand_cells := ground.get_used_cells().filter(func(c: Vector2i) -> bool:
		return (ground.get_cell_tile_data(c).get_custom_data("terrain") == "sand"
			and ground.to_global(ground.map_to_local(c)).distance_to(patches[2].global_position) < 4 * 32))
	_expect(steps > 0 and sand_cells.size() > 0, "parrotfish build the floor up step by step, until some becomes sand (%d steps)" % steps)
	_expect(eco.get("_sand_made") <= eco.sand_max, "but never more than %d tiles" % eco.sand_max)

	# --- Glassworks: 3 sand once sets up glass-making; extra sand earns funding ---
	var glass_data: Resource = load("res://data/buildings/glassworks.tres")
	var glass: Node = _place_on_land(build_mode, glass_data, reef)
	_expect(glass != null, "a Glassworks on the land")
	player.global_position = glass.global_position + Vector2(0, 40)
	inventory.restore({}, {"wood": 100, "sand": 5})
	labels = glass.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Put in 3 sand" in labels, "it takes 3 sand to start (%s)" % [labels])
	glass.start_capability()
	clock.advance(glass_data.make_minutes * 60.0 + 1.0)
	await process_frame
	_expect(fleet.has_flag(&"glass_made") and glass.stats().contains("Running"), "glass-making is set up for good")
	var funds: int = root.get_node("Funding").balance
	labels = glass.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Drop off 2 sand (+12 funding)" in labels, "extra sand can be dropped off for funding (%s)" % [labels])
	glass.sell_input()
	_expect(root.get_node("Funding").balance == funds + 12, "like the recycling centre")
	_expect(not fleet.reusable_bottles(), "glass alone doesn't replace plastic bottles")

	# --- Water Treatment Facility: clams settle there and filter Clean Water ---
	var water_data: Resource = load("res://data/buildings/water_treatment_facility.tres")
	var facility: Node = null
	var near := Vector2i((patches[3].global_position / 32.0).floor())
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			if not facility and build_mode.placement_problem(water_data, near + Vector2i(dx, dy)) == "":
				facility = build_mode.add_building(water_data, near + Vector2i(dx, dy))
	_expect(facility != null, "a Water Treatment Facility on the water")
	eco.settle()
	eco.settle()
	_expect(eco.living(load("res://data/animals/giant_clam.tres")).all(func(c: Node) -> bool: return c.home_area == facility)
		and eco.living(load("res://data/animals/giant_clam.tres")).size() == 2, "giant clams settle in its beds")
	clock.day += 1
	clock.new_day.emit(clock.day)
	_expect(facility.stock == 2 and fleet.has_flag(&"clean_water_made"), "each clam filters 1 clean water a morning")
	_expect(fleet.reusable_bottles(), "glass + clean water: reusable bottles everywhere")

	# --- Clean Water fills the ranger's water at their tent or house: faster while it lasts ---
	player.global_position = facility.global_position + Vector2(30, 0)
	facility.take_stock()
	_expect(inventory.count(&"clean_water") == 2, "the ranger takes the clean water")
	inventory.add(load("res://data/items/plastic_bottle.tres"), 10)  # a house is built with litter
	var house: Node = _place_on_land(build_mode, load("res://data/buildings/house.tres"), reef)
	player.global_position = house.global_position + Vector2(0, 40)
	var body: GDScript = load("res://scripts/player/controlled_body.gd")
	body.water_until = -1.0
	labels = house.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Drink clean water (fill up your water)" in labels, "at the house the ranger can drink clean water (%s)" % [labels])
	house.drink_water()
	_expect(inventory.count(&"clean_water") == 1 and body.water_level(self) > 0.99, "drinking fills the ranger's water")
	clock.advance(clock.DAY_LENGTH * body.WATER_DAYS * 0.5)
	_expect(absf(body.water_level(self) - 0.5) < 0.05, "it runs out slowly (half after %d day)" % roundi(body.WATER_DAYS * 0.5))
	var lodge: Node = _place_on_land(build_mode, load("res://data/buildings/reef_diving_centre.tres"), reef)
	player.global_position = lodge.global_position + Vector2(0, 40)
	labels = lodge.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect(not labels.any(func(l: String) -> bool: return l.contains("clean water")), "other buildings don't take water any more")

	# --- A shark circles lost gear; going there finds it ---
	shark.restore_freed()
	eco.call("_hide_gear")
	var gear_at: Vector2 = eco.hidden_gear()
	_expect(gear_at != Vector2.INF, "a shark has found lost gear and circles it")
	player.global_position = gear_at + Vector2(60, 0)  # close enough to see it, not touching it
	await process_frame
	var found := get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
		return d.item.id in [&"ghost_net", &"fishing_line"] and d.global_position.distance_to(gear_at) < 1.0)
	_expect(eco.hidden_gear() == Vector2.INF and found.size() == 1, "following it, the ranger finds the gear (%d)" % found.size())

	# --- Seahorses: freed, they live in a Protection Area once its seagrass has grown ---
	seahorse.restore_freed()
	var area_data: Resource = load("res://data/buildings/seagrass_protection_area.tres")
	var area: Node = null
	near = Vector2i((patches[4].global_position / 32.0).floor())
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			if not area and build_mode.placement_problem(area_data, near + Vector2i(dx, dy)) == "":
				area = build_mode.add_building(area_data, near + Vector2i(dx, dy))
	_expect(area != null, "a Seahorse & Seagrass Protection Area")
	eco.settle()
	_expect(eco.seahorses_supported() == 0, "its seagrass needs a day to grow")
	clock.day += 1
	eco.settle()
	eco.settle()
	_expect(eco.living(load("res://data/animals/seahorse.tres")).size() == 2 and seahorse.home_area == area, "then seahorses live in it")

	# --- The lab's missions ---
	var offered: Array = root.get_node("Missions").offered_by(&"coral_restoration_lab")
	_expect(offered.size() == 8, "the Coral Restoration Laboratory offers 8 missions")
	var report: Dictionary = eco.run_mission(load("res://data/missions/coral_survey.tres"))
	_expect(report.detail.contains("Coral is"), "coral survey (%s)" % report.detail)
	report = eco.run_mission(load("res://data/missions/clam_monitoring.tres"))
	_expect(report.detail.contains("clean water"), "clam monitoring (%s)" % report.detail)

	# --- Hurricane, objective, saved ---
	var hurricane: Resource = load("res://data/events/hurricane.tres")
	_expect(hurricane.region == &"tropical_reef", "the Hurricane hits the Tropical Reef")
	var sand_before := ground.get_used_cells().filter(func(c: Vector2i) -> bool: return ground.get_cell_tile_data(c).get_custom_data("terrain") == "sand").size()
	area.damaged = true
	_expect(eco.hurricane(0.4, 0.5) >= patches.size() / 2, "it breaks coral on half the patches")
	var sand_after := ground.get_used_cells().filter(func(c: Vector2i) -> bool: return ground.get_cell_tile_data(c).get_custom_data("terrain") == "sand").size()
	_expect(sand_after < sand_before, "waves wash some of the parrotfish's sand away (%d -> %d)" % [sand_before, sand_after])
	_expect(area.built_day == clock.day and eco.seahorses_supported() == 0, "and tear up the seagrass in a battered Protection Area (it regrows once repaired)")
	fleet.mark(&"reef_restored")
	eco.call("_objective")
	var rubble := get_nodes_in_group("debris").filter(func(d: Node) -> bool: return d.item.id == &"coral_rubble")
	_expect(rubble.size() == 2, "once restored: dead coral rubble on the sea floor, 2 a morning")
	rubble[0].collect()
	_expect(fleet.count_of(&"reef_limestone") == 1, "collecting it counts towards the Reef Limestone")
	var saved: Dictionary = eco.to_dict()
	patches[0].coral = 0.0
	eco.restore(saved)
	_expect(patches[0].coral > 0.1, "the reef is saved")
	_expect(root.get_node("SaveGame").save_to(world, PATH), "saved the game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	fleet.restore({})

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _place_on_land(build_mode: Node, data: Resource, region: Resource) -> Node:
	var centre := Vector2i((region.arrival / 32.0).floor())
	for r in range(0, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if build_mode.placement_problem(data, centre + Vector2i(dx, dy)) == "":
					return build_mode.add_building(data, centre + Vector2i(dx, dy))
	return null


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
