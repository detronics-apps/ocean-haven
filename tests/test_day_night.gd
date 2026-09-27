extends SceneTree
## Day/night: days roll over, noon is brighter than night, night stays playable.
## Run: godot --headless --path . --script res://tests/test_day_night.gd

var _failed := false


func _initialize() -> void:
	await process_frame
	var clock := root.get_node("GameClock")  # autoload: looked up at runtime
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	var tint: CanvasModulate = world.get_node("DayNight")

	clock.time_of_day = 0.5
	await process_frame
	var noon := tint.color
	clock.time_of_day = 0.0
	await process_frame
	var midnight := tint.color
	_expect(noon.v > midnight.v, "noon brighter than midnight")
	_expect(midnight.v >= 0.6, "night still bright enough to play (v=%.2f)" % midnight.v)

	clock.time_of_day = 0.3
	_expect(clock.period() == "Morning", "7am is Morning")

	var new_days: Array[int] = []
	clock.new_day.connect(func(d: int) -> void: new_days.append(d))
	clock.day = 1
	clock.time_of_day = 0.99
	clock.advance(0.02 * 600.0)  # 2% of a 600 s day
	_expect(clock.day == 2 and new_days == [2] and clock.time_of_day < 0.02, "midnight starts Day 2")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
