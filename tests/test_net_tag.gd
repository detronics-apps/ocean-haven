extends SceneTree
## The net tag (docs/CLUE_BOARD.md, O2): the first turtle is caught in an old ghost net with a
## worn tag; freeing it plants the clue (Fleet flag "net_tag_found"). Older saves, whose turtle
## was freed before, get the tag from Tom. The Map and the next island raise the question; the
## Deep Sea and Bram's story answer it; S4.C follows from it.
## Run: godot --headless --path . --script res://tests/test_net_tag.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var clues := root.get_node("Clues")
	var fleet := root.get_node("Fleet")
	var people := root.get_node("People")
	var journal := root.get_node("Journal")
	var regions: GDScript = load("res://scripts/world/regions.gd")
	clues.set_process(false)
	fleet.restore({})
	people.restore({})
	clues.restore({})
	journal.restore([])
	regions.restore(["home_island"])

	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var turtle: Node2D = world.get_node("GreenTurtle")
	_expect(turtle.tangled and turtle.tangle_item.id == &"ghost_net", "the first turtle is caught in an old ghost net")
	turtle._interact()
	_expect(not turtle.tangled and fleet.has_flag(&"net_tag_found"), "freeing it finds the tag")
	clues.check()
	_expect(clues.is_found(&"o2_net_tag") and not clues.is_open(&"o2_net_tag"), "the tag is pinned as a clue, no question yet")

	var tom: Resource = load("res://data/people/tom.tres")
	_expect(not _said(people.talk(tom) + people.talk(tom)).contains("from the net your first turtle"), "a new game's Tom has no tag to hand over")

	# The Map shows the hook-shaped island: now there's a question.
	fleet.mark(&"map_opened")
	clues.check()
	_expect(clues.is_open(&"o2_net_tag") and not clues.is_answered(&"o2_net_tag"), "the Map raises the question")
	var bram: Resource = load("res://data/people/bram.tres")
	var bram_said := _said(people.talk(bram)) + " " + _said(people.talk(bram))
	_expect(bram_said.contains("Hook's mark"), "Bram knows the mark")
	clues.check()
	_expect(not clues.is_answered(&"o2_net_tag"), "Bram's story alone isn't enough: the ranger hasn't found the hook yet")
	regions.discover(load("res://data/regions/deep_sea.tres"))
	clues.check()
	_expect(clues.is_answered(&"o2_net_tag"), "found the Deep Sea + Bram's story: answered")
	_expect(clues.statement(clues.card(&"o2_net_tag")).contains("the Hook"), "its statement names the Hook")
	_expect(clues.is_open(&"s4c_nets") and not clues.is_answered(&"s4c_nets"), "S4.C: can we tell where a lost net came from?")
	fleet.mark(&"gear_recovered")
	fleet.mark(&"gear_traced")
	clues.check()
	_expect(not clues.is_answered(&"s4c_nets"), "S4.C waits for the Net Return Point")

	# An older save: the turtle freed long ago, no tag. Tom kept it.
	fleet.restore({})
	people.restore({})
	clues.restore({})
	_expect(not fleet.has_flag(&"net_tag_found") and journal.helped_count(&"green_turtle") >= 1, "(an old save: turtle freed, no tag)")
	var tom_said := _said(people.talk(tom)) + " " + _said(people.talk(tom))
	_expect(tom_said.contains("from the net your first turtle") and fleet.has_flag(&"net_tag_found"), "Tom hands over the tag he kept")
	clues.check()
	_expect(clues.is_found(&"o2_net_tag"), "and the clue is pinned")

	if _failed:
		quit(1)
		return
	print("PASS")
	quit()


func _said(lines: Array) -> String:
	return " ".join(lines.map(func(l: Dictionary) -> String: return String(l.get("text", ""))))


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		push_error("FAIL: " + what)
	print(("ok   " if ok else "FAIL ") + what)
