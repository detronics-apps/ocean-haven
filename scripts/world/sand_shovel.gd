class_name SandShovel
extends Node
## Moving sand and mud. With the shovel picked up (Build menu -> Shovel), the 8 tiles around
## the ranger are outlined: sand or mud that can be dug up, and (while carrying some)
## shallow water that can be filled. Tap one to select it; the action bar then
## offers "Dig up sand / mud" or "Place sand / mud" for exactly that tile. The ranger carries
## one sand or 3 mud (storable in the Exploration Ship: dug mud is never lost, so a channel can
## always be filled back in); now and then sand hides buried litter. Digging mud makes a
## channel (shallow water); mud on shallow water makes a mud flat. Filling deep water takes 2.
## "Put shovel away" (an action button) ends it. Every changed tile is saved.

const SAND_TILE := Vector2i(1, 0)
const MUD_TILE := Vector2i(5, 0)
const SHALLOW_TILE := Vector2i(0, 0)
const CAN_PICK_UP := Color(0.55, 1.0, 0.55, 0.9)
const CAN_PLACE := Color(0.5, 0.8, 1.0, 0.9)

## Chance that scooping up sand turns up a piece of buried litter (like a digging crab).
@export var litter_chance := 0.1

var _sand: ItemData = load("res://data/items/sand.tres")
var _mud: ItemData = load("res://data/items/mud.tres")
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
		_label.text = "Shovel: tap a tile next to you · Sand %d/%d · Mud %d/%d" % [
			Inventory.count(_sand.id), _sand.carry_limit, Inventory.count(_mud.id), _mud.carry_limit]
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
	var item := material_at(cell)
	if item and Inventory.room_for(item) > 0:
		return "pick_up"
	var fillable := (terrain == "water" and not Terrain.walkable(get_tree(), centre)) \
		or (terrain == "" and Terrain.ground_near(get_tree(), centre) != null)  # deep water
	if fillable and carried_material() != null:
		return "place"
	return ""


## What digging `cell` gives (sand or mud), or null.
func material_at(cell: Vector2i) -> ItemData:
	match Terrain.at(get_tree(), Terrain.centre_of(cell)):
		"sand":
			return _sand
		"mud":
			return _mud
	return null


## What the ranger would place: mud first (if carrying any), else sand; null = nothing.
func carried_material() -> ItemData:
	if Inventory.count(_mud.id) > 0:
		return _mud
	if Inventory.count(_sand.id) > 0:
		return _sand
	return null


## For the action buttons: what can be done with the selected tile, and putting it away.
func actions() -> Array:
	if not active:
		return []
	var list := [{"label": "Put shovel away", "do": stop}]
	match what_can_be_done(selected) if selected != null else "":
		"pick_up":
			var dug := material_at(selected)
			list.push_front({"label": "Pick up sand" if dug == _sand else "Dig up mud (makes a channel)", "do": pick_up.bind(selected)})
		"place":
			var deep := Terrain.at(get_tree(), Terrain.centre_of(selected)) == ""
			var what := carried_material().display_name.to_lower()
			list.push_front({"label": ("Place %s (makes it shallow)" % what) if deep
				else ("Place mud (makes a mud flat)" if what == "mud" else "Place sand"), "do": place.bind(selected)})
	return list


## Beach -> shallow water; the ranger carries the sand.
func pick_up(cell: Vector2i) -> void:
	if what_can_be_done(cell) != "pick_up":
		return
	var dug := material_at(cell)
	_set_tile(cell, SHALLOW_TILE)
	Inventory.add(dug, 1, false)
	get_tree().call_group("ecosystems", "settle_now")  # the water changed
	if dug == _sand and randf() < litter_chance:
		var spawner: LitterSpawner = get_tree().get_first_node_in_group("litter_spawner")
		if spawner:
			spawner.dig_up_at(Terrain.centre_of(cell))
			get_tree().call_group("hud", "show_toast", "You dug up some buried litter!\nPick it up before it drifts away.")


## Shallow water -> beach, or deep water -> shallow, using the carried sand.
func place(cell: Vector2i) -> void:
	if what_can_be_done(cell) != "place":
		return
	var deep := Terrain.at(get_tree(), Terrain.centre_of(cell)) == ""
	var item := carried_material()
	if Inventory.take_item(item.id):
		_set_tile(cell, SHALLOW_TILE if deep else (MUD_TILE if item == _mud else SAND_TILE))
		get_tree().call_group("ecosystems", "settle_now")  # the water changed


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


## A short instruction at the top of the screen while the shovel is out.
func _build_bar() -> void:
	_bar = CanvasLayer.new()
	_bar.layer = 5
	add_child(_bar)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_top = 104  # below the clock and menu buttons (taller on phones)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_label)
