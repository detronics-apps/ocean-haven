extends Node2D
## The world: the home island, the sea around it, the ranger and their boat.

const TENT_PATH := "res://data/buildings/tent.tres"
## Phones and tablets shrink the PC-sized layout a lot; scale everything back up there.
const TOUCH_SCALE := 1.5


func _ready() -> void:
	if not SaveGame.attach(self):
		return
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		get_window().content_scale_factor = TOUCH_SCALE
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		# e.g. a phone browser blocking storage for a game embedded in another site.
		$HUD.show_warning("This browser won't keep your progress here. Open the game in its own tab or try another browser to save.")
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
