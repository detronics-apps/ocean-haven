extends SceneTree
## People's own wants and the reunions after the ending. Every one of the twelve people hopes
## for something of their own (PersonData.want): they say it once, after a talk, and once it's
## come true because of what the ranger did, they say what it means to them, once (saved with
## what's been heard). After the ending, someone from another island sometimes visits for the
## day (People.visit), and now and then every released rescue is out the same morning, only
## where it belongs (Rescues: a reunion).
## Run: godot --headless --path . --script res://tests/test_wants.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	people.restore({})
	fleet.restore({})
	var everyone: Array = people.all()
	var complete := 0
	for p: Resource in everyone:
		if p.want != null and not p.want.lines.is_empty() and p.want.outcome != "" and not p.want.outcome_when.is_empty() and p.visit_line != "":
			complete += 1
	_expect(everyone.size() == 12 and complete == 12, "all twelve people have a want of their own, its payoff, and a visit line")

	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var tom_node: Node2D = world.get_node("Person_tom")
	var tom: Resource = tom_node.data
	var player: Node2D = world.get_node("Player")
	player.global_position = tom_node.global_position + Vector2(20, 0)

	# --- Said once, after a talk (never when first met) ---
	var first := _text(people.talk(tom))
	_expect(not first.contains("count turtle tracks"), "not when first met")
	root.get_node("Funding").set("balance", 500)  # (no funding or wood tips in the way)
	root.get_node("Inventory").add(load("res://data/items/wood.tres"), 6)
	var second := _text(people.talk(tom))
	if not second.contains("count turtle tracks"):
		second = _text(people.talk(tom))  # (news first, then the wish)
	_expect(second.contains("count turtle tracks below this lighthouse"), "then Tom says what he hopes for (%s)" % second)
	var third := _text(people.talk(tom))
	_expect(not third.contains("count turtle tracks"), "only once")

	# --- Comes true because of what the ranger did: the payoff, once ---
	_expect(not people.wish_came_true(tom), "no turtle has nested yet")
	root.get_node("Journal").record_nest(load("res://data/animals/green_turtle.tres"))
	_expect(people.wish_came_true(tom), "a turtle nests: Tom's wish has come true")
	if true:
		var told := _text(people.talk(tom))
		_expect(told.contains("I saw tracks below the lighthouse"), "once it comes true, Tom says so (%s)" % told)
		_expect(not _text(people.talk(tom)).contains("I saw tracks below"), "and only once")
	var saved: Dictionary = people.to_dict()
	people.restore(saved)
	_expect(not _text(people.talk(tom)).contains("count turtle tracks"), "what's been said is saved")

	# --- Visits: only after the ending ---
	_expect(people.visit() == null, "no visitors before the ending")
	fleet.mark(&"observatory_opened")
	var finn: Resource = everyone.filter(func(p: Resource) -> bool: return p.id == &"finn")[0]
	people.restore({"met": ["tom", "finn"]})
	var visitor: Node2D = people.visit_by(finn, tom)
	await process_frame
	_expect(visitor != null and visitor.is_in_group("visitors") and visitor.name.begins_with("Visitor_"),
		"after the ending, Finn can come to visit Tom")
	_expect(people.has_news(visitor.data), "a visitor shows a '!' until talked to")
	var hello := _text(people.talk(visitor.data))
	_expect(hello.contains("Starting Island") and hello.contains("Tom"), "they say why they came (%s)" % hello)
	_expect(not people.has_news(visitor.data), "talked to: no '!'")
	_expect(world.get_node_or_null("Person_finn") == null or world.get_node("Person_finn") != visitor, "Finn's own place is untouched")
	people.visit()
	await process_frame
	_expect(not is_instance_valid(visitor) or visitor.is_queued_for_deletion(), "gone the next morning")

	# --- A reunion: everyone out, only where they belong ---
	var rescues := root.get_node("Rescues")
	var turtle: Resource = rescues.rescue(&"home_turtle")
	var seal: Resource = rescues.rescue(&"polar_seal")
	_expect(rescues._reunion_where(turtle, "home_island") == "home_island", "the turtle is at home for a reunion")
	_expect(rescues._reunion_where(seal, "home_island") == "arctic_ocean", "the seal pup never comes to warm water: it's out at home")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


func _text(lines: Array) -> String:
	return " ".join(lines.map(func(l: Dictionary) -> String: return String(l.get("text", ""))))


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
