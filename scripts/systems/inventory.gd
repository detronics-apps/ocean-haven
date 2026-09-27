extends Node
## Autoload "Inventory": what the ranger is carrying, counted per item id.

signal item_added(item: ItemData, count: int)
signal item_removed(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}
var _items: Dictionary[StringName, ItemData] = {}


func add(item: ItemData, amount := 1) -> void:
	_items[item.id] = item
	_counts[item.id] = _counts.get(item.id, 0) + amount
	item_added.emit(item, _counts[item.id])


func count(id: StringName) -> int:
	return _counts.get(id, 0)


func total() -> int:
	var n := 0
	for c in _counts.values():
		n += c
	return n


## Removes `amount` items of any kind, biggest piles first. Removes nothing and
## returns false if there aren't enough.
# ponytail: every item is litter for now; take by kind once non-litter items exist.
func take(amount: int) -> bool:
	if total() < amount:
		return false
	while amount > 0:
		var id: StringName = _counts.keys().reduce(func(a, b): return a if _counts[a] >= _counts[b] else b)
		var n := mini(amount, _counts[id])
		_counts[id] -= n
		amount -= n
		item_removed.emit(_items[id], _counts[id])
	return true
