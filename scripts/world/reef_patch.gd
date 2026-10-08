class_name ReefPatch
extends Node2D
## A patch of coral reef in the Tropical Reef's lagoon (placed by ReefEcosystem). `coral` (0..1)
## is drawn as how many coral heads stand and how bright they are; low coral is grey rock
## overgrown with green algae. `planted` is how much coral has been planted here (fragments
## the ranger brings by boat, or the lab's restoration team): coral can only grow back as far as
## it's been planted and the reef's conditions allow. Close by, the ranger plants a fragment.
## A patch at full coral can be split: it drops to SPLIT_TO and a new patch with as much starts
## on free shallow water beside it (less coral in all: the cost of spreading the reef). Any
## patch can be moved: towed behind the boat and set down on free shallow water.

const HEADS := 6
const ROCK := Color(0.55, 0.53, 0.5)
const ALGAE := Color(0.42, 0.55, 0.3)
const CORALS := [Color("f08a8a"), Color("f0c040"), Color("a070d0"), Color("f0a0c8"), Color("60c8c0"), Color("f08a30")]
const REACH := 70.0
## Each fragment planted adds this much to `planted`.
const FRAGMENT := 0.25
## A full patch splits into two of this much coral (and planting) each.
const SPLIT_TO := 0.35
## Full enough to split.
const FULL := 0.99

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
## Being moved: it follows the ranger's boat until set down.
var carried := false


func _enter_tree() -> void:
	add_to_group("reef_patches")
	add_to_group("interactables")


func _ready() -> void:
	z_index = -1


func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if carried:
		if _reef().spot_free(global_position, self):
			return [{"label": "Put down", "do": set_down, "helps": true}]
		return [{"label": "Can't put it here", "do": _explain_spot}]
	if not ranger or ranger.global_position.distance_to(global_position) > REACH:
		return []
	var list := []
	if coral >= FULL:
		list.append({"label": "Split", "do": split, "helps": true})
	if planted >= 1.0:
		list.append({"label": "Reef patch %d%%" % roundi(coral * 100.0), "do": _explain})
	elif Inventory.available(&"coral_fragment") > 0:
		list.append({"label": "Plant coral (%d%%)" % roundi(coral * 100.0), "do": plant, "helps": true})
	else:
		list.append({"label": "Reef patch %d%%" % roundi(coral * 100.0), "do": _explain})
	if ranger is Boat and not _reef().carrying():
		list.append({"label": "Move", "do": pick_up})
	return list


func _reef() -> ReefEcosystem:
	return get_parent() as ReefEcosystem


## Splits a full patch: this one drops to SPLIT_TO and a new one with as much starts on the
## nearest free shallow water around it. Returns the new patch (null: no room, or the reef is
## as big as it gets).
func split() -> ReefPatch:
	if coral < FULL:
		return null
	var reef := _reef()
	if reef.patches().size() >= reef.max_patches:
		get_tree().call_group("hud", "show_toast", "The reef is as big as it can get here (%d patches)." % reef.max_patches)
		return null
	var spot: Variant = reef.free_spot_near(global_position)
	if spot == null:
		get_tree().call_group("hud", "show_toast", "No free shallow water around this patch to split it onto: move it, or another patch, first.")
		return null
	coral = SPLIT_TO
	planted = SPLIT_TO
	var fresh := reef.add_patch(spot, SPLIT_TO, SPLIT_TO)
	get_tree().call_group("hud", "show_toast", "Split: 2 patches of %d%%" % roundi(SPLIT_TO * 100.0))
	return fresh


## Picks it up to move it: it follows the boat until set down on free shallow water.
func pick_up() -> void:
	carried = true
	z_index = 1
	get_tree().call_group("hud", "show_toast", "Sail to free shallow water and set the reef patch down.")


func set_down() -> void:
	if not _reef().spot_free(global_position, self):
		return
	carried = false
	z_index = -1
	get_tree().call_group("ecosystems", "settle_now")


func _process(_delta: float) -> void:
	if not carried:
		return
	var ranger := ControlledBody.active(get_tree())
	if ranger is Boat:
		global_position = ranger.global_position + Vector2(0, 28)  # towed just behind the boat
	else:
		carried = false  # (left the boat: it settles where it is)
		z_index = -1


func _explain_spot() -> void:
	get_tree().call_group("hud", "show_toast", "A reef patch needs free shallow water")


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
		var colour: Color = CORALS[(i + absi(String(name).hash())) % CORALS.size()]  # (each patch its own mix)
		draw_rect(Rect2(at + Vector2(-1, -7), Vector2(2, 7)), colour)
		draw_rect(Rect2(at + Vector2(-3, -5), Vector2(2, 2)), colour.lightened(0.15))
		draw_rect(Rect2(at + Vector2(1, -6), Vector2(2, 2)), colour.lightened(0.15))
