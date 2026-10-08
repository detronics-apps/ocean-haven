class_name VoyageMap
extends OverlayScreen
## The Map: every region of the ocean. You can sail to any island you've discovered
## (the voyage fades out and in, and brings the ranger and their rowboat ashore there).
## Undiscovered islands are shown but can't be chosen: they're found by exploring
## warmer or colder with the Exploration Ship (see ExploreMenu). The Map answers just two
## questions: discovered? (greyed out if not) and has an Exploration Ship? (a compass). The
## islands are listed coldest first (the Polar Ocean at the top, the Tropical Reef at the bottom).
## Everything else (levels, upgrades) belongs in the ship's own screen.

const COMPASS := preload("res://assets/ui/compass.svg")


func _enter_tree() -> void:
	add_to_group("voyage_map")


func _ready() -> void:
	super()
	_title.text = "Map"


func _fill() -> void:
	if ObservatoryScreen.is_open_to_ranger():  # the whole ocean, once the fleet has all six
		var observatory := BuildMode._big_button("Global Ocean Observatory", Color("2a78a8"))
		observatory.name = "Observatory"
		observatory.pressed.connect(func() -> void:
			close()
			get_tree().call_group("observatory", "open"))
		_content.add_child(observatory)
	var here := Regions.nearest(_ranger_position())
	for region: RegionData in Regions.coldest_first():
		var known := Regions.is_discovered(region)
		var lines: Array[String] = [region.display_name, region.description if known else region.theme]
		if region == here:
			lines.append("You are here.")
		elif region.in_development:
			lines.append("Still under development.")
		elif not known:
			lines.append("Not discovered yet.")
		var entry := card(region.map_icon, lines)
		entry.name = "Entry_" + region.id
		if not known:
			entry.modulate = Color(0.55, 0.58, 0.62, 0.8)  # greyed out
		if Regions.exploration_ready(get_tree(), region):
			var compass := TextureRect.new()
			compass.name = "Compass"
			compass.texture = COMPASS
			compass.custom_minimum_size = Vector2(32, 32)
			compass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			compass.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			compass.tooltip_text = "Has an Exploration Ship"
			entry.get_child(0).add_child(compass)
		if known and region != here and not region.in_development:
			var sail := Button.new()
			sail.name = "Sail"
			sail.text = "Set sail"
			sail.custom_minimum_size = Vector2(120, 48)
			sail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sail.pressed.connect(sail_to.bind(region))
			entry.get_child(0).add_child(sail)
		_content.add_child(entry)


## Sails to `region`: a fade, then the ranger steps ashore there (its own rowboat is moored nearby).
func sail_to(region: RegionData) -> void:
	close()
	get_tree().call_group("hud", "voyage", region)


## Moves the ranger to `region` straight away (the HUD calls this mid-fade).
static func arrive(tree: SceneTree, region: RegionData) -> void:
	var player: Player = tree.get_first_node_in_group("player")
	# Nothing sails along: every island has its own rowboat(s), which stay where they were left.
	for any: Boat in tree.get_nodes_in_group("boat"):
		if any.controlled:
			any.restore_ashore()
			any.stop()
	player.global_position = region.arrival
	player.stop()
	# The first visit: the island has had nobody looking after it, so litter is everywhere.
	var first_visit := StringName("arrived_%s" % region.id)
	if region.direction != &"" and region.arrival_litter > 0 and not Fleet.has_flag(first_visit):
		Fleet.mark(first_visit)
		for spawner: LitterSpawner in tree.get_nodes_in_group("litter_spawner"):
			if Regions.nearest(spawner.area.get_center()) == region:
				spawner.fill(region.arrival_litter)
		# Say what this island is about and what to do here (the objective line keeps the pointer).
		tree.call_group("hud", "show_toast", "First visit: %s" % region.display_name)


func _ranger_position() -> Vector2:
	var ranger := ControlledBody.active(get_tree())
	return ranger.global_position if ranger else Vector2.ZERO
