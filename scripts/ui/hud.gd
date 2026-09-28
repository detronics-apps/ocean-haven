extends CanvasLayer
## On-screen inventory counts, clock, the menu bar (Build / Journal / Look), and a
## short non-blocking note with a fact when something is collected, discovered or built.

var _labels: Dictionary[StringName, Label] = {}
var _toast_tween: Tween
## Notes waiting for the current one to fade (so they don't overwrite each other).
var _toast_queue: Array[String] = []

@onready var _rows: VBoxContainer = %Rows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _clock: Label = %Clock
@onready var _fade: ColorRect = %Fade
## Buttons for what the ranger can do nearby (bottom right, stacked).
var _action_bar: VBoxContainer
var _info: Label
var _shown_actions: Array[String] = []
var _saved_note: Label


func _enter_tree() -> void:
	add_to_group("hud")


func _ready() -> void:
	_toast.modulate.a = 0.0
	Inventory.changed.connect(_set_row)
	Inventory.item_added.connect(_on_item_added)
	Journal.discovered.connect(_on_discovered)
	Journal.observed.connect(_on_observed)
	Journal.photographed.connect(_on_photographed)
	Journal.helped.connect(_on_helped)
	Journal.nested.connect(_on_nested)
	Journal.hatched.connect(_on_hatched)
	Journal.gifted.connect(_on_gifted)
	Funding.earned.connect(_on_earned)
	Fleet.objective_completed.connect(_on_objective_completed)
	SaveGame.saved.connect(_flash_saved)
	Funding.donations_waiting.connect(_on_donations_waiting)
	GameClock.slept.connect(func() -> void: show_toast("Good morning! Day %d." % GameClock.day))
	%BuildButton.pressed.connect(get_tree().call_group.bind("build_menu", "open"))
	%JournalButton.pressed.connect(get_tree().call_group.bind("journal_screen", "open"))
	%LookButton.pressed.connect(get_tree().call_group.bind("avatar_creator", "open"))
	var map_button := Button.new()  # the voyage map, next to Journal
	map_button.name = "MapButton"
	map_button.text = "Map"
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.custom_minimum_size = Vector2(80, 44)
	map_button.pressed.connect(get_tree().call_group.bind("voyage_map", "open"))
	var explore := ExploreMenu.new()  # opened only from the Exploration Ship, never from here
	explore.name = "ExploreMenu"
	get_parent().add_child.call_deferred(explore)
	var missions := MissionMenu.new()  # opened from a signature facility
	missions.name = "MissionMenu"
	get_parent().add_child.call_deferred(missions)
	Missions.sent.connect(func(m: MissionData) -> void: show_toast("%s sent out. It's back at %s." % [m.display_name, Missions.back_time()]))
	Missions.returned.connect(_on_mission_returned)
	%JournalButton.add_sibling(map_button)
	for build_mode: BuildMode in get_tree().get_nodes_in_group("build_mode"):
		build_mode.built.connect(_on_built)
	# Which version this is (written by tools/publish_pages.sh), tiny, under the minimap.
	var revision := Label.new()
	revision.name = "Revision"
	revision.text = FileAccess.get_file_as_string("res://version.txt").strip_edges() \
		if FileAccess.file_exists("res://version.txt") else "dev"
	revision.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	revision.offset_left = 18
	revision.offset_top = -16
	revision.add_theme_font_size_override("font_size", 11)
	revision.modulate = Color(1, 1, 1, 0.6)
	revision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(revision)
	# Bottom right, stacked upwards: easy to reach with a thumb.
	_action_bar = VBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_bar.offset_left = -16
	_action_bar.offset_right = -16
	_action_bar.offset_top = -16
	_action_bar.offset_bottom = -16
	_action_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_action_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_action_bar.alignment = BoxContainer.ALIGNMENT_END
	_action_bar.add_theme_constant_override("separation", 8)
	add_child(_action_bar)
	# One line about the nearest animal (instead of a label over every animal), above the buttons.
	_info = Label.new()
	_info.name = "Info"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 260
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_constant_override("outline_size", 5)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_action_bar.add_child(_info)


## A small "Saved" that fades in and out after every save, so you know progress is kept.
func _flash_saved() -> void:
	if not _saved_note:
		_saved_note = Label.new()
		_saved_note.name = "SavedNote"
		_saved_note.text = "Saved"
		_saved_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_saved_note.anchor_left = 1.0
		_saved_note.anchor_right = 1.0
		_saved_note.offset_left = -80
		_saved_note.offset_right = -16
		_saved_note.offset_top = 106
		_saved_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_saved_note.add_theme_constant_override("outline_size", 4)
		_saved_note.add_theme_color_override("font_outline_color", Color.BLACK)
		_saved_note.modulate.a = 0.0
		add_child(_saved_note)
	var tween := create_tween()
	tween.tween_property(_saved_note, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_saved_note, "modulate:a", 0.0, 0.6)


