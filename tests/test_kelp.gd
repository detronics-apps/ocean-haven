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

	# --- Not discovered yet: nothing changes ---
	var before: float = ecosystem.kelp_health()
	root.get_node("GameClock").advance(600.0)
	await process_frame
	_expect(is_equal_approx(ecosystem.kelp_health(), before), "nothing happens before the island is found")

	# --- Overgrazing: urchins multiply and the kelp thins to a barren ---
	var bed: Node2D = beds[0]
	bed.health = 0.8
	bed.urchins = 8.0
	for i in 40:  # 10 days
		ecosystem.tick(0.25)
	_expect(bed.urchins > 10.0 and bed.health < 0.2, "many urchins: they multiply (%.0f) and graze it bare (%.2f)" % [bed.urchins, bed.health])

	# --- Restoration alone can't fix it while urchins are too many ---
	bed.restored_until = 1000.0
	for i in 40:
		ecosystem.tick(0.25)
	_expect(bed.health < 0.5, "restoring kelp alone doesn't last against overgrazing (%.2f)" % bed.health)
	bed.restored_until = -1.0

	# --- Few urchins: the kelp grows back (but some urchins always drift in) ---
	bed.urchins = 1.0
	var other: Node2D = beds[1]
	other.urchins = 0.0
	for i in 8:
		ecosystem.tick(0.25)
		bed.urchins = minf(bed.urchins, 2.0)  # (otters would keep them down)
	_expect(other.urchins > 0.0, "a bed never stays without urchins: a few drift in")
	for i in 32:
		ecosystem.tick(0.25)
		bed.urchins = minf(bed.urchins, 2.0)
	_expect(bed.health > 0.6, "with few urchins the kelp grows back (%.2f)" % bed.health)

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

	# --- A Kelp Restoration Site helps the beds near it grow back faster ---
	var near_bed: Node2D = beds[2]
	var far_bed: Node2D = beds.reduce(func(a: Node2D, b: Node2D) -> Node2D:
		return a if a.position.distance_to(near_bed.position) > b.position.distance_to(near_bed.position) else b)
	var site: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/kelp_restoration_site.tres"),
		Vector2i((near_bed.global_position / 32.0).floor()))
	for b: Node2D in [near_bed, far_bed]:
		b.health = 0.2
		b.urchins = 1.0
	for i in 8:
		ecosystem.tick(0.25)
		near_bed.urchins = 1.0
		far_bed.urchins = 1.0
	_expect(near_bed.health > far_bed.health + 0.1, "a restoration site speeds up kelp near it (%.2f vs %.2f far away)" % [near_bed.health, far_bed.health])
	near_bed.urchins = 12.0
	for i in 40:
		ecosystem.tick(0.25)
	_expect(near_bed.health < 0.5, "but it can't beat overgrazing (%.2f)" % near_bed.health)
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
