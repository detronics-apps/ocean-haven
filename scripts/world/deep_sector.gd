class_name DeepSector
extends Node2D
## One dark area of the Deep Sea (placed by DeepEcosystem). Until it's known, a dark veil lies
## over its deep water: `knowledge` (0..1) grows as the island's instruments listen and watch,
## or fast with a submarine dive. At 100 % the veil lifts and what it holds shows: its habitat
## (whale feeding ground, squid canyon, anglerfish slope, shark ledge, an old shipping lane) and
## any lost fishing gear hidden there. Close by in the boat the ranger can read it and mark it
## for the next submarine dive.

const HABITATS := {
	&"whale_ground": "a sperm whale feeding ground",
	&"squid_canyon": "a deep canyon where giant squid hunt",
	&"angler_slope": "a dark slope where anglerfish live",
	&"shark_ledge": "a ledge where sixgill sharks patrol",
	&"shipping_lane": "an old shipping lane: something big lies on the seabed",
}
const VEIL := Color(0.02, 0.04, 0.12)
const RING := Color(0.75, 0.9, 1.0)

@export var radius := 150.0
var knowledge := 0.0:
	set(value):
		knowledge = clampf(value, 0.0, 1.0)
		queue_redraw()
var habitat: StringName = &"whale_ground"
## Lost fishing gear hidden here (an item id; "" = none) and whether it has surfaced (been found).
var gear_item: StringName = &""
var gear_found := false
## The next submarine dive goes here.
var dive_marked := false:
	set(value):
		dive_marked = value
		queue_redraw()
## Oil from a spill is spreading here.
var oily := false
## Local offsets of the deep-water cells it covers (the veil is drawn on these only).
var cells: Array[Vector2] = []


func _enter_tree() -> void:
	add_to_group("deep_sectors")
	add_to_group("interactables")


func _ready() -> void:
	z_index = -1


func known() -> bool:
	return knowledge >= 1.0


## "Dark area 3" for notes.
func label() -> String:
	return "Dark area %s" % String(name).trim_prefix("Sector")


func describe() -> String:
	return HABITATS.get(habitat, "open deep water")


func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > radius * 0.8:
		return []
	if known():
		return [{"label": "%s: %s" % [label(), describe()], "do": _explain}]
	var list := [{"label": "%s: %d%% known" % [label(), floori(knowledge * 100.0)], "do": _explain}]
	if not dive_marked:
		list.append({"label": "Mark dive", "do": mark_for_dive})
	return list


## The Outpost's next dive goes here (only one area is marked at a time).
func mark_for_dive() -> void:
	for sector: DeepSector in get_tree().get_nodes_in_group("deep_sectors"):
		sector.dive_marked = false
	dive_marked = true
	get_tree().call_group("hud", "show_toast", "%s is marked: the Deep-Ocean Outpost's next submarine dive goes here." % label())


func _explain() -> void:
	if known():
		get_tree().call_group("hud", "show_toast", "%s is mapped: %s.%s" % [label(), describe(),
			" Lost fishing gear was found here: collect it by boat." if gear_item != &"" and gear_found else ""])
	else:
		get_tree().call_group("hud", "show_toast", "%s: nobody knows yet what's down here (%d%% known). Hydrophones and cameras learn a little every day; a submarine dive from the Deep-Ocean Outpost reveals it fast." % [
			label(), floori(knowledge * 100.0)])


func _draw() -> void:
	if not known():
		# Still dark (even when it's nearly known): a veil, an outline and how much is known, so the
		# last unmapped areas are always easy to find.
		var dark := maxf(0.62 * (1.0 - knowledge), 0.28)
		for cell in cells:
			draw_rect(Rect2(cell - Vector2(16, 16), Vector2(32, 32)), Color(VEIL, dark))
		for i in 24:
			var a := TAU * i / 24.0
			draw_arc(Vector2.ZERO, radius * 0.6, a, a + TAU / 48.0, 4, Color(1.0, 0.85, 0.3, 0.7), 2.0)
		var font := ThemeDB.fallback_font
		var text := "%s: %d%% known" % [label(), floori(knowledge * 100.0)]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(font, Vector2(-width / 2.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-width / 2.0, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.92, 0.6))
	if dive_marked:
		draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 48, Color(1.0, 0.85, 0.3, 0.8), 2.0)
	elif known():
		draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 48, Color(RING, 0.25), 1.0)
