class_name SandShovel
extends Node
## Moving sand: with the shovel picked up (Build menu -> Shovel), the ranger scoops
## up the beach tile in front of them (it becomes shallow water) and piles carried
## sand onto a shallow-water tile (it becomes beach). Offered on the action bar
## while the shovel is out; Done puts it away. Every changed tile is saved.

const SAND_TILE := Vector2i(1, 0)
const SHALLOW_TILE := Vector2i(0, 0)

var _sand: ItemData = load("res://data/items/sand.tres")
## Holding the shovel right now.
var active := false
var _bar: CanvasLayer


func _enter_tree() -> void:
	add_to_group("interactables")
	add_to_group("sand_shovel")


func start() -> void:
	active = true
	if not _bar:
		_build_bar()
	_bar.visible = true


func stop() -> void:
	active = false
	if _bar:
		_bar.visible = false


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
	var label := Label.new()
	label.text = "Shovel: face a beach tile to scoop up sand, or shallow water to place it."
	label.add_theme_font_size_override("font_size", 20)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var done := BuildMode._big_button("Done", Color("3f8a4a"))
	done.pressed.connect(stop)
	row.add_child(done)


## What the ranger can do with the tile in front of them, for the action bar.
func actions() -> Array:
	var player := ControlledBody.active(get_tree()) as Player
	if not active or not player:
		return []
	var cell := Terrain.cell_of(player.global_position) + player.facing
	if _blocked(cell):
		return []
	var centre := Terrain.centre_of(cell)
	var terrain := Terrain.at(get_tree(), centre)
	if terrain == "sand":
		return [{"label": "Scoop up sand", "do": scoop.bind(cell)}]
	if terrain == "water" and not Terrain.walkable(get_tree(), centre) and Inventory.count(_sand.id) > 0:
		return [{"label": "Place sand", "do": place.bind(cell)}]
	return []


## Beach -> shallow water; the ranger carries the sand.
func scoop(cell: Vector2i) -> void:
	if Terrain.at(get_tree(), Terrain.centre_of(cell)) != "sand" or _blocked(cell):
		return
	_set_tile(cell, SHALLOW_TILE)
	Inventory.add(_sand, 1, false)


## Shallow water -> beach, using one carried sand.
func place(cell: Vector2i) -> void:
	var centre := Terrain.centre_of(cell)
	if Terrain.at(get_tree(), centre) != "water" or Terrain.walkable(get_tree(), centre) or _blocked(cell):
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
