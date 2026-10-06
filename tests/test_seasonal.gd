extends SceneTree
## Seasonal moments and predict-then-watch. A few days a year something happens on an island
## (data/seasons/: the coral spawns on summer nights on the Reef, whales pass the Deep Sea in
## autumn, the terns arrive at the Polar Ocean in spring): the HUD says so, SeasonShow draws it,
## it's a photo moment, the island's hint-giver mentions it beforehand and the Journal lists it.
## Objective-givers ask a prediction with a reminder; the guess is kept and, once it's
## happened, they tell what really happened, next to the guess in the Journal. No score.
## Run: godot --headless --path . --script res://tests/test_seasonal.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	var clock := root.get_node("GameClock")
	var journal := root.get_node("Journal")
	people.restore({})
	fleet.restore({})
	journal.restore([])
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var events: Array = load("res://scripts/systems/season_event.gd").all()
	_expect(events.size() >= 3, "seasonal moments: %s" % [events.map(func(e: Resource) -> String: return e.id)])

	# --- The coral spawns on a summer night ---
	var spawning: Resource = load("res://data/seasons/coral_spawning.tres")
	clock.day = 38  # summer, day 8
	clock.time_of_day = 0.4
	_expect(not spawning.is_on(), "not by day")
	clock.time_of_day = 0.95
	_expect(spawning.is_on() and spawning.days_until() == 0, "on a summer night, day 8")
	clock.day = 33
	_expect(spawning.days_until() == 5, "5 days ahead (%d)" % spawning.days_until())
	var leilani: Resource = load("res://data/people/leilani.tres")
	_expect(people.check("soon:coral_spawning", leilani), "'soon' within a week")
	people.talk(leilani)  # (meeting her)
	var texts: Array = people.talk(leilani).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("spawns at once")), "Leilani tells the ranger to watch (%s)" % [texts])
	clock.day = 38
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	regions.discover(reef)
	world.get_node("Player").global_position = reef.arrival
	var hud: Node = world.get_node("HUD")
	hud.call("_check_unlocks")
	_expect(fleet.has_flag(&"seen_coral_spawning"), "the HUD says it's on, and it's marked seen")
	var show: Node = world.get_node("SeasonShow")
	show.refresh()
	_expect(show.event == spawning and show.get("_spots").size() > 0, "SeasonShow draws the spawn over the reef (%d spots)" % show.get("_spots").size())
	var clam: Node2D = null
	for animal: Node2D in get_nodes_in_group("animals"):
		if animal.data.id == &"giant_clam" and regions.nearest(animal.global_position) == reef:
			clam = animal
	if clam:
		_expect(clam.moment_holds("event:coral_spawning"), "a giant clam on that night is a photo moment")
	var screen: Node = world.find_child("JournalScreen", true, false)
	screen.open()
	var card: Node = screen.find_child("Seasons", true, false)
	_expect(card != null, "the Journal lists the island's seasonal moments")
	screen.close()
	clock.day = 50
	show.refresh()
	_expect(show.event == null, "over after day 10")

	# --- Predict, then watch: Maya ---
	world.get_node("Player").global_position = Vector2(0, 0)
	var maya: Resource = load("res://data/people/maya.tres")
	people.talk(maya)  # meets her: the photos question
	people.finish_talk()
	world.get_node("BuildMode").add_building(load("res://data/buildings/turtle_protection_area.tres"), Vector2i(-10, -10))
	var lines: Array = people.talk(maya)
	people.finish_talk()
	var guess_line: Dictionary = {}
	for line: Dictionary in lines:
		if line.has("predict"):
			guess_line = line
	_expect(not guess_line.is_empty() and guess_line.options.size() == 2, "with the reminder, Maya asks what will happen on the quiet sand")
	people.chose(guess_line, 1)
	var guesses: Array = people.predictions(&"home_island")
	_expect(guesses.size() == 1 and guesses[0].guess == "Nothing, yet." and guesses[0].outcome == "", "the guess is kept, still to see (%s)" % [guesses])
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(not texts.any(func(t: String) -> bool: return t.contains("quiet sand?")), "not asked twice")
	journal.record_nest(load("res://data/animals/green_turtle.tres"))
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("You said: \"Nothing, yet.\"")) and texts.any(func(t: String) -> bool: return t.contains("first nest")),
		"once a turtle nests, Maya tells what really happened (%s)" % [texts])
	_expect(people.predictions(&"home_island")[0].outcome.contains("first nest"), "and the Journal shows it next to the guess")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(people.to_dict()))
	people.restore({})
	people.restore(saved)
	_expect(people.predictions(&"home_island").size() == 1, "predictions are saved")
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(not texts.any(func(t: String) -> bool: return t.contains("You said")), "told only once")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
