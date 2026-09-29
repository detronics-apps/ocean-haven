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

	# --- Saved ---
	var saved: Dictionary = ecosystem.to_dict()
	bed.health = 0.0
	bed.urchins = 0.0
	ecosystem.restore(saved)
	_expect(bed.health > 0.6 and bed.urchins > 0.0, "the beds are restored from the save")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
