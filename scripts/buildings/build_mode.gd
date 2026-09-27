class_name BuildMode
extends Node2D
## Placing a building. A see-through "ghost" sits next to the ranger (or wherever you
## tap/click): green where it fits, red where it doesn't. Place with the Place
## button / E; cancel with the Cancel button / Esc.
## Also adds buildings directly (loading a save).

signal built(building: Building)

const BUILDING_SCENE := preload("res://scenes/buildings/building.tscn")
const FITS := Color(0.6, 1.0, 0.6, 0.75)
const BLOCKED := Color(1.0, 0.45, 0.45, 0.6)

var _data: BuildingData
## The first tent is free and can't be cancelled.
var _free := false
var _cell: Vector2i
var _follow_ranger := true
var _ghost: Sprite2D
var _bar: CanvasLayer
var _label: Label
var _place: Button
var _cancel: Button


func _enter_tree() -> void:
	add_to_group("build_mode")


func _ready() -> void:
	_ghost = Sprite2D.new()
	_ghost.z_index = 50
	add_child(_ghost)
	_build_bar()
	_show(false)


func is_active() -> bool:
	return _data != null


func start(data: BuildingData, free := false) -> void:
	_data = data
	_free = free
	_follow_ranger = true
	_ghost.texture = data.texture
	_cancel.visible = not free
	_show(true)


func cancel() -> void:
	if _free:
		return
	_data = null
	_show(false)


## Whether `data` fits with its top-left tile at `cell` (and can be paid for).
func can_place(data: BuildingData, cell: Vector2i) -> bool:
	for x in data.size.x:
		for y in data.size.y:
			if Terrain.at(get_tree(), Terrain.centre_of(cell + Vector2i(x, y))) not in data.terrain:
				return false
	var footprint := Rect2i(cell, data.size)
	for other: Building in get_tree().get_nodes_in_group("buildings"):
		if other.rect().intersects(footprint):
			return false
	return _free or Inventory.total() >= data.cost_litter


## Moves the ghost to `cell` and places it there.
func place_at(cell: Vector2i) -> bool:
	_cell = cell
	_follow_ranger = false
	return place()


func place() -> bool:
	if not _data or not can_place(_data, _cell):
		return false
	if not _free and not Inventory.take(_data.cost_litter):
		return false
	var building := add_building(_data, _cell)
	_data = null
	_free = false
	_show(false)
	built.emit(building)
	return true


## Adds a finished building (no cost, no fuss) — also used when loading a save.
func add_building(data: BuildingData, cell: Vector2i) -> Building:
	var building: Building = BUILDING_SCENE.instantiate()
	building.data = data
	building.cell = cell
	var world := get_parent()
	world.add_child(building)
	world.move_child(building, world.get_node("Player").get_index())  # drawn under the ranger
	return building


func _process(_delta: float) -> void:
	if not _data:
		return
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		_follow_ranger = true
	var ranger := ControlledBody.active(get_tree())
	if _follow_ranger and ranger:
		# Just right of the ranger, bottom row level with their feet.
		_cell = Terrain.cell_of(ranger.global_position) + Vector2i(1, 1 - _data.size.y)
	_ghost.position = Vector2(_cell * Terrain.TILE) + Vector2(_data.size * Terrain.TILE) / 2.0
	var fits := can_place(_data, _cell)
	_ghost.modulate = FITS if fits else BLOCKED
	_place.disabled = not fits
	var where := "on the beach" if _data.terrain == PackedStringArray(["sand"]) else "on the island"
	_label.text = "Place your %s %s: walk, or tap a spot." % [_data.display_name.to_lower(), where]
	if not fits and not _free and Inventory.total() < _data.cost_litter:
		_label.text = "You need %d litter to build this." % _data.cost_litter
	if not ranger is Player:
		_label.text = "Go ashore to place your %s." % _data.display_name.to_lower()
		_place.disabled = true
		_ghost.visible = false
	else:
		_ghost.visible = true


func _unhandled_input(event: InputEvent) -> void:
	# In the boat, E and taps belong to the boat (go ashore, sail): placing waits until you're on land.
	if not _data or not ControlledBody.active(get_tree()) is Player:
		return
	if ControlledBody.is_tap(event):
		_cell = Terrain.cell_of(get_global_mouse_position()) - _data.size / 2
		_follow_ranger = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		place()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()


func _show(on: bool) -> void:
	_ghost.visible = on
	_bar.visible = on
	set_process(on)


func _build_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	add_child(_bar)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 12
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_place = Button.new()
	_place.text = "Place"
	_place.custom_minimum_size = Vector2(96, 48)
	_place.pressed.connect(place)
	row.add_child(_place)
	_cancel = Button.new()
	_cancel.text = "Cancel"
	_cancel.custom_minimum_size = Vector2(96, 48)
	_cancel.pressed.connect(cancel)
	row.add_child(_cancel)
