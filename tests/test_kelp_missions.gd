extends SceneTree
## The Kelp Research Platform (the Kelp Forest's signature facility): its missions turn the
## hidden food web into information and give the ranger something to do about it —
## surveys mark where to look, restoration and relocation change the beds.
## Run: godot --headless --path . --script res://tests/test_kelp_missions.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var missions := root.get_node("Missions")
	var clock := root.get_node("GameClock")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	load("res://scripts/world/regions.gd").discover(kelp)
	root.get_node("Funding").restore({"balance": 2000})
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var offered: Array = missions.offered_by(&"kelp_research_platform").map(func(m: Resource) -> StringName: return m.id)
	_expect(offered == [&"kelp_health_survey", &"urchin_pressure_survey", &"otter_monitoring", &"ecosystem_balance_survey",
		&"kelp_restoration", &"urchin_relocation", &"storm_damage_survey"], "the platform offers its 7 missions (%s)" % [offered])
	var station: Resource = load("res://data/buildings/kelp_research_platform.tres")
	_expect(station.only_on == &"kelp_forest" and station.one_per_island and station.facility == &"signature", "one per island, only in the Kelp Forest")

	# --- Kelp health survey: marks the damaged beds ---
	await _send(missions, clock, "kelp_health_survey", kelp)
	var damaged: int = ecosystem.beds().filter(func(b: Node) -> bool: return b.health < 0.4).size()
	_expect(missions.marked().size() == damaged and damaged > 0 and missions.last_report.contains("damaged"),
		"the kelp survey marks the %d damaged beds and says so (%s)" % [damaged, missions.last_report])

	# --- Urchin pressure survey: the overgrazed beds, and that no otters are near them ---
	await _send(missions, clock, "urchin_pressure_survey", kelp)
	_expect(missions.marked().size() > 0 and missions.last_report.contains("otter"),
		"the urchin survey marks the overgrazed beds and points at the otters (%s)" % missions.last_report)

	# --- Otter monitoring, and the balance survey ---
	await _send(missions, clock, "otter_monitoring", kelp)
	_expect(missions.last_report.contains("Otter Habitat"), "otter monitoring: with no habitat yet, it says to build one (%s)" % missions.last_report)
	await _send(missions, clock, "ecosystem_balance_survey", kelp)
	_expect(missions.last_report.contains("Otters: 0") and missions.last_report.contains("cormorants"),
		"the balance survey spells out the food web (%s)" % missions.last_report)

	# --- Restoration: the most damaged beds get replanted and grow faster ---
	var worst: Node2D = ecosystem.beds().reduce(func(a: Node2D, b: Node2D) -> Node2D: return a if a.health <= b.health else b)
	var before: float = worst.health
	await _send(missions, clock, "kelp_restoration", kelp)
	_expect(worst in missions.marked() and worst.health > before and worst.restored_until > clock.now(),
		"kelp restoration replants the most damaged beds (%.2f -> %.2f)" % [before, worst.health])
	_expect(missions.last_report.contains("won't last"), "and warns it won't last while urchins overgraze them")

	# --- Relocation: urchins moved from the worst bed to lightly grazed ones ---
	var beds: Array = ecosystem.beds()
	var most: Node2D = beds.reduce(func(a: Node2D, b: Node2D) -> Node2D: return a if a.urchins >= b.urchins else b)
	var total: float = beds.reduce(func(sum: float, b: Node2D) -> float: return sum + b.urchins, 0.0)
	var from_before: float = most.urchins
	var result: Dictionary = ecosystem.run_mission(load("res://data/missions/urchin_relocation.tres"))
	_expect(most in result.found and result.detail.contains("aren't the enemy"), "it marks where they came from and went")
	var total_after: float = beds.reduce(func(sum: float, b: Node2D) -> float: return sum + b.urchins, 0.0)
	_expect(most.urchins < from_before and absf(total_after - total) < 0.01,
		"urchin relocation moves them, it doesn't remove them (%.0f -> %.0f; total %.0f -> %.0f)" % [from_before, most.urchins, total, total_after])

	# --- Storm damage survey: nothing to find without a storm ---
	await _send(missions, clock, "storm_damage_survey", kelp)
	_expect(missions.last_report.contains("No storm damage"), "the storm damage survey only finds storm damage")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _send(missions: Node, clock: Node, id: String, region: Resource) -> void:
	var mission: Resource = load("res://data/missions/%s.tres" % id)
	if not missions.send(mission, region):
		_expect(false, "sent %s (%s)" % [id, missions.problem(mission)])
	clock.advance(mission.minutes * 60.0 + 1.0)
	await process_frame
	await process_frame


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
