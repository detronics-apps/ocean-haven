extends SceneTree
## The ending (not "You won"): with all six discoveries the ships are Ocean Research Vessels and
## the Map opens the Global Ocean Observatory: the six islands, what joins them, every island's
## health. Once every kind of litter is stopped at its source too, it asks "What have you
## learned?" from the ranger's own game, shows the people at their work, and Maya's last
## question is answered. The world stays open: everyone has a new line afterwards.
## Run: godot --headless --path . --script res://tests/test_ending.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var people := root.get_node("People")
	var fleet := root.get_node("Fleet")
	people.restore({})
	fleet.restore({})
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var map: Node = world.get_node("VoyageMap")
	map.open()
	_expect(map.find_child("Observatory", true, false) == null, "no Observatory before the fleet has all six")
	map.close()

	# --- All six discoveries: the Observatory opens, but the reflection waits ---
	var all_six := ["salvaged_sonar_core", "kelp_fibre", "mangrove_resin", "reef_limestone", "cargo_module", "ice_core"]
	var flags := ["sonar_recovered", "kelp_balanced", "mangrove_flowing", "reef_restored", "deep_mapped", "polar_balanced", "gear_recovered"]
	fleet.restore({"installed": all_six, "flags": flags})
	for region: Resource in load("res://scripts/world/regions.gd").all():
		load("res://scripts/world/regions.gd").discover(region)
	map.open()
	var button: Button = map.find_child("Observatory", true, false)
	_expect(button != null, "the Map has the Global Ocean Observatory")
	button.pressed.emit()
	await process_frame
	var screen: Node = world.find_child("ObservatoryScreen", true, false)
	_expect(screen.visible and screen.find_child("Panorama", true, false) != null, "it shows the six islands side by side")
	var links: Array = screen.links()
	_expect(links.size() >= 3, "and what joins them (%s)" % [links.map(func(l: Dictionary) -> String: return l.text)])
	_expect(screen.find_child("Learned", true, false) == null and not fleet.has_flag(&"observatory_opened"),
		"no reflection while some litter still starts somewhere")
	_expect(screen.find_child("DownloadPoster", true, false) == null, "no poster before the whole ocean is connected")
	# --- Tap an island: how it looked when the ranger first arrived, beside now ---
	var journal := root.get_node("Journal")
	journal.photos_dir = OS.get_temp_dir().path_join("bluehaven_test_island_photos")  # never the player's folder
	DirAccess.make_dir_recursive_absolute(journal.photos_dir)
	var then_image := Image.create(36, 20, false, Image.FORMAT_RGB8)
	then_image.fill(Color(0.4, 0.4, 0.45))
	then_image.save_png(journal.island_photo_path(&"home_island", "arrival"))
	DirAccess.remove_absolute(journal.island_photo_path(&"home_island", "now"))
	var panorama: Control = screen.find_child("Panorama", true, false)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	var home_index: int = panorama.regions.find(load("res://data/regions/home_island.tres"))
	tap.position = Vector2(panorama.size.x / panorama.regions.size() * (home_index + 0.5), panorama.size.y / 2.0)
	panorama._gui_input(tap)
	var island_view: Node = screen.get_node_or_null("IslandView")
	_expect(island_view != null and (island_view.find_child("Then", true, false).find_child("Picture", true, false) as TextureRect).texture.get_width() == 36,
		"tap the Starting Island: the picture from when you first arrived")
	_expect(island_view.find_child("Now", true, false) != null and screen.find_children("*", "Label", true, false).any(
		func(l: Label) -> bool: return l.text.begins_with("Now:") and l.text.contains("healthy")), "beside how it is now")
	island_view.find_child("Back", true, false).pressed.emit()
	await process_frame
	_expect(screen.get_node_or_null("IslandView") == null and screen.visible, "Back: the Observatory again")
	DirAccess.remove_absolute(journal.island_photo_path(&"home_island", "arrival"))
	screen.close()

	# --- Every source stopped: the final chapter ---
	fleet.mark(&"fibres_traced")
	var build: Node = world.get_node("BuildMode")
	fleet.mark(&"gear_traced")
	var spots := {"refill_bar": Vector2i(-12, -12), "weaving_workshop": Vector2i(-16, -12), "box_return_depot": Vector2i(-20, -12), "filter_workshop": Vector2i(-24, -12), "net_return_point": Vector2i(-32, -12)}
	for id in spots:
		build.add_building(load("res://data/buildings/%s.tres" % id), spots[id])
	await process_frame
	var stopped_bottles: bool = fleet.stopped(&"plastic_bottle")
	if not stopped_bottles:  # (reusable bottles need glass and clean water made: stand in for them here)
		var data: Resource = load("res://data/buildings/box_return_depot.tres").duplicate()
		data.stops_litter = PackedStringArray(["plastic_bottle"])
		build.add_building(data, Vector2i(-28, -12))
		await process_frame
	for id in [&"plastic_bottle", &"plastic_bag", &"six_pack_rings", &"foam_box", &"ghost_net", &"microfibres"]:
		_expect(fleet.stopped(id), "%s stopped" % id)
	var maya: Resource = load("res://data/people/maya.tres")
	people.restore({"met": ["maya"]})
	_expect(people.current_question(maya) != null and people.current_question(maya).id == &"observatory", "Maya asks what we've learned (%s)" % people.current_question(maya))
	people.talk(maya)
	people.finish_talk()
	screen.open()
	var learned: Node = screen.find_child("Learned", true, false)
	if learned == null:
		_expect(false, "the reflection shows")
		quit(1)
		return
	_expect(learned != null and screen.find_child("Motto", true, false).text == "One ocean. Many places. Everything connected.",
		"'What have you learned?', then: one ocean, many places, everything connected")
	var texts: Array = []
	for label: Node in learned.find_children("*", "Label", true, false):
		texts.append(label.text)
	_expect(texts.any(func(t: String) -> bool: return t.contains("otters came back")), "observations from the ranger's own game (%s)" % [texts])
	var said: Array = []
	for label: Node in screen.find_children("*", "Label", true, false):
		said.append(label.text)
	_expect(said.any(func(t: String) -> bool: return t.contains("There was only ever one ocean.")), "the people at their work, each with a line")
	_expect(not said.any(func(t: String) -> bool: return t.to_lower().contains("you won")), "never 'You won'")
	_expect(screen.find_child("DownloadPoster", true, false) != null, "the prize: the ocean poster to download")
	var credits: Node = screen.credits()
	_expect(credits.is_playing() and fleet.has_flag(&"credits_seen"), "the first time: the screen goes black and the end credits roll")
	await process_frame
	await process_frame
	var rows: Array = credits.rows()
	_expect(rows.size() > 100 and rows[0].text == "A Final Word" and rows.any(func(r: Dictionary) -> bool: return r.text.contains("Thank you for sharing")),
		"'A Final Word', all the way to the last line (%d rows)" % rows.size())
	for i in 200:  # (past the black)
		credits._process(1.0 / 30.0)
	var slow: float = credits.progress()
	credits.toggle_speed()
	for i in 60:
		credits._process(1.0 / 30.0)
	var fast: float = credits.progress() - slow
	var speed_button: Button = credits.find_child("Speed", true, false)
	_expect(speed_button.text == "x2", "the speed button now reads x2")
	speed_button.pressed.emit()
	_expect(speed_button.text == "x3" and is_equal_approx(credits.speed(), 3.0), "then x3")
	speed_button.pressed.emit()
	_expect(speed_button.text == "x1", "then back to x1")
	var before: float = credits.progress()
	for i in 60:
		credits._process(1.0 / 30.0)
	var normal: float = credits.progress() - before
	_expect(credits.is_playing() and is_equal_approx(fast, normal * 2.0), "x2: twice as fast (%.4f vs %.4f)" % [fast, normal])
	var minutes: float = 1.0 / (normal * 30.0 / 60.0) / 60.0
	_expect(minutes > 4.0, "slow enough for slow readers: about %.1f minutes at normal speed" % minutes)
	credits.stop()
	_expect(not credits.is_playing() and screen.visible, "closed: back at the Observatory")
	screen.close()
	screen.open()
	_expect(not screen.credits().is_playing(), "not again by itself")
	screen.find_child("EndCreditsButton", true, false).pressed.emit()
	_expect(screen.credits().is_playing(), "the End credits button plays them again")
	screen.credits().stop()
	var poster: Image = screen.POSTER.get_image()
	_expect(poster.get_height() > poster.get_width() and poster.get_width() >= 700 and poster.save_jpg_to_buffer(0.95).size() > 100000, "the poster saves as a full-size JPEG (%dx%d)" % [poster.get_width(), poster.get_height()])
	_expect(fleet.has_flag(&"observatory_opened") and fleet.goal_met(people.questions(maya).back().objective), "Maya's last question is answered")
	screen.close()
	var thanks: Array = people.talk(maya).map(func(l: Dictionary) -> String: return l.text)
	people.finish_talk()
	_expect(thanks.any(func(t: String) -> bool: return t.contains("helping six islands")), "Maya: 'We thought we were helping six islands.'")
	var tom_lines: Array = people.talk(load("res://data/people/tom.tres")).map(func(l: Dictionary) -> String: return l.text)
	people.talk(load("res://data/people/tom.tres"))
	tom_lines = people.talk(load("res://data/people/tom.tres")).map(func(l: Dictionary) -> String: return l.text)
	_expect(tom_lines.any(func(t: String) -> bool: return t.contains("new story")), "afterwards everyone has a new line (Tom: %s)" % [tom_lines])
	world.get_node("ExploreMenu").open()
	_expect(world.get_node("ExploreMenu").get("_title").text == "Ocean Research Vessel", "the ships are Ocean Research Vessels")
	world.get_node("ExploreMenu").close()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
