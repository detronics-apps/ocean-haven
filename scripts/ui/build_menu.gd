extends OverlayScreen
## Build menu: everything in data/buildings/ — what you can build now (with its
## cost), and what's coming later. Choosing one starts placing it.


func _enter_tree() -> void:
	add_to_group("build_menu")


func _ready() -> void:
	super()
	_title.text = "Build"


func _fill() -> void:
	_title.text = "Build    (Funding: %d)" % Funding.balance
	var all := DataFiles.load_all("res://data/buildings")
	all.sort_custom(func(a: BuildingData, b: BuildingData) -> bool: return a.order < b.order)
	for data: BuildingData in all:
		_content.add_child(_entry(data))


func _entry(data: BuildingData) -> Control:
	var status: String
	var can_build := false
	if data.locked:
		status = "Coming later: " + data.unlock_hint
	elif data.unique and _exists(data.id):
		status = "Already built."
	elif data.requires and not _exists(data.requires):
		status = "Build a %s first." % data.requires
	else:
		can_build = Inventory.total() >= data.cost_litter and Funding.balance >= data.cost_funding
		status = _cost_text(data) + ("" if can_build else "  (you have %d litter, %d funding)" % [
			Inventory.total(), Funding.balance])
	if data.replaces and not data.locked:
		status += "  Replaces your %s." % data.replaces
	var entry := card(data.texture, [data.display_name, data.description, status], data.locked)
	entry.name = "Entry_" + data.id
	if can_build:
		var build := Button.new()
		build.name = "Build"
		build.text = "Build"
		build.custom_minimum_size = Vector2(96, 48)
		build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		build.pressed.connect(_choose.bind(data))
		entry.get_child(0).add_child(build)
	return entry


static func _cost_text(data: BuildingData) -> String:
	var parts: Array[String] = []
	if data.cost_funding > 0:
		parts.append("%d funding" % data.cost_funding)
	if data.cost_litter > 0:
		parts.append("%d recycled litter" % data.cost_litter)
	return "Needs " + " + ".join(parts) + "." if parts else "Free to build."


func _choose(data: BuildingData) -> void:
	close()
	get_tree().call_group("build_mode", "start", data)


func _exists(id: StringName) -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == id:
			return true
	return false
