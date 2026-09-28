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
## Upgrade tier, 1 to data.max_tier.
var tier := 1
## The day it was built (palms grow from it).
var built_day := -1
var _bob := 0.0
## Drawbridges: raised right now (boats pass, the ranger can't cross).
var is_open := false
## How close a sailing boat must come for a drawbridge to open.
const BRIDGE_OPEN_RANGE := 64.0
## Decks: the tiles they replaced, to put back if moved. World cell -> [ground, local cell, source, atlas, alt].
var _deck_tiles: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint: Label = $Hint
@onready var _coin: Sprite2D = $Coin


func _enter_tree() -> void:
	add_to_group("buildings")
	add_to_group("interactables")


func _ready() -> void:
	if built_day < 0:
		built_day = GameClock.day
	move_to(cell)
	_sprite.texture = data.texture if data.draw_texture else null
	if not data.fleet_textures.is_empty():
		_show_fleet_level()
		Fleet.upgraded.connect(_show_fleet_level.unbind(2))
	if data.deck:
		z_index = -1  # a floor: under the ranger, boats and animals (the ground is -2)
	if data.spawns:
		add_child(data.spawns.instantiate())
	_coin.visible = false


## Exploration Ships look the part of the fleet's equipment level.
func _show_fleet_level() -> void:
	var level := mini(Fleet.level(), data.fleet_textures.size())
	_sprite.texture = data.fleet_textures[level - 1] if level > 0 else data.texture


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
	if data.action == &"explore":
		list.append({"label": "Explore", "do": get_tree().call_group.bind("explore_menu", "open")})
	if recycle_value() > 0 and Inventory.total() > 0:
		list.append({"label": "Recycle %d litter (+%d funding)" % [Inventory.total(), Inventory.total() * recycle_value()],
			"do": recycle})
	if tier < data.max_tier:
		list.append({"label": "Upgrade (%d/%d)" % [tier + 1, data.max_tier], "do": upgrade})
	if storage() > 0:
		for item: ItemData in storable_items():
			var name := item.display_name.to_lower()
			var give := mini(Inventory.count(item.id), storage_space(get_tree()) - Inventory.stored(item.id))
			if give > 0:
				list.append({"label": "Store %d %s" % [give, name], "do": Inventory.store.bind(item, give)})
			var take := mini(Inventory.stored(item.id), Inventory.room_for(item))
			if take > 0:
				list.append({"label": "Take %d %s" % [take, name], "do": Inventory.take_out.bind(item, take)})
	if data.movable:
		list.append({"label": "Move " + data.display_name, "do": build_mode.start_move.bind(self)})
	return list


## Opens when a sailing boat comes close (and nobody's standing on it); closes after.
func _update_drawbridge() -> void:
	var boat_near := false
	for boat: Node2D in get_tree().get_nodes_in_group("boat"):
		boat_near = boat_near or (boat.get("controlled") and boat.global_position.distance_to(global_position) < BRIDGE_OPEN_RANGE)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var ranger_on := player and player.visible and rect().has_point(Terrain.cell_of(player.global_position))
	var want_open := boat_near and not ranger_on
	if want_open == is_open:
		return
	is_open = want_open
	if is_open:
		_lift_deck()  # water again: boats sail through
	else:
		_lay_deck()
	_sprite.texture = data.open_texture if is_open else data.texture


## Recycles everything the ranger is carrying into conservation funding.
func recycle() -> void:
	var pieces := Inventory.total()
	if pieces <= 0 or not Inventory.take(pieces):
		return
	Funding.earn(pieces * recycle_value(), "You recycled %d pieces of litter at your %s." % [pieces, data.display_name])


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
	return maxi(capacity() - animals_here(), 0)


## Upgrades add 1 per tier to whatever it does.
func capacity() -> int:
	return _upgraded(data.animal_capacity)


func storage() -> int:
	return _upgraded(data.storage)


func recycle_value() -> int:
	return _upgraded(data.recycle_value)


func _upgraded(base: int) -> int:
	return base + tier - 1 if base > 0 else 0


## Next tier, if the ranger has what it costs (otherwise says what's needed).
func upgrade() -> void:
	if tier >= data.max_tier:
		return
	if not BuildMode.has_enough(data.upgrade_funding, 0, data.upgrade_items):
		get_tree().call_group("hud", "show_toast", "To upgrade your %s: %s" % [
			data.display_name, data.upgrade_cost_text()])
		return
	BuildMode.pay(data.upgrade_funding, 0, data.upgrade_items)
	tier += 1
	var better := "pays %d funding per piece" % recycle_value()
	if data.animal_capacity > 0:
		better = "holds %d turtles" % capacity()
	elif data.storage > 0:
		better = "stores %d of each" % storage()
	get_tree().call_group("hud", "show_toast", "%s upgraded (%d/%d): it %s now." % [
		data.display_name, tier, data.max_tier, better])


## The footprint in tiles.
func rect() -> Rect2i:
	return Rect2i(cell, data.size)


func _process(delta: float) -> void:
	if data.open_texture and visible:  # not while being moved (hidden, deck lifted)
		_update_drawbridge()
	if pending_funds > 0:
		_bob += delta
		_coin.position.y = -data.size.y * Terrain.TILE / 2.0 - 12.0 + roundf(sin(_bob * 3.0) * 2.0)
		if _ranger_in_range(collect_range):
			Funding.earn(pending_funds, "You collected the visitors' donations at your %s!" % data.display_name)
			pending_funds = 0
			_coin.visible = false
	var near := _ranger_in_range(use_range)
	_hint.visible = near and (data.action != &"" or capacity() > 0)
	if _hint.visible and data.action == &"sleep":
		_hint.text = "E / tap: sleep until morning" if GameClock.is_night() else "Rest here when it gets dark"
		if storage() > 0:
			_hint.text += "\nStored: " + ", ".join(storable_items().map(func(item: ItemData) -> String:
				return "%d / %d %s" % [Inventory.stored(item.id), storage_space(get_tree()), item.display_name.to_lower()]))
	elif _hint.visible and data.action == &"explore":
		_hint.text = "Exploration Ship: equipment level %d" % Fleet.level()
	elif _hint.visible:
		var here := animals_here()
		var note := ""
		if here >= capacity():
			note = "  (full: new hatchlings join your other areas)" if _other_areas_have_room() \
				else "  (all areas full: new hatchlings swim out to sea)"
		_hint.text = "Turtles here: %d / %d%s" % [here, capacity(), note]


static var _storable: Array = []


## Items that can be kept in a Ranger House: those with a carry limit (wood, sand).
static func storable_items() -> Array:
	if _storable.is_empty():
		_storable = DataFiles.load_all("res://data/items").filter(func(item: ItemData) -> bool: return item.carry_limit > 0)
	return _storable


## How much of each storable item all the ranger's houses hold together.
static func storage_space(tree: SceneTree) -> int:
	var space := 0
	for building: Building in tree.get_nodes_in_group("buildings"):
		space += building.storage()
	return space


func _other_areas_have_room() -> bool:
	for other: Building in get_tree().get_nodes_in_group("buildings"):
		if other != self and other.data.id == data.id and other.room_for_animals() > 0:
			return true
	return false


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
