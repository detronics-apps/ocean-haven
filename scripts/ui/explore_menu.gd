class_name ExploreMenu
extends OverlayScreen
## The Exploration Ship's screen (only opened from the ship itself, never from the Map):
## the fleet's equipment (install island discoveries to upgrade every ship), and explore
## warmer or colder. Each finds the island next to the ship's own island that way
## (Regions.next_from), once the fleet has the upgrade it needs (RegionData.requires); it's then
## discovered for good (the Map can sail there from then on). To explore on beyond it,
## establish an Exploration Ship on it.


func _enter_tree() -> void:
	add_to_group("explore_menu")


func _ready() -> void:
	super()
	_title.text = "Exploration Ship"


func _fill() -> void:
	_content.add_child(_equipment_card())
	var note := Label.new()
	note.text = "Where shall we explore? You'll find out what's there when you arrive."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(note)
	for direction in [Regions.WARMER, Regions.COLDER]:
		var next := next_island(direction)
		var found := next != null and Regions.is_discovered(next)
		var needs := Fleet.missing_for(next) if next and not found else null
		var help_first := next != null and not found and needs == null and not Regions.can_find_more()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var button := BuildMode._big_button("Explore %s" % direction, Color("2a78a8") if direction == Regions.COLDER else Color("c9772e"))
		button.name = "Explore" + direction.capitalize()
		button.disabled = next == null or found or needs != null or help_first or next.in_development
		button.pressed.connect(explore.bind(direction))
		row.add_child(button)
		var hint := Label.new()
		if not next:
			hint.text = "No more islands lie in %s waters from here." % direction
		elif found:
			hint.text = "The %s lies that way: you've found it already. Sail there with the Map, and establish its own Exploration Ship to explore beyond it." % next.display_name
		elif help_first:
			hint.text = "First help the islands you've already found: you've found %d and the fleet is Level %d. Finish an island's objective and install its discovery at a ship to explore one island further." % [
				Regions.discovered_count(), Fleet.level()]
		elif next.in_development and needs:
			hint.text = "To find the way into %s waters, the fleet will need %s (from the %s). The next island that way, the %s, is still under development." % [
				direction, needs.upgrade_name, needs.display_name, next.display_name]
		elif next.in_development:
			hint.text = "You've done everything needed to explore %s waters! The next island, the %s, is still under development: it arrives in a future update." % [
				direction, next.display_name]
		elif needs:
			hint.text = "To find the way into %s waters, the fleet needs %s (from the %s). Restore the islands you've found to find it." % [
				direction, needs.upgrade_name, needs.display_name]
		else:
			hint.text = "Sail into %s waters to discover a new island." % direction
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint)
		_content.add_child(row)


## Current equipment level, what it can do, and the next upgrade (with an Upgrade button
## once its discovery has been found).
func _equipment_card() -> Control:
	var level := Fleet.level()
	var ship: BuildingData = load("res://data/buildings/expedition_boat.tres")
	var picture := ship.fleet_textures[mini(level, ship.fleet_textures.size()) - 1] if level > 0 else ship.texture
	var lines: Array[String] = ["Current equipment: Level %d" % level]
	var can := Fleet.installed().map(func(d: DiscoveryData) -> String: return d.capability)
	lines.append("Every ship in your fleet can " + ", ".join(can) + "." if can
		else "A basic ship. Install a discovery to upgrade the whole fleet.")
	var next: DiscoveryData = Fleet.ready_to_install().front() if Fleet.ready_to_install() else null
	if next:
		lines.append("Next upgrade: %s\nRequired: %s - found!" % [next.upgrade_name, next.display_name])
	else:
		lines.append("Next upgrade: complete an island's objective to find its discovery.")
	var entry := card(picture, lines)
	entry.name = "Equipment"
	if next:
		var upgrade := BuildMode._big_button("Upgrade", Color("3f8a4a"))
		upgrade.name = "Upgrade"
		upgrade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		upgrade.pressed.connect(install.bind(next))
		entry.get_child(0).add_child(upgrade)
	return entry


## Installs `discovery`: every ship is upgraded.
func install(discovery: DiscoveryData) -> void:
	Fleet.install(discovery.id)
	refresh.call_deferred()  # not while its own Upgrade button is still being pressed
	get_tree().call_group("hud", "show_toast", "Fleet upgraded to Level %d: %s!\nEvery ship can now %s." % [
		Fleet.level(), discovery.upgrade_name, discovery.capability])


## The island next to the ranger's (where this ship is) in `direction`.
func next_island(direction: StringName) -> RegionData:
	var ranger := ControlledBody.active(get_tree())
	return Regions.next_from(Regions.nearest(ranger.global_position if ranger else Vector2.ZERO), direction)


## Discovers the island next to this one in `direction` and sails there.
func explore(direction: StringName) -> void:
	var region := next_island(direction)
	if not region or Regions.is_discovered(region) or Fleet.missing_for(region) or region.in_development \
			or not Regions.can_find_more():
		return
	close()
	Regions.discover(region)
	get_tree().call_group("hud", "voyage", region, true)
