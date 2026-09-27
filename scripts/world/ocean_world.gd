extends Node2D
## The world: the home island, the sea around it, the ranger and their boat.

const TENT_PATH := "res://data/buildings/tent.tres"


func _ready() -> void:
	if not SaveGame.attach(self):
		return
	# A new game: make your ranger, then pitch your tent (older saves get whichever is missing).
	if not RangerProfile.created:
		$AvatarCreator.open()
		await $AvatarCreator.closed
	if not _has_home():
		$BuildMode.start(load(TENT_PATH), true)


func _has_home() -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"sleep":
			return true
	return false
