extends OverlayScreen
## Build menu: everything in data/buildings/ — what you can build now (with its
## cost), and what's coming later. Choosing one starts placing it.


func _enter_tree() -> void:
	add_to_group("build_menu")


## Tabs: label -> BuildingData.category ("" = everything).
const TABS := {"All": &"", "Buildings": &"buildings", "Land": &"land", "Sea": &"sea"}

var _tab: StringName = &""
## "You have: ..." next to the tabs.
var _have: Label


func _ready() -> void:
	super()
	_title.text = "Build"
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for label: String in TABS:
		var tab := Button.new()
		tab.name = "Tab" + label
		tab.text = label
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = TABS[label] == _tab
		tab.custom_minimum_size = Vector2(96, 44)
		tab.pressed.connect(func() -> void:
			_tab = TABS[label]
			refresh())
		tabs.add_child(tab)
	_have = Label.new()
	_have.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_have.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tabs.add_child(_have)
	_page.add_child(tabs)
	_page.move_child(tabs, 1)  # under the title


func _fill() -> void:
	# What you have, once, at the top (wood and saplings include what's stored).
	_have.text = "You have: %d funding, %d litter, %d wood, %d saplings" % [
		Funding.balance, Inventory.total(), Inventory.available(&"wood"), Inventory.available(&"sapling")]
	var all := DataFiles.load_all("res://data/buildings")
	all.sort_custom(func(a: BuildingData, b: BuildingData) -> bool: return a.order < b.order)
	for data: BuildingData in all:
		if _tab == &"" or data.category == _tab:
			_content.add_child(_entry(data))


func _entry(data: BuildingData) -> Control:
	var status: String
	var can_build := false
	if data.tool:
		status = "A tool: pick it up to use it, then tap Done."
		can_build = true
	elif data.locked:
		status = "Coming later: " + data.unlock_hint
	elif data.unique and _exists(data.id):
		status = "Already built."
	elif get_tree().get_first_node_in_group("build_mode").at_limit(data):
		status = "You've built as many as you can (%d)." % data.max_count
	elif data.requires and not _exists(data.requires):
		status = "Build a %s first." % data.requires
	else:
		can_build = get_tree().get_first_node_in_group("build_mode").can_afford(data)
		status = data.cost_text()
	if data.replaces and not data.locked:
		status += "  Replaces your %s." % data.replaces
	var entry := card(data.texture, [data.display_name, data.description, status], data.locked)
	entry.name = "Entry_" + data.id
	if can_build:
		var build := Button.new()
		build.name = "Build"
		build.text = "Pick up" if data.tool else "Build"
		build.custom_minimum_size = Vector2(96, 48)
		build.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		build.pressed.connect(_choose.bind(data))
		entry.get_child(0).add_child(build)
	return entry


func _choose(data: BuildingData) -> void:
	close()
	if data.tool == &"shovel":
		get_tree().call_group("sand_shovel", "start")
	else:
		get_tree().call_group("build_mode", "start", data)


func _exists(id: StringName) -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == id:
			return true
	return false
