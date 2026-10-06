extends Node
## Autoload "Inventory": what the ranger is carrying, counted per item id.

## Any count changed (HUD rows).
signal changed(item: ItemData, count: int)
## Something was picked up (HUD "collected!" note).
signal item_added(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}
## Kept in Ranger Houses (wood, sand): usable for building from anywhere.
var _stored: Dictionary[StringName, int] = {}
## Pieces of litter ever collected (island objectives), not what's carried now. Saved.
var litter_collected := 0
## Litter ever picked up, per kind (where it comes from becomes a question). Saved.
var picked: Dictionary[StringName, int] = {}
## Litter ever picked up on each island (region id; where the ranger was): an island's animals
## only start coming back once the ranger has helped there (Regions.helped). Saved.
var picked_on: Dictionary[StringName, int] = {}


## Adds as much of `amount` as the ranger can carry (see ItemData.carry_limit).
func add(item: ItemData, amount := 1, announce := true) -> void:
	amount = mini(amount, room_for(item))
	if amount <= 0:
		return
	if item.is_litter:
		litter_collected += amount
		picked[item.id] = picked.get(item.id, 0) + amount
		var ranger := ControlledBody.active(get_tree()) if is_inside_tree() else null
		if ranger:
			var here := Regions.nearest(ranger.global_position).id
			picked_on[here] = picked_on.get(here, 0) + amount
	_set_count(item, count(item.id) + amount)
	if announce:
		item_added.emit(item, _counts[item.id])


func count(id: StringName) -> int:
	return _counts.get(id, 0)


## Pieces of litter carried (what buildings cost and what gets recycled; not sand).
func total() -> int:
	var n := 0
	for id in _litter_ids():
		n += _counts[id]
	return n


## Removes `amount` pieces of litter, biggest piles first. Removes nothing and
## returns false if there aren't enough.
func take(amount: int) -> bool:
	if total() < amount:
		return false
	while amount > 0:
		var id: StringName = _litter_ids().reduce(func(a, b): return a if _counts[a] >= _counts[b] else b)
		var n := mini(amount, _counts[id])
		_set_count(_items[id], _counts[id] - n)
		amount -= n
	return true


func _litter_ids() -> Array:
	return _counts.keys().filter(func(id: StringName) -> bool: return _items[id].is_litter)


## Removes `amount` of one particular item (e.g. sand). Returns whether there was enough.
func take_item(id: StringName, amount := 1) -> bool:
	if count(id) < amount:
		return false
	_set_count(_items[id], count(id) - amount)
	return true


## How many more of `item` the ranger can carry.
func room_for(item: ItemData) -> int:
	return item.carry_limit - count(item.id) if item.carry_limit > 0 else 1 << 30


func stored(id: StringName) -> int:
	return _stored.get(id, 0)


## Moves up to `amount` carried into storage (the caller checks there's space).
func store(item: ItemData, amount: int) -> void:
	amount = mini(amount, count(item.id))
	_set_count(item, count(item.id) - amount)
	_stored[item.id] = stored(item.id) + amount


## Moves up to `amount` from storage into the ranger's arms.
func take_out(item: ItemData, amount: int) -> void:
	amount = mini(mini(amount, stored(item.id)), room_for(item))
	_stored[item.id] = stored(item.id) - amount
	_set_count(item, count(item.id) + amount)


## Carried plus stored: what building can use.
func available(id: StringName) -> int:
	return count(id) + stored(id)


## Spends `amount` for building: carried first, then stored. Returns whether there was enough.
func use(id: StringName, amount: int) -> bool:
	if available(id) < amount:
		return false
	var carried := mini(amount, count(id))
	if carried > 0:
		take_item(id, carried)
	_stored[id] = stored(id) - (amount - carried)
	return true


## Item id -> count, for the save file.
func to_dict() -> Dictionary:
	return _counts.duplicate()


func stored_to_dict() -> Dictionary:
	return _stored.duplicate()


## Replaces the contents from a save file. Items are looked up as data/items/<id>.tres.
func restore(counts: Dictionary, stored_counts: Dictionary = {}) -> void:
	for id in _counts.keys():
		_set_count(_items[id], 0)
	for id in counts:
		var path := "res://data/items/%s.tres" % id
		if ResourceLoader.exists(path):
			_set_count(load(path), int(counts[id]))
	_stored.clear()
	for id in stored_counts:
		_stored[StringName(id)] = int(stored_counts[id])


func _set_count(item: ItemData, n: int) -> void:
	_items[item.id] = item
	_counts[item.id] = n
	changed.emit(item, n)