## A note that stays on screen (e.g. progress can't be saved in this browser).
func show_warning(text: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "Warning"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 76
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.self_modulate = Color(1.0, 0.55, 0.45)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	add_child(panel)


## Fades out, sails to `region` (the ranger arrives there with their rowboat), fades in.
## `discovered`: found by exploring, so it says so.
func voyage(region: RegionData, discovered := false) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.8)
	tween.tween_callback(func() -> void: VoyageMap.arrive(get_tree(), region))
	tween.tween_interval(0.6)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: show_toast("%s %s!\n%s" % [
		"You discovered" if discovered else "You sailed to", region.display_name, region.description]))


## Fades to black, sleeps until morning, fades back in.
func sleep_through_night() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(GameClock.sleep_until_morning)
	tween.tween_interval(0.4)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)


## What the nearest animal with something to say is up to ("" if none).
func nearest_animal_info() -> String:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return ""
	var best: Node2D = null
	for animal: Node2D in get_tree().get_nodes_in_group("animals"):
		if animal.get("info") and (not best or animal.global_position.distance_to(ranger.global_position)
				< best.global_position.distance_to(ranger.global_position)):
			best = animal
	return best.info if best else ""


## Everything the ranger can do nearby: helping an animal first, at most 4, no repeats.
func nearby_actions() -> Array:
	var helps := []
	var others := []
	var seen := {}
	for thing: Node in get_tree().get_nodes_in_group("interactables"):
		for action: Dictionary in thing.actions():
			if seen.has(action.label):
				continue
			seen[action.label] = true
			(helps if action.get("helps", false) else others).append(action)
	return (helps + others).slice(0, 4)


func _update_action_bar() -> void:
	var actions := nearby_actions()
	var labels: Array[String] = []
	for action: Dictionary in actions:
		labels.append(action.label)
	if labels == _shown_actions:
		return
	_shown_actions = labels
	for button in _action_bar.get_children():
		if button is Button:
			button.queue_free()
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = action.label
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 52)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(action.do)
		_action_bar.add_child(button)


func _process(_delta: float) -> void:
	_update_action_bar()
	_info.text = nearest_animal_info()
	_info.visible = _info.text != ""
	_clock.text = "Day %d · %s    Funding: %d" % [GameClock.day, GameClock.period(), Funding.balance]


func _on_earned(amount: int, reason: String) -> void:
	show_toast("+%d funding\n%s" % [amount, reason])


func _on_donations_waiting(building: Building, amount: int) -> void:
	show_toast("Visitors left %d funding at your %s.\nGo and collect it!" % [amount, building.data.display_name])


func _on_item_added(item: ItemData, _count: int) -> void:
	show_toast("%s collected!\n%s" % [item.display_name, item.fact])


func _on_discovered(animal: AnimalData) -> void:
	show_toast("New discovery: %s!\n%s" % [animal.display_name, animal.fact])


func _on_observed(animal: AnimalData) -> void:
	show_toast("You quietly watched the %s.\nHabitat: %s. Diet: %s." % [
		animal.display_name, animal.habitat, animal.diet])


func _on_photographed(animal: AnimalData, count: int) -> void:
	if count == 1:
		show_toast("Your first photo of a %s!\n%s" % [animal.display_name, animal.photo_fact])
	else:
		show_toast("Photo saved! (%d %s photos)" % [count, animal.display_name])


func _on_helped(animal: AnimalData, _count: int) -> void:
	show_toast("You freed the %s!\n%s" % [animal.display_name, animal.help_fact])


func _on_gifted(animal: AnimalData) -> void:
	show_toast("A %s %s" % [animal.display_name, animal.gift_text])


func _on_nested(animal: AnimalData) -> void:
	show_toast("A %s is nesting on your beach!\n%s" % [animal.display_name, animal.nest_fact])


func _on_hatched(animal: AnimalData, count: int) -> void:
	show_toast("%d hatchlings are heading for the sea!\n%s" % [count, animal.hatch_fact])


func _on_objective_completed(region: RegionData, discovery: DiscoveryData) -> void:
	var text := "%s: objective complete!" % region.display_name
	if discovery:
		text += "\n%s\n%s" % [region.discovery_text, discovery.fact]
	show_toast(text)


func _on_mission_returned(mission: MissionData, found: int) -> void:
	var report := mission.report if found > 0 else mission.report_none
	show_toast("%s is back!\n%s" % [mission.display_name, report % found if "%d" in report else report])


func _on_built(building: Building) -> void:
	var done := "planted" if building.data.build_verb == "Plant" else "built"
	show_toast("%s %s!\n%s" % [building.data.display_name, done, building.data.fact])


func _set_row(item: ItemData, count: int) -> void:
	if not _labels.has(item.id):
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		row.add_child(icon)
		row.add_child(label)
		_rows.add_child(row)
		_labels[item.id] = label
	_labels[item.id].text = "%s  x%d" % [item.display_name, count]
	_labels[item.id].get_parent().visible = count > 0


func show_toast(text: String) -> void:
	if _toast_tween and _toast_tween.is_running():
		_toast_queue.append(text)
		if _toast_queue.size() > 2:
			_toast_queue.pop_front()  # keep it short: drop the oldest waiting note
		return
	_toast_label.text = text
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.finished.connect(_show_next_toast)


func _show_next_toast() -> void:
	if not _toast_queue.is_empty():
		show_toast(_toast_queue.pop_front())
