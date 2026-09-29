extends SceneTree
## Islands the ranger isn't on are paused: no storms start or strike there, no animals get
## caught, the ecosystem waits; only a little litter washes in, when the ranger gets back.
## Run: godot --headless --path . --script res://tests/test_away.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var clock := root.get_node("GameClock")
	var events := root.get_node("RareEvents")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	regions.discover(kelp)
	var player: Node2D = world.get_node("Player")
	player.global_position = Vector2(0, 0)  # on the Starting Island
	await process_frame
	_expect(regions.ranger_on(self, load("res://data/regions/home_island.tres")) and not regions.ranger_on(self, kelp),
		"the ranger is on the Starting Island, not the Kelp Forest")

	# --- Animals don't get caught on an island the ranger isn't on ---
	var spawner: Node = world.get_node("KelpLitter")
	var otter: Node2D = world.get_node("KelpIsland/Ecosystem").otters()[0]
	otter.restore_freed()
	var net: Node2D = spawner.spawn_at(load("res://data/items/ghost_net.tres"), otter.global_position + Vector2(20, 0), true)
	_expect(spawner.entangle().is_empty() and not otter.tangled, "no animal is caught while the ranger is away")

	# --- The ecosystem waits ---
	var ecosystem: Node = world.get_node("KelpIsland/Ecosystem")
	var urchins: float = ecosystem.urchin_amount()
	for i in 3:
		clock.advance(clock.DAY_LENGTH * 0.5)
		await process_frame
	_expect(absf(ecosystem.urchin_amount() - urchins) < 0.01, "the kelp food web doesn't change while the ranger is away")

	# --- Storms: none start there, and a warned one waits for the ranger ---
	var swell: Resource = load("res://data/events/underwater_storm.tres")
	events.restore({})
	events.call("_on_new_day", 999)  # long overdue: it would be certain on the island
	_expect(not events.is_coming_to(&"kelp_forest"), "no storm starts on an island the ranger isn't on")
	events.warn(swell)
	for bed: Node2D in ecosystem.beds():
		bed.storm_hit = false
	events.call("_on_new_day", clock.day + 5)
	_expect(events.is_coming_to(&"kelp_forest") and not ecosystem.beds().any(func(b: Node) -> bool: return b.storm_hit),
		"a warned storm doesn't strike while the ranger is away: it waits")

	# --- Back on the island: a little litter has washed in, and time runs again ---
	net.remove()
	await process_frame
	var litter_before: int = spawner.call("_litter_in_area")
	events.call("_process", 2.0)  # (it knows the ranger is on the Starting Island)
	player.global_position = kelp.center + Vector2(0, 40)
	await process_frame
	await process_frame
	var litter_after: int = spawner.call("_litter_in_area")
	_expect(litter_after > litter_before and litter_after - litter_before <= kelp.away_litter_max,
		"back on the island: a little litter washed in while you were away (%d -> %d)" % [litter_before, litter_after])
	events.call("_process", 2.0)  # notices the ranger is back
	var back: int = clock.day
	events._coming[&"underwater_storm"] = back + 1  # due the morning after coming back
	events.call("_on_new_day", back + 1)
	_expect(events.is_coming_to(&"kelp_forest"), "no storm in the first 2 days back")
	events.call("_on_new_day", back + 2)
	_expect(not events.is_coming_to(&"kelp_forest"), "then the warned storm strikes")

	# --- The time between storms kept counting while away: a new one can come soon after ---
	events.restore({"last_day": {"underwater_storm": back + 2}, "back_on": {"kelp_forest": back + 100}})
	events.call("_process", 2.0)
	clock.day = back + 100
	events.call("_on_new_day", back + 100)
	_expect(events.is_coming_to(&"kelp_forest") and events._coming[&"underwater_storm"] >= back + 103,
		"back after 100 days away, it's overdue: warned 3-4 days ahead, never within 2 days of coming back")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
