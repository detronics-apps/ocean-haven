class_name ExploreMenu
extends OverlayScreen
## The Exploration Ship's menu (only opened from the ship itself, never from the Map):
## explore warmer or colder. Each finds the next undiscovered island that way, which is
## then discovered for good (the Map can sail there from then on). To explore on from
## there, establish an Exploration Ship on it (that makes it Exploration Ready, and
## raises your Exploration Level: one per ship).


func _enter_tree() -> void:
	add_to_group("explore_menu")


func _ready() -> void:
	super()
	_title.text = "Exploration Ship"


func _fill() -> void:
	var level := Regions.exploration_level(get_tree())
	var note := Label.new()
	note.text = "Exploration Level %d: %s. Where shall we explore? You'll find out what's there when you arrive." % [
		level, "one ship" if level == 1 else "a network of %d ships" % level]
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


## Discovers the next island `direction` and sails there.
func explore(direction: StringName) -> void:
	var region := Regions.next_undiscovered(direction)
	if not region:
		return
	close()
	Regions.discover(region)
	get_tree().call_group("hud", "voyage", region, true)
