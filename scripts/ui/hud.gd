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


func _enter_tree() -> void:
	add_to_group("hud")


func _ready() -> void:
	_toast.modulate.a = 0.0
	Inventory.changed.connect(_set_row)
	Inventory.item_added.connect(_on_item_added)
	Journal.discovered.connect(_on_discovered)
	Journal.plant_discovered.connect(func(p: PlantData) -> void: show_toast("New plant in your Journal: %s!\n%s" % [p.display_name, p.fact]))
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
	var weather := StormWeather.new()  # a storm's weather when it strikes
	weather.name = "StormWeather"
	add_child(weather)
	var recycling := RecycleMenu.new()  # opened from a recycling centre
	recycling.name = "RecycleMenu"
	get_parent().add_child.call_deferred(recycling)
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
	Missions.sent.connect(func(m: MissionData) -> void: show_toast("%s sent out. It's back in %s." % [m.display_name, Missions.time_left()]))
	Missions.returned.connect(_on_mission_returned)
	RareEvents.warned.connect(func(e: EventData) -> void: show_toast("%s!\n%s" % [e.display_name, e.warning.replace("{when}", RareEvents.when(e.id))]))
	RareEvents.struck.connect(func(e: EventData, damaged: int) -> void: show_toast(e.aftermath % damaged if "%d" in e.aftermath else e.aftermath))
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
	# One tip at a time, only when the player asks for it.
	var tip := Button.new()
	tip.name = "TipButton"
	tip.text = "Tip"
	tip.custom_minimum_size = Vector2(72, 40)
	tip.size_flags_horizontal = Control.SIZE_SHRINK_END
	tip.focus_mode = Control.FOCUS_NONE
	tip.pressed.connect(func() -> void: show_toast("Tip: " + tip_text(), true))
	column.add_child(tip)
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
	# Only a dead zone while there are buttons (the animal note alone doesn't block taps).
	_action_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE if actions.is_empty() else Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_update_action_bar()
	_event_note.text = RareEvents.warning_text()
	_event_note.visible = _event_note.text != ""
	_unlock_check -= delta
	if _unlock_check <= 0.0:
		_unlock_check = 1.0
		_check_unlocks()
		_objective.text = objective_text()
		_objective.visible = _objective.text != ""
		# Islands with people: they give the objectives, and their hint-giver replaces the tip.
		var region := _ranger_region()
		($StatusColumn/TipButton as Control).visible = _objective.visible \
			and not (region and People.has_people(region.id))
	_info.text = nearest_animal_info()
	_info.visible = _info.text != ""
	_clock.text = "Day %d · %s    Funding: %d" % [GameClock.day, GameClock.period(), Funding.balance]


## The HUD grows with the game: the minimap comes with the Salvaged Sonar Core (the end of the
## first island), the island health bar with the research station on the second island.
const MINIMAP_NEEDS := &"salvaged_sonar_core"
const HEALTH_FLAG := &"health_gauge"


func _check_unlocks() -> void:
	var minimap: Control = $Minimap
	minimap.visible = Fleet.is_installed(MINIMAP_NEEDS)
	if minimap.visible and not Fleet.has_flag(&"minimap_shown"):
		Fleet.mark(&"minimap_shown")
		show_toast("The salvaged sonar gives you a map of the waters round you (bottom left): your home and what your missions find are marked on it.")
	if not Fleet.has_flag(HEALTH_FLAG):
		for building: Building in get_tree().get_nodes_in_group("buildings"):
			if building.data.facility == &"signature" and Regions.nearest(building.global_position).id != &"home_island":
				Fleet.mark(HEALTH_FLAG)
				show_toast("Your research station measures how healthy each island is: the bar at the top right shows it now, and where it's heading.")
				break


## The island's goal: bring its headline animal back ("Goal: Bring the sea turtles back:
## 3 / 10"), and then explore to find more islands. "" when there's nothing to say.
## On an island with people, objectives only come from them (People.goal_text).
func objective_text() -> String:
	var region := _ranger_region()
	if not region:
		return ""
	if People.has_people(region.id):
		return People.goal_text(region.id)
	var lines: Array[String] = []
	var factor := _flagship_factor(region)
	if factor and IslandHealth.count(get_tree(), region, factor) < factor.amount:
		lines.append("Goal: %s: %d / %d" % [region.flagship_goal, IslandHealth.count(get_tree(), region, factor), factor.amount])
	if _undiscovered() > 0:
		lines.append(("then " if not lines.is_empty() else "Goal: ") + "explore to find a new island")
	if lines.is_empty():
		return "Goal: keep %s thriving" % region.display_name
	return "\n".join(lines)


