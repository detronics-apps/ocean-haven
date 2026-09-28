class_name ExploreMenu
extends OverlayScreen
## The Exploration Ship's menu (only opened from the ship itself, never from the Map):
## explore warmer or colder. Each finds the next undiscovered island that way, which
## is then discovered for good (the Map can sail there from then on) and gets its own
## Exploration Ship moored by the shore, to explore on from there.

const SHIP := "res://data/buildings/expedition_boat.tres"


func _enter_tree() -> void:
	add_to_group("explore_menu")


func _ready() -> void:
	super()
	_title.text = "Exploration Ship"


func _fill() -> void:
	var note := Label.new()
	note.text = "Where shall we explore? You'll find out what's there when you arrive."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	for direction in [Regions.WARMER, Regions.COLDER]:
		var next := Regions.next_undiscovered(direction)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var button := BuildMode._big_button("Explore %s" % direction, Color("2a78a8") if direction == Regions.COLDER else Color("c9772e"))
		button.name = "Explore" + direction.capitalize()
		button.disabled = next == null
		button.pressed.connect(explore.bind(direction))
		row.add_child(button)
		var hint := Label.new()
		hint.text = "Sail into %s waters to discover a new island." % direction if next \
			else "You've discovered every island in the %s waters." % direction
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint)
		_content.add_child(row)


## Discovers the next island `direction`, moors a ship there, and sails there.
func explore(direction: StringName) -> void:
	var region := Regions.next_undiscovered(direction)
	if not region:
		return
	close()
	Regions.discover(region)
	moor_ship(get_tree(), region)
	get_tree().call_group("hud", "voyage", region, true)


## Adds an Exploration Ship in the shallows by the island's landing spot (if it hasn't one).
static func moor_ship(tree: SceneTree, region: RegionData) -> void:
	for building: Building in tree.get_nodes_in_group("buildings"):
		if building.data.id == &"expedition_boat" and building.global_position.distance_to(region.center) < region.waters_radius:
			return
	var data: BuildingData = load(SHIP)
	var mooring := Terrain.cell_of(region.boat_mooring)
	for ring in range(1, 6):  # nearest spot all in water, not on the rowboat's mooring
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				var cell := mooring + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == ring and _ship_fits(tree, data, cell, mooring):
					tree.get_first_node_in_group("build_mode").add_building(data, cell)
					return


static func _ship_fits(tree: SceneTree, data: BuildingData, cell: Vector2i, mooring: Vector2i) -> bool:
	var footprint := Rect2i(cell, data.size)
	if footprint.has_point(mooring):
		return false
	for x in data.size.x:
		for y in data.size.y:
			if Terrain.at(tree, Terrain.centre_of(cell + Vector2i(x, y))) not in data.terrain:
				return false
	return true
