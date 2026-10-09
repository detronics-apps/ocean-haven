extends CanvasLayer
## On-screen inventory counts, clock, the menu bar (Build / Journal / Look), and a
## short non-blocking note with a fact when something is collected, discovered or built.

## Phones have rounded corners: the bottom UI (minimap, revision, action buttons) moves up
## (and a little in) by this much when the screen is taller than it is wide...
@export var portrait_lift := 40.0
@export var portrait_inset := 10.0
## ... and in landscape, where the corners and the home bar sit at the bottom-left and right.
@export var landscape_lift := 28.0
@export var landscape_inset := 40.0
## Taps this close around the action buttons (and in the gaps between them) never walk
## the ranger: a missed button is just a missed button.
@export var action_dead_zone := 28.0

var _labels: Dictionary[StringName, Label] = {}
var _toast_tween: Tween
## Notes waiting for the current one to fade (so they don't overwrite each other).
var _toast_queue: Array[String] = []
## Notes: the longest line, the pause after one, and how soon the same note may show again.
const NOTE_MAX_CHARS := 60
const NOTE_GAP_SECONDS := 2.5
const NOTE_REPEAT_SECONDS := 90.0
var _note_shown := {}
var _note_free_at := 0.0

@onready var _rows: VBoxContainer = %Rows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _clock: Label = %Clock
@onready var _fade: ColorRect = %Fade
## Buttons for what the ranger can do nearby (bottom right, stacked).
var _action_bar: VBoxContainer
## Around the action buttons: stops taps (the dead zone).
var _action_zone: MarginContainer
var _revision: Label
var _info: Label
var _shown_actions: Array[String] = []
var _saved_note: Label
## "Patrol boats: +3 litter", under the inventory rows while they're collecting.
var _patrol_note: Label
var _patrol_count := 0
var _patrol_tween: Tween
var _event_note: Label
## The island's objective: the next goal and a pointer on how to go about it.
var _objective: Label
var _unlock_check := 0.0
var _cheer: ProgressCheer


func _enter_tree() -> void:
	add_to_group("hud")


