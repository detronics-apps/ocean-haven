extends SceneTree
## Renders the home page's picture (web/screenshot.png): the Starting Island as a new game
## starts (its litter, muted colours, one of each animal, the booby still tangled), Maya and Tom
## at their places, framed so it all shows; no HUD. Never the player's save. Needs a screen:
##   xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/make_home_picture.gd

## Where the picture is centred (world), and how far it's zoomed in.
const CENTRE := Vector2(30, 160)
const ZOOM := 1.2


func _initialize() -> void:
	await process_frame
	var world: Node = load("res://scenes/world/ocean_world.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await process_frame
	for layer in world.get_children():
		if layer is CanvasLayer:
			layer.visible = false
	await process_frame
	var ranger: Node2D = world.find_child("Player", true, false)
	_place(ranger, Vector2(-130, 230), ["sand"])
	_place(world.find_child("Boat", true, false), Vector2(-70, 260), ["water"])
	var kinds := {}
	for animal: Node2D in get_nodes_in_group("animals"):
		if animal.get("data") and load("res://scripts/world/regions.gd").nearest(animal.global_position).id == &"home_island":
			kinds[animal.data.id] = animal
	var spots := {
		&"green_turtle": [Vector2(40, 280)],
		&"bottlenose_dolphin": [Vector2(455, 330)],
		&"ghost_crab": [Vector2(170, 290)],
	}
	for id: StringName in spots:
		var animal: Node2D = kinds.get(id)
		if not animal:
			push_warning("no %s on the Starting Island" % id)
			continue
		var places: Array = spots[id]
		for i in places.size():
			var one: Node2D = animal if i == 0 else animal.duplicate()
			if i > 0:
				animal.get_parent().add_child(one)
			var on: Array = ["sand"] if id == &"ghost_crab" else ([] if id == &"red_footed_booby" else ["water"])
			_place(one, places[i], on)
			one.set("underwater", false)
			var sprite := one.get_node_or_null("Sprite2D") as CanvasItem
			if sprite:
				sprite.modulate.a = 1.0
			one.set("unborn", false)
			one.visible = true
	await process_frame
	for label in world.find_children("*", "Label", true, false):
		if not label.get_parent() is CanvasLayer and not _in_layer(label):
			label.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED  # everything holds still for the picture
	var camera := Camera2D.new()
	camera.position = CENTRE
	camera.zoom = Vector2.ONE * ZOOM
	root.add_child(camera)
	camera.make_current()
	for i in 4:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://web/screenshot.png")
	print("web/screenshot.png %dx%d" % [image.get_width(), image.get_height()])
	quit()


## Puts `node` at the nearest tile of one of `kinds` to `at` (anywhere if `kinds` is empty).
func _place(node: Node2D, at: Vector2, kinds: Array) -> void:
	if not node:
		return
	node.global_position = at if kinds.is_empty() else load("res://scripts/world/terrain.gd").nearest(self, at, kinds) + (at - load("res://scripts/world/terrain.gd").nearest(self, at, kinds)).limit_length(10.0)
	if node.has_method("stop"):
		node.call("stop")


func _in_layer(node: Node) -> bool:
	while node:
		if node is CanvasLayer:
			return true
		node = node.get_parent()
	return false
