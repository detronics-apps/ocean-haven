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
## Water gates: closed (holds water on the flats, blocks fish and flow) or open. Deep cameras:
## baited (see baited()); both switch to BuildingData.closed_texture.
var gate_closed := false:
	set(value):
		gate_closed = value
		if is_node_ready() and data.closed_texture:
			_sprite.texture = data.closed_texture if gate_closed else data.texture
## How close a sailing boat must come for a drawbridge to open.
const BRIDGE_OPEN_RANGE := 64.0
## Decks: the tiles they replaced, to put back if moved. World cell -> [ground, local cell, source, atlas, alt].
var _deck_tiles: Dictionary = {}
## Production: made and waiting to be taken, put in and still being made, and when the one
## being made is ready (GameClock.now()).
var stock := 0
var loaded := 0
var batch_done_at := -1.0

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
	if data.makes and data.makes_per_morning > 0:
		GameClock.new_day.connect(func(_d: int) -> void: _make_morning())
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
	if boat() and not boat().controlled:
		boat().position = Vector2.ZERO  # moved with its mooring
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
		list.append({"label": "Sleep until morning", "do": sleep})
	if data.action == &"sleep" and Inventory.count(&"clean_water") > 0 and ControlledBody.water_level(get_tree()) < 0.95:
		list.append({"label": "Drink clean water (fill up your water)", "do": drink_water})
	if data.action == &"explore":
		list.append({"label": "Explore", "do": get_tree().call_group.bind("explore_menu", "open")})
	if data.action == &"gate":
		list.append({"label": "Open the gate" if gate_closed else "Close the gate", "do": toggle_gate})
	if data.action == &"bait":
		list.append({"label": "Take the bait out" if gate_closed else "Bait the camera", "do": toggle_bait})
	if data.action == &"missions" and not damaged:
		list.append({"label": "Missions", "do": get_tree().call_group.bind("mission_menu", "open")})
	if data.accepts != &"" and Inventory.available(data.accepts) > 0 and not damaged:
		var item: ItemData = load("res://data/items/%s.tres" % data.accepts)
		var n := Inventory.available(data.accepts)
		list.append({"label": "Give %d %s to %s (+%d funding)" % [n, item.display_name.to_lower() + ("s" if n != 1 else ""),
			data.accepts_for, n * item.grant_value], "do": give_away})
	if recycle_value() > 0 and Inventory.total() > 0 and not damaged:
		list.append({"label": "Recycle litter (%d carried)" % Inventory.total(),
			"do": get_tree().call_group.bind("recycle_menu", "open_for", self)})
	if (data.makes or data.makes_from != &"") and not damaged:
		list.append_array(_production_actions())
	if tier < data.max_tier:
		list.append({"label": "Upgrade (%d/%d)" % [tier + 1, data.max_tier], "do": upgrade})
	if storage() > 0:
		list.append({"label": "Storage", "do": get_tree().call_group.bind("storage_menu", "open_for", self)})
	if data.movable:
		list.append({"label": "Move " + data.display_name, "do": build_mode.start_move.bind(self)})
	if data.demolishable:
		var sure := Time.get_ticks_msec() < _demolish_until
		list.append({"label": ("Tap again to demolish" if sure else "Demolish " + data.display_name), "do": demolish})
	return list


## The rowboat moored here (an extra rowboat), if any.
func boat() -> Boat:
	for child in get_children():
		if child is Boat:
			return child
	return null


func _production_actions() -> Array:
	var list := []
	if data.makes_from != &"" and loaded == 0 and not Fleet.has_flag(data.made_flag):
		var input: ItemData = load("res://data/items/%s.tres" % data.makes_from)
		var have := Inventory.available(data.makes_from)
		list.append({"label": ("Put in %d %s" % [data.makes_from_count, input.display_name.to_lower()]) if have >= data.makes_from_count
			else "Needs %d %s (%d now)" % [data.makes_from_count, input.display_name.to_lower(), have], "do": start_capability})
	if data.makes_from_value > 0 and Fleet.has_flag(data.made_flag) and Inventory.available(data.makes_from) > 0:
		var n := Inventory.available(data.makes_from)
		list.append({"label": "Drop off %d %s (+%d funding)" % [n, data.makes_from, n * data.makes_from_value], "do": sell_input})
	if data.makes:
		var take := mini(stock, Inventory.room_for(data.makes))
		if take > 0:
			list.append({"label": "Take %d %s" % [take, data.makes.display_name.to_lower()], "do": take_stock})
	return list


## Extra input (sand) dropped off once the capability is running: made into glass and sold.
func sell_input() -> void:
	var n := Inventory.available(data.makes_from)
	if n <= 0 or not Inventory.use(data.makes_from, n):
		return
	Funding.earn(n * data.makes_from_value, "Your %s made glass from %d sand." % [data.display_name, n])


## A capability (Glassworks): puts the sand in; make_minutes later it's established for good.
func start_capability() -> void:
	if loaded > 0 or not Inventory.use(data.makes_from, data.makes_from_count):
		return
	loaded = 1
	batch_done_at = GameClock.now() + data.make_minutes * 60.0 / GameClock.DAY_LENGTH
	get_tree().call_group("hud", "show_toast", "The %s is firing up: ready in %s." % [data.display_name, Missions.real_time(data.make_minutes * 60.0)])


func take_stock() -> void:
	var take := mini(stock, Inventory.room_for(data.makes))
	if take <= 0:
		return
	Inventory.add(data.makes, take)
	stock -= take


