class_name ReefPatch
extends Node2D
## A patch of coral reef in the Tropical Reef's lagoon (placed by ReefEcosystem). `coral` (0..1)
## is drawn as how many coral heads stand and how bright they are; low coral is grey rock
## overgrown with green algae. `planted` is how much coral has been planted here (fragments
## the ranger brings by boat, or the lab's restoration team): coral can only grow back as far as
## it's been planted and the reef's conditions allow. Close by, the ranger plants a fragment.

const HEADS := 6
const ROCK := Color(0.55, 0.53, 0.5)
const ALGAE := Color(0.42, 0.55, 0.3)
const CORALS := [Color("f08a8a"), Color("f0c040"), Color("a070d0"), Color("f0a0c8"), Color("60c8c0"), Color("f08a30")]
const REACH := 70.0
## Each fragment planted adds this much to `planted`.
const FRAGMENT := 0.25

var coral := 0.1:
	set(value):
		coral = clampf(value, 0.0, 1.0)
		queue_redraw()
var planted := 0.2:
	set(value):
		planted = clampf(value, 0.0, 1.0)
		queue_redraw()
## Damaged by a hurricane and not yet recovered.
var storm_hit := false


func _enter_tree() -> void:
	add_to_group("reef_patches")
	add_to_group("interactables")


func _ready() -> void:
	z_index = -1


func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > REACH:
		return []
	if planted >= 1.0:
		return [{"label": "Reef patch: fully planted (coral %d%%)" % roundi(coral * 100.0), "do": _explain}]
	if Inventory.available(&"coral_fragment") > 0:
		return [{"label": "Plant coral fragment (coral %d%%)" % roundi(coral * 100.0), "do": plant, "helps": true}]
	return [{"label": "Reef patch (coral %d%%)" % roundi(coral * 100.0), "do": _explain}]


func plant() -> void:
	if not Inventory.use(&"coral_fragment", 1):
		return
	planted += FRAGMENT
	get_tree().call_group("ecosystems", "settle_now")
	get_tree().call_group("hud", "show_toast", "Coral fragment planted. It grows a little each day while the water is clean and parrotfish keep the algae down.")


func _explain() -> void:
	get_tree().call_group("hud", "show_toast", "A coral reef patch (coral %d%%, planted %d%%). Plant coral fragments from a Coral Restoration Site here; coral grows back where the water is clean and parrotfish graze the algae." % [
		roundi(coral * 100.0), roundi(planted * 100.0)])


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(ROCK, 0.35))
	var algae := clampf(0.6 - coral, 0.0, 0.6)
	if algae > 0.0:
		draw_circle(Vector2(2, 2), 13.0, Color(ALGAE, algae))
	var standing := roundi(coral * HEADS)
	for i in HEADS:
		var at := Vector2(cos(i * 1.05) * 9.0, sin(i * 1.05) * 6.0)
		if i >= standing:
			draw_rect(Rect2(at - Vector2(2, 1), Vector2(4, 2)), Color(ROCK, 0.9))  # bare rock
			continue
		var colour: Color = CORALS[i % CORALS.size()]
		draw_rect(Rect2(at + Vector2(-1, -7), Vector2(2, 7)), colour)
		draw_rect(Rect2(at + Vector2(-3, -5), Vector2(2, 2)), colour.lightened(0.15))
		draw_rect(Rect2(at + Vector2(1, -6), Vector2(2, 2)), colour.lightened(0.15))
