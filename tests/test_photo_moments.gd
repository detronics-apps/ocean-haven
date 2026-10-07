extends SceneTree
## Photo moments: each species has 2-3 special situations to photograph it in (a hatchling, a
## crab digging, a dolphin leading you to litter...). The first photo of each is kept in the
## Journal; ordinary photos still count (research funding) but aren't kept; missing moments
## show as a hint. Maya mentions the collection. Released rescue companions that travel can turn
## up on another island, but only while both islands are healthy.
## Run: godot --headless --path . --script res://tests/test_photo_moments.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var journal := root.get_node("Journal")
	journal.photos_dir = OS.get_temp_dir().path_join("bluehaven_test_photos")  # never the player's folder
	journal.restore([])
	root.get_node("Rescues").restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var turtle_data: Resource = load("res://data/animals/green_turtle.tres")
	_expect(turtle_data.moments.size() == 3, "the green turtle has 3 photo moments")
	var missing: Array = []
	for animal: Resource in load("res://scripts/systems/data_files.gd").load_all("res://data/animals"):
		if animal.id != &"sea_urchin" and (animal.moments.size() < 2 or animal.moments.size() > 3):
			missing.append(animal.id)
	_expect(missing.is_empty(), "every species has 2-3 moments (%s)" % [missing])

	# --- A hatchling: its moment is caught with the photo ---
	var baby: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	baby.set("data", turtle_data)
	baby.set("young", true)
	baby.set("born_at", root.get_node("GameClock").now())
	baby.position = Vector2(-500, 100)
	world.add_child(baby)
	await process_frame
	var caught: Array = []
	journal.moment_caught.connect(func(a: Resource, m: Resource) -> void: caught.append(m.id))
	baby.call("_interact")
	_expect(caught == [&"hatchling"] and journal.has_moment(&"green_turtle", &"hatchling"), "photographing a hatchling catches the 'hatchling' moment (%s)" % [caught])
	baby.set("photo_day", -1)
	baby.call("_interact")
	_expect(caught.size() == 1 and journal.photos(&"green_turtle") == 2, "photos still count, but the same moment isn't kept twice")

	# --- Situations ---
	var crab: Node2D = world.get_node("Crab1")
	crab.set("_dug_at", root.get_node("GameClock").now())
	_expect(crab.moment_holds("digging"), "a crab that just dug something up is 'digging'")
	root.get_node("GameClock").time_of_day = 0.95
	_expect(crab.moment_holds("night") and not crab.moment_holds("day"), "night and day")
	root.get_node("GameClock").time_of_day = 0.4

	# --- The Journal shows the album: the kept one, and hints for the rest ---
	var screen: Node = world.get_parent().find_child("JournalScreen", true, false)
	if screen == null:
		screen = world.find_child("JournalScreen", true, false)
	_expect(screen != null, "(the Journal)")
	screen.set("tab", screen.ANIMALS)
	screen.open()
	var entry: Node = screen.find_child("Entry_green_turtle", true, false)
	_expect(entry != null and entry.find_child("Album", true, false) == null, "the list is simple: picture, name, what it does")
	screen.open_animal(turtle_data)
	var album: Node = screen.find_child("Album", true, false)
	_expect(album != null and album.get_child_count() == 3, "the turtle's page shows its 3 moments")
	var labels: Array = album.get_children().map(func(c: Node) -> String: return (c.get_child(1) as Label).text)
	_expect(labels.has("A hatchling") and labels.any(func(t: String) -> bool: return t.ends_with("?")), "the caught one by name, the others as hints (%s)" % [labels])
	(screen.find_child("Back", true, false) as Button).pressed.emit()
	await process_frame
	_expect(screen.find_child("Album", true, false) == null and screen.find_child("Entry_green_turtle", true, false) != null, "Back: the list again")
	screen.set("only_found", true)
	screen.refresh()
	_expect(screen.find_child("Entry_sperm_whale", true, false) == null and screen.find_child("Entry_green_turtle", true, false) != null,
		"'Only what I've found' hides the rest")
	screen.set("only_found", false)
	screen.close()

	# --- Saved ---
	var saved: Dictionary = journal.details()
	journal.restore([], {})
	journal.restore(journal.ids(), saved)
	_expect(journal.has_moment(&"green_turtle", &"hatchling"), "moments are saved")

	# --- Maya mentions the collection to a ranger who has moved on ---
	root.get_node("Fleet").restore({"installed": ["salvaged_sonar_core"], "flags": ["wreck_found", "wreck_cleared", "sonar_recovered"]})
	root.get_node("People").restore({"met": ["maya"]})
	var texts: Array = root.get_node("People").talk(load("res://data/people/maya.tres")).map(func(l: Dictionary) -> String: return l.text)
	root.get_node("People").finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("1 of %d photo moments" % journal.moments_total())), "Maya: '1 of N photo moments so far' (%s)" % [texts])

	# --- A released turtle visits only healthy islands ---
	var rescues := root.get_node("Rescues")
	rescues.restore({"done": {"home_turtle": {"name": "Milo", "day": 40}}})
	var mangrove: Resource = load("res://data/regions/mangrove_coast.tres")
	load("res://scripts/world/regions.gd").discover(mangrove)
	world.get_node("Player").global_position = mangrove.arrival
	rescues.check_visits()
	_expect(world.get_node_or_null("Visiting_home_turtle") == null, "while the islands aren't healthy, Milo doesn't turn up")
	var visitor: Node2D = world.visit_animal(load("res://data/rescues/home_turtle.tres"), "Milo", mangrove)
	_expect(visitor.visiting and load("res://scripts/world/regions.gd").nearest(visitor.global_position) == mangrove, "a visit: Milo swims near the Mangrove Coast, just visiting")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