func _ready() -> void:
	_toast.modulate.a = 0.0
	# Notes are small: one short line in a light box, not a big black panel.
	_toast_label.custom_minimum_size = Vector2.ZERO
	_toast_label.add_theme_font_size_override("font_size", 17)
	var note_box := StyleBoxFlat.new()
	note_box.bg_color = Color(0.05, 0.1, 0.15, 0.6)
	note_box.set_corner_radius_all(10)
	note_box.content_margin_left = 14
	note_box.content_margin_right = 14
	note_box.content_margin_top = 5
	note_box.content_margin_bottom = 6
	_toast.add_theme_stylebox_override("panel", note_box)
	Inventory.changed.connect(_set_row)
	Inventory.item_added.connect(_on_item_added)
	Journal.discovered.connect(_on_discovered)
	Journal.plant_discovered.connect(func(p: PlantData) -> void: show_toast("New plant in your Journal: %s" % p.display_name))
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
	GameClock.slept.connect(func() -> void: show_toast("Day %d" % GameClock.day))
	GameClock.new_day.connect(_on_new_day)
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
	var weather := StormWeather.new()  # a storm's weather when it strikes
	weather.name = "StormWeather"
	add_child(weather)
	move_child(weather, 0)  # over the world, under the buttons, bars and notes
	var clouds := StormClouds.new()  # a storm gathering beyond the island's waters
	clouds.name = "StormClouds"
	add_child(clouds)
	move_child(clouds, 0)
	var observatory := ObservatoryScreen.new()  # the whole ocean (from the Map)
	observatory.name = "ObservatoryScreen"
	get_parent().add_child.call_deferred(observatory)
	add_child(CameraZoom.new())  # pinch / wheel / + − buttons
	_cheer = ProgressCheer.new()  # sparkles, return cards, "+N" funding
	add_child(_cheer)
	var season_show := SeasonShow.new()  # seasonal moments' sights (SeasonEvent)
	season_show.name = "SeasonShow"
	get_parent().add_child.call_deferred(season_show)
	var recycling := RecycleMenu.new()  # opened from a recycling centre
	recycling.name = "RecycleMenu"
	get_parent().add_child.call_deferred(recycling)
	var info := BuildingInfo.new()  # "What is this?" on any building
	info.name = "BuildingInfo"
	get_parent().add_child.call_deferred(info)
	var rescue_screen := RescueScreen.new()  # the rescue companion (Rescues)
	rescue_screen.name = "RescueScreen"
	get_parent().add_child.call_deferred(rescue_screen)
	Rescues.found.connect(func(r: RescueData) -> void: show_toast("A young %s needs help" % r.species.display_name.to_lower()))
	Rescues.sighted.connect(func(r: RescueData, animal_name: String, region: RegionData) -> void:
		show_toast("%s (rescued %s) is here" % [animal_name, r.species.display_name.to_lower()]))
	Journal.moment_caught.connect(func(animal: AnimalData, moment: PhotoMoment) -> void:
		show_toast("New photo moment: %s" % moment.title.to_lower(), true))
	Rescues.released.connect(func(r: RescueData, animal_name: String) -> void:
		show_toast("%s released" % animal_name, true))
	for activity_screen: ActivityScreen in [SonarSweep.new(), OtterDive.new(), ChannelFlow.new(), EchoDive.new(), IceMatch.new(), GlassSort.new()]:  # ranger activities (data/activities/)
		activity_screen.name = activity_screen.get_script().get_global_name()
		get_parent().add_child.call_deferred(activity_screen)
	var talk := TalkBox.new()  # talking to the people of the islands
	talk.name = "TalkBox"
	get_parent().add_child.call_deferred(talk)
	People.objective_given.connect(func(_p: PersonData, goal: ObjectiveGoal) -> void:
		show_toast("New objective: " + goal.text)
		_unlock_check = 0.0)
	var storage := StorageMenu.new()  # opened from a Ranger House or an Exploration Ship
	storage.name = "StorageMenu"
	get_parent().add_child.call_deferred(storage)
	var missions := MissionMenu.new()  # opened from a signature facility
	missions.name = "MissionMenu"
	get_parent().add_child.call_deferred(missions)
	Missions.sent.connect(func(m: MissionData) -> void: show_toast("%s: back in %s" % [m.display_name, Missions.time_left()], true))
	Missions.returned.connect(_on_mission_returned)
	RareEvents.warned.connect(func(e: EventData) -> void: show_toast("%s coming %s" % [e.display_name, RareEvents.when(e.id)], true))
	# What's coming (a storm warning), under the clock until it arrives.
	_event_note = Label.new()
	_event_note.name = "EventNote"
	_event_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_event_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_note.add_theme_color_override("font_color", Color("ffd27a"))
	_event_note.add_theme_constant_override("outline_size", 5)
	_event_note.add_theme_color_override("font_outline_color", Color.BLACK)
	_event_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%JournalButton.add_sibling(map_button)
	%LookButton.add_sibling(SoundButton.new())  # sound on / off and volume
	# Under the menu bar, top right, one under the other: the island's health (once there's a
	# research station on the 2nd island), the ranger's water (once clean water can be made),
	# the island's objective with a pointer, and a coming storm. Hidden ones take no room.
	var column := VBoxContainer.new()
	column.name = "StatusColumn"
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.offset_left = -12.0 - 320.0
	column.offset_right = -12.0
	column.offset_top = 110.0
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var gauge := HealthGauge.new()
	gauge.name = "HealthGauge"
	gauge.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(gauge)
	var water := WaterGauge.new()
	water.name = "WaterGauge"
	water.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(water)
	_objective = Label.new()
	_objective.name = "Objective"
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_font_size_override("font_size", 14)
	_objective.add_theme_constant_override("outline_size", 5)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_objective)
	column.add_child(_event_note)
	for build_mode: BuildMode in get_tree().get_nodes_in_group("build_mode"):
		build_mode.built.connect(_on_built)
	# Which version this is (written by tools/publish_pages.sh), tiny, under the minimap.
	var revision := Label.new()
	revision.name = "Revision"
	revision.text = FileAccess.get_file_as_string("res://version.txt").strip_edges() \
		if FileAccess.file_exists("res://version.txt") else "dev"
	revision.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	revision.grow_vertical = Control.GROW_DIRECTION_BEGIN
	revision.offset_left = 18
	revision.offset_bottom = 0
	revision.add_theme_font_size_override("font_size", 11)
	revision.modulate = Color(1, 1, 1, 0.6)
	revision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(revision)
	_revision = revision
	# Bottom right, stacked upwards: easy to reach with a thumb. The zone around them
	# (margins, gaps) swallows taps, so a near miss doesn't walk the ranger off.
	_action_zone = MarginContainer.new()
	_action_zone.name = "ActionZone"
	_action_zone.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_zone.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_action_zone.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_action_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_zone.add_theme_constant_override("margin_left", int(action_dead_zone))
	_action_zone.add_theme_constant_override("margin_top", int(action_dead_zone))
	add_child(_action_zone)
	_action_bar = VBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.alignment = BoxContainer.ALIGNMENT_END
	_action_bar.add_theme_constant_override("separation", 8)
	_action_zone.add_child(_action_bar)
	get_viewport().size_changed.connect(_layout_bottom)
	_layout_bottom()
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


