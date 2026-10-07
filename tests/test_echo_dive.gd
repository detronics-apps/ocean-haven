extends SceneTree
## Echo Dive: once Imani asks about the lost cargo module it's at the Deep-Ocean Outpost. The
## view sinks by itself, never back up; the sub moves about the screen (up only holds the depth);
## only the sonar light shows the dark (90 % on at level 1, 50 % at level 5); lost gear sinks
## slowly; wrecks and boulders slow it and add time; past
## the deep's animals at their real depths. The story dive reaches the cargo module at
## 1,000 m (Imani's cargo search); then it's for fun, each level 1,000 m deeper.
## Run: godot --headless --path . --script res://tests/test_echo_dive.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var activities := root.get_node("Activities")
	var fleet := root.get_node("Fleet")
	activities.restore({})
	root.get_node("People").restore({})
	fleet.restore({"flags": ["deep_mapped"]})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var deep: Resource = load("res://data/regions/deep_sea.tres")
	load("res://scripts/world/regions.gd").discover(deep)
	var dive_data: Resource = load("res://data/activities/echo_dive.tres")
	_expect(not activities.is_open(dive_data), "not before Imani asks about the cargo module")
	var imani: Resource = load("res://data/people/imani.tres")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	world.get_node("BuildMode").add_building(load("res://data/buildings/deep_ocean_outpost.tres"), terrain.cell_of(deep.arrival) + Vector2i(-2, 2))
	var people := root.get_node("People")
	people.talk(imani)
	people.talk(imani)
	people.finish_talk()
	_expect(people.check("asked:cargo", imani) and activities.is_open(dive_data), "Imani asks about the cargo: Echo Dive opens")

	var screen: Node = world.get_parent().find_child("EchoDive", true, false)
	screen.open_activity(dive_data)
	screen.call("_begin")
	_expect(screen.hearts() == 3, "the sub starts with 3 hearts")
	screen.obstacles().clear()  # (the controls first, with nothing in the way)
	for i in 90:
		screen.step(1.0 / 30.0, Vector2.ZERO)
	_expect(screen.get("_playing") and screen.depth() > 50.0, "the sub sinks with the view by itself")
	# Lower on the screen = faster; higher = slower. The sub can go back up the screen for something
	# it missed, but the view itself never goes back up.
	var slow_at_top: float
	var fast_at_bottom: float
	for i in 30:
		screen.step(1.0 / 30.0, Vector2(0, 1))
	var low_depth: float = screen.depth()
	var view_before: float = screen.get("_top")
	var view_rose := false
	for i in 40:
		var top: float = screen.get("_top")
		screen.step(1.0 / 30.0, Vector2(0, -1))
		view_rose = view_rose or float(screen.get("_top")) < top - 0.001
	slow_at_top = screen.sink_speed()
	_expect(screen.depth() < low_depth - 40.0, "holding up, the sub climbs back up the screen to reach what it missed (%.0f -> %.0f m)" % [low_depth, screen.depth()])
	_expect(not view_rose and float(screen.get("_top")) > view_before, "but the view never goes back up")
	for i in 90:
		screen.step(1.0 / 30.0, Vector2(0, 1))
	fast_at_bottom = screen.sink_speed()
	_expect(fast_at_bottom > slow_at_top * 3.0, "low on the screen it sinks much faster (%.0f vs %.0f m/s)" % [fast_at_bottom, slow_at_top])
	var x: float = screen.position_x()
	for i in 10:
		screen.step(1.0 / 30.0, Vector2(1, 0))
	_expect(screen.position_x() > x, "and it moves sideways")
	screen.set("_hearts", 3)
	screen.set("_bump_wait", 0.0)
	for i in 40:  # into the left wall: one heart lost, then safe for a moment (1.5 s)
		screen.step(1.0 / 30.0, Vector2(-1, 0))
	_expect(screen.position_x() - 0.03 >= screen.gap_at(screen.depth()).x - 0.001, "bumping a wall stops it at the rock")
	_expect(screen.hearts() == 2, "a bump costs one heart (%d left)" % screen.hearts())
	var kit := {"depth": screen.depth(), "x": screen.position_x()}
	screen.wrenches().append(kit)
	screen.step(1.0 / 30.0, Vector2.ZERO)
	_expect(screen.hearts() == 3 and not screen.wrenches().has(kit), "a repair kit gives a heart back")
	var got_before: int = screen.gear_got()
	screen.gear_left().append({"depth": screen.depth(), "x": screen.position_x(), "item": null})
	screen.step(1.0 / 30.0, Vector2.ZERO)
	_expect(screen.gear_got() == got_before + 1, "lost gear the sub reaches is picked up (%d)" % screen.gear_got())
	screen.set("_hearts", 99)  # (the autopilot below is about what's seen on the way, not steering)
	var lit := 0
	var dark_steps := 0
	var steps := 0
	while screen.get("_playing") and steps < 30000:  # dive down the middle, towards gear, round obstacles
		var d: float = screen.depth()
		var gap: Vector2 = screen.gap_at(d + 30.0)
		var aim := (gap.x + gap.y) / 2.0
		for piece: Dictionary in screen.gear_left():
			if absf(piece.depth - d) < 120.0:
				aim = piece.x
				break
		for thing: Dictionary in screen.obstacles():
			if thing.depth > d - 10.0 and thing.depth - d < 60.0 and absf(thing.x - aim) < 0.12:
				aim = thing.x + (0.15 if thing.x < (gap.x + gap.y) / 2.0 else -0.15)
		screen.step(1.0 / 30.0, Vector2(clampf((aim - screen.position_x()) * 8.0, -1.0, 1.0), 0.0))
		if screen.light_on():
			lit += 1
		else:
			dark_steps += 1
		steps += 1
	_expect(not screen.get("_playing") and screen.depth() >= 975.0, "down to 1,000 m (%d steps)" % steps)
	var time_now: float = screen.get("_time")
	var on_steps := 0
	for i in 1000:  # the light's timing over 10 cycles
		screen.set("_time", i * 0.02)
		on_steps += 1 if screen.light_on() else 0
	screen.set("_time", time_now)
	_expect(absf(on_steps / 1000.0 - 0.9) < 0.02, "level 1: the sonar light is on 90%% of the time (%.0f%%)" % (on_steps / 10.0))
	_expect(screen.daylight(50.0) > 0.7 and screen.daylight(1000.0) == 0.0, "daylight near the top, none in the deep")
	_expect(screen.seen().has("Giant squid") and screen.seen().has("Midnight zone") and screen.seen().has("Bottlenose dolphin"),
		"passing the dolphins, the giant squid's depth and into the midnight zone (%s)" % [screen.seen()])
	_expect(fleet.has_flag(&"cargo_located"), "the story dive found the cargo module")
	var levels: Array = dive_data.levels
	_expect(levels.size() == 5 and levels.map(func(l: Vector3i) -> int: return l.x * 100) == [1000, 2000, 3000, 4000, 5000],
		"each level is 1,000 m deeper, down to 5,000 m")
	var harder := true
	for i in range(1, levels.size()):
		harder = harder and levels[i].y > levels[i - 1].y and levels[i].z > levels[i - 1].z
	_expect(harder, "and each sinks faster with more obstacles")
	screen.level = 4
	screen.call("_begin")
	_expect(is_equal_approx(screen.light_share(), 0.5) and screen.obstacles().size() == levels[4].y, "level 5: light on half the time, %d obstacles" % screen.obstacles().size())
	# Out of hearts: the sub heads back up, and the depth reached is the record.
	screen.level = 1
	screen.call("_begin")
	for i in 120:
		screen.step(1.0 / 30.0, Vector2(0, 1))
	var reached: float = screen.depth()
	for i in 3:
		screen.set("_bump_wait", 0.0)
		screen.call("_bump", "a boulder")
	_expect(not screen.get("_playing") and screen.hearts() == 0, "three bumps and the sub needs repairs: the dive ends")
	_expect(absf(activities.best_depth(dive_data, 1) - reached) < 5.0 and activities.best(dive_data, 1) == INF,
		"before the sea floor is reached, the record is the depth (%.0f m)" % activities.best_depth(dive_data, 1))
	var info: String = screen.get("_info").text
	_expect(info.contains("%d m" % roundi(reached)) and not info.contains("fail"), "it says how deep you got, never 'failed' (%s)" % info)
	var level_button_text: String = ""
	screen.call("_show_levels")
	for b in screen.get("_buttons").get_children():
		if b.name == "Level2":
			level_button_text = b.text
	_expect(level_button_text.contains("Deepest"), "the level shows its deepest dive until the bottom is reached (%s)" % level_button_text)
	screen.level = 4
	screen.call("_begin")
	# A missed piece of gear above, still on screen: holding up, the sub gets back to it.
	for i in 60:  # down to the bottom of the screen first: room to wait under the piece
		screen.step(1.0 / 30.0, Vector2(0, 1))
	var piece := {"depth": screen.depth() - 40.0, "x": screen.position_x(), "item": null}
	screen.gear_left().append(piece)
	var got: int = screen.gear_got()
	for i in 200:
		screen.step(1.0 / 30.0, Vector2(0, -1))
	_expect(screen.gear_got() == got + 1, "a missed piece still on screen can be caught by going back up for it")
	screen.close_screen()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
