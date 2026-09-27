extends Node2D
## The world: the home island, the sea around it, the ranger and their boat.


func _ready() -> void:
	if SaveGame.attach(self) and not RangerProfile.created:
		$AvatarCreator.open()  # new game (or a save from before avatars): make your ranger first