## Keeps the bottom UI clear of a phone's rounded corners and home bar (portrait or landscape;
## not on a computer).
func _layout_bottom() -> void:
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	var phone := OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile")
	var lift := portrait_lift if portrait else (landscape_lift if phone else 0.0)
	var inset := portrait_inset if portrait else (landscape_inset if phone else 0.0)
	var minimap: Control = $Minimap
	minimap.offset_left = 16.0 + inset
	minimap.offset_right = 144.0 + inset
	minimap.offset_top = -144.0 - lift
	minimap.offset_bottom = -16.0 - lift
	_revision.offset_left = 18.0 + inset
	_revision.offset_top = -lift
	_revision.offset_bottom = -lift
	# The zone reaches the screen edge; the buttons sit 16 px (plus the lift) in from it.
	_action_zone.add_theme_constant_override("margin_right", int(16.0 + inset))
	_action_zone.add_theme_constant_override("margin_bottom", int(16.0 + lift))
	_action_zone.offset_left = 0.0
	_action_zone.offset_top = 0.0
	_action_zone.offset_right = 0.0
	_action_zone.offset_bottom = 0.0


## Notes sit bottom middle, but never over the action buttons (a narrow phone screen in
## portrait): then they go up above them.
func _place_toast() -> void:
	var bottom := -112.0
	var view := get_viewport().get_visible_rect().size
	var buttons := _action_bar.get_children().filter(func(c: Node) -> bool: return c is Button and c.visible)
	if not buttons.is_empty():
		var bar := _action_bar.get_global_rect()
		if (view.x + _toast.get_combined_minimum_size().x) / 2.0 > bar.position.x - 8.0:
			bottom = minf(bottom, bar.position.y - view.y - 12.0)
	var box := _toast.get_combined_minimum_size()
	_toast.offset_left = -box.x / 2.0
	_toast.offset_right = box.x / 2.0
	_toast.offset_bottom = bottom
	_toast.offset_top = bottom - box.y


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
		_saved_note.offset_top = 146
		_saved_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_saved_note.add_theme_constant_override("outline_size", 4)
		_saved_note.add_theme_color_override("font_outline_color", Color.BLACK)
		_saved_note.modulate.a = 0.0
		add_child(_saved_note)
	var tween := create_tween()
	tween.tween_property(_saved_note, "modulate:a", 1.0, 0.2)
	tween.tween_interval(1.2)
	tween.tween_property(_saved_note, "modulate:a", 0.0, 0.6)


## A patrol boat put a piece of litter into the ranger's inventory: counted up in a
## small note under the inventory (not a note per piece).
func patrol_collected(_item: ItemData) -> void:
	if not _patrol_note:
		_patrol_note = Label.new()
		_patrol_note.name = "PatrolNote"
		_patrol_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_patrol_note.add_theme_color_override("font_color", Color("9fe3ff"))
		_patrol_note.add_theme_constant_override("outline_size", 4)
		_patrol_note.add_theme_color_override("font_outline_color", Color.BLACK)
		_rows.add_child(_patrol_note)
	_rows.move_child(_patrol_note, -1)
	if not _patrol_tween or not _patrol_tween.is_running():
		_patrol_count = 0
	elif _patrol_tween:
		_patrol_tween.kill()
	_patrol_count += 1
	_patrol_note.text = "Patrol boats: +%d litter" % _patrol_count
	_patrol_note.modulate.a = 1.0
	_patrol_tween = create_tween()
	_patrol_tween.tween_interval(4.0)
	_patrol_tween.tween_property(_patrol_note, "modulate:a", 0.0, 0.8)


## An animal came to `region` (a newcomer or one born there): a card with its picture
## instead of a plain note, only while the ranger is on that island (elsewhere it just
## happens, and they'll see more of them when they get there).
func animal_returned(species: AnimalData, note: String, region: RegionData = null) -> void:
	var ranger := ControlledBody.active(get_tree())
	if region and ranger and Regions.nearest(ranger.global_position) != region:
		return
	_cheer.show_return(species, note, region)


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
	Sound.play(&"whoosh")
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.8)
	tween.tween_callback(func() -> void: VoyageMap.arrive(get_tree(), region))
	tween.tween_interval(0.6)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: show_toast("%s %s" % [
		"Discovered:" if discovered else "Arrived:", region.display_name]))


