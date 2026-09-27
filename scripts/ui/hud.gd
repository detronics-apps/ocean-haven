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
## Buttons for what the ranger can do nearby (top centre).
var _action_bar: HBoxContainer
var _shown_actions: Array[String] = []


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
	%JournalButton.add_sibling(map_button)
	for build_mode: BuildMode in get_tree().get_nodes_in_group("build_mode"):
		build_mode.built.connect(_on_built)
	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.anchor_left = 0.5
	_action_bar.anchor_right = 0.5
	_action_bar.offset_top = 12
	_action_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_action_bar.add_theme_constant_override("separation", 10)
	add_child(_action_bar)


## Fades out, sails to `region` (the ranger arrives there with their rowboat), fades in.
func voyage(region: RegionData) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.8)
	tween.tween_callback(func() -> void: VoyageMap.arrive(get_tree(), region))
	tween.tween_interval(0.6)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)
	tween.tween_callback(func() -> void: show_toast("You sailed to %s!\n%s" % [region.display_name, region.description]))


## Fades to black, sleeps until morning, fades back in.
func sleep_through_night() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(GameClock.sleep_until_morning)
	tween.tween_interval(0.4)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)


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


func _on_built(building: Building) -> void:
	show_toast("%s built!\n%s" % [building.data.display_name, building.data.fact])


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