## One tip, for where the player is in the game on this island (asked for with the Tip button):
## the objective's next step first (it opens up exploring), then the Exploration Ship, its
## discovery, exploring, and how to bring the island's animal back.
func tip_text() -> String:
	var region := _ranger_region()
	if not region:
		return "Sail to one of your islands."
	if not region.goals.is_empty() and not Fleet.objective_done(region):
		for goal: ObjectiveGoal in region.goals:
			if not Fleet.goal_met(goal):
				return "Next step towards exploring: " + (goal.hint if goal.hint != "" else Fleet.goal_line(region, goal))
	if Fleet.objective_done(region) and not Regions.exploration_ready(get_tree(), region):
		return "Build this island's Exploration Ship (Build menu, next to 2 dock planks)."
	if not Fleet.ready_to_install().is_empty():
		return "Install the %s at an Exploration Ship (Explore): it upgrades your whole fleet." % Fleet.ready_to_install().front().display_name
	if Regions.exploration_ready(get_tree(), region) and Regions.can_find_more() and _next_here(region):
		return "Use Explore at this island's Exploration Ship to find the next island, %s." % ("warmer" if _next_here(region).direction == Regions.WARMER else "colder")
	var factor := _flagship_factor(region)
	if factor and IslandHealth.count(get_tree(), region, factor) < factor.amount and region.flagship_tip != "":
		return region.flagship_tip
	if _undiscovered() > 0 and not Regions.can_find_more():
		return "Help the islands you've found: each one's discovery, installed, lets the fleet find one more island."
	if _undiscovered() > 0:
		return "Sail (Map) to an island at the edge of what you've found, and explore on from its Exploration Ship."
	return "%s is doing well. Visit your other islands (Map) and see how they're doing." % region.display_name


func _ranger_region() -> RegionData:
	var ranger := ControlledBody.active(get_tree())
	return Regions.nearest(ranger.global_position) if ranger else null


## The "animals" health factor for the island's headline animal (null = none).
func _flagship_factor(region: RegionData) -> HealthFactor:
	for factor: HealthFactor in region.health:
		if factor.kind == &"animals" and factor.target == region.flagship and region.flagship != &"":
			return factor
	return null


## Playable islands not found yet.
func _undiscovered() -> int:
	return Regions.all().filter(func(r: RegionData) -> bool: return not Regions.is_discovered(r) and not r.in_development).size()


## The undiscovered island next to `region` (warmer or colder), or null.
func _next_here(region: RegionData) -> RegionData:
	for direction: StringName in [Regions.WARMER, Regions.COLDER]:
		var next := Regions.next_from(region, direction)
		if next and not Regions.is_discovered(next) and not next.in_development:
			return next
	return null


func _on_earned(amount: int, reason: String) -> void:
	show_toast("+%d funding\n%s" % [amount, reason])


func _on_donations_waiting(building: Building, amount: int) -> void:
	show_toast("Visitors left %d funding at your %s.\nGo and collect it!" % [amount, building.data.display_name])


func _on_item_added(item: ItemData, _count: int) -> void:
	show_toast("%s collected!\n%s" % [item.display_name, item.fact])


func _on_discovered(animal: AnimalData) -> void:
	show_toast("You spotted a %s!\nStay calm, and take a photo to add it to your Journal." % animal.display_name)


func _on_observed(animal: AnimalData) -> void:
	show_toast("You quietly watched the %s.\nHabitat: %s. Diet: %s." % [
		animal.display_name, animal.habitat, animal.diet])


func _on_photographed(animal: AnimalData, count: int) -> void:
	if count == 1:
		show_toast("New in your Journal: %s!\n%s %s" % [animal.display_name, animal.fact, animal.photo_fact])
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
	show_toast("%s is back!\n%s" % [mission.display_name, Missions.last_report])


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


## Shows a note for a few seconds (waiting its turn; `now`: straight away, e.g. a tip the player
## asked for, and the interrupted note comes back after it).
func show_toast(text: String, now := false) -> void:
	if now and _toast_tween and _toast_tween.is_running():
		_toast_tween.kill()
		if _toast.modulate.a > 0.5:
			_toast_queue.push_front(_toast_label.text)
	elif _toast_tween and _toast_tween.is_running():
		_toast_queue.append(text)
		if _toast_queue.size() > 2:
			_toast_queue.pop_front()  # keep it short: drop the oldest waiting note
		return
	_toast_label.text = text
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(clampf(2.5 + text.length() / 45.0, 3.0, 10.0))  # time to read it
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.finished.connect(_show_next_toast)


func _show_next_toast() -> void:
	if not _toast_queue.is_empty():
		show_toast(_toast_queue.pop_front())