## Fades to black, sleeps until morning, fades back in.
func sleep_through_night() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(GameClock.sleep_until_morning)
	tween.tween_callback(Births.born_now.bind(get_tree()))  # (young due overnight are born)
	tween.tween_interval(0.4)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)


## What the nearest animal with something to say is up to ("" if none).
func nearest_animal_info() -> String:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return ""
	# Things close by that have something to say but nothing to press (`info_line`): the line
	# above the buttons, never a button that only shows a note.
	for thing: Node in get_tree().get_nodes_in_group("interactables"):
		if thing.has_method("info_line"):
			var line: String = thing.info_line()
			if line != "":
				return line
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
	# Only a dead zone while there are buttons (the animal note alone doesn't block taps).
	_action_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE if actions.is_empty() else Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_update_action_bar()
	_place_toast()
	_event_note.text = RareEvents.warning_text()
	_event_note.visible = _event_note.text != ""
	_unlock_check -= delta
	if _unlock_check <= 0.0:
		_unlock_check = 1.0
		_check_unlocks()
		_objective.text = objective_text()
		_objective.visible = _objective.text != ""
	_info.text = nearest_animal_info()
	_info.visible = _info.text != ""
	_clock.text = "%s · %s    Funding: %d" % [GameClock.calendar(), GameClock.period(), Funding.balance]


## The HUD grows with the game: the minimap comes with the Salvaged Sonar Core (the end of the
## first island), the island health bar with the research station on the second island.
const MINIMAP_NEEDS := &"salvaged_sonar_core"
const HEALTH_FLAG := &"health_gauge"


func _check_unlocks() -> void:
	_check_season_moment()
	var minimap: Control = $Minimap
	minimap.visible = Fleet.is_installed(MINIMAP_NEEDS)
	if minimap.visible and not Fleet.has_flag(&"minimap_shown"):
		Fleet.mark(&"minimap_shown")
		show_toast("Map unlocked (bottom left)", true)
	if not Fleet.has_flag(HEALTH_FLAG):
		for building: Building in get_tree().get_nodes_in_group("buildings"):
			if building.data.facility == &"signature" and Regions.nearest(building.global_position).id != &"home_island":
				Fleet.mark(HEALTH_FLAG)
				show_toast("Island health unlocked (top right)", true)
				break


## The goal line: objectives only come from the island's people (People.goal_text); their
## hint-givers give the advice.
func objective_text() -> String:
	var ranger := ControlledBody.active(get_tree())
	return People.goal_text(Regions.nearest(ranger.global_position).id) if ranger else ""


## A new season: what it means for the island's animals (data: SEASON_NOTES).
const SEASON_NOTES := {
	&"spring": "Spring has come: nesting season for the sea turtles.",
	&"summer": "Summer has begun. The turtles nested in spring; now their young grow up.",
	&"autumn": "Autumn has begun.",
	&"winter": "Winter has begun. Next spring the turtles come back to nest.",
}


## A seasonal moment starting on the ranger's island (data/seasons/): said once a year, and
## marked seen ("seen_<id>") for the Journal.
var _season_told := {}


func _check_season_moment() -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position).id
	for event in SeasonEvent.all():
		if event.region != here or not event.is_on():
			continue
		var key := "%s/%d" % [event.id, GameClock.year()]
		if _season_told.has(key):
			continue
		_season_told[key] = true
		Fleet.mark(StringName("seen_%s" % event.id))
		show_toast(event.note)


func _on_new_day(day: int) -> void:
	if GameClock.day_of_season(day) == 1 and day > 1:
		show_toast(SEASON_NOTES.get(GameClock.season(day), ""))


func _on_earned(_amount: int, _reason: String) -> void:
	pass  # the "+N" rising from the funding (ProgressCheer) says it


func _on_donations_waiting(building: Building, amount: int) -> void:
	show_toast("+%d funding waiting at the %s" % [amount, building.data.display_name], false, building.global_position)


func _on_item_added(item: ItemData, _count: int) -> void:
	show_toast("%s collected" % item.display_name)


func _on_discovered(animal: AnimalData) -> void:
	show_toast("New: %s (take a photo)" % animal.display_name.to_lower())


func _on_observed(animal: AnimalData) -> void:
	show_toast("%s watched" % animal.display_name.to_lower())


