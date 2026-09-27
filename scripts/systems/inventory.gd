extends Node
## Autoload "Inventory": what the ranger is carrying, counted per item id.

signal item_added(item: ItemData, count: int)

var _counts: Dictionary[StringName, int] = {}


func add(item: ItemData, amount := 1) -> void:
	_counts[item.id] = _counts.get(item.id, 0) + amount
	item_added.emit(item, _counts[item.id])


func count(id: StringName) -> int:
	return _counts.get(id, 0)
