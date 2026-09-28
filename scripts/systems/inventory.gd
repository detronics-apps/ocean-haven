extends Node
## Autoload "Inventory": what the ranger is carrying, counted per item id.

## Any count changed (HUD rows).
signal changed(item: ItemData, count: int)
## Something was picked up (HUD "collected!" note).
signal item_added(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}


func add(item: ItemData, amount := 1, announce := true) -> void:
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


## Item id -> count, for the save file.
func to_dict() -> Dictionary:
	return _counts.duplicate()


## Replaces the contents from a save file. Items are looked up as data/items/<id>.tres.
func restore(counts: Dictionary) -> void:
	for id in _counts.keys():
		_set_count(_items[id], 0)
	for id in counts:
		var path := "res://data/items/%s.tres" % id
		if ResourceLoader.exists(path):
			_set_count(load(path), int(counts[id]))


func _set_count(item: ItemData, n: int) -> void:
	_items[item.id] = item
	_counts[item.id] = n
	changed.emit(item, n)
