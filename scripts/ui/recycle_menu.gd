class_name RecycleMenu
extends OverlayScreen
## A recycling centre's screen (opened from the building): how much of the litter the ranger
## carries to recycle into funding (25 / 50 / 75 / 100 %), so they can keep some for building
## (tents, Ranger Houses and recycling centres cost litter).

const SHARES := [25, 50, 75, 100]

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


func _recycle(percent: int) -> void:
	_centre.recycle(pieces_for(percent))
	close()
