class_name SandShovel
extends Node
## Moving sand. With the shovel picked up (Build menu -> Shovel), the 8 tiles around
## the ranger are outlined: sand that can be picked up, and (while carrying sand)
## shallow water that can be filled. Tap one to select it; the action bar then
## offers "Pick up sand" or "Place sand" for exactly that tile. The ranger carries
## one sand at a time. Done puts the shovel away. Every changed tile is saved.

const SAND_TILE := Vector2i(1, 0)
const SHALLOW_TILE := Vector2i(0, 0)
## How much sand the ranger can carry at once.
const CARRY_LIMIT := 1
const CAN_PICK_UP := Color(0.55, 1.0, 0.55, 0.9)
const CAN_PLACE := Color(0.5, 0.8, 1.0, 0.9)

var _sand: ItemData = load("res://data/items/sand.tres")
## Holding the shovel right now.
var active := false
## The tile the ranger tapped (one of the 8 around them), or null.
var selected: Variant = null
var _bar: CanvasLayer
var _label: Label
var _outlines: Node2D


func _enter_tree() -> void:
	add_to_group("interactables")
	add_to_group("sand_shovel")


func _ready() -> void:
	_outlines = Node2D.new()
	_outlines.z_index = 60
	_outlines.draw.connect(_draw_outlines)
	add_child(_outlines)


func start() -> void:
	active = true
	selected = null
	if not _bar:
		_build_bar()
	_bar.visible = true


func stop() -> void:
	active = false
	selected = null
	if _bar:
		_bar.visible = false
	_outlines.queue_redraw()


func _process(_delta: float) -> void:
	if not active:
		return
	var around := tiles_around()
	if selected != null and selected not in around:
		selected = null  # walked away from it
	if _label:
		_label.text = "Shovel: tap a tile next to you. Carrying %d / %d sand." % [Inventory.count(_sand.id), CARRY_LIMIT]
	_outlines.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not active or not ControlledBody.is_tap(event):
		return
	var tapped := Terrain.cell_of(_outlines.get_global_mouse_position())
	if tapped in tiles_around():
		selected = tapped
		get_viewport().set_input_as_handled()  # a tile pick, not a walk


## The 8 tiles around the ranger (on foot), or none.
func tiles_around() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var player := ControlledBody.active(get_tree()) as Player
	if not player:
		return tiles
	var here := Terrain.cell_of(player.global_position)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx != 0 or dy != 0:
				tiles.append(here + Vector2i(dx, dy))
	return tiles


## "pick_up", "place" or "" for a tile.
func what_can_be_done(cell: Vector2i) -> String:
	if _blocked(cell):
		return ""
	var centre := Terrain.centre_of(cell)
	var terrain := Terrain.at(get_tree(), centre)
	if terrain == "sand" and Inventory.count(_sand.id) < CARRY_LIMIT:
		return "pick_up"
	if terrain == "water" and not Terrain.walkable(get_tree(), centre) and Inventory.count(_sand.id) > 0:
		return "place"
	return ""


## For the action bar: what can be done with the selected tile.
func actions() -> Array:
	if not active or selected == null:
		return []
	match what_can_be_done(selected):
		"pick_up":
			return [{"label": "Pick up sand", "do": pick_up.bind(selected)}]
		"place":
			return [{"label": "Place sand", "do": place.bind(selected)}]
	return []


## Beach -> shallow water; the ranger carries the sand.
func pick_up(cell: Vector2i) -> void:
	if what_can_be_done(cell) != "pick_up":
		return
	_set_tile(cell, SHALLOW_TILE)
	Inventory.add(_sand, 1, false)


## Shallow water -> beach, using the carried sand.
func place(cell: Vector2i) -> void:
	if what_can_be_done(cell) != "place":
		return
	if Inventory.take_item(_sand.id):
		_set_tile(cell, SAND_TILE)


func _set_tile(cell: Vector2i, atlas: Vector2i) -> void:
	var centre := Terrain.centre_of(cell)
	var ground := Terrain.ground_near(get_tree(), centre)
	if not ground:
		return
	var local := ground.local_to_map(ground.to_local(centre))
	ground.set_cell(local, 0, atlas)
	SaveGame.record_tile(ground, local, atlas)


## Not under a building, tree, nest or boat.
func _blocked(cell: Vector2i) -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.rect().has_point(cell):
			return true
	for group in ["plants", "nests", "boat"]:
		for thing: Node2D in get_tree().get_nodes_in_group(group):
			if Terrain.cell_of(thing.global_position) == cell:
				return true
	return false


## Outlines: green = sand to pick up, blue = water to fill; thick = selected.
func _draw_outlines() -> void:
	if not active:
		return
	for cell in tiles_around():
		var colour: Color
		match what_can_be_done(cell):
			"pick_up":
				colour = CAN_PICK_UP
			"place":
				colour = CAN_PLACE
			_:
				continue
		var rect := Rect2(Vector2(cell * Terrain.TILE) + Vector2(2, 2), Vector2.ONE * (Terrain.TILE - 4))
		var width := 3.0 if cell == selected else 1.0
		_outlines.draw_rect(rect, colour, false, width)
		if cell == selected:
			_outlines.draw_rect(rect, Color(colour, 0.25), true)


func _build_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	add_child(_bar)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -16
	panel.offset_bottom = -16
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	var done := BuildMode._big_button("Done", Color("3f8a4a"))
	done.pressed.connect(stop)
	row.add_child(done)
