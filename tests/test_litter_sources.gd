extends SceneTree
## Litter at its source: each kind of litter the ranger keeps picking up becomes a question
## from someone (where does it come from?), a research mission finds out, and a fix built from
## what was found stops that kind drifting in on every island. A problem solved early never
## skips an island's own story. Six kinds: bottles, bags, rings, foam boxes, fishing gear and
## (from the ice core) microfibres.
## Run: godot --headless --path . --script res://tests/test_litter_sources.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	var inventory := root.get_node("Inventory")
	var missions := root.get_node("Missions")
	people.restore({})
	missions.restore({})
	inventory.restore({})
	inventory.picked.clear()
	var regions: GDScript = load("res://scripts/world/regions.gd")
	var terrain: GDScript = load("res://scripts/world/terrain.gd")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	world.get_node("LitterSpawner").set_process(false)

	# --- The new kinds of litter ---
	var rings: Resource = load("res://data/items/six_pack_rings.tres")
	var foam: Resource = load("res://data/items/foam_box.tres")
	_expect(rings.is_litter and rings.entangles and foam.is_litter, "six-pack rings (they catch animals) and foam boxes are litter")
	inventory.add(rings, 2)
	inventory.add(load("res://data/items/wood.tres"), 1)
	_expect(inventory.picked.get(&"six_pack_rings", 0) == 2 and not inventory.picked.has(&"wood"), "litter picked up is counted per kind (%s)" % [inventory.picked])

	# --- A problem solved early never skips an island's story ---
	var imani: Resource = load("res://data/people/imani.tres")
	fleet.restore({"flags": ["gear_marking"]})
	_expect(people.current_question(imani).id == &"outpost", "gear marking done early: Imani still starts at the outpost (%s)" % people.current_question(imani).id)

	# --- Finn, after the Kelp Forest's story: where do the rings come from? ---
	var kelp: Resource = load("res://data/regions/kelp_forest.tres")
	regions.discover(kelp)
	fleet.restore({"installed": ["salvaged_sonar_core", "kelp_fibre"], "flags": ["kelp_balanced"], "counts": {"shed_kelp": 5}})
	var build: Node = world.get_node("BuildMode")
	var platform: Node2D = build.add_building(load("res://data/buildings/kelp_research_platform.tres"), terrain.cell_of(kelp.arrival) + Vector2i(-3, 4))
	world.get_node("Player").global_position = kelp.arrival
	var finn: Resource = load("res://data/people/finn.tres")
	people.restore({"met": ["finn"]})
	_expect(people.current_question(finn) == null, "not before the ranger has picked up a dozen rings")
	inventory.picked[&"six_pack_rings"] = 12
	_expect(people.current_question(finn).id == &"rings", "12 rings picked up: Finn has a question")
	var trace: Resource = load("res://data/missions/trace_rings.tres")
	_expect(not missions.offered_by(&"kelp_research_platform").has(trace), "the research isn't offered before anyone asks")
	var texts: Array = people.talk(finn).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("picked up 12 yourself")), "Finn: 'you've picked up 12 yourself' (%s)" % [texts])
	_expect(missions.offered_by(&"kelp_research_platform").has(trace), "now the platform offers Trace the rings")
	var refill: Resource = load("res://data/buildings/refill_bar.tres")
	missions.run_now(trace, kelp)
	_expect(fleet.has_flag(&"rings_traced") and missions.last_report.contains("harbour"), "the research finds the harbour cafe (%s)" % missions.last_report)
	_expect(not missions.offered_by(&"kelp_research_platform").has(trace), "(and isn't offered again)")
	texts = people.talk(finn).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(texts.any(func(t: String) -> bool: return t.contains("Refill Bar")) and people.current_question(finn).id == &"refill", "Finn thanks, then asks what the cafe could do instead")
	people.talk(load("res://data/people/ines.tres"))  # (meeting her)
	people.finish_talk()
	var ines_texts: Array = people.talk(load("res://data/people/ines.tres")).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(ines_texts.any(func(t: String) -> bool: return t.contains("kegs")), "Ines explains the refill bar (%s)" % [ines_texts])

	# --- The fix: no new rings anywhere ---
	_expect(not fleet.stopped(&"six_pack_rings"), "rings still drift in")
	build.add_building(refill, terrain.cell_of(kelp.arrival) + Vector2i(2, -3))
	_expect(fleet.stopped(&"six_pack_rings") and fleet.goal_met(people.questions(finn).back().objective), "the Refill Bar stops them at their source: Finn's question is answered")
	var spawner: Node = world.get_node("LitterSpawner")
	for d in get_nodes_in_group("debris"):
		d.free()
	var kinds := {}
	for i in 300:
		var piece: Node = spawner.spawn_one()
		if piece:
			kinds[piece.item.id] = true
			piece.free()
	_expect(not kinds.has(&"six_pack_rings") and kinds.has(&"foam_box"), "no new rings drift in, other litter still does (%s)" % [kinds.keys()])

	# --- Every fix building waits for its research ---
	for id in ["weaving_workshop", "refill_bar", "box_return_depot", "filter_workshop"]:
		var data: Resource = load("res://data/buildings/%s.tres" % id)
		_expect(data.needs_flag != &"" and data.stops_litter.size() == 1, "%s needs research and stops one kind" % id)
	var asked := []
	for person: Resource in people.all():
		for topic: Resource in people.questions(person):
			if topic.objective.kind == &"stopped" or topic.objective.target == &"gear_marking":
				asked.append(String(topic.objective.target))
	_expect(asked.size() == 6, "six kinds of litter, each asked about by someone (%s)" % [asked])
	platform.queue_free()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
