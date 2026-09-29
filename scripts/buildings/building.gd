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
## Upgrade tier, 1 to data.max_tier. Each tier can have its own picture.
var tier := 1:
	set(value):
		tier = value
		if is_node_ready():
			_show_tier()
## Made safe for a coming storm (RareEvents): it won't be damaged.
var secured := false
## Damaged by a storm: no visitors, nesting or use until the ranger repairs it.
var damaged := false:
	set(value):
		damaged = value
		if is_node_ready():
			_sprite.modulate = DAMAGED_TINT if damaged else Color.WHITE
const DAMAGED_TINT := Color(0.62, 0.55, 0.5)
## Extra reach from the rowboat.
const BOAT_REACH := 40.0
## Its upkeep was paid this morning (unpaid: not looked after today).
var upkeep_paid := true
## "Demolish" was tapped: tap again before this (msec) to confirm.
var _demolish_until := 0
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
	_show_tier()
	damaged = damaged  # show it
	if not data.fleet_textures.is_empty():
		_show_fleet_level()
		Fleet.upgraded.connect(_show_fleet_level.unbind(2))
	if data.deck:
		z_index = -1  # a floor: under the ranger, boats and animals (the ground is -2)
	if data.spawns:
		add_child(data.spawns.instantiate())
	_coin.visible = false


func _show_tier() -> void:
	if not data.tier_textures.is_empty() and data.draw_texture:
		_sprite.texture = data.tier_textures[clampi(tier, 1, data.tier_textures.size()) - 1]


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
	if damaged:
		var wood := _repair_wood()
		list.append({"label": "Repair %s (%d wood)" % [data.display_name, wood], "do": repair, "helps": true})
	elif RareEvents.is_coming_to(Regions.nearest(global_position).id) and not secured and not data.storm_proof:
		list.append({"label": "Secure for the storm", "do": func() -> void: secured = true, "helps": true})
	if data.action == &"sleep" and GameClock.is_night():
		list.append({"label": "Sleep until morning", "do": get_tree().call_group.bind("hud", "sleep_through_night")})
	if data.action == &"explore":
		list.append({"label": "Explore", "do": get_tree().call_group.bind("explore_menu", "open")})
	if data.action == &"missions" and not damaged:
		list.append({"label": "Missions", "do": get_tree().call_group.bind("mission_menu", "open")})
	if data.accepts != &"" and Inventory.available(data.accepts) > 0 and not damaged:
		var item: ItemData = load("res://data/items/%s.tres" % data.accepts)
		var n := Inventory.available(data.accepts)
		list.append({"label": "Give %d %s to %s (+%d funding)" % [n, item.display_name.to_lower() + ("s" if n != 1 else ""),
			data.accepts_for, n * item.grant_value], "do": give_away})
	if recycle_value() > 0 and Inventory.total() > 0 and not damaged:
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
	if data.demolishable:
		var sure := Time.get_ticks_msec() < _demolish_until
		list.append({"label": ("Tap again to demolish" if sure else "Demolish " + data.display_name), "do": demolish})
	return list


## Takes it down (tap twice), giving back half its wood. Animals living here move out
## (they may settle at another home, or leave the island).
func demolish() -> void:
	if Time.get_ticks_msec() >= _demolish_until:
		_demolish_until = Time.get_ticks_msec() + 4000
		return
	for animal: Node in get_tree().get_nodes_in_group("animals"):
		if animal.get("home_area") == self:
			animal.set("home_area", null)
	var wood: int = data.cost_items.get(&"wood", 0) / 2
	if wood > 0:
		Inventory.add(load("res://data/items/wood.tres"), wood, false)
	remove_from_group("buildings")
	get_tree().call_group.call_deferred("ecosystems", "settle_now")  # its animals react straight away
	get_tree().call_group("hud", "show_toast", "%s taken down.%s" % [data.display_name,
		" You got %d wood back." % wood if wood > 0 else ""])
	queue_free()


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


## Gives every spare `accepts` item (carried and stored) to its project, for a grant.
func give_away() -> void:
	var item: ItemData = load("res://data/items/%s.tres" % data.accepts)
	var n := Inventory.available(item.id)
	if n <= 0 or not Inventory.use(item.id, n):
		return
	Funding.earn(n * item.grant_value, "A grant for the %d %s you gave to %s." % [
		n, item.display_name.to_lower() + ("s" if n != 1 else ""), data.accepts_for])


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


## The building that makes this nesting area too busy to nest in (null = it's quiet).
func too_busy() -> Building:
	if data.needs_quiet <= 0:
		return null
	var around := rect().grow(data.needs_quiet)
	for other: Building in get_tree().get_nodes_in_group("buildings"):
		if other != self and other.visible and not other.data.deck and other.data.build_verb != "Plant" \
				and other.data.id != data.id and around.intersects(other.rect()):
			return other
	return null


## Animals of the `watches` species in view (e.g. dolphins from a viewing area).
func animals_in_view() -> int:
	if data.watches == &"":
		return 0
	return get_tree().get_nodes_in_group("animals").filter(func(a: Node2D) -> bool:
		return (a.data.id == data.watches and not a.leaving and (a.global_position.distance_to(global_position) <= data.watch_range
			or (data.watch_range <= 0.0 and Regions.nearest(a.global_position) == Regions.nearest(global_position))))).size()


