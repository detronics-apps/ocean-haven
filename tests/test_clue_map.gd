extends SceneTree
## The Clue Board map (ClueMap): the same cards and threads in landscape (the spine left to
## right) and portrait (top to bottom); all 9 slots always drawn, lit only when they hold a
## card; fixed zoom steps; a tap on a card opens its details, with its links; a drag pans.
## Run: godot --headless --path . --script res://tests/test_clue_map.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	clues.set_process(false)
	fleet.restore({})
	clues.restore({})
	for flag in [&"wreck_found", &"rings_asked", &"rings_traced", &"foam_traced", &"fibres_asked"]:
		fleet.mark(flag)
	clues.check(true)

	var map: Control = load("res://scripts/ui/clue_map.gd").new()
	root.add_child(map)
	map.size = Vector2(1200, 700)
	await process_frame
	map.rebuild()
	var wide := _layout(map)
	_expect(map.landscape() and wide.cards.size() == 4, "landscape: the 4 visible cards (S1.1, S4.A, S4.B, S4.D) (%s)" % [wide.cards.keys()])
	_expect(wide.pins.keys() == [&"places", &"trash", &"better_ways"],
		"no placeholders: only the sections holding notes have a tag (%s)" % [wide.pins.keys()])
	var near := func(layout: Dictionary, card: StringName, section: StringName) -> bool:
		var at: Vector2 = layout.cards[card]
		for other in layout.pins:
			if other != section and at.distance_to(layout.pins[other]) < at.distance_to(layout.pins[section]):
				return false
		return true
	_expect(near.call(wide, &"s4a_sources", &"trash") and near.call(wide, &"s4d_fibres", &"trash")
		and near.call(wide, &"s1_beyond", &"places") and near.call(wide, &"s4b_prevent", &"better_ways"),
		"each note sits with its own section's tag")

	map.size = Vector2(400, 820)
	await process_frame
	map.rebuild()
	var tall := _layout(map)
	_expect(not map.landscape() and tall.cards.keys() == wide.cards.keys(), "portrait: the same cards")
	_expect(tall.pins.keys() == wide.pins.keys() and near.call(tall, &"s4a_sources", &"trash"), "portrait: the same sections")
	var fan: Node = map._cards[&"s4a_sources"].get_node_or_null("Pictures")
	_expect(fan != null and fan.get_child_count() == 2, "S4.A shows a card for each litter traced so far (rings, foam boxes)")
	_expect(map.card_text(clues.card(&"s4a_sources")) == "People, on land and boats", "an answered note says its short answer")

	# Rescues seen again: one note, a picture card for each animal seen.
	var saved: Dictionary = clues.to_dict()
	saved[&"s6n_home_turtle"] = {"open": 1, "ev": ["again"]}
	saved[&"s6n_polar_seal"] = {"open": 1, "ev": ["again"]}
	clues.restore(saved)
	map.rebuild()
	var seen_again: Node = map._cards.get(&"s6n_home_turtle")
	_expect(seen_again != null and not map._cards.has(&"s6n_polar_seal"), "the rescues seen again are one note")
	_expect(seen_again.get_node("Pictures").get_child_count() == 2, "with the turtle and the seal pup on it")
	map.set_step(0)
	var overview: float = map.STRING_PX / map._canvas.scale.x
	map.set_step(2)
	_expect(overview > map.STRING_PX / map._canvas.scale.x, "the string keeps its width on screen: thinner beside the notes closer in")

	# Zoom steps and the overview fit.
	map.set_step(0)
	_expect(map.step == 0 and map._canvas.scale.x <= 0.6, "opens on the whole board")
	map.set_step(2)
	_expect(map.step == 2 and is_equal_approx(map._canvas.scale.x, map.zoom_steps[2]), "+ steps in")
	map.set_step(99)
	_expect(map.step == map.zoom_steps.size() - 1, "zoom stays within its steps")
	var biggest_jump := 0.0
	for i in range(1, map.zoom_steps.size()):
		biggest_jump = maxf(biggest_jump, map.zoom_steps[i] / map.zoom_steps[i - 1])
	_expect(map.zoom_steps.size() >= 4 and biggest_jump <= 1.55, "even zoom steps, no big jump (%s)" % [map.zoom_steps])
	map.set_step(0)
	_expect(is_equal_approx(map.string_alpha(), 1.0), "zoomed right out the string is solid")
	map.set_step(1)
	var nearer: float = map.string_alpha()
	map.set_step(map.zoom_steps.size() - 1)
	_expect(nearer < 1.0 and map.string_alpha() < nearer, "closer in the string fades, more the closer (%.2f, %.2f)" % [nearer, map.string_alpha()])
	var toggle: Button = map.find_child("StringsToggle", true, false)
	var was: bool = map.detailed
	toggle.pressed.emit()
	_expect(toggle != null and map.detailed != was and toggle.text.ends_with("detailed" if map.detailed else "simple"),
		"a button switches between simple and detailed strings")
	toggle.pressed.emit()

	# A tap opens the card's details (the answered S4.A shows its statement).
	var card: Control = map._cards[&"s4a_sources"]
	map.centre_on(card)
	map.tap(map.size / 2.0)
	_expect(map._detail.visible and map._focus == &"s4a_sources", "a tap on a card opens its details")
	var texts: Array = map._detail_text.get_children().filter(func(c: Node) -> bool: return c is Label).map(func(l: Label) -> String: return l.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("harbour cafe")), "the details show the statement: %s" % [texts])
	_expect(texts.any(func(t: String) -> bool: return t.begins_with("You wondered:")), "and what was wondered")

	# A drag pans; it isn't a tap.
	var before: Vector2 = map._canvas.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 100)
	map._gui_input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(160, 130)
	map._gui_input(move)
	_expect(map._canvas.position != before, "a drag pans the map")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


## {pins: slot -> position, cards: id -> position}
func _layout(map: Control) -> Dictionary:
	var pins := {}
	for slot in map._pins:
		pins[slot] = (map._pins[slot] as Control).position
	var cards := {}
	for id in map._cards:
		cards[id] = (map._cards[id] as Control).position
	return {"pins": pins, "cards": cards}


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
