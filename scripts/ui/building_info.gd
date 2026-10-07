class_name BuildingInfo
extends OverlayScreen
## "What is this?" on any building: its picture, what it's for (BuildingData.description), how
## it's doing (Building.stats) and a real-life fact. Opened from the building's actions.

var _building: Building


func _enter_tree() -> void:
	add_to_group("building_info")


func open_for(building: Building) -> void:
	_building = building
	open()


func _fill() -> void:
	if not is_instance_valid(_building):
		_title.text = "Building"
		return
	var data := _building.data
	_title.text = data.display_name
	var picture: Texture2D = data.tier_textures[clampi(_building.tier, 1, data.tier_textures.size()) - 1] if not data.tier_textures.is_empty() else data.texture
	var lines: Array[String] = ["What it's for", data.description]
	var stats := _building.stats()
	if stats != "":
		lines.append(stats)
	_content.add_child(card(picture, lines, false, true))
	if data.fact != "":
		var fact: Array[String] = ["In real life", data.fact]
		_content.add_child(card(null, fact))
