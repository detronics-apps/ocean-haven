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
		status.text += "\nYour %s is out, back in %s." % [Missions.active.display_name.to_lower(), Missions.time_left()]
	else:
		status.text += "\nSend a mission: it's back in a few minutes and responds to what's happening on the island."
	for effect: StringName in [&"boat_patrol", &"dolphin_tracking"]:
		if Missions.is_on(effect):
			status.text += "\n%s: going on for %s more." % ["Boat patrol" if effect == &"boat_patrol" else "Visiting dolphin",
				Missions.real_time((Missions._until[effect] - GameClock.now()) * GameClock.DAY_LENGTH)]
	_content.add_child(status)
	if station and station.data.guide != "":
		var guide := card(null, ["How it works", station.data.guide])
		guide.name = "Guide"
		_content.add_child(guide)
	if Missions.last_report != "" and not Missions.active:
		var last := card(null, ["Last report", Missions.last_report])
		last.name = "LastReport"
		_content.add_child(last)
	if not station:
		return
	for mission: MissionData in Missions.offered_by(station.data.id):
		var problem := Missions.problem(mission)
		var lines: Array[String] = [mission.display_name, mission.description,
			"Costs %d funding. Back in %s." % [mission.cost, Missions.real_time(mission.minutes * 60.0)],
			_times_text(Missions.times_done(mission, region))]
		if problem != "":
			lines.append(problem)  # (no tooltips on a phone)
		var entry := card(mission.icon, lines)
		entry.name = "Mission_" + mission.id
		var send := BuildMode._big_button("Send", Color("3f8a4a"))
		send.name = "Send"
		send.disabled = problem != ""
		send.tooltip_text = problem
		send.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		send.pressed.connect(_send.bind(mission, region))
		entry.get_child(0).add_child(send)
		_content.add_child(entry)


static func _times_text(times: int) -> String:
	match times:
		0:
			return "Not run yet."
		1:
			return "Run once so far."
	return "Run %d times so far." % times


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
