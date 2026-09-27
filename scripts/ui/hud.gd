extends CanvasLayer
## On-screen inventory counts, plus a short non-blocking note with a fact when
## something is collected, discovered or built.

var _labels: Dictionary[StringName, Label] = {}
var _toast_tween: Tween

@onready var _rows: VBoxContainer = %Rows
@onready var _toast: PanelContainer = %Toast
@onready var _toast_label: Label = %ToastLabel


func _ready() -> void:
	_toast.modulate.a = 0.0
	Inventory.changed.connect(_set_row)
	Inventory.item_added.connect(_on_item_added)
	Journal.discovered.connect(_on_discovered)
	for site: BuildSite in get_tree().get_nodes_in_group("build_sites"):
		site.built.connect(_on_built)


func _on_item_added(item: ItemData, _count: int) -> void:
	_show_toast("%s collected!\n%s" % [item.display_name, item.fact])


func _on_discovered(animal: AnimalData) -> void:
	_show_toast("New discovery: %s!\n%s" % [animal.display_name, animal.fact])


func _on_built(building: BuildingData) -> void:
	_show_toast("%s built!\n%s" % [building.display_name, building.fact])


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


func _show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
