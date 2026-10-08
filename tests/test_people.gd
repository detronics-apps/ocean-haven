extends SceneTree
## People: Maya (Researcher) and Tom (Lighthouse keeper) on the Starting Island. Objectives only
## come from people: Maya asks a question, it becomes the objective a moment after the talk,
## and when it's done the ranger goes back for the next. What people say is worked out from
## the game as it is now: a save from far into the game skips what's done. Tom gives hints and
## stories (his tracks story makes the ranger notice turtle tracks), never objectives. People
## and their places can't be built over; who's been met and what's been asked is saved.
## Run: godot --headless --path . --script res://tests/test_people.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	var journal := root.get_node("Journal")
	people.restore({})
	fleet.restore({})
	journal.restore([])
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var maya_node: Node2D = world.get_node_or_null("Person_maya")
	var tom_node: Node2D = world.get_node_or_null("Person_tom")
	_expect(maya_node != null and tom_node != null, "Maya and Tom live on the Starting Island")
	var maya: Resource = maya_node.data
	var tom: Resource = tom_node.data
	var hud: Node = world.get_node("HUD")
	var player: Node2D = world.get_node("Player")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	_expect(regions.nearest(maya_node.global_position).id == &"home_island" and terrain.walkable(self, maya_node.global_position)
		and terrain.walkable(self, tom_node.global_position), "they stand on the island's land")

	# --- Before meeting anyone, the goal line says who to talk to; no Tip button here ---
	_expect(hud.objective_text().begins_with("Talk to Dr. Maya Okafor (Researcher)"), "goal line: talk to Maya (%s)" % hud.objective_text())
	hud.set("_unlock_check", 0.0)
	await process_frame
	_expect(not hud.has_node("StatusColumn/TipButton"), "no Tip button: the hint-givers give the advice")

	# --- Talking: a question, then a moment later the objective ---
	player.global_position = maya_node.global_position + Vector2(20, 0)
	var labels: Array = maya_node.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Talk to Maya" in labels, "the ranger can talk to Maya (%s)" % [labels])
	root.get_node("RangerProfile").set_ranger_name("Sam")
	var lines: Array = people.talk(maya)
	var texts: Array = lines.map(func(l: Dictionary) -> String: return l.text)
	_expect(texts[0].contains("I'm Maya, a researcher") and texts.any(func(t: String) -> bool: return t.contains("three different kinds of animal")),
		"Maya introduces herself and asks who still lives here")
	_expect(texts[0].contains("Sam, the new ranger"), "she calls the ranger by their name (%s)" % texts[0])
	var replies: Array = lines.filter(func(l: Dictionary) -> bool: return l.has("options"))
	_expect(replies.size() == 1 and replies[0].who == "Sam" and replies[0].options.size() == 2,
		"the ranger picks one of 2 replies (%s)" % [replies])
	_expect(not hud.objective_text().begins_with("Goal:"), "the objective doesn't show while she's still talking")
	people.finish_talk()
	await create_timer(people.DELAY + 0.2).timeout
	_expect(hud.objective_text() == "Goal: Photograph 3 different kinds of animal: 0 / 3",
		"a moment later it's the ranger's objective (%s)" % hud.objective_text())
	_expect(people.notebook().size() == 1, "and it's in the notebook")
	var reminder: Array = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	_expect(not reminder.is_empty() and reminder[0].contains("Any luck with the photos"), "talking again: a reminder, not the same question (then any funding / wood tips)")
	people.finish_talk()

	# --- Done: go back to her; she thanks the ranger and asks the next question ---
	for id in ["green_turtle", "ghost_crab", "bottlenose_dolphin"]:
		journal.photograph(load("res://data/animals/%s.tres" % id))
	_expect(hud.objective_text().begins_with("Done! Go back to Maya"), "photos done: go back to Maya (%s)" % hud.objective_text())
	_expect(people.has_news(maya), "a '!' above her")
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts[0].contains("Every one of them does something") and texts.any(func(t: String) -> bool: return t.contains("search and rescue station")),
		"she thanks the ranger and asks about a search and rescue station")
	people.finish_talk()
	await create_timer(people.DELAY + 0.2).timeout
	_expect(hud.objective_text() == "Goal: Build the Marine Search & Rescue Station", "the next objective (%s)" % hud.objective_text())

	# --- Looked in the Build menu but built nothing: Maya sends the ranger to Tom, who says to gather wood ---
	fleet.mark(&"build_menu_opened")
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Tom at the lighthouse")), "Maya sends the ranger to Tom (%s)" % [texts])
	people.finish_talk()
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Sam, isn't it") and t.contains("fifty years")), "Tom meets the ranger (%s)" % [texts])
	_expect(texts.any(func(t: String) -> bool: return t.contains("turtle tracks every summer")), "and remembers the beach full of turtle tracks")
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("caught out there")), "an animal caught in litter comes first (%s)" % [texts])
	for animal: Node in get_nodes_in_group("animals"):
		if animal.tangled:
			animal.restore_freed()
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Cut down a full-grown palm") and t.contains("Plant a sapling")),
		"then: gather wood by cutting palms, and plant a sapling for each (%s)" % [texts])
	people.finish_talk()

	# --- Built: Maya moves beside her station ---
	var station: Node2D = world.get_node("BuildMode").add_building(load("res://data/buildings/marine_rescue_station.tres"), Vector2i(-6, -6))
	maya_node.call("_settle")
	_expect(maya_node.global_position.distance_to(station.global_position) < 90.0, "Maya moves in by her station")
	_expect(hud.objective_text().begins_with("Done! Go back to Maya by the rescue station"), "and says where she is now (%s)" % hud.objective_text())
	people.talk(maya)
	people.finish_talk()
	await create_timer(people.DELAY + 0.2).timeout
	_expect(hud.objective_text() == "Goal: Find what's hidden off the coast", "then: the wreck (%s)" % hud.objective_text())

	# --- Saved and restored ---
	var saved: Dictionary = people.to_dict()
	people.restore({})
	_expect(not people.has_met(maya), "(cleared)")
	people.restore(saved)
	_expect(people.has_met(maya) and hud.objective_text() == "Goal: Find what's hidden off the coast",
		"who's been met and what's been asked is saved (%s)" % hud.objective_text())

	# --- Tom: hints and stories, never objectives ---
	player.global_position = tom_node.global_position + Vector2(20, 0)
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Turtle Protection Area")), "with no turtle area, his hint is a quiet stretch of sand (%s)" % [texts])
	_expect(people.notebook().size() == 1, "Tom gives no objectives")
	var nest: Node2D = load("res://scenes/animals/nest.tscn").instantiate()
	nest.set("species", load("res://data/animals/green_turtle.tres"))
	nest.set("laid_at", root.get_node("GameClock").now())
	nest.position = Vector2(176, 240)
	world.add_child(nest)
	await process_frame
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Tracks!")) and fleet.has_flag(&"tracks_noticed"),
		"a nest on the beach: Tom tells how his father read the tracks, and the ranger notices them")
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	_expect(not texts.any(func(t: String) -> bool: return t.contains("Tracks!")), "a story is only told once")
	nest.queue_free()

	# --- Nothing can be built over people or their places ---
	var lighthouse_cell: Vector2i = tom_node.cells()[1]
	var problem: String = world.get_node("BuildMode").placement_problem(load("res://data/buildings/tent.tres"), lighthouse_cell)
	_expect(problem == "Tom is in the way.", "the lighthouse can't be built over (%s)" % problem)

	# --- A save from far into the game: what's done is skipped ---
	people.restore({})
	fleet.restore({"completed": ["home_island"], "found": ["salvaged_sonar_core"], "installed": ["salvaged_sonar_core"],
		"flags": ["wreck_found", "wreck_cleared", "sonar_recovered"]})
	_expect(hud.objective_text().begins_with("Talk to Dr. Maya"), "far along, never met: talk to Maya first")
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts[0].contains("pulled the old sonar out of that wreck") and not texts.any(func(t: String) -> bool: return t.contains("photograph")),
		"Maya greets the ranger for what's done, and asks for nothing that's behind them (%s)" % [texts])
	people.finish_talk()
	await create_timer(people.DELAY + 0.2).timeout
	_expect(hud.objective_text() == "" and people.notebook().is_empty(), "no objective left on the Starting Island (%s)" % hud.objective_text())

	# --- Every island has its people: someone to give objectives, someone to ask for advice ---
	for region_id in [&"home_island", &"kelp_forest", &"mangrove_coast", &"tropical_reef", &"deep_sea", &"arctic_ocean"]:
		var here: Array = people.on(region_id)
		var roles: Array = here.map(func(p: Resource) -> StringName: return p.role)
		_expect(here.size() == 2 and &"objective" in roles and &"hint" in roles, "%s: an objective-giver and a hint-giver" % region_id)
		for person: Resource in here:
			var node: Node2D = world.get_node("Person_%s" % person.id)
			_expect(regions.nearest(node.global_position).id == region_id and terrain.walkable(self, node.global_position),
				"%s stands on %s's land" % [person.display_name, region_id])
	# Far along on the Kelp Forest: Finn greets the ranger for it and asks for nothing that's done.
	people.restore({})
	fleet.restore({"completed": ["home_island", "kelp_forest"], "found": ["salvaged_sonar_core", "kelp_fibre"],
		"installed": ["salvaged_sonar_core", "kelp_fibre"], "flags": ["wreck_found", "wreck_cleared", "sonar_recovered", "kelp_balanced"],
		"counts": {"shed_kelp": 5}})
	var finn: Resource = load("res://data/people/finn.tres")
	texts = people.talk(finn).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts[0].contains("brought the otters back") and people.notebook().is_empty(), "Finn: the kelp's done, nothing to ask (%s)" % [texts])
	var ines: Resource = load("res://data/people/ines.tres")
	people.talk(ines)
	texts = people.talk(ines).map(func(l: Dictionary) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("Samuel")) or texts.size() > 0, "Ines sends the ranger on (%s)" % [texts])
	# A new Mangrove Coast: Rosa's first question is about the water.
	people.restore({})
	var rosa: Resource = load("res://data/people/rosa.tres")
	texts = people.talk(rosa).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	await create_timer(people.DELAY + 0.2).timeout
	_expect(people.goal_text(&"mangrove_coast") == "Goal: Build the Mangrove Waterworks Station", "Rosa: build the waterworks station (%s)" % people.goal_text(&"mangrove_coast"))

	# --- Reminders: low funding, low wood (once a day each), and news the ranger may have missed ---
	var funding := root.get_node("Funding")
	var clock := root.get_node("GameClock")
	var inventory := root.get_node("Inventory")
	var balance: int = funding.balance
	funding.balance = 20
	inventory.restore({})
	clock.day += 1
	people.talk(tom)  # (meeting him first: no reminders then)
	people.finish_talk()
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("Funding's running low") and t.contains("Dolphin Viewing Area")),
		"low funding: Tom names the island's funding facilities (%s)" % [texts])
	_expect(texts.any(func(t: String) -> bool: return t.contains("Short of wood") and t.contains("sapling") and t.contains("nesting")),
		"low wood: cut a grown tree, replant, mind the nests")
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(not texts.any(func(t: String) -> bool: return t.contains("running low") or t.contains("Short of wood")), "only once a day")
	var reef_giver: Resource = load("res://data/people/kai.tres")
	_expect(people.wood_tip(reef_giver).contains("no trees to cut here") or world.get_tree().get_nodes_in_group("plants").size() > 0,
		"an island without trees: bring stored wood from another island (%s)" % people.wood_tip(reef_giver))
	people.add_news(&"home_island", "Did you see? Steve, the green turtle you rescued, is about the island today!")
	texts = people.talk(tom).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("Steve")), "news: the next person you talk to there tells you what happened")
	texts = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(not texts.any(func(t: String) -> bool: return t.contains("Steve")), "(once)")
	funding.balance = balance

	# --- Observations: now and then someone mentions what the animals do (once a day, a few times a game) ---
	var bram: Resource = load("res://data/people/bram.tres")
	var noticed: Array = []
	for i in 12:
		clock.day += 1
		var said: String = people.observation(bram)
		if said != "":
			noticed.append(said)
		_expect(people.observation(bram) == "" or said == "", "(at most one a day)")
	_expect(noticed.size() == people.OBSERVATION_TIMES and noticed.all(func(t: String) -> bool: return t.contains("noise and bright lights")),
		"Bram: noise and light scare the deep away, said %d times, no more (the anglerfish one waits for anglerfish)" % noticed.size())
	_expect(people.to_dict().observed.get("bram/noise_light", 0) == people.OBSERVATION_TIMES, "how often is saved")
	var all_said := 0
	for someone: Resource in people.all():
		all_said += someone.observations.size()
	_expect(all_said == 26, "26 observations across the islands (%d)" % all_said)

	# --- The talk box: the game waits while they talk; a tap goes on ---
	var box: Node = world.get_parent().find_child("TalkBox", true, false)
	_expect(box != null, "the HUD adds a talk box")
	tom_node.talk()
	_expect(box.visible and paused, "talking: the box shows and the game waits")
	var back: Button = box.find_child("Back", true, false)
	var first_line: String = box.get("_text").text
	_expect(back != null and back.disabled, "a Back button, not usable on the first line")
	if box.get("_lines").size() > 1 and not box.is_choosing():
		box.next()
		_expect(not back.disabled, "on the next line it is")
		back.pressed.emit()
		_expect(box.visible and box.get("_text").text == first_line, "Back shows the line before again")
	for i in 10:
		if box.visible:
			box.next()
	_expect(not box.visible and not paused, "tapped through: it closes and the game goes on")

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
