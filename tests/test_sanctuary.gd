extends SceneTree
## Building the turtle protection area: refused with too little litter, then built
## with enough — litter is used up and a new turtle arrives.
## Run: godot --headless --path . --script res://tests/test_sanctuary.gd

var _world: Node
var _site: Node2D  # untyped: BuildSite uses autoloads
var _inventory: Node
var _frames := 0
var _bottle: ItemData = load("res://data/items/plastic_bottle.tres")
var _bag: ItemData = load("res://data/items/plastic_bag.tres")


func _initialize() -> void:
	_world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(_world)
	_site = _world.get_node("TurtleSanctuarySite")
	_inventory = root.get_node("Inventory")
	# Ranger walks up to the site.
	(_world.get_node("Player") as Node2D).global_position = _site.global_position + Vector2(0, 24)
	_inventory.add(_bottle, 3)


func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_interact()
	elif _frames == 10:
		if _site.is_built:
			return _fail("built with only 3 litter")
		_inventory.add(_bag, 2)
		_interact()
	elif _frames == 15:
		if not _site.is_built:
			return _fail("not built with 5 litter")
		if _inventory.total() != 0:
			return _fail("litter not used up (%d left)" % _inventory.total())
		if _count_animals() != 2:
			return _fail("expected a second turtle, found %d animals" % _count_animals())
		print("PASS")
		quit(0)
		return true
	return false


func _count_animals() -> int:
	var n := 0
	for child in _world.get_children():
		var script: Script = child.get_script()
		if script and script.resource_path == "res://scripts/animals/animal.gd":
			n += 1
	return n


func _interact() -> void:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)


func _fail(why: String) -> bool:
	printerr("FAIL: " + why)
	quit(1)
	return true
