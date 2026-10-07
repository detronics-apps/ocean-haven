extends SceneTree
## Sound: every island has its music (data/music/) with streams that load; every effect the
## game plays exists; the tune plays more as an island recovers; the speaker button's panel
## mutes and sets the volumes (on the buses).
## Run: godot --headless --path . --script res://tests/test_sound.gd --quit-after 300000

var _failed := false


func _initialize() -> void:
	await process_frame
	var sound := root.get_node("Sound")  # autoloads: looked up at runtime

	# --- Every island has music, and its sounds load ---
	for region: Resource in load("res://scripts/systems/data_files.gd").load_all("res://data/regions"):
		var track: Resource = sound.get("_tracks").get(region.id)
		_expect(track != null, "%s has music" % region.id)
		if track:
			_expect(track.melody and track.pad and track.bass and track.bells and track.ambient, "%s: its instruments load" % region.id)
			_expect(not track.calls.is_empty() and track.calls.all(func(c: Resource) -> bool: return c != null), "%s: its animals' calls load" % region.id)
			_expect((track.ambient as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s: its surroundings loop" % region.id)

	# --- Every effect played in the code exists ---
	var ids := {}
	var pattern := RegEx.create_from_string("Sound\\.play\\(&\"(\\w+)\"|play\\(&\"(\\w+)\"|play\\.bind\\(&\"(\\w+)\"")
	for dir: String in ["res://scripts/systems", "res://scripts/ui", "res://scripts/world", "res://scripts/player", "res://scripts/animals", "res://scripts/buildings"]:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string(dir.path_join(file))):
					for g in [1, 2, 3]:
						if found.get_string(g) != "":
							ids[found.get_string(g)] = file
	_expect(ids.size() >= 15, "the effects are found in the code (%d)" % ids.size())
	for id: String in ids:
		_expect(ResourceLoader.exists("res://audio/sfx/%s.wav" % id), "effect %s (in %s) exists" % [id, ids[id]])

	# --- The tune: sparse on a damaged island, fuller on a healthy one ---
	sound.call("_change_track", sound.get("_tracks").get(&"home_island"))
	var notes_at := func(health: float) -> int:
		sound.set("_health", health)
		var played := 0
		var players: Array = sound.get("_note_players")
		for step in 400:
			var before: int = sound.get("_next_note")
			sound.call("_beat")
			if sound.get("_next_note") != before:
				played += posmod(int(sound.get("_next_note")) - before, players.size())
		return played
	seed(3)
	var damaged: int = notes_at.call(0.05)
	var healthy: int = notes_at.call(0.95)
	_expect(damaged > 0, "a damaged island still hums (%d notes)" % damaged)
	_expect(healthy > damaged * 2, "a healthy island plays much more (%d vs %d notes)" % [healthy, damaged])

	# --- The speaker button and its panel ---
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var button: Node = world.find_child("SoundButton", true, false)
	_expect(button != null, "the menu bar has a speaker button")
	if button:
		var panel: Control = button.panel()
		_expect(panel and not panel.visible, "the sound panel starts closed")
		button.emit_signal("pressed")
		_expect(panel.visible, "the speaker opens the sound panel")
		(panel.find_child("Mute", true, false) as Button).emit_signal("pressed")
		_expect(sound.muted and AudioServer.is_bus_mute(0), "the panel's button mutes everything")
		(panel.find_child("Mute", true, false) as Button).emit_signal("pressed")
		_expect(not sound.muted and not AudioServer.is_bus_mute(0), "and turns the sound back on")
		(panel.find_child("Music", true, false) as HSlider).value = 0.25
		_expect(is_equal_approx(sound.music_volume, 0.25), "the music slider sets the music volume")
		_expect(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.25)) < 0.1, "on the Music bus")
		(panel.find_child("Sounds", true, false) as HSlider).value = 0.0
		_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Sounds")), "sounds at 0 are silent")
		(panel.find_child("Done", true, false) as Button).emit_signal("pressed")
		_expect(not panel.visible, "Done closes the panel")
	sound.load_state({})
	world.free()
	_finish()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		print("FAIL: ", what)


func _finish() -> void:
	print("FAIL" if _failed else "PASS")
	quit(1 if _failed else 0)
