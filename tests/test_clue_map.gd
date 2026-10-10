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
	_expect(wide.pins.keys() == [1, 4], "no placeholders: only the nodes with notes have a tag (%s)" % [wide.pins.keys()])
	_expect(wide.pins[1].x > wide.pins[4].x and wide.pins[1].y < wide.pins[4].y,
		"round the circle clockwise from the top: node 1 up on the right, node 4 at the bottom")
	_expect(wide.cards[&"s4a_sources"].y > wide.pins[4].y, "node 4's notes fan outward (down) from its tag")

	map.size = Vector2(400, 820)
	await process_frame
	map.rebuild()
	var tall := _layout(map)
	_expect(not map.landscape() and tall.cards.keys() == wide.cards.keys(), "portrait: the same cards")
	_expect(tall.pins[1].x > tall.pins[4].x and tall.pins[1].y < tall.pins[4].y and tall.cards[&"s4a_sources"].y > tall.pins[4].y,
		"portrait: the same circle")
	var fan: Node = map._cards[&"s4a_sources"].get_node_or_null("Pictures")
	_expect(fan != null and fan.get_child_count() == 5, "S4.A shows the five kinds of litter, fanned out like cards")
	map.set_step(0)
	var overview: float = map.STRING_PX / map._canvas.scale.x
	map.set_step(2)
	_expect(overview > map.STRING_PX / map._canvas.scale.x, "the string keeps its width on screen: thinner beside the notes closer in")

	# Zoom steps and the overview fit.
	map.set_step(0)
	_expect(map.step == 0 and map._canvas.scale.x <= 0.6, "opens on the whole board")
	map.set_step(2)
	_expect(map.step == 2 and is_equal_approx(map._canvas.scale.x, map.zoom_steps[2]), "+ steps in")
	map.set_step(9)
	_expect(map.step == 2, "zoom stays within its steps")

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
