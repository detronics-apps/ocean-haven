class_name IslandSleep
extends Node
## Islands the ranger isn't on sleep (the phone: a full late game ran every island's animals,
## litter and trees every frame, and lagged): their animals, floating litter, people and
## buildings, and the island's own trees, kelp beds, reef patches and dark areas stop running
## per-frame code (and offer the HUD nothing), and wake as the ranger arrives. What happens on those islands was already paused while the
## ranger is away (Regions.ranger_on) and catches up on return; the ecosystems themselves keep
## running (they do that pausing). A few things are looked at each frame; all of them at once when
## the ranger comes to another island.

## What sleeps: animals, litter, buildings, people, trees, kelp beds, reef patches and dark areas
## (not the ecosystems).
const GROUPS: Array[StringName] = [&"animals", &"debris", &"buildings", &"people", &"plants",
	&"kelp_beds", &"reef_patches", &"deep_sectors"]
const PER_FRAME := 12

var _here: RegionData
var _queue: Array = []
## A sleeping thing -> the process_mode it had (given back when it wakes).
var _asleep := {}


func _process(_delta: float) -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position)
	if here != _here:  # (a new island: everything at once)
		_here = here
		_queue = _everything()
		_sweep(_queue.size())
		return
	if _queue.is_empty():
		_queue = _everything()
	_sweep(PER_FRAME)


## Whether `node` is asleep now (for tests and the curious).
func is_asleep(node: Node) -> bool:
	return _asleep.has(node)


func _everything() -> Array:
	for node in _asleep.keys():  # (forget the ones that are gone)
		if not is_instance_valid(node):
			_asleep.erase(node)
	var all: Array = []
	for group in GROUPS:
		all.append_array(get_tree().get_nodes_in_group(group))
	return all


func _sweep(count: int) -> void:
	for i in mini(count, _queue.size()):
		var node = _queue.pop_back()  # (untyped: it may have gone since, e.g. litter picked up)
		if is_instance_valid(node) and node is Node2D and node.is_inside_tree():
			_settle(node, Regions.nearest((node as Node2D).global_position) != _here)


func _settle(node: Node, sleep: bool) -> void:
	if sleep:
		if not _asleep.has(node) and node.process_mode != Node.PROCESS_MODE_DISABLED:
			_asleep[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
	elif _asleep.has(node):
		# (a young one not born yet stays put away, as Births left it; one hidden until it's
		# time to show, like the first turtle, wakes: it looks out for that itself)
		if node.process_mode == Node.PROCESS_MODE_DISABLED and not node.get("unborn"):
			node.process_mode = _asleep[node]
		_asleep.erase(node)
