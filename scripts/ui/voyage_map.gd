class_name VoyageMap
extends OverlayScreen
## The voyage map: every region of the ocean. With an Expedition Boat you can set
## sail to any region that's unlocked; the voyage fades out and in, and brings the
## ranger (and their rowboat) ashore there.


func _enter_tree() -> void:
	add_to_group("voyage_map")


func _ready() -> void:
	super()
	_title.text = "Voyage map"


func _fill() -> void:
	var can_sail := has_expedition_boat()
	if not can_sail:
		var note := Label.new()
		note.text = "Build an Expedition Boat at your dock to sail to other islands."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(note)
	var here := Regions.nearest(_ranger_position())
	for region: RegionData in Regions.all():
		var locked := Regions.why_locked(get_tree(), region)
		var status := "You are here." if region == here else ("Locked: " + locked if locked else "Ready to visit.")
		var entry := card(null, [region.display_name, region.description, status], locked != "")
		entry.name = "Entry_" + region.id
		if can_sail and not locked and region != here:
			var sail := Button.new()
			sail.name = "Sail"
			sail.text = "Set sail"
			sail.custom_minimum_size = Vector2(120, 48)
			sail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sail.pressed.connect(sail_to.bind(region))
			entry.get_child(0).add_child(sail)
		_content.add_child(entry)


func has_expedition_boat() -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == &"expedition_boat":
			return true
	return false


## Sails to `region`: a fade, then the ranger steps ashore there with their rowboat moored nearby.
func sail_to(region: RegionData) -> void:
	close()
	get_tree().call_group("hud", "voyage", region)


## Moves the ranger and rowboat to `region` straight away (the HUD calls this mid-fade).
static func arrive(tree: SceneTree, region: RegionData) -> void:
	var player: Player = tree.get_first_node_in_group("player")
	var boat: Boat = tree.get_first_node_in_group("boat")
	if boat.controlled:
		boat.restore_ashore()
	player.global_position = region.arrival
	boat.global_position = region.boat_mooring
	player.stop()
	boat.stop()


func _ranger_position() -> Vector2:
	var ranger := ControlledBody.active(get_tree())
	return ranger.global_position if ranger else Vector2.ZERO
