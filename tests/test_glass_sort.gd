extends SceneTree
## Glass Sort: once the Glassworks is firing its first batch, Kai's sorting bench opens. Pour
## the top layer from jar to jar (onto the same colour or into an empty jar, while there's
## room) until every jar is one colour. Boards are shuffled from a sorted one, so they can be
## solved; "Start again" puts them back. The story play finishes the first batch of glass.
## Run: godot --headless --path . --script res://tests/test_glass_sort.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var activities := root.get_node("Activities")
	activities.restore({})
	root.get_node("Fleet").restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	load("res://scripts/world/regions.gd").discover(reef)
	var data: Resource = load("res://data/activities/glass_sort.tres")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var works: Node = world.get_node("BuildMode").add_building(load("res://data/buildings/glassworks.tres"), terrain.cell_of(reef.arrival) + Vector2i(2, -2))
	_expect(not activities.is_open(data), "not before the Glassworks is firing")
	root.get_node("Inventory").add(load("res://data/items/sand.tres"), 3)
	works.start_capability()
	_expect(activities.is_open(data), "sand in the furnace: Glass Sort opens")

	var screen: Node = world.get_parent().find_child("GlassSort", true, false)
	screen.open_activity(data)
	screen.call("_begin")
	_expect(not screen.solved() and screen.jars.size() == 5, "five jars, all mixed up")
	var start: Array = screen.jars.duplicate(true)
	_expect(screen.pour(0, 0) == 0, "(can't pour a jar into itself)")
	var path := _solve(screen.jars, 4)
	_expect(not path.is_empty(), "there's a way to sort it (%d pours)" % path.size())
	screen.pour(path[0].x, path[0].y)
	screen.restart()
	_expect(screen.jars == start, "'Start again' puts the jars back")
	for move: Vector2i in path:
		screen.pour(move.x, move.y)
	_expect(screen.solved() and not screen.get("_playing"), "sorted: done")
	_expect(activities.story_done(data) and works.batch_done_at <= root.get_node("GameClock").now() + 0.001,
		"the story play finishes the first batch of glass at once")
	screen.close_screen()
	var all_solvable := true
	for i in 20:
		screen.set("_playing", true)
		screen.set("_depth", 4)
		screen.call("_deal", 4, 2)
		all_solvable = all_solvable and not _solve(screen.jars, 4).is_empty()
	_expect(all_solvable, "every shuffled board can be sorted")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


## Breadth-first search over pours (the same rule as the game).
func _solve(jars: Array, depth: int) -> Array:
	var seen := {}
	var queue: Array = [[jars.duplicate(true), []]]
	seen[str(jars)] = true
	while not queue.is_empty() and seen.size() < 200000:
		var item: Array = queue.pop_front()
		var state: Array = item[0]
		if _sorted(state, depth):
			return item[1]
		for a in state.size():
			for b in state.size():
				if a == b or state[a].is_empty() or state[b].size() >= depth:
					continue
				var colour: int = state[a].back()
				if not state[b].is_empty() and state[b].back() != colour:
					continue
				var next: Array = state.duplicate(true)
				while not next[a].is_empty() and next[a].back() == colour and next[b].size() < depth:
					next[b].append(next[a].pop_back())
				var key := str(next)
				if not seen.has(key):
					seen[key] = true
					var moves: Array = item[1].duplicate()
					moves.append(Vector2i(a, b))
					queue.append([next, moves])
	return []


func _sorted(state: Array, depth: int) -> bool:
	for jar: Array in state:
		if not jar.is_empty() and (jar.size() != depth or jar.any(func(c: int) -> bool: return c != jar[0])):
			return false
	return true


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
