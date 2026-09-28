class_name MissionMenu
extends OverlayScreen
## A signature facility's screen (opened from the building): the island's health, the
## mission that's out, and the missions it can send for funding (see Missions).


func _enter_tree() -> void:
	add_to_group("mission_menu")


func _ready() -> void:
	super()
	_title.text = "Missions"


func _fill() -> void:
	var station := _station()
	var region := Regions.nearest(station.global_position) if station else Regions.all()[0]
	if station:
		_title.text = station.data.display_name
	var health := IslandHealth.of(get_tree(), region)
	var status := Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "%s health: %d%%. Funding: %d." % [region.display_name, roundi(maxf(health, 0.0) * 100.0), Funding.balance]
	if Missions.active:
		status.text += "\nYour %s is out, back at %s." % [Missions.active.display_name.to_lower(), Missions.back_time()]
	else:
		status.text += "\nSend a mission. It's back in a few hours, and what it finds is marked on your minimap for the rest of the day."
	_content.add_child(status)
	if not station:
		return
	for mission: MissionData in Missions.offered_by(station.data.id):
		var problem := Missions.problem(mission)
		var lines: Array[String] = [mission.display_name, mission.description,
			"Costs %d funding. Back in %d hours." % [mission.cost, roundi(mission.hours)]]
		var entry := card(null, lines)
		entry.name = "Mission_" + mission.id
		var send := BuildMode._big_button("Send", Color("3f8a4a"))
		send.name = "Send"
		send.disabled = problem != ""
		send.tooltip_text = problem
		send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		send.pressed.connect(_send.bind(mission, region))
		entry.get_child(0).add_child(send)
		_content.add_child(entry)


func _send(mission: MissionData, region: RegionData) -> void:
	if Missions.send(mission, region):
		close()


## The signature facility the ranger is at (the nearest one that sends missions).
func _station() -> Building:
	var ranger := ControlledBody.active(get_tree())
	var best: Building = null
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"missions" and (not best or not ranger
				or building.global_position.distance_to(ranger.global_position)
				< best.global_position.distance_to(ranger.global_position)):
			best = building
	return best
