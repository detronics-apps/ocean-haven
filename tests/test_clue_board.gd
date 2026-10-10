extends SceneTree
## The Clue Board (docs/CLUE_BOARD.md, the Clues autoload): the first activation that holds
## opens a card and later ones change nothing; evidence is kept even before its card shows (unless
## marked "^"); a card turns blue only once every answer group holds, with its statement fixed
## from the evidence that answered it; nothing ever goes back; an old save fills in quietly; the
## final question is never answered. Plus data checks on every card.
## Run: godot --headless --path . --script res://tests/test_clue_board.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	var clock := root.get_node("GameClock")
	clues.set_process(false)  # (checked by hand here)
	fleet.restore({})
	clues.restore({})
	clock.day = 3

	# --- Every card's data holds together ---
	for card: Resource in clues.cards():
		var ids: Array = card.evidence_list().map(func(p: Dictionary) -> String: return p.id)
		var groups_ok: bool = card.answer_groups().all(func(g: Dictionary) -> bool:
			return int(g.need) >= 1 and int(g.need) <= g.ids.size() and Array(g.ids).all(func(id: String) -> bool: return id in ids))
		_expect(groups_ok, "%s: every answer group names its own evidence, and can be met" % card.id)
		_expect(card.kind in [&"final", &"globe"] or not card.answer.is_empty(), "%s: a question has an answer" % card.id)
		_expect(not card.activate.is_empty() or not card.discover.is_empty(), "%s: something makes it appear" % card.id)
		var sections := [&"people", &"trash", &"animals", &"places", &"storms", &"plants", &"land_water", &"disturbance", &"better_ways"]
		_expect(card.section in sections + [&"centre"] and Array(card.links).all(func(x: String) -> bool: return StringName(x) in sections),
			"%s: in a section (%s), linked only to sections" % [card.id, card.section])
		_expect(card.statements.is_empty() == (card.kind in [&"final", &"globe"]), "%s: a statement unless it's the globe or the final question" % card.id)
	# The source phrases say what the Trace reports say.
	var reports := {"rings": ["trace_rings", "cafe"], "bags": ["trace_bags", "fish market"], "foam": ["trace_foam", "fishing boats"],
		"gear": ["trace_gear", "fishing boats"], "fibres": ["study_fibres", "wash"]}
	for piece in clues.card(&"s4a_sources").evidence_list():
		var report: String = load("res://data/missions/%s.tres" % reports[piece.id][0]).report
		_expect(piece.text.contains(reports[piece.id][1]) and report.contains(reports[piece.id][1]),
			"S4.A's %s phrase matches its report (%s)" % [piece.id, reports[piece.id][1]])

	# --- A test card: first trigger wins, evidence before showing, "^", answer, statement ---
	var test: ClueData = ClueData.new()
	test.id = &"t_card"
	test.node = 3
	test.question = "Test?"
	test.activate = PackedStringArray(["flag:t_open", "flag:t_other"])
	test.evidence = PackedStringArray(["a | flag:t_a | Saw A", "b | ^flag:t_b | Saw B", "c | flag:t_c | Saw C"])
	test.answer = PackedStringArray(["1: a", "2: b, c"])
	test.statements = PackedStringArray(["c, x => never (x isn't evidence)", "{g0.1}, then {g1.1} and {g1.2}."])
	DataFiles.load_all("res://data/clues")
	(DataFiles._folders["res://data/clues"] as Array).append(test)
	var told: Array[String] = []
	clues.changed.connect(func(card: ClueData, what: StringName) -> void:
		if card == test:
			told.append(String(what)))

	fleet.mark(&"t_a")
	fleet.mark(&"t_b")
	clues.check()
	_expect(not clues.is_visible(&"t_card"), "not on the board before a reason to ask")
	_expect(clues._state[&"t_card"].ev == ["a"], "evidence seen before the question is kept; '^' evidence waits")
	fleet.mark(&"t_open")
	clues.check()
	_expect(clues.is_open(&"t_card") and int(clues._state[&"t_card"].open) == 3, "the first trigger opens it")
	_expect(clues._state[&"t_card"].ev == ["a", "b"] and not clues.is_answered(&"t_card"), "'^' evidence counts once open; 1 of 2 isn't enough")
	clock.day = 5
	fleet.mark(&"t_other")
	clues.check()
	_expect(int(clues._state[&"t_card"].open) == 3, "a second trigger changes nothing (idempotent)")
	fleet.mark(&"t_c")
	clues.check()
	_expect(clues.is_answered(&"t_card"), "blue once every group holds")
	_expect(clues.statement(test) == "Saw A, then Saw B and Saw C.", "statement filled from what answered it: %s" % clues.statement(test))
	_expect(told == ["open", "evidence", "evidence", "answered"], "notes for open, new evidence, answered: %s" % [told])
	for flag in [&"t_a", &"t_b", &"t_c", &"t_open"]:
		fleet.unmark(flag)
	clues.check()
	_expect(clues.is_answered(&"t_card") and clues.statement(test) == "Saw A, then Saw B and Saw C.", "never goes back")
	(DataFiles._folders["res://data/clues"] as Array).erase(test)

	# --- Real cards: S1.1, S4.A, the final question ---
	clues.restore({})
	fleet.restore({})
	clues.check()
	fleet.mark(&"wreck_found")
	clues.check()
	_expect(clues.is_open(&"s1_beyond") and not clues.is_answered(&"s1_beyond"), "S1.1: the wreck raises the question, not the answer")
	fleet.mark(&"rings_asked")
	fleet.mark(&"rings_traced")
	clues.check()
	_expect(clues.is_open(&"s4a_sources") and not clues.is_answered(&"s4a_sources"), "S4.A: one source isn't enough")
	fleet.mark(&"fibres_traced")
	clues.check()
	_expect(clues.is_answered(&"s4a_sources"), "S4.A: two sources answer it")
	var said: String = clues.statement(clues.card(&"s4a_sources"))
	_expect(said.contains("harbour cafe") and said.contains("clothes in the wash") and not said.contains("{"),
		"S4.A names exactly the two sources traced: %s" % said)
	fleet.mark(&"observatory_opened")
	clues.check()
	_expect(clues.is_found(&"conclusion_globe") and not clues.is_open(&"final_who"), "the Observatory pins the globe up: it's all connected")
	fleet.mark(&"credits_rolled")
	clues.check()
	_expect(clues.is_open(&"final_who") and not clues.is_answered(&"final_who"), "the credits bring the final question, never answered")

	# --- An old save fills in quietly ---
	var notes := [0]
	clues.changed.connect(func(_c: ClueData, _w: StringName) -> void: notes[0] += 1)
	clues.restore({})
	fleet.mark(&"bags_traced")
	clues.set_process(true)
	for i in 3:
		await create_timer(1.1).timeout
	clues.set_process(false)
	_expect(clues.is_open(&"s1_beyond") and notes[0] == 0, "after loading, the board catches up without a note per card")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
