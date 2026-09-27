extends CanvasLayer
## On-screen inventory counts, clock, the menu bar (Build / Journal / Look), and a
## short non-blocking note with a fact when something is collected, discovered or built.

var _labels: Dictionary[StringName, Label] = {}
var _toast_tween: Tween

@onready var _rows: VBoxContainer = %Rows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel
@onready var _clock: Label = %Clock
@onready var _fade: ColorRect = %Fade


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
	GameClock.slept.connect(func() -> void: show_toast("Good morning! Day %d." % GameClock.day))
	%BuildButton.pressed.connect(get_tree().call_group.bind("build_menu", "open"))
	%JournalButton.pressed.connect(get_tree().call_group.bind("journal_screen", "open"))
	%LookButton.pressed.connect(get_tree().call_group.bind("avatar_creator", "open"))
	for build_mode: BuildMode in get_tree().get_nodes_in_group("build_mode"):
		build_mode.built.connect(_on_built)


## Fades to black, sleeps until morning, fades back in.
func sleep_through_night() -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.6)
	tween.tween_callback(GameClock.sleep_until_morning)
	tween.tween_interval(0.4)
	tween.tween_property(_fade, "color:a", 0.0, 0.8)


func _process(_delta: float) -> void:
	_clock.text = "Day %d · %s" % [GameClock.day, GameClock.period()]


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
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