func _produce(amount: int) -> void:
	if amount <= 0:
		return
	if data.makes:
		stock = mini(stock + amount, data.stock_max)
	if data.made_flag != &"" and not Fleet.has_flag(data.made_flag):
		Fleet.mark(data.made_flag)


func _make_morning() -> void:
	if damaged or not is_inside_tree() or not Regions.ranger_on(get_tree(), Regions.nearest(global_position)):
		return
	var workers := tier
	if data.hosts != &"":
		workers = get_tree().get_nodes_in_group("animals").filter(func(a: Node) -> bool:
			return a.get("home_area") == self and not a.get("leaving") and not a.get("tangled") and not a.get("injured")).size()
	_produce(workers * data.makes_per_morning)


## At the tent or house: drinks a clean water, so the ranger's water is full (they move faster
## on foot and by boat until it runs out).
func drink_water() -> void:
	if not Inventory.take_item(&"clean_water", 1):
		return
	ControlledBody.fill_water(get_tree())
	get_tree().call_group("hud", "show_toast", "Water full! While you have water you move faster, on foot and by boat. It runs out over %d days: drink more clean water at your tent or house." % roundi(ControlledBody.WATER_DAYS))


## Sleeps until morning.
func sleep() -> void:
	get_tree().call_group("hud", "sleep_through_night")


## Opens or closes a water gate: the island's water and flow change straight away.
func toggle_gate() -> void:
	gate_closed = not gate_closed
	get_tree().call_group("ecosystems", "settle_now")
	get_tree().call_group("hud", "show_toast", "Gate %s. %s" % ["closed" if gate_closed else "opened",
		"It holds water on the flats, but fish and flowing water can't get through." if gate_closed
		else "Fish and water flow through, flushing silt out, but the flats drain a little."])


## A deep camera with bait: it learns faster, but draws sixgill sharks in.
func baited() -> bool:
	return data.action == &"bait" and gate_closed


func toggle_bait() -> void:
	gate_closed = not gate_closed
	get_tree().call_group("ecosystems", "settle_now")
	get_tree().call_group("hud", "show_toast", "Camera baited: it learns faster, but the bait draws sixgill sharks in from far away." if gate_closed
		else "Bait taken out: the camera learns more slowly, and visiting sharks drift away again.")


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
## Recycles `pieces` of the litter the ranger carries (-1 = all of it) into funding.
func recycle(pieces := -1) -> void:
	if pieces < 0 or pieces > Inventory.total():
		pieces = Inventory.total()
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


## What it stores of each item: `storage_per_tier` (a Ranger House: 4, 8, 10), or the full
## amount again for each tier.
func storage() -> int:
	if data.storage_needs != &"" and not Fleet.is_installed(data.storage_needs):
		return 0
	if not data.storage_per_tier.is_empty():
		return data.storage_per_tier[clampi(tier, 1, data.storage_per_tier.size()) - 1]
	return data.storage * tier


func recycle_value() -> int:
	return _upgraded(data.recycle_value)


func _upgraded(base: int) -> int:
	return base + tier - 1 if base > 0 else 0


## Next tier, if the ranger has what it costs (otherwise says what's needed).
func upgrade() -> void:
	if tier >= data.max_tier:
		return
	if not BuildMode.has_enough(data.upgrade_funding, data.upgrade_litter, data.upgrade_items):
		get_tree().call_group("hud", "show_toast", "To upgrade your %s: %s" % [
			data.display_name, data.upgrade_cost_text()])
		return
	BuildMode.pay(data.upgrade_funding, data.upgrade_litter, data.upgrade_items)
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
	if loaded > 0 and GameClock.now() >= batch_done_at:
		loaded = 0
		_produce(1)
		if data.capability_note != "":
			get_tree().call_group("hud", "show_toast", data.capability_note)
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
	if data.watches != &"":
		var kind: String = load("res://data/animals/%s.tres" % data.watches).display_name
		return "%ss: %d" % [kind.get_slice(" ", kind.get_slice_count(" ") - 1), animals_in_view()]
	if data.action == &"missions":
		return "Back in %s" % Missions.time_left() if Missions.active else ""
	if data.makes:
		return "%s ready: %d" % [data.makes.display_name, stock]
	if data.makes_from != &"":
		return "Running" if Fleet.has_flag(data.made_flag) else ("Firing up" if loaded > 0 else "Needs %d %s" % [data.makes_from_count, data.makes_from])
	if data.action == &"explore":
		return "Level %d" % Fleet.level()
	if data.action == &"bait":
		return "Baited: draws sharks" if baited() else "Lamp on"
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


## Items that can be kept in storage at all: those with a carry limit (wood, sand...).
static func storable_items() -> Array:
	if _storable.is_empty():
		_storable = DataFiles.load_all("res://data/items").filter(func(item: ItemData) -> bool: return item.carry_limit > 0)
	return _storable


## The items this building keeps (BuildingData.stores): wood and saplings in a Ranger House,
## everything else in an Exploration Ship.
func kept_items() -> Array:
	return storable_items().filter(func(item: ItemData) -> bool: return String(item.id) in data.stores) \
		if storage() > 0 else []


## How much of `id` all the ranger's buildings that keep it hold together (every island).
static func storage_space(tree: SceneTree, id: StringName) -> int:
	var space := 0
	for building: Building in tree.get_nodes_in_group("buildings"):
		if String(id) in building.data.stores:
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
