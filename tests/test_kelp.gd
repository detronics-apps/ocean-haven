extends SceneTree
## The Kelp Forest's food web: kelp beds on the island's water, each with its urchins.
## Too many urchins graze the kelp down to a barren; with few urchins it grows back; planting
## (restoration) alone can't beat overgrazing. The beds are saved.
## Run: godot --headless --path . --script res://tests/test_kelp.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var beds: Array = ecosystem.beds()
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	_expect(beds.size() >= 12, "kelp beds grow round the Kelp Forest (%d)" % beds.size())
	var on_water := true
	for b: Node2D in beds:
		on_water = on_water and terrain.at(self, b.global_position) in ["water", ""] and not terrain.walkable(self, b.global_position)
	_expect(on_water, "all on water, none on land")
	var spread := true
	for a: Node2D in beds:
		for b: Node2D in beds:
			spread = spread and (a == b or a.position.distance_to(b.position) >= ecosystem.bed_spacing)
	_expect(spread, "spread out")
	_expect(ecosystem.kelp_health() < 0.45 and ecosystem.urchin_total() > beds.size() * 5,
		"it starts damaged: thin kelp (%.2f), lots of urchins (%d)" % [ecosystem.kelp_health(), ecosystem.urchin_total()])

	# --- The first visit: years of litter already about, so the island is in very poor health ---
	var kelp_waters: Resource = load("res://data/regions/kelp_forest.tres")
	var litter_there := func() -> int:
		return get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
			return d.global_position.distance_to(kelp_waters.center) < kelp_waters.waters_radius).size()
	var voyage: GDScript = load("res://scripts/ui/voyage_map.gd")
	voyage.arrive(self, kelp_waters)
	var surge: int = litter_there.call()
	_expect(surge >= 20, "arriving the first time, there's litter everywhere (%d)" % surge)
	_expect(load("res://scripts/systems/island_health.gd").of(self, kelp_waters) < 0.1,
		"so the island starts close to 0 %% health (%.2f)" % load("res://scripts/systems/island_health.gd").of(self, kelp_waters))
	voyage.arrive(self, kelp_waters)
	_expect(litter_there.call() == surge, "only the first time")
	for d in get_nodes_in_group("debris"):
		d.free()
	voyage.arrive(self, load("res://data/regions/home_island.tres"))

	# --- Not discovered yet: nothing changes ---
	var before: float = ecosystem.kelp_health()
	root.get_node("GameClock").advance(600.0)
	await process_frame
	_expect(is_equal_approx(ecosystem.kelp_health(), before), "nothing happens before the island is found")

	# --- Found for the first time: every species is there, but struggling ---
	var regions0: GDScript = load("res://scripts/world/regions.gd")
	regions0.discover(load("res://data/regions/kelp_forest.tres"))
	await process_frame
	var seeded_otters: Array = ecosystem.otters()
	_expect(seeded_otters.size() == 1 and seeded_otters[0].tangled, "an otter is caught in a ghost net, waiting for help")
	_expect(ecosystem.living(ecosystem.FISH).size() == 2 and ecosystem.living(ecosystem.CORMORANT).size() == 1,
		"a few rockfish in the thin kelp and one hungry cormorant")
	seeded_otters[0].restore_freed()
	ecosystem.settle()
	_expect(seeded_otters[0].homeless_since >= 0.0 and not seeded_otters[0].leaving, "freed, it needs a quiet place to rest")
	root.get_node("GameClock").advance(root.get_node("GameClock").DAY_LENGTH * 1.1)
	ecosystem.settle()
	_expect(seeded_otters[0].leaving, "with no Otter Habitat it moves away after a day")
	for animal in ecosystem.living(ecosystem.FISH) + ecosystem.living(ecosystem.CORMORANT):
		animal.free()
	seeded_otters[0].free()
	regions0.forget(load("res://data/regions/kelp_forest.tres"))

	# --- No otters: urchins build up and graze the kelp down, mostly within a day or two ---
	var bed: Node2D = beds[0]
	bed.health = 0.8
	bed.urchins = 2.0
	var urchin_goal: float = ecosystem.urchin_target(bed, 0.0)
	ecosystem.tick(0.25)
	ecosystem.tick(0.25)
	ecosystem.tick(0.25)
	ecosystem.tick(0.25)
	var day_one: float = (bed.urchins - 2.0) / (urchin_goal - 2.0)
	_expect(day_one > 0.45 and day_one < 0.6, "about half the change happens in the first day (%.0f%%)" % (day_one * 100.0))
	for i in 12:  # 3 more days
		ecosystem.tick(0.25)
	_expect(bed.urchins > urchin_goal * 0.9 and bed.health < 0.3,
		"within 4 days it has settled: many urchins (%.0f), kelp grazed down (%.2f)" % [bed.urchins, bed.health])

	# --- Restoration alone can't fix it while urchins are too many ---
	bed.restored_until = 1000.0
	for i in 16:
		ecosystem.tick(0.25)
	_expect(bed.health < 0.3, "restoring kelp alone doesn't last against overgrazing (%.2f)" % bed.health)
	bed.restored_until = -1.0

	# --- Otters anywhere on the island keep urchins down everywhere, and the kelp grows back ---
	var otter_nodes: Array = []
	for i in 6:
		var otter: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
		otter.set("data", load("res://data/animals/sea_otter.tres"))
		otter.position = beds[beds.size() - 1].global_position  # all at one end
		world.add_child(otter)
		otter_nodes.append(otter)
	var far_bed: Node2D = beds.reduce(func(a: Node2D, b: Node2D) -> Node2D:
		return a if a.global_position.distance_to(otter_nodes[0].global_position) > b.global_position.distance_to(otter_nodes[0].global_position) else b)
	ecosystem.nudge()
	_expect(bed.urchins < urchin_goal * 0.85, "a change shows straight away (%.1f urchins)" % bed.urchins)
	for i in 16:  # 4 days of the food web (these otters have no habitat, so not settle())
		ecosystem._approach(1.0 - pow(0.5, 0.25))
	_expect(far_bed.urchins < 2.5 and far_bed.health > 0.7,
		"even the bed furthest from the otters recovers within 4 days (%.1f urchins, kelp %.2f)" % [far_bed.urchins, far_bed.health])
	for otter: Node in otter_nodes:
		otter.free()

	# --- Fish follow the kelp, cormorants follow the fish (one change a morning) ---
	var regions: GDScript = load("res://scripts/world/regions.gd")
	regions.discover(load("res://data/regions/kelp_forest.tres"))
	for b: Node2D in beds:
		b.health = 0.1
	_expect(ecosystem.fish_supported() == 0, "thin kelp supports no fish")
	for b: Node2D in beds:
		b.health = 0.9
		b.urchins = 1.0
	var fish_target: int = ecosystem.fish_supported()
	_expect(fish_target >= 6, "a healthy forest supports fish (%d)" % fish_target)
	for i in fish_target + 1:
		ecosystem.settle()
	var fish: Array = ecosystem.living(ecosystem.FISH)
	_expect(fish.size() == fish_target, "fish come back to the kelp, one a morning (%d)" % fish.size())
	_expect(fish.all(func(f: Node2D) -> bool: return terrain.at(self, f.global_position) in ["water", ""]), "they live in the water by the kelp")
	var birds: Array = ecosystem.living(ecosystem.CORMORANT)
	_expect(birds.size() >= 1, "with fish to eat, cormorants arrive (%d)" % birds.size())
	for b: Node2D in beds:
		b.health = 0.1
	for i in 12:
		ecosystem.settle()
	_expect(ecosystem.living(ecosystem.FISH).is_empty() and ecosystem.living(ecosystem.CORMORANT).is_empty(),
		"the kelp collapses: fish swim away, and the cormorants follow")
	for b: Node2D in beds:
		b.health = 0.7
		b.urchins = 1.0

	# --- Cross-island: clean water at the Starting Island speeds the kelp's regrowth ---
	var spawner: Node = world.get_node("LitterSpawner")
	for d in get_nodes_in_group("debris"):
		d.free()
	var probe: Node2D = beds[3]
	probe.health = 0.2
	probe.urchins = 0.0
	ecosystem.tick(1.0)
	var clean_gain: float = probe.health - 0.2
	for i in 20:
		spawner.spawn_at(load("res://data/items/plastic_bottle.tres"), Vector2(-500 + i * 20, -300), true)
	probe.health = 0.2
	probe.urchins = 0.0
	ecosystem.tick(1.0)
	var dirty_gain: float = probe.health - 0.2
	_expect(clean_gain > dirty_gain * 1.2, "kelp grows back faster while the Starting Island's water is clean (%.3f vs %.3f)" % [clean_gain, dirty_gain])
	_expect(ecosystem.balance_report().contains("connected"), "the balance survey says why")
	for d in get_nodes_in_group("debris"):
		d.free()

	# --- A Kelp Restoration Site restores the island's most damaged beds, wherever it stands ---
	for b: Node2D in beds:
		b.health = 0.5
		b.urchins = 5.0
	for i in 8:
		ecosystem._approach(1.0 - pow(0.5, 0.25))
		for b: Node2D in beds:
			b.urchins = 5.0  # (a few otters about)
	var without: float = ecosystem.kelp_health()
	for b: Node2D in beds:
		b.health = 0.5
		b.urchins = 5.0
	var site: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/kelp_restoration_site.tres"),
		Vector2i((beds[0].global_position / 32.0).floor()))
	_expect(ecosystem._restored_by_sites().size() == 3, "it looks after 3 of the most damaged beds, anywhere on the island")
	for i in 8:
		ecosystem._approach(1.0 - pow(0.5, 0.25))
		for b: Node2D in beds:
			b.urchins = 5.0
	_expect(ecosystem.kelp_health() > without + 0.03, "the forest recovers further with it (%.2f vs %.2f)" % [ecosystem.kelp_health(), without])
	var worst_bed: Node2D = ecosystem._restored_by_sites()[0]
	for b: Node2D in beds:
		b.urchins = 12.0
	for i in 16:
		ecosystem._approach(1.0 - pow(0.5, 0.25))
		for b: Node2D in beds:
			b.urchins = 12.0
	_expect(worst_bed.health < 0.3, "but it can't beat overgrazing (%.2f)" % worst_bed.health)
	site.free()

	# --- The Build menu there offers the Kelp Forest's buildings, not the Starting Island's ---
	var player: Node2D = world.get_node("Player")
	player.global_position = load("res://data/regions/kelp_forest.tres").arrival
	var menu: Node = world.get_node("BuildMenu")
	menu.open()
	for id in ["otter_habitat", "kelp_research_platform", "kelp_restoration_site", "kelp_discovery_centre", "coastal_tree"]:
		_expect(menu.find_child("Entry_" + id, true, false) != null, "the Kelp Forest's Build menu has the %s" % id)
	for id in ["turtle_protection_area", "dolphin_viewing_area", "palm_tree", "marine_rescue_station"]:
		_expect(menu.find_child("Entry_" + id, true, false) == null, "but not the %s" % id)
	menu.close()

	# --- Island health follows the food web ---
	var health: GDScript = load("res://scripts/systems/island_health.gd")
	var kelp_region: Resource = load("res://data/regions/kelp_forest.tres")
	for b: Node2D in beds:
		b.health = 0.2
		b.urchins = 10.0
	var poor: float = health.of(self, kelp_region)
	_expect(poor >= 0.0 and poor < 0.4, "an overgrazed Kelp Forest is in poor health (%.2f)" % poor)
	for b: Node2D in beds:
		b.health = 0.9
		b.urchins = 2.0
	for d in get_nodes_in_group("debris"):
		if d.global_position.distance_to(kelp_region.center) < kelp_region.waters_radius:
			d.free()
	for id in ["sea_otter:4", "blue_rockfish:8", "double_crested_cormorant:3"]:
		var parts: PackedStringArray = id.split(":")
		var have: int = ecosystem.living(load("res://data/animals/%s.tres" % parts[0])).size()
		for i in int(parts[1]) - have:
			var animal: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
			animal.set("data", load("res://data/animals/%s.tres" % parts[0]))
			animal.position = beds[i % beds.size()].global_position
			world.add_child(animal)
	var full: float = health.of(self, kelp_region)
	_expect(is_equal_approx(full, 1.0), "dense kelp, urchins in balance, 4 otters, 8 fish, 3 cormorants, no litter: 100 %% (%.2f)" % full)
	for b: Node2D in beds:
		b.urchins = 0.0
	_expect(health.of(self, kelp_region) < 1.0, "no urchins at all isn't balance either")
	for b: Node2D in beds:
		b.urchins = 2.0

	# --- The objective: balance, then gather shed kelp → Kelp Fibre ---
	var fleet := root.get_node("Fleet")
	_expect(not fleet.objective_done(kelp_region), "the objective isn't done yet")
	ecosystem._objective()
	_expect(fleet.has_flag(&"kelp_balanced"), "a balanced food web is marked")
	for day in 4:
		for d in get_nodes_in_group("debris").filter(func(n: Node) -> bool: return n.item.id == &"shed_kelp"):
			d.collect()
		await process_frame
		ecosystem._objective()
	for d in get_nodes_in_group("debris").filter(func(n: Node) -> bool: return n.item.id == &"shed_kelp"):
		d.collect()
	_expect(fleet.count_of(&"shed_kelp") >= 5, "the healthy forest sheds kelp to gather (%d)" % fleet.count_of(&"shed_kelp"))
	_expect(fleet.objective_done(kelp_region) and fleet.has_found(&"kelp_fibre"), "objective done: Kelp Fibre found")

	# --- Saved ---
	var saved: Dictionary = ecosystem.to_dict()
	var saved_health: float = bed.health
	bed.health = 0.0
	bed.urchins = 0.0
	ecosystem.restore(saved)
	_expect(is_equal_approx(bed.health, saved_health), "the beds are restored from the save")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
