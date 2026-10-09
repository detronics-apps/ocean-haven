class_name RecycleMenu
extends OverlayScreen
## A recycling centre's screen (opened from the building): how much of the litter the ranger
## carries to recycle into funding (25 / 50 / 75 / 100 %), so they can keep some for building
## (tents, Ranger Houses and recycling centres cost litter). Under that, every kind of litter:
## how much the ranger has picked up and carries, and whether it has been stopped at its source
## (no more of it drifts in on any island: Fleet.stopped_by), or still washes in.

const SHARES := [25, 50, 75, 100]
## Every kind of litter, and the microfibres (in the water, never picked up).
const KINDS: Array[StringName] = [&"plastic_bottle", &"plastic_bag", &"six_pack_rings", &"foam_box", &"fishing_line", &"ghost_net"]
const STOPPED := Color("7fe0a0")
const WASHING_IN := Color("ffd27a")

var _centre: Building


func _enter_tree() -> void:
	add_to_group("recycle_menu")


func _ready() -> void:
	super()
	_title.text = "Recycling"


## Opens for `centre`.
func open_for(centre: Building) -> void:
	_centre = centre
	open()


## How many pieces `percent` of the carried litter is (at least 1 while there is any).
static func pieces_for(percent: int) -> int:
	var carried := Inventory.total()
	return mini(carried, maxi(ceili(carried * percent / 100.0), 1)) if carried > 0 else 0


func _fill() -> void:
	if not is_instance_valid(_centre):
		return
	_title.text = _centre.data.display_name
	var carried := Inventory.total()
	var status := Label.new()
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "You carry %d piece(s) of litter; each recycles into %d funding. Keep some if you want to build a tent, a Ranger House or a recycling centre: they're built with litter." % [carried, _centre.recycle_value()]
	_content.add_child(status)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	_content.add_child(row)
	for percent: int in SHARES:
		var n := pieces_for(percent)
		var button := BuildMode._big_button("%d%%\n%d litter, +%d" % [percent, n, n * _centre.recycle_value()], Color("3f8a4a"))
		button.name = "Recycle%d" % percent
		button.custom_minimum_size = Vector2(150, 88)
		button.disabled = n <= 0
		button.pressed.connect(_recycle.bind(percent))
		row.add_child(button)
	_add_stats()


## The litter table: picture, kind, picked up ever, carried now, stopped or still washing in.
func _add_stats() -> void:
	var heading := Label.new()
	heading.name = "StatsHeading"
	heading.text = "Your litter so far: %d picked up in all" % Inventory.litter_collected
	heading.add_theme_font_size_override("font_size", 20)
	_content.add_child(heading)
	var stopped := 0
	var table := GridContainer.new()
	table.name = "Stats"
	table.columns = 4
	table.add_theme_constant_override("h_separation", 14)
	table.add_theme_constant_override("v_separation", 6)
	_content.add_child(table)
	for id: StringName in KINDS:
		var item: ItemData = DataFiles.res("res://data/items/%s.tres" % id)
		var picture := TextureRect.new()
		picture.texture = item.icon
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(36, 36)
		table.add_child(picture)
		var name_label := Label.new()
		name_label.text = item.display_name
		table.add_child(name_label)
		var counts := Label.new()
		counts.name = "Count_%s" % id
		counts.text = "%d picked up, %d carried" % [int(Inventory.picked.get(id, 0)), Inventory.count(id)]
		table.add_child(counts)
		table.add_child(_status(id))
		if Fleet.stopped(id):
			stopped += 1
	# The microfibres: not litter you can pick up, but stopped at their source too.
	table.add_child(Control.new())
	var fibres := Label.new()
	fibres.text = "Microfibres"
	table.add_child(fibres)
	var where := Label.new()
	where.text = "too small to pick up"
	table.add_child(where)
	table.add_child(_status(&"microfibres"))
	if Fleet.stopped(&"microfibres"):
		stopped += 1
	var summary := Label.new()
	summary.name = "StatsSummary"
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "Stopped at the source: %d of %d. Litter that's stopped never drifts in again, on any island." % [stopped, KINDS.size() + 1] \
		if stopped < KINDS.size() + 1 else "Every kind of litter is stopped at its source. The whole ocean is getting cleaner!"
	_content.add_child(summary)


func _status(id: StringName) -> Label:
	var label := Label.new()
	label.name = "Status_%s" % id
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	var by := Fleet.stopped_by(id)
	label.text = "Stopped at its source by %s" % by if by != "" else "Still washing in"
	label.add_theme_color_override("font_color", STOPPED if by != "" else WASHING_IN)
	return label


func _recycle(percent: int) -> void:
	_centre.recycle(pieces_for(percent))
	close()
