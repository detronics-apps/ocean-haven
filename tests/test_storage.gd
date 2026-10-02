extends SceneTree
## Storage: Ranger Houses keep wood and saplings, Exploration Ships (once the fleet has the
## Cargo Module) keep 99 of everything (sand,
## mud, clean water, coral fragments); every storable item has a home; each store opens a
## Storage menu (store / take per item) instead of a long line of text; stored items are shared
## by every island; sand stored in a house before ships held it can still be taken out.
## Run: godot --headless --path . --script res://tests/test_storage.gd --quit-after 200000

var _failed := false


func _initialize() -> void:
	await process_frame
	var inventory := root.get_node("Inventory")
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var build_mode: Node = world.get_node("BuildMode")
	var building_script: GDScript = load("res://scripts/buildings/building.gd")
	var house_data: Resource = load("res://data/buildings/house.tres")
	var ship_data: Resource = load("res://data/buildings/expedition_boat.tres")
	var wood: Resource = load("res://data/items/wood.tres")
	var sand: Resource = load("res://data/items/sand.tres")

	# Every item that can be stored is kept by a house or a ship.
	var homeless: Array = building_script.storable_items().filter(func(item: Resource) -> bool:
		return not (String(item.id) in house_data.stores or String(item.id) in ship_data.stores))
	_expect(homeless.is_empty(), "every storable item has a store (%s)" % [homeless.map(func(i: Resource) -> StringName: return i.id)])
	_expect(not ("sand" in house_data.stores) and "wood" in house_data.stores and "sapling" in house_data.stores,
		"Ranger Houses keep wood and saplings only")
	_expect("sand" in ship_data.stores and "mud" in ship_data.stores and "wood" in ship_data.stores,
		"Exploration Ships' cargo hold keeps everything")

	var house: Node2D = build_mode.add_building(house_data, Vector2i(2, 2))
	var tree := house.get_tree()
	_expect(building_script.storage_space(tree, &"wood") == 4 and building_script.storage_space(tree, &"sand") == 0,
		"a house: room for 4 wood, none for sand")
	_expect(house.stats().find("Wood") == -1, "no long line of stored items above the house")

	# An older save with sand in storage and no ship yet: it can still be taken out at the house.
	inventory.restore({}, {"sand": 2})
	var menu: Node = world.get_node("../StorageMenu") if world.has_node("../StorageMenu") else root.find_child("StorageMenu", true, false)
	_expect(menu != null, "the HUD adds a Storage menu")
	var player: Node2D = world.get_node("Player")
	player.global_position = house.global_position + Vector2(-50, 20)
	var labels: Array = house.actions().map(func(a: Dictionary) -> String: return a.label)
	_expect("Storage" in labels, "the house offers its Storage (%s)" % [labels])
	house.actions().filter(func(a: Dictionary) -> bool: return a.label == "Storage")[0].do.call()
	_expect(menu.visible, "Storage opens the menu")
	var content: Node = menu.get("_content")
	_expect(content.has_node("wood") and content.has_node("sapling") and content.has_node("sand"),
		"the house menu lists wood, saplings, and the sand left over from before")
	content.get_node("sand/Take").pressed.emit()
	await process_frame
	_expect(inventory.count(&"sand") == 1 and inventory.stored(&"sand") == 1, "took 1 sand (the ranger carries 1)")
	inventory.add(wood, 3)
	menu.refresh()  # (the game is paused while it's open: nothing else changes what's carried)
	content = menu.get("_content")
	content.get_node("wood/Store").pressed.emit()
	await process_frame
	_expect(inventory.count(&"wood") == 0 and inventory.stored(&"wood") == 3, "stored 3 wood from the menu")
	menu.close()

	# A ship's cargo hold opens with the Cargo Module: room for 99 of everything, shared with every island.
	var ship: Node2D = build_mode.add_building(ship_data, Vector2i(-30, 30))
	_expect(building_script.storage_space(tree, &"sand") == 0, "no ship hold before the Cargo Module")
	root.get_node("Fleet").restore({"found": ["cargo_module"], "installed": ["cargo_module"]})
	_expect(building_script.storage_space(tree, &"sand") == 99 and building_script.storage_space(tree, &"wood") == 4 + 99,
		"an Exploration Ship's cargo hold: room for 99 of everything, wood too")
	player.global_position = ship.global_position + Vector2(0, 40)
	_expect(ship.actions().any(func(a: Dictionary) -> bool: return a.label == "Storage"), "the ship offers its Storage")
	ship.actions().filter(func(a: Dictionary) -> bool: return a.label == "Storage")[0].do.call()
	content = menu.get("_content")
	_expect(content.has_node("sand") and content.has_node("mud") and content.has_node("wood"),
		"the ship's menu lists everything")
	content.get_node("sand/Store").pressed.emit()
	await process_frame
	_expect(inventory.count(&"sand") == 0 and inventory.stored(&"sand") == 2, "sand stored in the ship")
	_expect(inventory.available(&"sand") == 2, "stored sand can be used for building anywhere")
	menu.close()

	if not _failed:
		print("PASS")
	quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	_failed = _failed or not ok
