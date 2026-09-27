class_name Avatar
extends Node2D
## The ranger's layered sprite. Follows RangerProfile, so the creator preview,
## the ranger on foot and the ranger in the boat always match.


func _ready() -> void:
	RangerProfile.look_changed.connect(apply)
	apply()


func apply() -> void:
	$Skin.modulate = RangerProfile.pick("skin")
	$Eyes.modulate = RangerProfile.pick("eyes")
	$Trousers.modulate = RangerProfile.pick("trousers")
	$Shirt.modulate = RangerProfile.pick("shirt")
	$Backpack.modulate = RangerProfile.pick("backpack")
	$Hair.texture = RangerProfile.pick("hair")
	$Hair.modulate = RangerProfile.pick("hair_colour")
	$Hat.texture = RangerProfile.pick("hat")  # null = no hat
	$Hat.modulate = RangerProfile.pick("hat_colour")