## What visitors donate this morning: a base amount, more for every animal that lives here
## or is in view, and more again the healthier the island is.
func visitors_today() -> int:
	if data.visitors <= 0 or damaged:
		return 0  # closed until it's repaired
	var base := data.visitors + data.visitors_per_animal * (animals_here() + animals_in_view())
	var health := maxf(IslandHealth.of(get_tree(), Regions.nearest(global_position)), 0.0)
	return roundi(base * (1.0 + health * data.health_bonus))


## How many more animals can join this area.
func room_for_animals() -> int:
	return maxi(capacity() - animals_here(), 0)


## Upgrades add 1 per tier to what it does (storage: see storage()).
func capacity() -> int:
	return _upgraded(data.animal_capacity)


## Each tier stores the full amount again (a Ranger House: 10, 20, 30 of each).
func storage() -> int:
	return data.storage * tier


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
	if not data.range_per_tier.is_empty():
		better = "patrols %d px around its buoy" % roundi(data.range_per_tier[mini(tier, data.range_per_tier.size()) - 1])
	elif data.animal_capacity > 0:
		better = "holds %d turtles" % capacity()
	elif data.storage > 0:
		better = "stores %d of each" % storage()
	get_tree().call_group("hud", "show_toast", "%s upgraded (%d/%d): it %s now." % [
		data.display_name, tier, data.max_tier, better])


## Fixes storm damage, if the ranger has the wood.
func repair() -> void:
	var wood := _repair_wood()
	if not Inventory.use(&"wood", wood):
		get_tree().call_group("hud", "show_toast", "Repairing your %s needs %d wood." % [data.display_name, wood])
		return
	damaged = false
	get_tree().call_group("hud", "show_toast", "%s repaired!" % data.display_name)


func _repair_wood() -> int:
	var event := RareEvents.for_region(Regions.nearest(global_position).id)
	return event.repair_wood if event else 1


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
	# Just the numbers above it (what to do is on the action buttons).
	_hint.text = stats() if _ranger_in_range(use_range) else ""
	_hint.visible = _hint.text != ""


## Short stats shown above it when the ranger is close ("" = nothing to show).
func stats() -> String:
	if damaged:
		return "Damaged"
	var lines: Array[String] = []
	if data.max_tier > 1:
		lines.append("Lv %d/%d" % [tier, data.max_tier])
	var numbers := _numbers()
	if numbers:
		lines.append(numbers)
	if secured and RareEvents.is_coming_to(Regions.nearest(global_position).id):
		lines.append("Secured")
	return "\n".join(lines)


func _numbers() -> String:
	if data.action == &"sleep":
		return "  ".join(storable_items().map(func(item: ItemData) -> String:
			return "%s %d/%d" % [item.display_name, Inventory.stored(item.id), storage_space(get_tree())])) \
			if storage() > 0 else ""
	if data.watches != &"":
		var kind: String = load("res://data/animals/%s.tres" % data.watches).display_name
		return "%ss: %d" % [kind.get_slice(" ", kind.get_slice_count(" ") - 1), animals_in_view()]
	if data.action == &"missions":
		return "Back in %s" % Missions.time_left() if Missions.active else ""
	if data.action == &"explore":
		return "Level %d" % Fleet.level()
	var lines: Array[String] = []
	if capacity() > 0:
		var kind := "Turtles"
		if data.hosts != &"":
			var name: String = load("res://data/animals/%s.tres" % data.hosts).display_name
			kind = name.get_slice(" ", name.get_slice_count(" ") - 1) + "s"
		lines.append("%s %d/%d" % [kind, animals_here(), capacity()])
		var busy := too_busy()
		if busy:
			lines.append("Too busy: %s nearby" % busy.data.display_name)
	if data.upkeep > 0 and not upkeep_paid:
		lines.append("Upkeep unpaid today")
	if has_node("PatrolBoat"):  # patrol boats must leave turtles and dolphins some quiet water
		var free := PatrolBoat.free_water_share(get_tree(), Regions.nearest(global_position))
		lines.append("Quiet water left: %d%%%s" % [roundi(free * 100.0), " (too little!)" if free < 0.65 else ""])
	return "\n".join(lines)


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


func _unhandled_input(event: InputEvent) -> void:
	if not _ranger_in_range(use_range):
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 32.0
	if (tapped or event.is_action_pressed("interact")) and data.action == &"sleep" and GameClock.is_night():
		get_viewport().set_input_as_handled()
		get_tree().call_group("hud", "sleep_through_night")


## The ranger is this close, on foot or in their rowboat (e.g. to move a buoy offshore; the
## boat can't come right up to things on land, so it gets a little more room).
func _ranger_in_range(distance: float) -> bool:
	var ranger := ControlledBody.active(get_tree())
	if ranger is Boat:
		distance += BOAT_REACH
	return (ranger is Player or ranger is Boat) and ranger.global_position.distance_to(global_position) <= distance
