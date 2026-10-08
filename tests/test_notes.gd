extends SceneTree
## Notes (HUD.show_toast): one short line in a small box, one at a time with a pause between,
## only the newest waiting, never the same one again soon, and only about the island the ranger
## is on.
## Run: godot --headless --path . --script res://tests/test_notes.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 3:
		await process_frame
	var hud: Node = world.get_node("HUD")
	var label: Label = hud.get("_toast_label")
	var hud_script: GDScript = hud.get_script()
	var calm := func() -> void:  # nothing on screen, nothing waiting
		if hud.get("_toast_tween"):
			(hud.get("_toast_tween") as Tween).kill()
		hud.set("_toast_queue", [] as Array[String])
		hud.set("_note_free_at", 0.0)
		label.text = ""

	# --- Short: the first line and first sentence, at most 60 letters ---
	var long_note := "Oil from passing ships has started drifting in: dark patches on the water. Sail through them.\nMore text."
	var short: String = hud_script.brief(long_note)
	_expect(short.length() <= 60 and not short.contains("\n") and short.begins_with("Oil from passing ships"),
		"a long note is cut to one short line (%s)" % short)
	_expect(hud_script.brief("Water gate built.") == "Water gate built.", "a short note stays as it is")

	# --- One at a time: while one shows, only the newest waits ---
	calm.call()
	hud.show_toast("First note")
	hud.show_toast("Second note")
	hud.show_toast("Third note")
	_expect(label.text == "First note" and hud.get("_toast_queue") == ["Third note"],
		"a busy moment: the first shows, only the newest waits (%s)" % [hud.get("_toast_queue")])
	hud.show_toast("Done that!", true)
	_expect(label.text == "Done that!", "something the ranger just did shows at once")

	# --- Never the same note again soon ---
	calm.call()
	hud.show_toast("Done that!")
	_expect(label.text == "", "the same note isn't repeated straight away")

	# --- Only the ranger's island ---
	calm.call()
	var reef: Resource = load("res://data/regions/tropical_reef.tres")
	hud.show_toast("Something on the Reef", false, reef.center)
	_expect(label.text != "Something on the Reef" and hud.get("_toast_queue").is_empty(), "a note about another island is dropped")
	var turtle: Resource = load("res://data/animals/green_turtle.tres")
	root.get_node("Journal").record_hatch(turtle, 3, reef.center)
	_expect(not label.text.contains("hatchlings"), "hatchlings on another island: no note")
	root.get_node("Journal").record_hatch(turtle, 3, world.get_node("Player").global_position)
	_expect(label.text.contains("hatchlings"), "hatchlings here: a note (%s)" % label.text)

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
