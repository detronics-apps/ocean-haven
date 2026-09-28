class_name Building
extends Node2D
## A building the player placed. Its top-left footprint tile is `cell`.
## Buildings with an action (e.g. the tent's "sleep") offer it when the ranger is close.
## Visitor donations wait here (a bobbing coin) until the ranger walks up to collect them.

@export var data: BuildingData
@export var cell: Vector2i
@export var use_range := 56.0
## How close the ranger must come to collect waiting donations.
@export var collect_range := 72.0

## The water tile variant that makes a walkable deck (see the tileset).
const WATER_TILE := Vector2i(0, 0)
const DECK_ALTERNATIVE := 1

## Visitor donations waiting to be collected here.
var pending_funds := 0
var _bob := 0.0
## Decks: the tiles they replaced, to put back if moved. World cell -> [ground, local cell, source, atlas, alt].
var _deck_tiles: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint: Label = $Hint
@onready var _coin: Sprite2D = $Coin


func _enter_tree() -> void:
	add_to_group("buildings")
	add_to_group("interactables")


func _ready() -> void:
	move_to(cell)
	_sprite.texture = data.texture if data.draw_texture else null
	if data.deck:
		z_index = -1  # a floor: under the ranger, boats and animals (the ground is -2)
	if data.spawns:
		add_child(data.spawns.instantiate())
	_coin.visible = false


## Puts it with its top-left footprint tile at `new_cell`.
func move_to(new_cell: Vector2i) -> void:
	if data.deck:
		_lift_deck()
	cell = new_cell
	position = Vector2(cell * Terrain.TILE) + Vector2(data.size * Terrain.TILE) / 2.0
	if data.deck:
		_lay_deck()


func _exit_tree() -> void:
	if data.deck:
		_lift_deck()


## Turns the water under its footprint into walkable deck (adding a tile out at sea).
func _lay_deck() -> void:
	for x in data.size.x:
		for y in data.size.y:
			var centre := Terrain.centre_of(cell + Vector2i(x, y))
			var ground := Terrain.ground_near(get_tree(), centre)
			if not ground:
				continue
			var local := ground.local_to_map(ground.to_local(centre))
			_deck_tiles[cell + Vector2i(x, y)] = [ground, local, ground.get_cell_source_id(local),
				ground.get_cell_atlas_coords(local), ground.get_cell_alternative_tile(local)]
			ground.set_cell(local, 0, WATER_TILE, DECK_ALTERNATIVE)


## Puts back the tiles the deck replaced.
func _lift_deck() -> void:
	for entry: Array in _deck_tiles.values():
		var ground: TileMapLayer = entry[0]
		if not is_instance_valid(ground):
			continue
		if entry[2] == -1:
			ground.erase_cell(entry[1])
		else:
			ground.set_cell(entry[1], entry[2], entry[3], entry[4])
	_deck_tiles.clear()


## What the ranger can do here right now, for the action bar: [{label, do}].
func actions() -> Array:
	var build_mode: BuildMode = get_tree().get_first_node_in_group("build_mode")
	if not ranger_is_near() or (build_mode and build_mode.is_active()) or not visible:
		return []
	var list := []
	if data.action == &"sleep" and GameClock.is_night():
		list.append({"label": "Sleep until morning", "do": get_tree().call_group.bind("hud", "sleep_through_night")})
	if data.recycle_value > 0 and Inventory.total() > 0:
		list.append({"label": "Recycle %d litter (+%d funding)" % [Inventory.total(), Inventory.total() * data.recycle_value],
			"do": recycle})
	list.append({"label": "Move " + data.display_name, "do": build_mode.start_move.bind(self)})
	return list


## Recycles everything the ranger is carrying into conservation funding.
func recycle() -> void:
	var pieces := Inventory.total()
	if pieces <= 0 or not Inventory.take(pieces):
		return
	Funding.earn(pieces * data.recycle_value, "You recycled %d pieces of litter at your %s." % [pieces, data.display_name])


## Whether the ranger (on foot) is standing next to it.
func ranger_is_near() -> bool:
	return _ranger_in_range(use_range)


func add_funds(amount: int) -> void:
	pending_funds += amount
	_coin.visible = pending_funds > 0


## Animals that belong here (not counting hatchlings heading out to sea).
func animals_here() -> int:
	return get_tree().get_nodes_in_group("animals").filter(
		func(a: Node) -> bool: return a.get("home_area") == self and not a.get("leaving")).size()


## How many more animals can join this area.
func room_for_animals() -> int:
	return maxi(data.animal_capacity - animals_here(), 0)


## The footprint in tiles.
func rect() -> Rect2i:
	return Rect2i(cell, data.size)


func _process(delta: float) -> void:
	if pending_funds > 0:
		_bob += delta
		_coin.position.y = -data.size.y * Terrain.TILE / 2.0 - 12.0 + roundf(sin(_bob * 3.0) * 2.0)
		if _ranger_in_range(collect_range):
			Funding.earn(pending_funds, "You collected the visitors' donations at your %s!" % data.display_name)
			pending_funds = 0
			_coin.visible = false
	var near := _ranger_in_range(use_range)
	_hint.visible = near and (data.action != &"" or data.animal_capacity > 0)
	if _hint.visible and data.action == &"sleep":
		_hint.text = "E / tap: sleep until morning" if GameClock.is_night() else "Rest here when it gets dark"
	elif _hint.visible:
		var here := animals_here()
		_hint.text = "Turtles here: %d / %d%s" % [here, data.animal_capacity,
			"  (full: new hatchlings swim out to sea)" if here >= data.animal_capacity else ""]


func _unhandled_input(event: InputEvent) -> void:
	if not _hint.visible:
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 32.0
	if (tapped or event.is_action_pressed("interact")) and data.action == &"sleep" and GameClock.is_night():
		get_viewport().set_input_as_handled()
		get_tree().call_group("hud", "sleep_through_night")


func _ranger_in_range(distance: float) -> bool:
	var ranger := ControlledBody.active(get_tree())
	return ranger is Player and ranger.global_position.distance_to(global_position) <= distance
