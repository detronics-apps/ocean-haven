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
var _move_button: Button


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
	_move_button = Button.new()
	_move_button.name = "MoveButton"
	_move_button.focus_mode = Control.FOCUS_NONE
	_move_button.custom_minimum_size = Vector2(140, 48)
	_move_button.anchor_left = 1.0
	_move_button.anchor_right = 1.0
	_move_button.anchor_top = 1.0
	_move_button.anchor_bottom = 1.0
	_move_button.offset_left = -156
	_move_button.offset_right = -16
	_move_button.offset_top = -64
	_move_button.offset_bottom = -16
	_move_button.visible = false
	_move_button.pressed.connect(_on_move_pressed)
	add_child(_move_button)


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


## The building next to the ranger that could be moved (none while placing something).
func _movable_building() -> Building:
	var build_mode: BuildMode = get_tree().get_first_node_in_group("build_mode")
	if build_mode and build_mode.is_active():
		return null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.ranger_is_near():
			return building
	return null


func _on_move_pressed() -> void:
	var building := _movable_building()
	if building:
		get_tree().get_first_node_in_group("build_mode").start_move(building)


func _process(_delta: float) -> void:
	var movable := _movable_building()
	_move_button.visible = movable != null
	if movable:
		_move_button.text = "Move " + movable.data.display_name
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
