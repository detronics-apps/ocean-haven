extends SceneTree
## Full loop: walk to the boat, board, sail into litter (collected), sail back, go ashore.
## Run: godot --headless --path . --script res://tests/test_boat_cleanup.gd

var _world: Node
var _player: Player
var _boat  # untyped: Boat uses autoloads
var _frames := 0
var _step := 0
var _bottle: ItemData = load("res://data/items/plastic_bottle.tres")


func _initialize() -> void:
	_world = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(_world)
	_player = _world.get_node("Player")
	_boat = _world.get_node("Boat")
	# A piece of litter directly south of the boat.
	var d: Node2D = load("res://scenes/world/debris.tscn").instantiate()  # untyped: Debris uses an autoload
	d.set("item", _bottle)
	d.position = _boat.position + Vector2(0, 80)
	_world.add_child(d)
	Input.action_press("move_down")  # walk south from the island centre to the beach


func _physics_process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0 when _frames == 150:  # at the shore
			Input.action_release("move_down")
			_interact()
			_next()
		1 when _frames == 5:
			_expect(_boat.controlled and not _player.visible, "boarded the boat")
			Input.action_press("move_down")
			_next()
		2 when _frames == 60:  # sailed over the litter
			Input.action_release("move_down")
			# Autoload looked up at runtime: --script compiles before autoloads exist.
			_expect(root.get_node("Inventory").count(&"plastic_bottle") == 1, "collected the bottle")
			Input.action_press("move_up")
			_next()
		3 when _frames == 90:  # back against the beach
			Input.action_release("move_up")
			_interact()
			_next()
		4 when _frames == 5:
			var ground: TileMapLayer = _world.get_node("StarterIsland/Ground")
			var data := ground.get_cell_tile_data(ground.local_to_map(ground.to_local(_player.global_position)))
			_expect(_player.visible and not _boat.controlled, "went ashore")
			_expect(data != null and data.get_custom_data("walkable"), "standing on land")
			print("PASS")
			quit(0)
			return true
	return false


func _next() -> void:
	_step += 1
	_frames = 0


func _interact() -> void:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	Input.parse_input_event(e)


func _expect(ok: bool, what: String) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])
	if not ok:
		quit(1)