func _on_photographed(animal: AnimalData, count: int) -> void:
	if count == 1:
		show_toast("New in your Journal: %s" % animal.display_name, true)
	else:
		show_toast("Photo taken", true)


func _on_helped(animal: AnimalData, _count: int) -> void:
	show_toast("%s freed" % animal.display_name.to_lower(), true)


func _on_gifted(animal: AnimalData) -> void:
	show_toast("A %s %s" % [animal.display_name, animal.gift_text])


func _on_nested(animal: AnimalData) -> void:
	show_toast("%s nesting" % animal.display_name.to_lower(), false, Journal.event_at)


func _on_hatched(animal: AnimalData, count: int) -> void:
	show_toast("%d hatchlings" % count, false, Journal.event_at)


func _on_objective_completed(region: RegionData, discovery: DiscoveryData) -> void:
	show_toast("Objective complete: %s" % discovery.display_name if discovery else "Objective complete!", true)


func _on_mission_returned(mission: MissionData, found: int) -> void:
	var report := mission.report if found > 0 else mission.report_none
	show_toast("%s back: report ready" % mission.display_name)


func _on_built(building: Building) -> void:
	var done := "planted" if building.data.build_verb == "Plant" else "built"
	Sound.play(&"dig" if done == "planted" else &"build")
	show_toast("%s %s" % [building.data.display_name, done], true)


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


## Shows a note for a few seconds (waiting its turn; `now`: straight away, e.g. a tip the player
## asked for, and the interrupted note comes back after it).
## A note: one short line (`brief`), one at a time, a pause between them, never the same one
## again soon, and only about the island the ranger is on (`at`, a place in the world: notes
## from other islands are dropped). While one shows, only the newest waits; the rest are
## dropped, so a busy moment never piles notes up. `now`: shown at once (the ranger just did
## something), replacing the one on screen.
func show_toast(text: String, now := false, at := Vector2.INF) -> void:
	if at != Vector2.INF and not _here(at):
		return
	text = brief(text)
	var clock := Time.get_ticks_msec() / 1000.0
	if text == "" or clock - float(_note_shown.get(text, -INF)) < NOTE_REPEAT_SECONDS:
		return
	var busy := (_toast_tween and _toast_tween.is_running()) or clock < _note_free_at
	if busy and not now:
		_toast_queue = [text]  # only the newest waits
		return
	if _toast_tween:
		_toast_tween.kill()
	_note_shown[text] = clock
	_toast_label.text = text
	# As wide as its one line (a wrapping label with no width shrinks to one letter), never
	# wider than the screen: then it wraps.
	var font := _toast_label.get_theme_font("font")
	var line_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_toast_label.get_theme_font_size("font_size")).x + 2.0
	_toast_label.custom_minimum_size.x = minf(line_width, get_viewport().get_visible_rect().size.x - 60.0)
	_toast.reset_size()
	_toast.modulate.a = 1.0
	var showing := clampf(1.8 + text.length() / 30.0, 2.5, 4.0)  # time to read it
	_note_free_at = clock + showing + 0.4 + NOTE_GAP_SECONDS
	_toast_tween = create_tween()
	_toast_tween.tween_interval(showing)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_interval(NOTE_GAP_SECONDS)
	_toast_tween.finished.connect(_show_next_toast)


func _show_next_toast() -> void:
	if not _toast_queue.is_empty():
		show_toast(_toast_queue.pop_front())


## `text` cut to its first line and first sentence, at most NOTE_MAX_CHARS (whole words).
static func brief(text: String) -> String:
	var line := text.strip_edges().get_slice("\n", 0).strip_edges()
	if line.length() > NOTE_MAX_CHARS:
		for stop in [". ", "! ", "? ", ": ", "; ", " - ", ", "]:
			var at := line.find(stop)
			if at > 8 and at < NOTE_MAX_CHARS:
				line = line.left(at + (1 if stop.strip_edges() in [".", "!", "?"] else 0))
				break
	if line.length() > NOTE_MAX_CHARS:
		line = line.left(NOTE_MAX_CHARS)
		line = line.left(line.rfind(" ")) if line.rfind(" ") > 20 else line
	return line.strip_edges().trim_suffix(",").trim_suffix(":")


## Whether `at` is on the island the ranger is on.
func _here(at: Vector2) -> bool:
	var ranger := ControlledBody.active(get_tree())
	return not ranger or Regions.nearest(ranger.global_position) == Regions.nearest(at)
